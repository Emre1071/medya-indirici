package com.medyaindirici.medya_indirici

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Inen dosyayi baska bir uygulamada acar veya paylasir.
 *
 * ## Nicin ayri bir kopru
 * "Indirilenler" listesindeki "Aç" dugmesi uzun sure yalnizca bir uyari
 * gosteriyordu — Asama 5'in kalan parcasiydi. Dosya artik telefonun ortak
 * klasorunde duruyor ama kullaniciyi "muzik calarindan bul" diye
 * gondermek, uc dokunusluk akisin sonunu dorduncu bir aramaya baglamak
 * demekti.
 *
 * ## Iki farkli yol geliyor, ikisi ayri kuruluyor
 * `MedyaKaydedici` iki Android surumunde farkli sey donduruyor:
 *
 * | Android | `yol` | Burada ne yapiliyor |
 * |---|---|---|
 * | 29+ | `content://…` (MediaStore kaydi) | oldugu gibi kullaniliyor |
 * | 24-28 | duz dosya yolu | FileProvider'dan `content://` uretiliyor |
 *
 * Duz `file://` gondermek secenek **degil**: Android 7'den beri
 * `FileUriExposedException` ile sonuclaniyor.
 *
 * ## MIME tipi tahmin edilmiyor
 * `content://` icin `contentResolver.getType()` soruluyor — kaydi zaten
 * MediaStore'a biz yazdik, dogru cevabi o biliyor. Tahmin etmek, ses
 * dosyasini video oynaticiya gondermek gibi sonuclar uretirdi.
 *
 * ## Paket gorunurlugu
 * 🔴 Android 11'den beri `resolveActivity` cagrisi, manifestte `<queries>`
 * girisi olmadan **her zaman `null` donuyor** — hata da vermiyor. Yani
 * kontrol eklemek, dogru kurulmazsa "hicbir sey olmadi" uretir. Manifeste
 * `ACTION_VIEW` icin ses ve video joker sorgulari bu yuzden eklendi.
 *
 * ⚠️ Bu dosyanin yorumlarinda MIME jokeri **yazilmiyor.** Kotlin blok
 * yorumlari IC ICE gecebiliyor: `audio` sonrasindaki bolu-yildiz ikilisi
 * yeni bir yorum aciyor ve dosyanin sonunda "Unclosed comment" olarak
 * patliyor. Hata satiri da acildigi yeri degil dosyanin sonunu gosteriyor,
 * yani sebebi bulmak zor.
 *
 * ## Hatalar `Throwable`
 * Bu dosya gomulu ikiliye gitmiyor ama proje kurali her yerde ayni:
 * yakalanmayan bir `Error` sureci oldurur.
 */
class DosyaKoprusu(private val etkinlik: Activity) {

    companion object {
        private const val ETIKET = "DosyaKoprusu"
        const val KANAL = "medyaindirici/dosya"
    }

    fun kanallariBagla(mesajci: BinaryMessenger) {
        MethodChannel(mesajci, KANAL).setMethodCallHandler { cagri, cevap ->
            val yol = cagri.argument<String>("yol")
            if (yol.isNullOrBlank()) {
                cevap.error("YOL_YOK", "Dosya yolu verilmedi", null)
                return@setMethodCallHandler
            }

            // Tur Dart tarafindan geliyor (isin `ses`/`video` alani).
            // Tahmin etmiyoruz: MIME cozulemezse yedek deger buna bakiyor
            // ve yanlis tahmin, dosyayi acabilecek uygulamayi listeden
            // eler.
            val tur = cagri.argument<String>("tur")

            when (cagri.method) {
                "dosyaAc" -> calistir(yol, tur, paylas = false, cevap = cevap)
                "dosyaPaylas" -> calistir(yol, tur, paylas = true, cevap = cevap)
                else -> cevap.notImplemented()
            }
        }
    }

