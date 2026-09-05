package com.medyaindirici.medya_indirici

import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Paylas menusunden gelen metni Flutter'a tasir.
 *
 * ## Nicin hazir paket degil?
 * `receive_sharing_intent` ayni isi yapiyor ama iOS tarafini, dosya/gorsel
 * paylasimini ve kendi yasam dongusunu de beraberinde getiriyor. Bize
 * gereken tek sey `text/plain`. Bu sinif 60 satir ve zaten var olan
 * MethodChannel kalibina oturuyor — projenin bagimlilik cizgisi bu
 * (bkz. `ApkKurucu` basindaki not).
 *
 * ## Iki ayri yol var, ikisi de gerekli
 * Kullanici "Paylaş" dediginde uygulama iki farkli durumda olabiliyor:
 *
 * - **Kapaliysa** (soguk acilis): Android uygulamayi paylasim niyetiyle
 *   baslatiyor. Flutter tarafi hazir olmadigi icin metin [ilkMetin]'de
 *   bekletiliyor; Dart hazir olunca `ilkPaylasim` ile aliyor.
 * - **Aciksa** (sicak acilis): `onNewIntent` tetikleniyor ve metin
 *   dogrudan olay akisindan gonderiliyor.
 *
 * Manifest'te `launchMode="singleTop"` bu yuzden onemli: olmasaydi her
 * paylasimda uygulamanin ikinci bir kopyasi acilirdi.
 *
 * ## Metin bir kez teslim ediliyor
 * [ilkMetin] okundugu anda temizleniyor. Temizlenmezse Dart tarafi
 * yeniden sordugunda (ornegin surec canlandirildiginda) ayni gonderi
 * ikinci kez onizlemeye dusurulurdu.
 */
class PaylasimKoprusu {

    companion object {
        private const val ETIKET = "PaylasimKoprusu"
        const val KOMUT_KANALI = "medyaindirici/paylasim"
        const val AKIS_KANALI = "medyaindirici/paylasim/akis"
    }

    private val anaIsParcacigi = Handler(Looper.getMainLooper())

    /** Dart'in henuz almadigi paylasim metni. */
    private var ilkMetin: String? = null

    private var akis: EventChannel.EventSink? = null

    fun kanallariBagla(mesajci: BinaryMessenger) {
        MethodChannel(mesajci, KOMUT_KANALI).setMethodCallHandler { cagri, cevap ->
            when (cagri.method) {
                "ilkPaylasim" -> {
                    cevap.success(ilkMetin)
                    ilkMetin = null
                }
                else -> cevap.notImplemented()
            }
        }

        EventChannel(mesajci, AKIS_KANALI).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(argumanlar: Any?, yeniAkis: EventChannel.EventSink?) {
                    akis = yeniAkis

                    // Dinleyici baglanmadan once gelmis bir paylasim varsa
                    // simdi teslim ediliyor. Aksi halde uygulama acikken
                    // gelen ama araya denk gelen paylasim kaybolurdu.
                    val bekleyen = ilkMetin
                    if (bekleyen != null) {
                        ilkMetin = null
                        anaIsParcacigi.post { akis?.success(bekleyen) }
                    }
                }

                override fun onCancel(argumanlar: Any?) {
                    akis = null
                }
            }
        )
    }

    /** Uygulama paylasim niyetiyle acildiginda. */
    fun acilistakiIntent(intent: Intent?) {
        val metin = metniCikar(intent) ?: return
        Log.i(ETIKET, "Acilista paylasim alindi")
        ilkMetin = metin
    }

    /** Uygulama acikken yeni bir paylasim geldiginde. */
    fun yeniIntent(intent: Intent?) {
        val metin = metniCikar(intent) ?: return
        Log.i(ETIKET, "Calisirken paylasim alindi")

        val acikAkis = akis
        if (acikAkis == null) {
            // Dart henuz dinlemiyor; kaybetmemek icin bekletiliyor.
            ilkMetin = metin
            return
        }
        anaIsParcacigi.post { acikAkis.success(metin) }
    }

    /**
     * Niyetten paylasilan metni cikarir.
     *
     * Yalnizca `ACTION_SEND` + `text/plain` isleniyor. Uygulamanin kendi
     * baslatici niyeti (`ACTION_MAIN`) ya da baska bir tur buraya
     * dustugunde `null` donuyor — sessizce yok sayilmasi dogru.
     */
    private fun metniCikar(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("text/") != true) return null

        val metin = intent.getStringExtra(Intent.EXTRA_TEXT)
        return metin?.takeIf { it.isNotBlank() }
    }
}
