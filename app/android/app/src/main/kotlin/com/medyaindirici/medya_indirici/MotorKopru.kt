package com.medyaindirici.medya_indirici

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.youtubedl_android.YoutubeDLException
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Collections
import java.util.concurrent.Executors

/**
 * Flutter ile gomulu yt-dlp arasindaki kopru.
 *
 * ## Burasi uygulamanin kalbi
 * Masaustundeki `mp3_donusturucu.py` ne yapiyorsa aynisi — sadece PC yerine
 * telefonun icinde. Gomulu Python 3.8 + yt-dlp + ffmpeg burada calisiyor.
 *
 * ## Neden her sey ayri is parcaciginda?
 * `getInfo` ve `execute` **bloklayan** cagrilar; bir Instagram linkini
 * cozmek 1-3 saniye, indirme dakikalar surebiliyor. Ana is parcaciginda
 * calistirilirlarsa arayuz tamamen donar ve Android "uygulama yanit
 * vermiyor" uyarisi cikarir.
 *
 * Sonuclar `Handler(Looper.getMainLooper())` ile ana is parcacigina geri
 * tasiniyor: `MethodChannel.Result` ve `EventChannel.EventSink` yalnizca
 * oradan cagrilabilir.
 *
 * ## Hatalar `Throwable` olarak yakalaniyor, `Exception` olarak degil
 * Bu dosyadaki her cagri gomulu bir ikiliye gidiyor. Ikili acilamadiginda
 * JVM `UnsatisfiedLinkError` firlatiyor ve o bir **`Error`**, `Exception`
 * degil — `catch (Exception)` onu KACIRIR. Havuz is parcaciginda
 * yakalanmayan bir Throwable ise surecin tamamini oldurur.
 *
 * Bu yuzden buradaki yakalamalar bilerek `Throwable`. Kural: **motorun
 * cokmesi uygulamayi cokertmez.** Kullanici en kotu ihtimalle "motor
 * calismiyor" mesaji gorur, kapanan bir uygulama degil.
 *
 * ## Ilerleme neden ayri kanaldan?
 * MethodChannel tek soru-tek cevap icin. Indirme boyunca onlarca ilerleme
 * bildirimi geliyor; bunlar EventChannel'dan akiyor ve her bildirim hangi
 * ise ait oldugunu `isKimlik` ile soyluyor.
 */
class MotorKopru(private val baglam: Context) {

    companion object {
        private const val ETIKET = "MotorKopru"
        const val KOMUT_KANALI = "medyaindirici/motor"
        const val ILERLEME_KANALI = "medyaindirici/motor/ilerleme"

        /**
         * Instagram'a gonderilen tarayici basligi.
         *
         * Instagram tanimadigi istemcilere bazi gonderileri vermiyor ve
         * "giris yapmayi gerektiriyor" diyor. YALNIZ Instagram'da
         * kullaniliyor — genel ayarlamak YouTube'u bozar.
         */
        const val MASAUSTU_TARAYICI =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }

    /** Indirme ve cozumleme isleri bu havuzda calisiyor. */
    private val havuz = Executors.newFixedThreadPool(2)

    private val anaIsParcacigi = Handler(Looper.getMainLooper())

    private var ilerlemeAkisi: EventChannel.EventSink? = null

    /** Inen dosyayi telefonun ortak klasorune cikaran katman. */
    private val kaydedici = MedyaKaydedici(baglam)

    /**
     * Iptali istenen islerin kimlikleri.
     *
     * Surec olduruldugunde `execute` istisna firlatiyor ama bu istisna
     * "kullanici durdurdu" ile "indirme bozuldu" arasinda ayrim yapmiyor.
     * Ayrimi burada tutuyoruz: iptal edilen iste yarim dosyalar siliniyor
     * ve Flutter tarafina ayri bir hata kodu gidiyor.
     *
     * Iptal komutu indirme is parcaciginda degil, ana is parcaciginda
     * geliyor — bu yuzden es zamanli erisime acik bir kume.
     */
    private val iptalEdilenler: MutableSet<String> =
        Collections.synchronizedSet(HashSet())

