# R8 kurallari — gomulu indirme motorunu korur.
#
# ====================================================================
# NICIN VAR: uygulama bu dosya olmadan TELEFONDA CALISMIYORDU
#
# Release derlemesinde R8 kodu kuculttugu gibi sinif ve alan adlarini da
# kisaltiyor (`com.yausername...VideoInfo` -> `p3.a`). Java tarafinda bu
# sorun degil, cunku cagrilar derleme aninda cozuluyor.
#
# Ama youtubedl-android yt-dlp'nin JSON ciktisini **yansimayla**
# (reflection) nesneye ceviriyor: sinifi adiyla ariyor, alanlari
# adiyla dolduruyor. Adlar degisince o arama basarisiz oluyor ve
# telefonda su hata cikiyordu:
#
#   ExceptionInInitializerError:
#     RuntimeException: class p3.a is not a concrete class
#
# `p3.a` obfuscation'in urunu — hatanin kaynagini gosteren tek ipucu da
# buydu. Yansima R8'in goremedigi bir bagimlilik; ne kullanildigini
# ancak biz soyleyebiliriz, bu dosya onu soyluyor.
#
# DIKKAT: Bu dosya sessizce devre disi kalabilir. `build.gradle.kts`
# icindeki `proguardFiles(...)` satiri silinirse R8 yine calisir ama
# kurallar uygulanmaz ve uygulama yine bozulur — derleme HATA VERMEZ.
# ====================================================================

# --- Indirme motoru ---------------------------------------------------
# Sinif adlari, alanlar ve metotlar oldugu gibi kalmali: yt-dlp ciktisi
# bu modellere alan ADIYLA eslestiriliyor.
-keep class com.yausername.youtubedl_android.** { *; }
-dontwarn com.yausername.youtubedl_android.**

# ffmpeg ve aria2c sarmalayicilari ayni pakette degil ama ayni yontemle
# calisiyor. `FFmpeg.getInstance()` dogrudan cagriliyor.
-keep class com.yausername.** { *; }
-dontwarn com.yausername.**

# --- Zip acici --------------------------------------------------------
# Gomulu Python ve ffmpeg APK'ya `.zip.so` olarak giriyor ve ilk acilista
# commons-compress ile aciliyor.
#
# `ExtraFieldUtils` statik baslaticisinda "extra field" siniflarini
# YANSIMAYLA uretiyor (`newInstance()`). R8 bu kuruculari kimse
# cagirmiyor sanip siliyor, `newInstance()` InstantiationException
# firlatiyor ve kutuphane onu su mesajla yeniden firlatiyor:
#
#   class k2.a is not a concrete class
#
# Telefonda goruldu; `k2.a` = AsiExtraField, `k2.e` = ExtraFieldUtils.
# Kuruculari korumak sart.
-keep class org.apache.commons.compress.** { *; }
-dontwarn org.apache.commons.compress.**

# --- JSON cozumleyici -------------------------------------------------
# youtubedl-android, yt-dlp ciktisini Jackson ile okuyor. Jackson bastan
# sona yansimayla calisiyor.
-keep class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.**

# --- Yansimanin ihtiyac duydugu ustveri -------------------------------
# Bunlar olmadan siniflar korunsa bile Jackson isini yapamaz:
#   *Annotation*    -> @JsonProperty gibi isaretler
#   Signature       -> List<VideoFormat> gibi jenerik turler
#   EnclosingMethod
#   InnerClasses    -> ic siniflar
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses
