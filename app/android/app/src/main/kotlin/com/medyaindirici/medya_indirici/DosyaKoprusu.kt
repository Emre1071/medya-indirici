package com.medyaindirici.medya_indirici

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
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

            when (cagri.method) {
                "dosyaAc" -> calistir(yol, paylas = false, cevap = cevap)
                "dosyaPaylas" -> calistir(yol, paylas = true, cevap = cevap)
                else -> cevap.notImplemented()
            }
        }
    }

    private fun calistir(yol: String, paylas: Boolean, cevap: MethodChannel.Result) {
        try {
            val adres = adreseCevir(yol)
            if (adres == null) {
                // Dosya silinmis olabilir: kullanici galeriden temizlemis
                // ve gecmis satiri geride kalmistir. Bu bir cokme sebebi
                // degil, anlatilacak bir durum.
                cevap.error(
                    "DOSYA_YOK",
                    "Dosya bulunamadi, silinmis olabilir",
                    null,
                )
                return
            }

            val mime = mimeBul(adres, yol)

            if (paylas) {
                baslat(paylasimNiyeti(adres, mime), adres)
            } else {
                acmayiDene(adres, mime)
            }
            cevap.success(true)
        } catch (h: ActivityNotFoundException) {
            // Telefonda bu turu acabilecek uygulama yok. Ham istisna
            // metnini gostermek kullaniciya hicbir sey soylemez.
            Log.w(ETIKET, "Acacak uygulama yok: $yol", h)
            cevap.error("UYGULAMA_YOK", "Bu dosyayi açacak uygulama yok", null)
        } catch (h: Throwable) {
            Log.e(ETIKET, "Dosya acilamadi: $yol", h)
            cevap.error("ACILAMADI", h.message, null)
        }
    }

    /**
     * Dosyayi acar; dogrudan yol tutmazsa seciciye duser.
     *
     * ## Nicin iki asamali
     * 🔑 **`content://` adresi galeri indeksinden bagimsiz calisir** —
     * dosyayi MediaStore sunuyor, oynatici onu galeride gormemis olsa bile
     * aciyor. Yani "galeride gorunmuyor" ile "acilmiyor" ayri sorunlar ve
     * ilkinin cozumunu beklemeye gerek yok.
     *
     * Ama dogrudan `ACTION_VIEW` tek bir varsayilan uygulamaya gidiyor ve
     * o uygulama bozuksa (MIUI'de varsayilan oynatici bazen tanimadigi
     * saglayicidan okumayi reddediyor) is orada bitiyordu. Ikinci asama
     * seciciyi aciyor: kullanici calisan bir uygulamayi kendi seciyor.
     */
    private fun acmayiDene(adres: Uri, mime: String) {
        val niyet = acmaNiyeti(adres, mime)

        try {
            baslat(niyet, adres)
            return
        } catch (h: ActivityNotFoundException) {
            Log.w(ETIKET, "Dogrudan acma tutmadi, secici denenecek", h)
        }

        // Secici, MIME'i tam eslesmeyen uygulamalari da listeliyor.
        baslat(Intent.createChooser(niyet, "Aç"), adres)
    }

    /**
     * Niyeti baslatir ve okuma iznini **acikca** verir.
     *
     * `FLAG_GRANT_READ_URI_PERMISSION` cogu cihazda yetiyor. Bazi uretici
     * arayuzlerinde (MIUI dahil) karsi uygulama adresi yine okuyamiyor;
     * `grantUriPermission` izni paket adina birebir yaziyor. Cozumlenen
     * uygulama yoksa dongu bos gecip `startActivity`'nin kendi istisnasini
     * cagirana birakiyor.
     */
    private fun baslat(niyet: Intent, adres: Uri) {
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
            // Izin yazilamadiysa bayrak yine duruyor; denemeye devam.
            Log.w(ETIKET, "Uri izni acikca verilemedi", h)
        }

        etkinlik.startActivity(niyet)
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
    private fun mimeBul(adres: Uri, yol: String): String {
        if (adres.scheme == "content") {
            etkinlik.contentResolver.getType(adres)?.let { return it }
        }

        val uzanti = yol.substringAfterLast('.', "").lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(uzanti) ?: "*/*"
    }

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