    /**
     * Motor kuruldu mu? Kurulum bir kez yapiliyor ve **basarisiz olabilir**
     * (yer yok, ikili acilamadi). Basarisizsa her cagri anlamli bir hata
     * donuyor; sessizce calismamis gibi yapmiyor.
     */
    // @Volatile SART: bu iki alan havuz is parcaciginda YAZILIP ana is
    // parcaciginda OKUNUYOR. Isaretlenmezse ana is parcacigi eski degeri
    // onbellekten okuyabiliyor ve motor hazir oldugu halde arayuz sonsuza
    // kadar "hazirlaniyor" gosterebiliyor.
    @Volatile
    private var hazir = false

    @Volatile
    private var kurulumHatasi: String? = null

    /**
     * Kurulum basarisiz oldugunda ortamin fotografi.
     *
     * ## Nicin gerekiyor
     * "Motor baslatilamadi" tek basina hicbir sey soylemiyor. Sebep genelde
     * su ucundan biri ve ucu de disaridan gorunmuyor:
     * cihazin mimarisi APK'ninkiyle uyusmuyor, gomulu ikili kurulumda
     * diske acilmamis, ya da telefonda yer yok.
     *
     * Cihaz `adb`'ye baglanamadiginda (USB hata ayiklama kapali) logcat
     * alinamiyor. Bu rapor sayesinde uygulama kendi tanisini kendi
     * koyabiliyor: kullanici Ayarlar'dan metni kopyalayip iletebiliyor.
     */
    @Volatile
    private var kurulumRaporu: String? = null

    /** Ayni anda iki kurulum baslamasin. */
    @Volatile
    private var kurulumSuruyor = false

    fun kur() {
        if (hazir || kurulumSuruyor) return
        kurulumSuruyor = true

        havuz.execute {
            try {
                YoutubeDL.getInstance().init(baglam)
                FFmpeg.getInstance().init(baglam)
                hazir = true
                kurulumHatasi = null
                kurulumRaporu = null
                Log.i(ETIKET, "Motor hazir")
            } catch (h: Throwable) {
                // `Exception` DEGIL `Throwable` yakalaniyor.
                //
                // Gomulu ikili acilamadiginda JVM `UnsatisfiedLinkError`
                // firlatiyor ve o bir `Error`, `Exception` degil. Yalnizca
                // `Exception` yakalanirsa hata buradan KACIYOR; havuz is
                // parcaciginda yakalanmayan bir Throwable ise Android'in
                // varsayilan isleyicisine gidip **surecin tamamini
                // olduruyor**. Uygulama acilir acilmaz kapaniyor ve
                // kullanici "Sürekli durduruluyor" uyarisi goruyor.
                //
                // Motor kurulamasa bile uygulama ayakta kalmali: kullanici
                // gecmisine bakabilmeli, ayarlari acabilmeli ve en onemlisi
                // NEDEN calismadigini gorebilmeli.
                // Ham metin degil, TUM zincir saklaniyor: YoutubeDLException
                // genelde asil sebebi (IOException, ZipException...) sarmaliyor
                // ve disardaki mesaj "failed to initialize" gibi bos bir cumle
                // oluyor.
                kurulumHatasi = hataZinciri(h)
                kurulumRaporu = ortamRaporu()
                Log.e(ETIKET, "Motor kurulamadi\n$kurulumRaporu", h)
            } finally {
                kurulumSuruyor = false
            }
        }
    }

    /** Istisnayi sebep zinciriyle birlikte okunur metne cevirir. */
    private fun hataZinciri(h: Throwable): String {
        val yazi = StringBuilder()
        var suanki: Throwable? = h
        var derinlik = 0

        // Zincir kendini tekrar edebiliyor; derinlik sinirli.
        while (suanki != null && derinlik < 6) {
            if (derinlik > 0) yazi.append("\n  sebep: ")
            yazi.append(suanki.javaClass.simpleName)
            suanki.message?.let { yazi.append(": ").append(it) }
            suanki = suanki.cause
            derinlik++
        }
        return yazi.toString()
    }

