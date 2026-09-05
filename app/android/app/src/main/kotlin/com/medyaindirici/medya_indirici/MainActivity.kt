package com.medyaindirici.medya_indirici

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Indirilen guncelleme APK'sini Android'in kurulum ekranina teslim eder.
 *
 * DevLingo'daki ayni sinifin karsiligi — orada calistigi dogrulandigi icin
 * yapisi degistirilmedi, yalnizca kanal adi bu uygulamaya gore ayarlandi.
 *
 * ## Neden hazir bir paket kullanmiyoruz?
 * `open_filex` / `install_plugin` gibi paketler ayni isi yapiyor ama bu
 * proje bagimlilik eklemekten bilerek kaciniyor. Buradaki is 40 satir —
 * paket tasimaya degmez.
 *
 * ## Iki asamali izin
 * `REQUEST_INSTALL_PACKAGES` manifestte olsa bile Android 8'den itibaren
 * kullanicinin ayrica sistem ayarlarindan onay vermesi gerekiyor.
 * [kurulumIzniVarMi] bunu soruyor, [izinEkraniniAc] ilgili ayar sayfasini
 * aciyor. Izin yokken kuruluma kalkismak sessiz basarisizlik olurdu.
 */
class MainActivity : FlutterActivity() {

    private val kanalAdi = "medyaindirici/kurulum"

    /**
     * Gomulu yt-dlp koprusu.
     *
     * Kurulum `configureFlutterEngine` icinde **hemen** baslatiliyor ve
     * arka planda suruyor. Sebep: ilk acilista gomulu Python ve ffmpeg
     * ikililerinin acilmasi birkac saniye aliyor; kullanici linki
     * yapistirana kadar hazir olsun diye beklemeden basliyoruz.
     */
    private lateinit var motor: MotorKopru

    /**
     * Paylas menusunden gelen linki tasiyan kopru.
     *
     * `configureFlutterEngine`'den ONCE, `onCreate`'te olusturuluyor:
     * uygulama paylasimla acildiginda niyet daha Flutter baslamadan
     * elimizde oluyor ve kaybolmamasi icin hemen saklanmasi gerekiyor.
     */
    private val paylasim = PaylasimKoprusu()

    companion object {
        /** Depolama izni istegini tanimak icin; cevabi ayrica islemiyoruz. */
        private const val DEPOLAMA_IZIN_KODU = 1071
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        paylasim.acilistakiIntent(intent)
        eskiAndroidDepolamaIzniniIste()
    }

    /**
     * Uygulama aciKken gelen paylasim buraya dusuyor.
     *
     * `setIntent` cagrisi Android'in beklentisi: sonradan `intent`'i okuyan
     * kod eskisini degil bunu gormeli.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        paylasim.yeniIntent(intent)
    }

    /**
     * Android 9 ve oncesinde indirilen dosyayi Muzik/Filmler klasorune
     * yazabilmek icin depolama izni gerekiyor.
     *
     * **Android 10 ve ustunde istenmiyor**, cunku gerekmiyor: uygulama
     * kendi ekledigi medyayi MediaStore uzerinden izinsiz yazabiliyor
     * (bkz. [MedyaKaydedici]). Gereksiz izin istemek, kullaniciya
     * anlamsiz bir soru sormak olurdu.
     *
     * Cevap islenmiyor: izin verilmezse dosya uygulamanin kendi
     * klasorunde kaliyor ve arayuz bunu zaten ayri gosteriyor. Reddedilen
     * izin yuzunden uygulamanin acilisini kesmenin bir anlami yok.
     */
    private fun eskiAndroidDepolamaIzniniIste() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) return

        val izin = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
        )
        if (izin == PackageManager.PERMISSION_GRANTED) return

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
            DEPOLAMA_IZIN_KODU,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        motor = MotorKopru(applicationContext)
        motor.kur()
        motor.kanallariBagla(flutterEngine.dartExecutor.binaryMessenger)

        paylasim.kanallariBagla(flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kanalAdi)
            .setMethodCallHandler { cagri, cevap ->
                when (cagri.method) {
                    "kurulumIzniVarMi" -> cevap.success(kurulumIzniVarMi())
                    "izinEkraniniAc" -> {
                        izinEkraniniAc()
                        cevap.success(null)
                    }
                    "apkKur" -> {
                        val yol = cagri.argument<String>("yol")
                        if (yol == null) {
                            cevap.error("YOL_YOK", "APK yolu verilmedi", null)
                        } else {
                            apkKur(yol, cevap)
                        }
                    }
                    else -> cevap.notImplemented()
                }
            }
    }

    private fun kurulumIzniVarMi(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true // Android 8 oncesinde manifest izni yeterliydi
        }

    private fun izinEkraniniAc() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
            )
        }
    }

    private fun apkKur(yol: String, cevap: MethodChannel.Result) {
        val dosya = File(yol)
        if (!dosya.exists()) {
            cevap.error("DOSYA_YOK", "Indirilen dosya bulunamadi: $yol", null)
            return
        }

        try {
            val adres: Uri = FileProvider.getUriForFile(
                this,
                "$packageName.dosyalar",
                dosya
            )

            val niyet = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(adres, "application/vnd.android.package-archive")
                // Gecici okuma izni: kurulum ekrani dosyayi bu sayede gorebiliyor.
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            startActivity(niyet)
            cevap.success(true)
        } catch (h: Exception) {
            cevap.error("KURULUM_HATASI", h.message, null)
        }
    }
}
