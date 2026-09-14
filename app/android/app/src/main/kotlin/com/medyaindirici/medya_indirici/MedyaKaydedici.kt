package com.medyaindirici.medya_indirici

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import java.io.File

/**
 * Inen dosyayi telefonun ortak Muzik / Filmler klasorune cikarir.
 *
 * ## Nicin gerekli
 * yt-dlp dosyayi uygulamanin **kendi** klasorune indiriyor. Orasi diger
 * uygulamalara kapali: dosya iner, "İndirildi" yazar, ama muzik calarda,
 * galeride veya WhatsApp'ta gorunmez. Kullanici acisindan indirme hic
 * olmamis gibidir. Bu sinif dosyayi disari cikarip MediaStore'a kaydeder;
 * kaydedildigi anda telefonun butun oynaticilari onu gorur.
 *
 * ## Iki ayri yol var, ikisi de gerekli
 * Android 10 (API 29) ile birlikte **kapsamli depolama** (scoped storage)
 * geldi ve ortak klasorlere duz dosya yolu ile yazmak kapandi.
 *
 * - **API 29 ve ustu:** MediaStore'a bir kayit acilir, dosya o kaydin
 *   akisina yazilir. **Hicbir izin gerekmiyor** — uygulama kendi ekledigi
 *   medyayi izinsiz yazabiliyor. (Android 13'te gelen `READ_MEDIA_AUDIO` /
 *   `READ_MEDIA_VIDEO` izinleri *baskalarinin* medyasini OKUMAK icin;
 *   burada yazma yaptigimiz icin onlar da gerekmiyor.)
 * - **API 24-28:** Ortak klasore duz dosya olarak yazilir ve medya
 *   tarayicisina haber verilir. Burada `WRITE_EXTERNAL_STORAGE` izni
 *   **gerekiyor** (`MainActivity` acilista istiyor).
 *
 * ## Basarisizlik sessiz degil
 * Cikarma her nedenle basarisiz olabilir (izin verilmedi, yer yok, ad
 * cakismasi). O durumda dosya **silinmiyor** — uygulamanin klasorunde
 * kaliyor ve [Sonuc.kayitYeri] `null` donuyor. Arayuz bunu ayri gosteriyor;
 * "indirildi" deyip kullaniciyi bos yere aratmak en kotu sonuc olurdu.
 */
class MedyaKaydedici(private val baglam: Context) {

    companion object {
        private const val ETIKET = "MedyaKaydedici"

        /**
         * Ortak klasorlerin altinda acilan uygulama klasoru.
         *
         * 🔑 **ASCII.** Eskiden `Medya İndirici` yaziyordu ve icindeki `İ`
         * (U+0130) gercek bir risk: bu klasor adi dosya sisteminde birebir
         * olusuyor, SD kart FAT/exFAT ile bicimlendirilmis olabiliyor ve
         * uretici tarayicilarinin (MIUI) non-ASCII yol islemesi tutarsiz.
         * Ad ASCII olunca degisken sayisi bir azaliyor.
         *
         * ⚠️ **Eski indirmeler tasinmiyor.** v0.1.3 ve oncesinde inen
         * dosyalar `Medya İndirici` klasorunde kaliyor; yenileri buraya
         * iniyor. Tasima yapilmadi: MediaStore kayitlarini toplu
         * guncellemek, calisan kayitlari bozma riskini "klasor ikiye
         * bolundu"nun onunde tutuyor. Gecmisteki satirlar `content://`
         * adresi tasidigi icin **acilmaya devam ediyor.**
         */
        const val KLASOR = "MedyaIndirici"

        /**
         * Videonun indigi ortak klasor.
         *
         * 🔴 **DCIM, cunku MIUI `Movies/` kokunu taramiyor.** v0.1.4'te
         * `Movies` denendi ve cihazda dogrulandi: dosya
         * `Movies/MedyaIndirici` altinda olusuyor, dosya yoneticisinden
         * aciliyor, ama **MIUI Galerisi'ne hic dusmuyor.** Yani sorun ne
         * klasor adindaki Turkce karakterdi ne de taramanin
         * tetiklenmemesi — MIUI galerisinin taradigi **kok kumesi**.
         *
         * DCIM her galeri uygulamasinin taradigi tek koktur; standart
         * cihazlarda da dogru calisiyor.
         *
         * ⚠️ **Bedeli kabul edildi:** DCIM semantik olarak "kamerayla
         * cekilen" demek ve indirilen videolar kullanicinin kendi
         * cekimlerinin arasina giriyor. Ayri bir alt klasorde
         * (`DCIM/MedyaIndirici`) durduklari icin karisiklik klasor
         * seviyesinde degil, yalniz "tum fotograflar" akisinda.
         * Gorunmeyen dosya, yanlis yerde gorunen dosyadan kotudur.
         *
         * ℹ️ Ses bu tartismanin disinda: muzik calarlar
         * `MediaStore.Audio`'yu klasorden bagimsiz okuyor ve galeri sesle
         * ilgilenmiyor. Ses `Music/` altinda kaliyor.
         */
        private val VIDEO_KLASORU = Environment.DIRECTORY_DCIM

        /** Ad cakismasinda kac kez yeniden denenecegi. */
        private const val AD_DENEME_SINIRI = 30
    }

