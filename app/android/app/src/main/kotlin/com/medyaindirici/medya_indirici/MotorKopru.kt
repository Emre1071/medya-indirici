package com.medyaindirici.medya_indirici

import android.content.Context
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
    private var hazir = false
    private var kurulumHatasi: String? = null

    fun kur() {
        havuz.execute {
            try {
                YoutubeDL.getInstance().init(baglam)
                FFmpeg.getInstance().init(baglam)
                hazir = true
                Log.i(ETIKET, "Motor hazir")
            } catch (h: YoutubeDLException) {
                kurulumHatasi = h.message
                Log.e(ETIKET, "Motor kurulamadi", h)
            } catch (h: Exception) {
                kurulumHatasi = h.message
                Log.e(ETIKET, "Motor kurulamadi", h)
            }
        }
    }

    fun kanallariBagla(mesajci: BinaryMessenger) {
        MethodChannel(mesajci, KOMUT_KANALI).setMethodCallHandler { cagri, cevap ->
            when (cagri.method) {
                "hazirMi" -> cevap.success(hazir)
                "motorSurumu" -> motorSurumu(cevap)
                "cozumle" -> {
                    val adres = cagri.argument<String>("adres")
                    if (adres == null) cevap.error("ADRES_YOK", "Adres verilmedi", null)
                    else cozumle(adres, cevap)
                }
                "indir" -> indir(cagri.argument("adres"),
                    cagri.argument("tur"),
                    cagri.argument("formatKimlik"),
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
            } catch (h: Exception) {
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
            } catch (h: Exception) {
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
        } catch (h: Exception) {
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
            } catch (h: Exception) {
                Log.e(ETIKET, "Cozumleme hatasi: $adres", h)
                anaIsParcacigi.post {
                    cevap.error("COZUMLEME_HATASI", h.message, null)
                }
            }
        }
    }

    private fun indir(
        adres: String?,
        tur: String?,
        formatKimlik: String?,
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
                    // Video + ses. yt-dlp gerekiyorsa ikisini ffmpeg ile
                    // birlestiriyor; Instagram'da tek parca geldigi icin
                    // birlestirme adimi genelde hic calismiyor.
                    istek.addOption("-f", formatKimlik ?: "bestvideo+bestaudio/best")
                    istek.addOption("--merge-output-format", "mp4")
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
            } catch (h: Exception) {
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
        } catch (h: Exception) {
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