    /**
     * Dosyayi acar/paylasir — **birden fazla yol deneyerek.**
     *
     * ## Nicin tek deneme yetmedi
     * v0.1.4'te dosya yoneticisinden aciliyor ama uygulamadan acilmiyordu.
     * Tek bir niyet kuruluyordu ve tutmadiginda elde hicbir bilgi
     * kalmiyordu. Uc ayri sebep ayni belirtiyi uretiyor:
     *
     * 1. **`external_primary` birim adi.** Kayit
     *    `MediaStore.VOLUME_EXTERNAL_PRIMARY` ile aciliyor ve adres
     *    `content://media/external_primary/...` oluyor. Bircok oynatici
     *    yalnizca klasik `content://media/external/...` bicimini tanıyor.
     * 2. **MIME cozulemiyor.** `getType()` `null` veya
     *    `application/octet-stream` donerse niyet hicbir uygulamaya
     *    eslesmiyor.
     * 3. **Saglayici erisimi.** Bazi uretici oynaticilari MediaStore
     *    adresini okuyamiyor; FileProvider adresi calisiyor (o saglayiciyi
     *    biz sahiplendigimiz icin izni birebir yazabiliyoruz).
     *
     * Adaylar sirayla deneniyor, ilk tutan kazaniyor.
     *
     * ## Hata artik yutulmuyor
     * Hicbiri tutmazsa **butun denemelerin dokumu** Dart tarafina
     * `ayrinti` olarak gidiyor ve karta dokununca kopyalanabiliyor.
     * Cihaz `adb`'ye baglanamadigi icin (§4.5) sebebi ogrenmenin baska
     * yolu yok — ayni kalip motor kurulumunda ve indirmede zaten
     * kullaniliyor.
     */
    private fun calistir(
        yol: String,
        tur: String?,
        paylas: Boolean,
        cevap: MethodChannel.Result,
    ) {
        val gunluk = StringBuilder("Yol: $yol\nTur: ${tur ?: "bilinmiyor"}\n")

        try {
            val adres = adreseCevir(yol)
            if (adres == null) {
                // Dosya silinmis olabilir: kullanici galeriden temizlemis
                // ve gecmis satiri geride kalmistir. Bu bir cokme sebebi
                // degil, anlatilacak bir durum.
                cevap.error(
                    "DOSYA_YOK",
                    "Dosya bulunamadi, silinmis olabilir",
                    gunluk.toString(),
                )
                return
            }

            var mime = mimeBul(adres, yol, tur)
            if (paylas) mime = paylasimIcinSomut(mime, tur)
            gunluk.append("MIME: $mime\n")

            val adaylar = adaylariKur(yol, adres, mime, paylas, gunluk)

            for (aday in adaylar) {
                try {
                    izinVer(aday.niyet, aday.adres)
                    etkinlik.startActivity(aday.niyet)
                    gunluk.append("TUTTU: ${aday.ad}\n")
                    Log.i(ETIKET, "Acildi (${aday.ad}): $yol")
                    cevap.success(true)
                    return
                } catch (h: Throwable) {
                    // ActivityNotFoundException, SecurityException ve
                    // digerleri burada toplaniyor; bir sonraki aday
                    // deneniyor. Yutulmuyorlar — dokume yaziliyorlar.
                    gunluk.append("${aday.ad}: ${h.javaClass.simpleName}")
                    h.message?.let { gunluk.append(" — ").append(it) }
                    gunluk.append('\n')
                    Log.w(ETIKET, "Aday tutmadi: ${aday.ad}", h)
                }
            }

            cevap.error(
                "ACILAMADI",
                "Dosya açılamadı; hiçbir uygulama yanıt vermedi",
                gunluk.toString(),
            )
        } catch (h: Throwable) {
            gunluk.append("Beklenmeyen: ${sebepZinciri(h)}")
            Log.e(ETIKET, "Dosya acilamadi: $yol", h)
            cevap.error("ACILAMADI", h.message, gunluk.toString())
        }
    }

    /** Denenecek tek bir yol. */
    private data class Aday(val ad: String, val adres: Uri, val niyet: Intent)