    /**
     * Kurulumun basarisiz olabilecegi uc sebebi de gosteren ortam raporu.
     *
     * Sirasiyla: cihaz mimarisi, gomulu ikililerin diske acilip acilmadigi,
     * bos alan.
     */
    private fun ortamRaporu(): String {
        val yazi = StringBuilder()

        yazi.append("Cihaz: ${Build.MANUFACTURER} ${Build.MODEL}")
        yazi.append(" (Android ${Build.VERSION.RELEASE}, API ${Build.VERSION.SDK_INT})\n")
        yazi.append("Cihaz mimarileri: ${Build.SUPPORTED_ABIS.joinToString()}\n")

        // ASIL SORU: gomulu ikililer kurulumda diske acilmis mi?
        // Acilmamissa YoutubeDL.init() zaten calisamaz.
        val ikiliKlasoru = baglam.applicationInfo.nativeLibraryDir
        yazi.append("Ikili klasoru: $ikiliKlasoru\n")
        try {
            val dosyalar = File(ikiliKlasoru).listFiles()
            if (dosyalar == null || dosyalar.isEmpty()) {
                yazi.append("  BOS - gomulu ikililer diske ACILMAMIS\n")
            } else {
                dosyalar.sortedBy { it.name }.forEach {
                    yazi.append("  ${it.name}  ${it.length() / 1024} KB\n")
                }
            }
        } catch (h: Throwable) {
            yazi.append("  okunamadi: ${h.javaClass.simpleName}\n")
        }

        try {
            val klasor = baglam.noBackupFilesDir
            val bosMb = klasor.usableSpace / (1024 * 1024)
            yazi.append("Calisma klasoru: ${klasor.absolutePath}\n")
            yazi.append("Bos alan: $bosMb MB")
            if (bosMb < 300) yazi.append("  ← AZ OLABILIR")
        } catch (h: Throwable) {
            yazi.append("Bos alan okunamadi: ${h.javaClass.simpleName}")
        }

        return yazi.toString()
    }