    /**
     * @param yol Dosyanin son yeri. API 29+ ve basarili cikarmada bu bir
     *   `content://` adresidir (kapsamli depolamada duz yol yok).
     * @param kayitYeri Kullaniciya gosterilecek klasor (`Music/Medya İndirici`).
     *   `null` ise cikarma basarisiz oldu, dosya uygulamanin icinde kaldi.
     * @param hataAyrinti Cikarma basarisizsa **sebebin ham metni**.
     *   `kayitYeri` doluyken `null`.
     */
    data class Sonuc(
        val yol: String,
        val kayitYeri: String?,
        val hataAyrinti: String? = null,
    )

    fun kaydet(kaynak: File, sesMi: Boolean): Sonuc {
        if (!kaynak.exists()) {
            return Sonuc(
                kaynak.absolutePath,
                null,
                "Cikarilacak dosya bulunamadi: ${kaynak.absolutePath}",
            )
        }

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                modernKaydet(kaynak, sesMi)
            } else {
                eskiKaydet(kaynak, sesMi)
            }
        } catch (h: Throwable) {
            // Cikarma basarisiz: dosya yerinde kaliyor, indirme kaybolmuyor.
            //
            // 🔑 SEBEP ARTIK KAYBOLMUYOR. Eskiden yalnizca `Log.e`'ye
            // gidiyordu; cihaz `adb`'ye baglanmadigi icin (USB hata
            // ayiklama kapali) o satir hic okunamiyordu ve "galeride
            // gorunmuyor" sikayetinin sebebi hicbir zaman ogrenilemiyordu.
            // Ayni kalip motor kurulum hatasinda sorunu tek seferde
            // cozdurmustu.
            Log.e(ETIKET, "Dosya disari cikarilamadi: ${kaynak.name}", h)
            Sonuc(kaynak.absolutePath, null, cikarmaRaporu(kaynak, sesMi, h))
        }
    }

    /**
     * Cikarma basarisiz oldugunda ortamin fotografi.
     *
     * Yigin izi tek basina yetmiyor: hatanin sebebi cogu zaman **ne
     * gonderdigimizde** (ad, MIME, hedef klasor) saklı. Uc sey birlikte
     * yazilmazsa telefondan gelen rapor okunamaz kaliyor.
     */
    private fun cikarmaRaporu(kaynak: File, sesMi: Boolean, h: Throwable): String {
        val yazi = StringBuilder()
        yazi.append("Dosya: ${kaynak.name}\n")
        yazi.append("Boyut: ${kaynak.length()} bayt\n")
        yazi.append("Hedef: ${anaKlasor(sesMi)}/$KLASOR\n")
        yazi.append("MIME: ${mimeTuru(kaynak, sesMi)}\n")
        yazi.append("Kayit adi: ${kayitAdi(kaynak, sesMi)}\n")
        yazi.append("Android: ${Build.VERSION.SDK_INT}\n")
        yazi.append("Bos alan: ${kaynak.usableSpace} bayt\n\n")
        yazi.append(sebepZinciri(h))
        return yazi.toString()
    }

    /**
     * Istisnanin **butun sebep zinciri**.
     *
     * MediaStore hatalari sarmalanarak geliyor ve distaki mesaj cogu zaman
     * bos; asil cumle (`Mismatched extension`, `ENOSPC`, `Invalid file
     * name`) iki kat iceride duruyor. `MotorKopru` ayni yaklasimi kullaniyor.
     */
    private fun sebepZinciri(h: Throwable): String {
        val yazi = StringBuilder()
        var sira: Throwable? = h
        var derinlik = 0
        while (sira != null && derinlik < 6) {
            yazi.append(if (derinlik == 0) "" else "  sebep: ")
            yazi.append(sira.javaClass.simpleName)
            sira.message?.let { yazi.append(": ").append(it) }
            yazi.append('\n')
            sira = sira.cause
            derinlik++
        }
        return yazi.toString()
    }

    // ------------------------------------------------------- Android 10+

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun modernKaydet(kaynak: File, sesMi: Boolean): Sonuc {
        val cozucu = baglam.contentResolver
        val koleksiyon = if (sesMi) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
        val gorecelYol = "${anaKlasor(sesMi)}/$KLASOR"
        val mime = mimeTuru(kaynak, sesMi)

        val adres = kayitAc(koleksiyon, kayitAdi(kaynak, sesMi), mime, gorecelYol)

        try {
            // Kopyalama bitene kadar kayit "beklemede": yarim dosya bu sure
            // boyunca muzik calarda gorunmuyor. Aksi halde kullanici, daha
            // yazilmakta olan bozuk bir dosyaya dokunabilirdi.
            cozucu.openOutputStream(adres)?.use { cikis ->
                kaynak.inputStream().use { giris -> giris.copyTo(cikis) }
            } ?: throw IllegalStateException("MediaStore akisi acilamadi")

            val bitir = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            val guncellenen = cozucu.update(adres, bitir, null, null)

            // 🔴 Bu kontrol SART.
            //
            // `IS_PENDING` temizlenmezse dosya MediaStore'da "yazilmaya
            // devam ediyor" olarak kaliyor ve galeride/muzik calarda
            // GORUNMUYOR. Sonuc kullanici acisindan tam bir tuzak:
            // uygulama "indirildi" diyor, dosya gercekten orada, ama
            // hicbir yerde acilmiyor.
            //
            // Sessizce gecilseydi bu durumu anlamanin yolu yoktu; hata
            // sayilinca dosya uygulama klasorunde kaliyor ve arayuz
            // "telefonun klasorlerine cikarilamadi" uyarisini gosteriyor.
            if (guncellenen != 1) {
                throw IllegalStateException(
                    "MediaStore kaydi yayimlanamadi (IS_PENDING temizlenmedi)"
                )
            }
        } catch (h: Throwable) {
            // Yarim kalan kayit siliniyor; birakilirsa oynaticilarda
            // acilmayan bos bir sarki olarak gorunurdu.
            cozucu.delete(adres, null, null)
            throw h
        }

        // Kopya disari cikti, uygulamanin icindeki asil dosya artik gereksiz.
        // Silinmezse ayni dosya telefonda iki kez yer kaplardi.
        kaynak.delete()

        // Uretici galerisini uyandir. Basarisiz olsa bile kayit gecerli.
        taramayiZorla(adres)

        return Sonuc(adres.toString(), gorecelYol)
    }

    /**
     * Yeni kaydi uretici galerisine **zorla** duyurur.
     *
     * ## Bu, onceki karari tersine ceviriyor
     * Burada uzun sure "API 29+ yolunda tarama GEREKMIYOR" yaziyordu ve
     * gerekce teoride dogruydu: kaydi MediaStore'un kendisine yaziyoruz,
     * `IS_PENDING` temizlendigi anda dosya AOSP'de gorunur oluyor.
     *
     * 🔴 **Cihazda boyle cikmadi.** Xiaomi/MIUI'de (Redmi Note 9 Pro,
     * Android 12) dosya bazen gorunuyor bazen gorunmuyordu. MIUI galerisi
     * MediaStore'u dogrudan okumuyor; `com.miui.gallery` kendi indeksini
     * tutuyor ve onu tembel guncelliyor. AOSP'de gereksiz olan adim burada
     * belirleyici.
     *
     * ## Ikinci kayit riski nicin gerceklesmiyor
     * Eski gerekce "taramak ikinci bir kayit uretebilir" diyordu. Tarayici
     * **dosya yoluna gore** esleme yapiyor: var olan satiri buluyor ve
     * guncelliyor, yenisini acmiyor. Bu yuzden yol tahmin EDILMIYOR —
     * az once yazdigimiz satirin `DATA` sutunu okunuyor. Tahmin edilen
     * (ve bir harfi tutmayan) bir yol, iste o zaman ikinci kayit uretirdi.
     *
     * ## Hicbir sekilde basarisiz olamaz
     * Dosya zaten yerinde ve MediaStore'da kayitli; bu yalniz bir
     * "haber ver" adimi. Patlamasi indirmeyi basarisiz saydiramaz.
     */
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun taramayiZorla(adres: Uri) {
        try {
            val yol = diskYolu(adres)

            if (yol != null) {
                // Tarayiciya MIME de veriliyor: vermezsek dosyayi uzantidan
                // tanimaya calisiyor ve `.opus`/`.weba` gibi uzantilarda
                // yanlis kategoriye dusurebiliyor.
                MediaScannerConnection.scanFile(
                    baglam,
                    arrayOf(yol),
                    arrayOf(tipiOku(adres)),
                    null,
                )
            } else {
                Log.w(ETIKET, "Tarama icin disk yolu bulunamadi: $adres")
            }

            // Yol okunamasa bile icerik gozlemcileri uyandiriliyor. MIUI
            // galerisi degisiklik bildirimlerini de dinliyor; iki kanal
            // birden denenmis oluyor.
            baglam.contentResolver.notifyChange(adres, null)
        } catch (h: Throwable) {
            // Tarama bir iyilestirme, sart degil. Dosya zaten MediaStore'da.
            Log.w(ETIKET, "Galeri taramasi tetiklenemedi", h)
        }
    }

    /**
     * MediaStore kaydinin diskteki gercek yolu.
     *
     * `DATA` sutunu API 29'da kullanimdan kaldirildi ama **okunabilir
     * kalmaya devam ediyor** — yazmak yasak, okumak degil. Tarayicinin
     * dosya yolundan baska bir girdisi olmadigi icin baska yol yok.
     *
     * Yol kendimiz kurmuyoruz (`RELATIVE_PATH` + `DISPLAY_NAME`):
     * MediaProvider adi degistirmis olabiliyor (uzanti duzeltmesi, ad
     * cakismasinda sayi ekleme). Kurulan yol bir harf tutmazsa tarayici
     * "yeni dosya" sanip IKINCI bir kayit acar — kacinmak istedigimiz sey.
     */
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun diskYolu(adres: Uri): String? {
        @Suppress("DEPRECATION")
        val sutun = MediaStore.MediaColumns.DATA

        baglam.contentResolver
            .query(adres, arrayOf(sutun), null, null, null)
            ?.use { imlec ->
                if (!imlec.moveToFirst()) return null
                val dizin = imlec.getColumnIndex(sutun)
                if (dizin < 0) return null
                return imlec.getString(dizin)?.takeIf { it.isNotBlank() }
            }
        return null
    }

    /** Kaydin MediaStore'daki MIME turu; okunamazsa `null`. */
    private fun tipiOku(adres: Uri): String? =
        try {
            baglam.contentResolver.getType(adres)
        } catch (h: Throwable) {
            Log.w(ETIKET, "MIME okunamadi: $adres", h)
            null
        }

    /**
     * MediaStore kaydini acar; ad cakisirsa sonuna sayi ekleyerek dener.
     *
     * Cakisma gercek bir durum: ayni Reels'i iki kez indirmek siradan.
     * Android surumleri bu durumda farkli davraniyor — bazisi kendisi
     * `(1)` ekliyor, bazisi hata firlatiyor. Kendimiz ele almak iki
     * davranisi da guvenli hale getiriyor.
     */
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun kayitAc(
        koleksiyon: Uri,
        dosyaAdi: String,
        mime: String,
        gorecelYol: String,
    ): Uri {
        val govde = dosyaAdi.substringBeforeLast('.', dosyaAdi)
        val uzanti = dosyaAdi.substringAfterLast('.', "")

        // 🔑 SON ISTISNA SAKLANIYOR.
        //
        // Eskiden dongu icindeki her hata yalnizca `Log.w`'ya gidiyor,
        // dongu tukendiginde de icerigi olmayan bir "kayit acilamadi"
        // firlatiliyordu. Yani asil cumle — `Mismatched extension`,
        // `Invalid file name`, `ENOSPC` — hicbir yere ulasmiyordu.
        // Ad cakismasi disindaki sebepler de ayni sessiz yoldan gidiyordu.
        var sonHata: Throwable? = null

        for (deneme in 0 until AD_DENEME_SINIRI) {
            val ad = when {
                deneme == 0 -> dosyaAdi
                uzanti.isEmpty() -> "$govde ($deneme)"
                else -> "$govde ($deneme).$uzanti"
            }

            val degerler = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, ad)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, gorecelYol)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            try {
                val adres = baglam.contentResolver.insert(koleksiyon, degerler)
                if (adres != null) return adres
                sonHata = IllegalStateException("insert() null dondu ($ad)")
            } catch (h: Throwable) {
                // Ad cakismasi bekleniyor; dongu bir sonraki adi deneyecek.
                Log.w(ETIKET, "Kayit acilamadi ($ad), yeni ad denenecek", h)
                sonHata = h
            }
        }

        throw IllegalStateException(
            "MediaStore kaydi acilamadi ($AD_DENEME_SINIRI ad denendi)",
            sonHata,
        )
    }

    // -------------------------------------------------------- Android 9-

    private fun eskiKaydet(kaynak: File, sesMi: Boolean): Sonuc {
        val izin = ContextCompat.checkSelfPermission(
            baglam,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
        )
        if (izin != PackageManager.PERMISSION_GRANTED) {
            // Izin yoksa dosyaya dokunmuyoruz. Kullaniciya "indirildi ama
            // bulamazsin" demek, arayuzun isi.
            Log.w(ETIKET, "Depolama izni yok, dosya disari cikarilmadi")
            return Sonuc(
                kaynak.absolutePath,
                null,
                "WRITE_EXTERNAL_STORAGE izni verilmemis (Android " +
                    "${Build.VERSION.SDK_INT}). Uygulama ayarlarindan " +
                    "depolama iznini acip tekrar indir.",
            )
        }

        val gorecelYol = "${anaKlasor(sesMi)}/$KLASOR"
        @Suppress("DEPRECATION")
        val kok = Environment.getExternalStoragePublicDirectory(anaKlasor(sesMi))
        val klasor = File(kok, KLASOR)
        if (!klasor.exists() && !klasor.mkdirs()) {
            throw IllegalStateException("Klasor acilamadi: ${klasor.absolutePath}")
        }

        val hedef = bosDosyaAdi(klasor, kayitAdi(kaynak, sesMi))
        kaynak.copyTo(hedef, overwrite = false)
        kaynak.delete()

        // Medya tarayicisina haber verilmezse dosya diskte durur ama muzik
        // calarda ve galeride **gorunmez** — tam kacinmaya calistigimiz sey.
        MediaScannerConnection.scanFile(
            baglam,
            arrayOf(hedef.absolutePath),
            arrayOf(mimeTuru(hedef, sesMi)),
            null,
        )
        return Sonuc(hedef.absolutePath, gorecelYol)
    }

    private fun bosDosyaAdi(klasor: File, dosyaAdi: String): File {
        val govde = dosyaAdi.substringBeforeLast('.', dosyaAdi)
        val uzanti = dosyaAdi.substringAfterLast('.', "")

        for (deneme in 0 until AD_DENEME_SINIRI) {
            val ad = when {
                deneme == 0 -> dosyaAdi
                uzanti.isEmpty() -> "$govde ($deneme)"
                else -> "$govde ($deneme).$uzanti"
            }
            val aday = File(klasor, ad)
            if (!aday.exists()) return aday
        }
        throw IllegalStateException("Bos dosya adi bulunamadi: $dosyaAdi")
    }

    // -------------------------------------------------------------- ortak

    private fun anaKlasor(sesMi: Boolean): String =
        if (sesMi) Environment.DIRECTORY_MUSIC else VIDEO_KLASORU

    /**
     * Dosyanin MIME turu.
     *
     * MediaStore bunu **zorunlu** tutuyor ve yanlis deger dosyanin yanlis
     * kategoriye dusmesine yol aciyor (ses dosyasi videolarda gorunmek
     * gibi). Once kendi tablomuz: yt-dlp'nin verdigi uzantilar belli ve
     * sistemin `MimeTypeMap`'i bazilarini bilmiyor.
     *
     * ⚠️ **Tablo Android'in KENDI eslemesiyle ayni olmak zorunda.**
     * MediaProvider, `DISPLAY_NAME`'in uzantisi ile `MIME_TYPE`
     * uyusmadiginda kendi kararini dayatiyor: ya ada ikinci bir uzanti
     * ekliyor ya da inserti tamamen reddediyor. Iki eski deger bu yuzden
     * degisti:
     *
     * | Uzanti | Onceden | Android'in tablosu | Sonuc |
     * |---|---|---|---|
     * | `.opus` | `audio/opus` | `audio/ogg` | uyusmazlik |
     * | `.webm` (ses) | `audio/webm` | `video/webm` | uyusmazlik |
     *
     * Bu **en sik karsilasilan durum**, istisna degil: `mp3Zorla`
     * varsayilan kapali oldugu icin inen ses dosyasi cogu zaman tam da
     * `.opus` veya `.webm` oluyor. Ses `.webm` icin ad `.weba`'ya
     * ceviriliyor ([kayitAdi]) — AOSP'nin ses-webm uzantisi o.
     */
    private fun mimeTuru(dosya: File, sesMi: Boolean): String {
        val uzanti = dosya.extension.lowercase()

        val bilinen = when (uzanti) {
            "mp3" -> "audio/mpeg"
            "m4a", "m4b" -> "audio/mp4"
            "aac" -> "audio/aac"
            // AOSP `mime.types`: `audio/ogg  oga ogg opus`
            "opus", "ogg", "oga" -> "audio/ogg"
            "flac" -> "audio/flac"
            "wav" -> "audio/wav"
            "mp4", "m4v" -> "video/mp4"
            "mkv" -> "video/x-matroska"
            "3gp" -> "video/3gpp"
            "weba" -> "audio/webm"
            // webm hem ses hem video olabiliyor; yt-dlp'den hangisini
            // istedigimizi biliyoruz. Ses ise ad da `.weba`'ya ceviriliyor.
            "webm" -> if (sesMi) "audio/webm" else "video/webm"
            else -> null
        }
        if (bilinen != null) return bilinen

        val sistemden = MimeTypeMap.getSingleton().getMimeTypeFromExtension(uzanti)
        if (sistemden != null) return sistemden

        // Bilinmeyen uzanti: turu dogru kategoriye dusurecek genel bir deger.
        return if (sesMi) "audio/mpeg" else "video/mp4"
    }

    /**
     * MediaStore'a verilecek `DISPLAY_NAME`.
     *
     * Ham dosya adi yt-dlp'nin **basliktan** urettigi ad
     * (`%(title).100s.%(ext)s`). Instagram'da baslik = alt yazi, yani
     * icinde satir sonu, sekme ve gorunmez bicimlendirme karakterleri
     * olabiliyor. MediaProvider bu adi reddedebiliyor ve red, kullaniciya
     * "galeride gorunmuyor" olarak yansiyordu.
     *
     * Iki is yapiliyor:
     * 1. Kontrol karakterleri bosluga cevriliyor, bosluklar sadelestiriliyor.
     * 2. Ses `.webm` uzantisi `.weba`'ya ceviriliyor — gerekcesi [mimeTuru].
     */
    private fun kayitAdi(dosya: File, sesMi: Boolean): String {
        val temiz = dosya.name
            .map { if (it.isISOControl()) ' ' else it }
            .joinToString("")
            .replace(Regex("\\s+"), " ")
            .trim()
            .ifEmpty { if (sesMi) "ses" else "video" }

        if (!sesMi || !temiz.endsWith(".webm", ignoreCase = true)) return temiz
        return temiz.dropLast(5) + "weba"
    }
}