    /**
     * Denenecek yollar.
     *
     * ## 🔴 Artik KENDI saglayicimiz asil yol
     * v0.1.5 cihazda `SecurityException — UID does not have permission`
     * verdi. Sebep: `FLAG_GRANT_READ_URI_PERMISSION` bir MediaStore
     * adresinde **bize ait olmayan** bir saglayiciya izin yazmaya
     * calismak demek; izni veren taraf biz degiliz, dolayisiyla verecek
     * bir seyimiz de yok. Karsi uygulama adresi ancak kendi depolama
     * izniyle okuyabiliyor ve MIUI uygulama arka plana dustugunde bunu
     * dusuruyor.
     *
     * FileProvider'da bu sorun **yapisal olarak yok**: saglayicinin
     * sahibi biziz, `grantUriPermission` gercekten calisiyor ve izin
     * karsi uygulama isini bitirene kadar yasiyor. WhatsApp gibi dosyayi
     * kendi surecinde okuyan uygulamalarin calismasinin da tek yolu bu.
     *
     * Sira bu yuzden tersine cevrildi: FileProvider once, MediaStore
     * yalnizca **son care**.
     *
     * ⚠️ **MediaStore adayi bilerek silinmedi.** FileProvider adresi
     * ancak diskteki gercek yol okunabildiginde kurulabiliyor (`DATA`
     * sutunu) ve o sutun her kayitta dolu olmayabiliyor; SD karttaki bir
     * dosya da `dosya_yollari.xml` agaclarinin disinda kalir. Tek yol
     * birakilsaydi bu durumlarda "Aç" **kesin** basarisiz olurdu. Son
     * carenin bedeli uc satir, yoklugunun bedeli calismayan bir dugme.
     */
    private fun adaylariKur(
        yol: String,
        adres: Uri,
        mime: String,
        paylas: Boolean,
        gunluk: StringBuilder,
    ): List<Aday> {
        val liste = mutableListOf<Aday>()

        fun ekle(ad: String, hedef: Uri) {
            val niyet = if (paylas) paylasimNiyeti(hedef, mime)
            else acmaNiyeti(hedef, mime)
            liste.add(Aday(ad, hedef, niyet))
        }

        // 1) ASIL YOL: kendi FileProvider adresimiz.
        val saglayici = saglayiciAdresi(yol, gunluk)
        if (saglayici != null) {
            gunluk.append("Aday 1 (FileProvider): $saglayici\n")
            ekle("FileProvider", saglayici)

            // 2) Secici — ayni FileProvider adresiyle. Paylasimda asil
            //    yol bu: kullanici WhatsApp'i buradan seciyor.
            val baslik = if (paylas) "Paylaş" else "Aç"
            liste.add(
                Aday(
                    "FileProvider + secici",
                    saglayici,
                    Intent.createChooser(
                        if (paylas) paylasimNiyeti(saglayici, mime)
                        else acmaNiyeti(saglayici, mime),
                        baslik,
                    ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) },
                )
            )
        }