    fun kanallariBagla(mesajci: BinaryMessenger) {
        MethodChannel(mesajci, KOMUT_KANALI).setMethodCallHandler { cagri, cevap ->
            when (cagri.method) {
                // Yalnizca "hazir mi" yetmiyor: kurulum BASARISIZ da
                // olabiliyor ve o durumda arayuzun sonsuza kadar beklemek
                // yerine sebebi gostermesi gerekiyor.
                "motorDurumu" -> cevap.success(
                    mapOf(
                        "hazir" to hazir,
                        "hata" to kurulumHatasi,
                        "rapor" to kurulumRaporu,
                    )
                )

                // Kurulum basarisiz olduysa uygulamayi yeniden baslatmadan
                // yeniden denenebilsin. Gecici bir sebep (yer yoksa acilan
                // alan gibi) icin uygulamayi kapatip acmak gereksiz.
                "motoruYenidenKur" -> {
                    kur()
                    cevap.success(null)
                }
                "motorSurumu" -> motorSurumu(cevap)
                "cozumle" -> {
                    val adres = cagri.argument<String>("adres")
                    if (adres == null) cevap.error("ADRES_YOK", "Adres verilmedi", null)
                    else cozumle(adres, cevap)
                }
                "indir" -> indir(cagri.argument("adres"),
                    cagri.argument("tur"),
                    cagri.argument("formatKimlik"),
                    cagri.argument("sesIceriyor") ?: false,
                    cagri.argument("isKimlik"),
                    cagri.argument("hedefKlasor"),
                    cagri.argument("mp3Zorla") ?: false,
                    cevap)
                "motoruGuncelle" -> motoruGuncelle(cevap)
                "iptal" -> {
                    val isKimlik = cagri.argument<String>("isKimlik")
                    if (isKimlik == null) {
                        cevap.error("KIMLIK_YOK", "Is kimligi verilmedi", null)
                    } else {
                        iptalEt(isKimlik, cevap)
                    }
                }
                else -> cevap.notImplemented()
            }
        }

        EventChannel(mesajci, ILERLEME_KANALI).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(argumanlar: Any?, akis: EventChannel.EventSink?) {
                    ilerlemeAkisi = akis
                }

                override fun onCancel(argumanlar: Any?) {
                    ilerlemeAkisi = null
                }
            }
        )
    }

    // ------------------------------------------------------------- komutlar

    private fun motorSurumu(cevap: MethodChannel.Result) {
        havuz.execute {
            val surum = try {
                YoutubeDL.getInstance().version(baglam)
            } catch (h: Throwable) {
                null
            }
            anaIsParcacigi.post { cevap.success(surum) }
        }
    }

    private fun motoruGuncelle(cevap: MethodChannel.Result) {
        havuz.execute {
            try {
                val sonuc = YoutubeDL.getInstance()
                    .updateYoutubeDL(baglam, YoutubeDL.UpdateChannel.STABLE)
                anaIsParcacigi.post { cevap.success(sonuc?.name) }
            } catch (h: Throwable) {
                anaIsParcacigi.post {
                    cevap.error("GUNCELLEME_HATASI", h.message, null)
                }
            }
        }
    }

    /**
     * Suren indirmeyi durdurur.
     *
     * Once kimlik "iptal edildi" olarak isaretleniyor, sonra surec
     * olduruluyor. Sira onemli: surec olunce [indir] hemen istisna yakalayip
     * temizlige giriyor ve o an isaretin konulmus olmasi gerekiyor.
     *
     * `destroyProcessById` calisan bir surec bulamazsa `false` donuyor —
     * bu bir hata degil, is zaten bitmis olabilir. Yine de isaret
     * temizleniyor ki kimlik kumede birikip kalmasin.
     */
    private fun iptalEt(isKimlik: String, cevap: MethodChannel.Result) {
        iptalEdilenler.add(isKimlik)

        val durduruldu = try {
            YoutubeDL.getInstance().destroyProcessById(isKimlik)
        } catch (h: Throwable) {
            Log.w(ETIKET, "Surec durdurulamadi: $isKimlik", h)
            false
        }

        if (!durduruldu) iptalEdilenler.remove(isKimlik)
        cevap.success(durduruldu)
    }

    private fun cozumle(adres: String, cevap: MethodChannel.Result) {
        if (!hazirDegilseHataVer(cevap)) return

        havuz.execute {
            try {
                val bilgi = YoutubeDL.getInstance().getInfo(adres)

                val sesler = ArrayList<Map<String, Any?>>()
                val videolar = ArrayList<Map<String, Any?>>()

                bilgi.formats?.forEach { f ->
                    val sesVar = f.acodec != null && f.acodec != "none"
                    val goruntuVar = f.vcodec != null && f.vcodec != "none"

                    // Ne sesi ne goruntusu olan formatlar (yalnizca altyazi,
                    // storyboard vb.) listeye girmiyor.
                    if (!sesVar && !goruntuVar) return@forEach

                    val kayit = mapOf(
                        "formatKimlik" to f.formatId,
                        // Bu format kendi icinde ses TASIYOR mu?
                        //
                        // YouTube yuksek cozunurluklu videoyu SESSIZ veriyor
                        // (DASH): `137` = 1080p, ses yok. Bu bilgi tasinmazsa
                        // indirme `-f 137` olarak gidiyor, tek akis iniyor ve
                        // ortada birlestirilecek ses olmuyor — video sessiz
                        // kaydediliyor. Telefonda tam bu yasandi.
                        "sesVarMi" to sesVar,
                        "uzanti" to f.ext,
                        "boyutBayt" to f.fileSize.takeIf { it > 0 },
                        "etiket" to formatEtiketi(f.formatNote, f.height, f.abr, goruntuVar),
                        "yukseklik" to f.height,
                    )

                    if (goruntuVar) videolar.add(kayit) else sesler.add(kayit)
                }

                // En iyi kalite basta olsun: arayuz listenin ilkini "onerilen"
                // sayiyor.
                videolar.sortByDescending { (it["yukseklik"] as? Int) ?: 0 }
                sesler.sortByDescending { (it["boyutBayt"] as? Long) ?: 0L }

                val sonuc = mapOf(
                    "adres" to adres,
                    "baslik" to (bilgi.title ?: adres),
                    "kapakAdresi" to bilgi.thumbnail,
                    "sureSaniye" to bilgi.duration.takeIf { it > 0 },
                    "yukleyen" to bilgi.uploader,
                    "kaynak" to kaynakBul(bilgi.extractorKey, adres),
                    "sesSecenekleri" to sesler,
                    "videoSecenekleri" to videolar,
                )

                anaIsParcacigi.post { cevap.success(sonuc) }
            } catch (h: Throwable) {
                Log.e(ETIKET, "Cozumleme hatasi: $adres", h)
                anaIsParcacigi.post {
                    cevap.error("COZUMLEME_HATASI", h.message, null)
                }
            }
        }
    }

    /**
     * Video indirmede kullanilacak yt-dlp format kurali.
     *
     * ## Sessiz video sorunu
     * YouTube yuksek cozunurluklu videoyu **sessiz** veriyor (DASH):
     * `137` = 1080p goruntu, ses ayri bir formatta. Secilen kimlik
     * dogrudan `-f 137` olarak gonderilirse tek akis iniyor ve ortada
     * birlestirilecek ses olmuyor — `--merge-output-format` bu durumu
     * kurtaramaz, cunku birlestirecek ikinci parca hic indirilmemistir.
     *
     * Cozum: format kendi icinde ses tasimiyorsa `+bestaudio` ekleniyor.
     * Zaten sesli olan formatlara eklenmiyor — eklenirse dosyaya ikinci
     * bir ses izi girer.
     */
    private fun videoFormatKurali(
        formatKimlik: String?,
        sesIceriyor: Boolean,
    ): String = when {
        // Kullanici kalite secmedi: en iyi goruntu + en iyi ses, ikisi de
        // bulunamazsa tek parca gelen en iyi dosya.
        formatKimlik == null ->
            "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"

        // Secilen format zaten sesli (Instagram'da hep boyle).
        sesIceriyor -> formatKimlik

        // Sessiz goruntu: ses eklenmeli. Once mp4 ile uyumlu m4a deneniyor,
        // sonra herhangi bir ses, en sonda tek parca yedegi.
        else ->
            "$formatKimlik+bestaudio[ext=m4a]/$formatKimlik+bestaudio/best"
    }

    private fun indir(
        adres: String?,
        tur: String?,
        formatKimlik: String?,
        sesIceriyor: Boolean,
        isKimlik: String?,
        hedefKlasor: String?,
        mp3Zorla: Boolean,
        cevap: MethodChannel.Result,
    ) {
        if (adres == null || tur == null || isKimlik == null || hedefKlasor == null) {
            cevap.error("EKSIK_ARGUMAN", "Indirme icin gerekli bilgiler eksik", null)
            return
        }
        if (!hazirDegilseHataVer(cevap)) return

        havuz.execute {
            val klasor = File(hedefKlasor).apply { mkdirs() }

            // Indirmeden ONCE klasorde ne varsa not ediliyor. Sebep:
            // yt-dlp uretilen dosyanin yolunu geriye dondurmuyor; dosya
            // adini basliktan tahmin etmek ise uzanti ve temizleme
            // kurallari yuzunden guvenilmez. Sonradan "yeni ne olustu"
            // diye bakmak kesin sonuc veriyor.
            //
            // `try` blogunun DISINDA duruyorlar: iptal temizligi de bu
            // listeye ihtiyac duyuyor ve o kod `catch` icinde calisiyor.
            val oncekiler = klasor.list()?.toSet() ?: emptySet()

            try {
                val istek = YoutubeDLRequest(adres)
                istek.addOption("-o", "${klasor.absolutePath}/%(title).100s.%(ext)s")
                istek.addOption("--no-playlist")
                istek.addOption("--no-mtime")

                if (tur == "ses") {
                    if (mp3Zorla) {
                        // Gercek donusturme: ffmpeg calisir, yavastir.
                        istek.addOption("-x")
                        istek.addOption("--audio-format", "mp3")
                        istek.addOption("--audio-quality", "0")
                    } else {
                        // Hazir ses akisi dogrudan iniyor — donusturme yok,
                        // saniyeler suruyor. Cogu durumda istenen bu.
                        istek.addOption("-f", formatKimlik ?: "bestaudio/best")
                    }
                } else {
                    istek.addOption("-f", videoFormatKurali(formatKimlik, sesIceriyor))

                    // Ses ve goruntu ayri indiginde ffmpeg ikisini mp4'te
                    // birlestiriyor. Tek parca gelen kaynaklarda (Instagram)
                    // bu adim zaten hic calismiyor.
                    istek.addOption("--merge-output-format", "mp4")
                }

                // Instagram bazi gonderileri tanimadigi istemcilere
                // vermiyor ve "giris yapmayi gerektiriyor" diyor.
                //
                // Basligi YALNIZ Instagram'a veriyoruz. Genel olarak
                // ayarlamak YouTube'u bozabilir: YouTube gelen basliga gore
                // farkli oynatici yaniti donduruyor ve yt-dlp'nin kendi
                // ayarladigi basligi ezmek yeni kirilmalar uretir.
                if (adres.contains("instagram", ignoreCase = true)) {
                    istek.addOption("--user-agent", MASAUSTU_TARAYICI)
                }

                YoutubeDL.getInstance().execute(istek, isKimlik) { yuzde, kalanSaniye, satir ->
                    ilerlemeYolla(isKimlik, yuzde, kalanSaniye, satir)
                }

                val yeniDosya = yeniDosyalar(klasor, oncekiler).firstOrNull()

                if (yeniDosya == null) {
                    anaIsParcacigi.post {
                        cevap.error("DOSYA_BULUNAMADI",
                            "İndirme bitti ama dosya oluşmadı", null)
                    }
                } else {
                    // Dosya ancak burada, indirme TAMAMLANDIKTAN sonra
                    // telefonun ortak klasorune cikiyor. Indirme sirasinda
                    // cikarilsaydi yarim dosya muzik calarda gorunurdu.
                    val sonuc = kaydedici.kaydet(yeniDosya, tur == "ses")
                    anaIsParcacigi.post {
                        cevap.success(
                            mapOf(
                                "yol" to sonuc.yol,
                                "kayitYeri" to sonuc.kayitYeri,
                            )
                        )
                    }
                }
            } catch (h: Throwable) {
                // Iptal de buraya dusuyor: surec olduruldugunde `execute`
                // istisna firlatiyor. Ayrimi `iptalEdilenler` yapiyor.
                val iptalMi = iptalEdilenler.remove(isKimlik)

                if (iptalMi) {
                    // Yarim inen dosyalar siliniyor. Birakilirsa bir sonraki
                    // indirmede "yeni olusan dosya" aramasi onlari bulur ve
                    // yanlis dosyayi kullaniciya teslim ederdi.
                    yariminKalanlariSil(klasor, oncekiler)
                    Log.i(ETIKET, "Indirme iptal edildi: $isKimlik")
                    anaIsParcacigi.post {
                        cevap.error("IPTAL_EDILDI", "Indirme iptal edildi", null)
                    }
                } else {
                    Log.e(ETIKET, "Indirme hatasi: $adres", h)
                    anaIsParcacigi.post {
                        cevap.error("INDIRME_HATASI", h.message, null)
                    }
                }
            } finally {
                iptalEdilenler.remove(isKimlik)
            }
        }
    }

    /** Indirme baslamadan once orada olmayan dosyalar. */
    private fun yeniDosyalar(klasor: File, oncekiler: Set<String>): List<File> =
        klasor.listFiles()?.filter { it.name !in oncekiler } ?: emptyList()

    /**
     * Iptal edilen indirmenin geride biraktigi dosyalari siler.
     *
     * yt-dlp yarim indirmeyi `.part` uzantisiyla birakiyor, birlestirme
     * asamasinda ise gecici parcalar olusuyor. Hicbiri calisan bir dosya
     * degil; telefonda yer kaplamalari disinda bir islevleri yok.
     */
    private fun yariminKalanlariSil(klasor: File, oncekiler: Set<String>) {
        try {
            yeniDosyalar(klasor, oncekiler).forEach { dosya ->
                if (dosya.delete()) {
                    Log.i(ETIKET, "Yarim dosya silindi: ${dosya.name}")
                }
            }
        } catch (h: Throwable) {
            // Temizlik basarisiz olsa da kullanici acisindan is bitti;
            // hata gostermek anlamsiz olurdu.
            Log.w(ETIKET, "Yarim dosyalar silinemedi", h)
        }
    }

    // -------------------------------------------------------------- yardimci

    /** Motor hazir degilse hata dondurup `false` verir. */
    private fun hazirDegilseHataVer(cevap: MethodChannel.Result): Boolean {
        if (hazir) return true
        cevap.error(
            "MOTOR_HAZIR_DEGIL",
            kurulumHatasi ?: "İndirme motoru henüz hazır değil, birkaç saniye sonra dene",
            null,
        )
        return false
    }

    private fun ilerlemeYolla(
        isKimlik: String,
        yuzde: Float,
        kalanSaniye: Long,
        satir: String,
    ) {
        anaIsParcacigi.post {
            ilerlemeAkisi?.success(
                mapOf(
                    "isKimlik" to isKimlik,
                    // yt-dlp 0-100 veriyor, arayuz 0-1 bekliyor.
                    // Negatif geldiginde (bilinmiyor) null yolluyoruz ki
                    // arayuz belirsiz cubuk gostersin.
                    "oran" to if (yuzde >= 0) yuzde / 100.0 else null,
                    "kalanSaniye" to kalanSaniye.takeIf { it > 0 },
                    "satir" to satir,
                )
            )
        }
    }

    /**
     * Kullaniciya gosterilecek kalite etiketi.
     * Video icin cozunurluk (`720p`), ses icin bit hizi (`128 kbps`).
     */
    private fun formatEtiketi(
        not: String?,
        yukseklik: Int,
        abr: Int,
        goruntuVar: Boolean,
    ): String = when {
        goruntuVar && yukseklik > 0 -> "${yukseklik}p"
        // `abr` (ortalama bit hizi) youtubedl-android 0.18.1'de Int.
        // Float yazilmisti ve derleme bu satirda kaliyordu.
        !goruntuVar && abr > 0 -> "$abr kbps"
        !not.isNullOrBlank() -> not
        else -> "bilinmiyor"
    }

    /** yt-dlp'nin cikarici adini arayuzun bekledigi kisa ada cevirir. */
    private fun kaynakBul(cikarici: String?, adres: String): String {
        val k = (cikarici ?: "").lowercase()
        val a = adres.lowercase()
        return when {
            k.contains("instagram") || a.contains("instagram") -> "instagram"
            k.contains("youtube") || a.contains("youtu") -> "youtube"
            k.contains("facebook") || a.contains("facebook") || a.contains("fb.watch") -> "facebook"
            k.contains("tiktok") || a.contains("tiktok") -> "tiktok"
            else -> "diger"
        }
    }
}
