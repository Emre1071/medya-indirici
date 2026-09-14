package com.medyaindirici.medya_indirici

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
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

            val mime = mimeBul(adres, yol, tur)
            gunluk.append("MIME: $mime\n")

            val adaylar = adaylariKur(adres, mime, paylas, gunluk)

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
     * Denenecek yollar — **en dogrudan olandan en toleransliya.**
     *
     * Sira onemli: ilk aday tutarsa kullanici hicbir secim ekrani gormuyor.
     * Secici en sona konuyor cunku her seferinde acilmasi, calisan bir
     * varsayilani olan kullaniciya fazladan bir dokunus ekler.
     */
    private fun adaylariKur(
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

        // 1) Klasik birim adiyla MediaStore adresi (en genis uyumluluk).
        uyumluAdres(adres)?.let {
            gunluk.append("Aday 1: $it\n")
            ekle("media/external", it)
        }

        // 2) Elimizdeki adres, oldugu gibi.
        gunluk.append("Aday 2: $adres\n")
        ekle("verilen adres", adres)

        // 3) FileProvider. Diskteki gercek yol MediaStore'dan okunuyor;
        //    bu saglayiciyi BIZ sahiplendigimiz icin okuma iznini karsi
        //    uygulamaya birebir yazabiliyoruz (MediaStore'a yazamayiz).
        diskYolu(adres)?.let { diskte ->
            try {
                val dosya = File(diskte)
                if (dosya.exists()) {
                    val saglayici = FileProvider.getUriForFile(
                        etkinlik,
                        "${etkinlik.packageName}.dosyalar",
                        dosya,
                    )
                    gunluk.append("Aday 3: $saglayici ($diskte)\n")
                    ekle("FileProvider", saglayici)
                } else {
                    gunluk.append("Aday 3 atlandi: disk yolu yok ($diskte)\n")
                }
            } catch (h: Throwable) {
                // Yol `dosya_yollari.xml`'deki agaclarin disindaysa
                // FileProvider istisna atiyor. Yedegin yoklugu asil
                // adaylari etkilemiyor.
                gunluk.append("Aday 3 kurulamadi: ${h.message}\n")
                Log.w(ETIKET, "FileProvider yedegi kurulamadi: $diskte", h)
            }
        }

        // 4) Secici: MIME'i tam eslesmeyen uygulamalari da listeliyor.
        val ilk = liste.firstOrNull()
        if (ilk != null) {
            val baslik = if (paylas) "Paylaş" else "Aç"
            liste.add(
                Aday(
                    "secici",
                    ilk.adres,
                    Intent.createChooser(ilk.niyet, baslik).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    },
                )
            )
        }
        return liste
    }

    /**
     * `content://media/external_primary/...` → `content://media/external/...`
     *
     * 🔑 Kayit `VOLUME_EXTERNAL_PRIMARY` ile aciliyor ve donen adres o birim
     * adini tasiyor. Ikisi ayni satiri gosteriyor, ama ucuncu taraf
     * oynaticilarin cogu yalnizca klasik `external` bicimini bekliyor ve
     * digerini "tanimadigim adres" diye reddediyor. Ayni satira giden
     * ikinci bir kapi.
     *
     * MediaStore adresi degilse `null`.
     */
    private fun uyumluAdres(adres: Uri): Uri? {
        if (adres.authority != MediaStore.AUTHORITY) return null

        val parcalar = adres.pathSegments
        if (parcalar.size < 2) return null
        if (parcalar[0] != MediaStore.VOLUME_EXTERNAL_PRIMARY) return null

        val kurucu = adres.buildUpon().path(null)
        kurucu.appendPath(MediaStore.VOLUME_EXTERNAL)
        parcalar.drop(1).forEach { kurucu.appendPath(it) }
        return kurucu.build()
    }

    /**
     * MediaStore kaydinin diskteki gercek yolu; yoksa `null`.
     *
     * `DATA` sutunu API 29'da kullanimdan kaldirildi ama **okunabilir**
     * kalmaya devam ediyor (yazmak yasak, okumak degil). FileProvider
     * yedegi icin baska bir girdi yok.
     */
    private fun diskYolu(adres: Uri): String? {
        // `content` disi bir sema (API 24-28 duz yolu) zaten dosya yolu.
        if (adres.scheme != "content") return adres.path

        @Suppress("DEPRECATION")
        val sutun = MediaStore.MediaColumns.DATA

        return try {
            etkinlik.contentResolver
                .query(adres, arrayOf(sutun), null, null, null)
                ?.use { imlec ->
                    if (!imlec.moveToFirst()) return null
                    val dizin = imlec.getColumnIndex(sutun)
                    if (dizin < 0) return null
                    imlec.getString(dizin)?.takeIf { it.isNotBlank() }
                }
        } catch (h: Throwable) {
            Log.w(ETIKET, "Disk yolu okunamadi: $adres", h)
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
    private fun paylasimNiyeti(adres: Uri, mime: String): Intent {
        val paylasim = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, adres)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return Intent.createChooser(paylasim, "Paylaş").apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }
}