        // 3) SON CARE: `content://` adresini dogrudan vermek.
        //
        // ⚠️ Bunun `SecurityException` ile bitmesi BEKLENIYOR (§4.13):
        // sahibi olmadigimiz bir saglayiciya izin yazamiyoruz. Yine de
        // duruyor, cunku hicbir sey denememekten iyi — bazi oynaticilar
        // kendi depolama izinleriyle okuyabiliyor. Asil degeri gunlukte:
        // buraya dusuldugu gorulurse FileProvider'in NICIN kurulamadigi
        // hemen ustteki satirlarda yaziyor.
        if (saglayici == null) {
            gunluk.append("Son care (verilen adres): $adres\n")
            ekle("verilen adres", adres)

            liste.firstOrNull()?.let { ilk ->
                liste.add(
                    Aday(
                        "secici",
                        ilk.adres,
                        Intent.createChooser(
                            ilk.niyet,
                            if (paylas) "Paylaş" else "Aç",
                        ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) },
                    )
                )
            }
        }

        return liste
    }

    /**
     * Paylasilabilir bir FileProvider adresi uretir.
     *
     * ## 🔴 `DATA` sutunu artik HIC sorulmuyor
     * v0.1.6 cihazda `FileProvider kurulamadi: disk yolu okunamadi` verdi:
     * MIUI `content://` adresinden `DATA` sutununu okutmuyor. Zincirin
     * tamami o tek sutuna bagliydi; okunamayinca `content://` yedegine
     * dusuluyor ve orada `SecurityException` aliniyordu.
     *
     * Artik `MedyaKaydedici` dogrudan **mutlak yol** donduruyor, yani
     * sorulacak bir sey kalmiyor.
     *
     * ## Iki yol, ikisi de gerekli
     * 1. **Dosya okunabiliyorsa** dogrudan FileProvider. API 28 ve altinda
     *    her zaman boyle; yeni surumlerde de medya erisimi aciksa.
     * 2. **Okunamiyorsa onbellege kopyalaniyor.** Android 10'dan beri
     *    kapsamli depolama ortak klasorlere DUZ DOSYA erisimini kapatiyor:
     *    yol dogru olsa bile `canRead()` `false` donebiliyor ve
     *    FileProvider dosyayi acamaz. Ama kendi MediaStore kaydimizi
     *    **izinsiz** okuyabiliyoruz — bayt akisi oradan alinip uygulamanin
     *    kendi onbellegine yaziliyor, FileProvider onu sunuyor.
     *
     * 🔑 Ikinci yol **yeni izin gerektirmiyor.** `READ_EXTERNAL_STORAGE` /
     * `READ_MEDIA_*` eklemek kullaniciya yeni bir izin sorusu cikarirdi;
     * §4.1'de "bizim isimiz yazmak" diye yazilan cizgi korunuyor.
     */
    private fun saglayiciAdresi(yol: String, gunluk: StringBuilder): Uri? {
        val dosya = File(yol)

        // 1) Dogrudan okunabiliyor mu?
        if (!yol.startsWith("content://") && dosya.canRead()) {
            gunluk.append("Dosya dogrudan okunabiliyor" + "\n")
            return saglayiciyaVer(dosya, gunluk)
        }

        // 2) MediaStore uzerinden onbellege kopyala.
        val kayit = mediaStoreAdresi(yol, gunluk)
        if (kayit == null) {
            gunluk.append("MediaStore kaydi bulunamadi" + "\n")
            return null
        }

        val kopya = onbellegeKopyala(kayit, dosya.name, gunluk) ?: return null
        return saglayiciyaVer(kopya, gunluk)
    }

    private fun saglayiciyaVer(dosya: File, gunluk: StringBuilder): Uri? =
        try {
            FileProvider.getUriForFile(
                etkinlik,
                "${etkinlik.packageName}.dosyalar",
                dosya,
            )
        } catch (h: Throwable) {
            // Yol `dosya_yollari.xml` agaclarinin disindaysa (ornegin SD
            // kart) FileProvider `IllegalArgumentException` atiyor.
            gunluk.append("FileProvider reddetti: ${h.message}" + "\n")
            Log.w(ETIKET, "FileProvider adresi uretilemedi: $dosya", h)
            null
        }

    /**
     * Yolun MediaStore kaydini bulur.
     *
     * Iki giris bicimi de destekleniyor:
     * - `content://…` — **geriye donuk uyumluluk.** v0.1.6 ve oncesinde
     *   inen dosyalarin gecmis kayitlarinda yol boyle duruyor; kalici
     *   gecmis silinmedigi surece bu satirlar yasamaya devam ediyor.
     * - Mutlak yol — `RELATIVE_PATH` + `DISPLAY_NAME` olarak parcalanip
     *   sorgulaniyor. 🔑 `DATA` ile DEGIL: sorgulanan iki sutun da
     *   engellenmiyor.
     */
    private fun mediaStoreAdresi(yol: String, gunluk: StringBuilder): Uri? {
        if (yol.startsWith("content://")) return Uri.parse(yol)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null

        val dosya = File(yol)
        val ad = dosya.name
        val klasor = dosya.parentFile?.name ?: return null
        val ust = dosya.parentFile?.parentFile?.name ?: return null
        val gorecel = "$ust/$klasor/"

        val sesMi = ust.equals("Music", ignoreCase = true)
        val koleksiyon = if (sesMi) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        }

        return try {
            etkinlik.contentResolver.query(
                koleksiyon,
                arrayOf(MediaStore.MediaColumns._ID),
                "${MediaStore.MediaColumns.DISPLAY_NAME} = ? AND " +
                    "${MediaStore.MediaColumns.RELATIVE_PATH} = ?",
                arrayOf(ad, gorecel),
                null,
            )?.use { imlec ->
                if (!imlec.moveToFirst()) {
                    gunluk.append("MediaStore sorgusu bos: $gorecel$ad" + "\n")
                    return null
                }
                val kimlik = imlec.getLong(0)
                Uri.withAppendedPath(koleksiyon, kimlik.toString())
            }
        } catch (h: Throwable) {
            gunluk.append("MediaStore sorgusu patladi: ${h.message}" + "\n")
            Log.w(ETIKET, "MediaStore sorgusu patladi: $yol", h)
            null
        }
    }

    /**
     * Kaydin baytlarini uygulamanin kendi onbellegine kopyalar.
     *
     * Kendi MediaStore kaydimizi okumak icin **izin gerekmiyor** — onu biz
     * ekledik. Onbellek klasoru `dosya_yollari.xml`'de zaten paylasiliyor
     * (guncelleme APK'si icin acilmisti).
     *
     * Klasor her cagrida temizleniyor: paylasim gecici bir istek, 60 MB'lik
     * kopyalar birikirse telefonu doldurur.
     */
    private fun onbellegeKopyala(
        kayit: Uri,
        ad: String,
        gunluk: StringBuilder,
    ): File? {
        return try {
            val klasor = File(etkinlik.cacheDir, "paylasim")
            if (klasor.exists()) klasor.listFiles()?.forEach { it.delete() }
            klasor.mkdirs()

            val hedef = File(klasor, if (ad.isBlank()) "medya" else ad)
            etkinlik.contentResolver.openInputStream(kayit)?.use { giris ->
                hedef.outputStream().use { cikis -> giris.copyTo(cikis) }
            } ?: run {
                gunluk.append("MediaStore akisi acilamadi" + "\n")
                return null
            }

            gunluk.append("Onbellege kopyalandi: ${hedef.length()} bayt" + "\n")
            hedef
        } catch (h: Throwable) {
            gunluk.append("Onbellege kopyalanamadi: ${h.message}" + "\n")
            Log.w(ETIKET, "Onbellege kopyalanamadi: $kayit", h)
            null
        }
    }

    /**
     * Okuma iznini karsi uygulamaya **acikca** yazar.
     *
     * ⚠️ Yalnizca KENDI saglayicimiz icin. `grantUriPermission` sahibi
     * olmadigin bir saglayici icin cagrildiginda `SecurityException`
     * atiyor — MediaStore adresinde her seferinde patlayip gunlugu
     * kirletiyordu. Bayrak (`FLAG_GRANT_READ_URI_PERMISSION`) zaten
     * niyetin uzerinde duruyor; bu yalnizca ek bir saglamlastirma.
     */
    private fun izinVer(niyet: Intent, adres: Uri) {
        if (adres.authority != "${etkinlik.packageName}.dosyalar") return

        try {
            etkinlik.packageManager
                .queryIntentActivities(niyet, PackageManager.MATCH_DEFAULT_ONLY)
                .forEach { cozum ->
                    etkinlik.grantUriPermission(
                        cozum.activityInfo.packageName,
                        adres,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION,
                    )
                }
        } catch (h: Throwable) {
            Log.w(ETIKET, "Uri izni acikca verilemedi", h)
        }
    }

    /** Istisnanin sebep zinciri; distaki mesaj cogu zaman bos. */
    private fun sebepZinciri(h: Throwable): String {
        val yazi = StringBuilder()
        var sira: Throwable? = h
        var derinlik = 0
        while (sira != null && derinlik < 5) {
            yazi.append(if (derinlik == 0) "" else "  sebep: ")
            yazi.append(sira.javaClass.simpleName)
            sira.message?.let { yazi.append(": ").append(it) }
            yazi.append('\n')
            sira = sira.cause
            derinlik++
        }
        return yazi.toString()
    }

    /**
     * Kayit yolunu paylasilabilir bir `content://` adresine cevirir.
     *
     * Dosya artik yoksa `null` doner.
     */
    private fun adreseCevir(yol: String): Uri? {
        if (yol.startsWith("content://")) return Uri.parse(yol)

        val dosya = File(yol)
        if (!dosya.exists()) return null

        return FileProvider.getUriForFile(
            etkinlik,
            "${etkinlik.packageName}.dosyalar",
            dosya,
        )
    }

    /**
     * Adresin MIME turu.
     *
     * `content://` icin **sisteme soruluyor**: kaydi MediaStore'a biz
     * yazdik, dogru deger orada duruyor. Duz dosyada uzantidan tahmin
     * ediliyor; bulunamazsa joker tur veriliyor — Android o durumda
     * kullaniciya uygulama sectiriyor, ki yanlis uygulamaya gondermekten
     * iyidir.
     *
     * NOT: joker turun metni koda yaziliyor, bu yoruma degil — yildiz ve
     * bolu ikilisi blok yorumu erken kapatir (derleyici bunu "top level
     * declaration bekleniyor" diye bildiriyor ve sebep hic gorunmuyor).
     */
    private fun mimeBul(adres: Uri, yol: String, tur: String?): String {
        if (adres.scheme == "content") {
            val sistemden = try {
                etkinlik.contentResolver.getType(adres)
            } catch (h: Throwable) {
                Log.w(ETIKET, "getType patladi: $adres", h)
                null
            }
            if (kullanilirMi(sistemden)) return sistemden!!
        }

        val uzanti = yol.substringAfterLast('.', "").lowercase()
        val uzantidan = MimeTypeMap.getSingleton().getMimeTypeFromExtension(uzanti)
        if (kullanilirMi(uzantidan)) return uzantidan!!

        // Son care: isin turune gore joker. Dart tarafi `ses`/`video`
        // gonderiyor, tahmin edilmiyor.
        return when (tur) {
            "ses" -> "audio/*"
            "video" -> "video/*"
            else -> "*/*"
        }
    }

    /**
     * Paylasimda joker tur **kullanilamaz.**
     *
     * Acmada joker ise yariyor: Android kullaniciya uygulama sectiriyor.
     * Paylasimda ise tam tersi — WhatsApp gibi uygulamalar niyet
     * filtrelerinde somut turler ilan ediyor ve joker gelen paylasimda
     * listede HIC gorunmuyorlar. Yani joker, en cok kullanilacak hedefi
     * eliyor.
     *
     * Somutlastirma indirilen bicime gore: video artik mp4 olarak
     * uretiliyor (bkz. `MotorKopru.videoFormatKurali` ve `--remux-video`),
     * ses tarafinda en yaygin kabul goren tur mpeg.
     */
    private fun paylasimIcinSomut(mime: String, tur: String?): String {
        if (!mime.endsWith("/*")) return mime
        return when {
            mime.startsWith("video") || tur == "video" -> "video/mp4"
            mime.startsWith("audio") || tur == "ses" -> "audio/mpeg"
            else -> mime
        }
    }

    /**
     * Bu MIME degeri niyete konulabilir mi?
     *
     * `null` ve bos bir yana, **`application/octet-stream` de ise
     * yaramiyor**: "ne oldugunu bilmiyorum" demek ve hicbir oynatici bu
     * turu ustlenmiyor. Niyete konursa dosya acilamiyor; joker turle
     * degistirmek dogru uygulamalari listeye geri getiriyor.
     *
     * (Joker turun metni yalniz kodda geciyor — gerekcesi sinif
     * basindaki ic ice yorum uyarisinda.)
     */
    private fun kullanilirMi(mime: String?): Boolean =
        !mime.isNullOrBlank() &&
            mime.contains('/') &&
            !mime.equals("application/octet-stream", ignoreCase = true)

    private fun acmaNiyeti(adres: Uri, mime: String): Intent =
        Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(adres, mime)
            // Gecici okuma izni: karsi uygulama dosyayi bu sayede gorebiliyor.
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

    /**
     * Paylasim her zaman secici ile aciliyor.
     *
     * `createChooser` olmadan Android "her zaman bu uygulamayi kullan"
     * tercihini hatirliyor ve kullanici bir daha baska uygulamaya
     * gonderemiyor.
     */
    private fun paylasimNiyeti(adres: Uri, mime: String): Intent =
        Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, adres)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

            // 🔑 `ClipData` SART — WhatsApp'in calismasinin sarti.
            //
            // `EXTRA_STREAM` icindeki adres bir "extra"; sistem niyetin
            // `data`/`clipData` alanlarina bakarak izin tasiyor ve extra'lar
            // o taramaya GIRMIYOR. Yani bayrak tek basina konuldugunda
            // paylasilan uygulama adresi okuyamiyor ve WhatsApp'ta
            // "dosya desteklenmiyor" ya da sessiz basarisizlik olarak
            // gorunuyor. Ayni adresi `clipData` olarak da vermek izni
            // gercekten tasiyor.
            clipData = ClipData.newUri(etkinlik.contentResolver, "medya", adres)
        }

}
