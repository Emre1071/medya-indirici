import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ====================================================================
// IMZA ANAHTARI
//
// Degerler `android/key.properties` dosyasindan okunuyor; o dosya da
// keystore'un kendisi de repoda YOK (.gitignore). Keystore depo agacinin
// tamamen disinda duruyor.
//
// ## Nicin bu kadar onemli
// Android, bir uygulamanin guncellemesini ancak AYNI anahtarla
// imzalanmissa kabul ediyor. Anahtar degisirse ya da kaybolursa
// kullanici "uygulamayi kaldir, yeniden kur" yapmak zorunda kalir —
// gecmisi ve ayarlari gider. Bu yuzden anahtar bir kez uretildi ve
// degistirilmeyecek.
//
// ## key.properties yoksa ne oluyor?
// Depoyu klonlayan biri (ya da CI) o dosyaya sahip olmuyor. Derlemenin
// tamamen durmasi yerine debug anahtarina dusuluyor ki kod calistirilip
// denenebilsin. Ama bu APK **dagitilamaz**; ayrimin gozden kacmamasi
// icin derleme sirasinda uyari basiliyor.
// ====================================================================
val anahtarOzellikleri = Properties()
val anahtarDosyasi = rootProject.file("key.properties")
val anahtarVar = anahtarDosyasi.exists()

if (anahtarVar) {
    anahtarDosyasi.inputStream().use { anahtarOzellikleri.load(it) }
} else {
    logger.warn(
        "UYARI: android/key.properties bulunamadi. Release derlemesi DEBUG " +
            "anahtariyla imzalanacak — bu APK dagitilamaz."
    )
}

android {
    namespace = "com.medyaindirici.medya_indirici"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.medyaindirici.medya_indirici"

        // youtubedl-android gomulu Python 3.8 calistiriyor; API 24 altinda
        // desteklenmiyor. Flutter'in varsayilani zaten bunun uzerinde ama
        // acikca yaziliyor ki Flutter varsayilani dusurse bile bozulmasin.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ====================================================================
    // MIMARI SECIMI BURADA DEGIL, DERLEME KOMUTUNDA
    //
    // Her mimari icin ayri APK uretmek hala amac: gomulu Python ve ffmpeg
    // her mimari icin ayri paketleniyor, hepsi tek APK'da birleserse dosya
    // iki katina cikiyor. Kullanicinin telefonuna yalnizca kendi
    // mimarisinin APK'si kuruluyor.
    //
    // Ama bu isi Gradle'da yapmak MUMKUN DEGIL. Flutter'in Gradle eklentisi
    // `ndk.abiFilters` ve `splits.abi` alanlarini KENDISI dolduruyor;
    // burada da yazildiginda AGP "Conflicting configuration" deyip derlemeyi
    // tamamen durduruyor. (Uygulama uzun sure hic derlenemedi, sebebi buydu:
    // ikisi de elle yazilmisti.)
    //
    // Dogru yol — mimari secimi komuttan geliyor:
    //
    //   flutter build apk --release --split-per-abi \
    //       --target-platform android-arm,android-arm64
    //
    // `--target-platform` x86/x86_64'u disarida birakiyor (onlar yalnizca
    // emulator icin gerekli). Emulatorde denemek gerekirse listeye
    // `android-x64` eklenir.
    //
    // Uretilen dosyalar: build/app/outputs/flutter-apk/ altinda
    // `app-arm64-v8a-release.apk` (59 MB) ve `app-armeabi-v7a-release.apk`
    // (52 MB). Supabase'e yuklenecek olan **arm64-v8a** olani
    // (2019 sonrasi tum telefonlar).
    // ====================================================================

    signingConfigs {
        // key.properties yoksa bu yapilandirma bos kalir ve kullanilmaz;
        // olusturulmasi tek basina zararsiz.
        create("release") {
            keyAlias = anahtarOzellikleri.getProperty("keyAlias")
            keyPassword = anahtarOzellikleri.getProperty("keyPassword")
            storePassword = anahtarOzellikleri.getProperty("storePassword")

            // Yol mutlak: keystore proje agacinin disinda duruyor.
            val depoYolu = anahtarOzellikleri.getProperty("storeFile")
            if (depoYolu != null) storeFile = file(depoYolu)
        }
    }

    buildTypes {
        release {
            signingConfig = if (anahtarVar) {
                signingConfigs.getByName("release")
            } else {
                // Anahtar yokken derlemeyi tamamen durdurmuyoruz; yukaridaki
                // uyari basiliyor ve cikan APK dagitilmiyor.
                signingConfigs.getByName("debug")
            }
        }
    }

    packaging {
        jniLibs {
            // youtubedl-android'in SART kostugu ayar: gomulu Python ve ffmpeg
            // ikilileri APK icinden dogrudan CALISTIRILIYOR. Sikistirilmis
            // halde birakilirlarsa calistirilamazlar.
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Gomulu indirme motoru: Python 3.8 + yt-dlp.
    // Bu, masaustundeki `mp3_donusturucu.py` ile AYNI yt-dlp — sadece
    // telefonun icinde calisiyor.
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")

    // Ses ayirma ve video+ses birlestirme icin. Instagram indirmelerinde
    // genelde hic calismiyor (tek parca geliyor), YouTube'da calisiyor.
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")

    // aria2c BILEREK EKLENMEDI: coklu baglantiyla indirmeyi hizlandiriyor
    // ama APK'ya boyut ekliyor ve Instagram/YouTube CDN'leri zaten tek
    // baglantida hizli. Gerekirse sonra eklenir.
}

flutter {
    source = "../.."
}
