/// Guncellemenin nereden okundugu.
///
/// ## Bu uygulama GitHub'i YALNIZCA guncelleme icin kullaniyor
/// Indirilen videolar/muzikler buraya ugramiyor — hepsi telefonda kaliyor.
/// Disari giden tek sey "yeni surum var mi?" sorusu ve nadiren APK dosyasi.
///
/// ## Nicin Supabase degil de GitHub Releases?
/// Basta Supabase Storage secilmisti (DevLingo'da calisan yapi buraya
/// tasinacakti). Iki somut engel cikti:
///
/// 1. **Dosya boyutu:** ucretsiz planin yukleme siniri 50 MB, bizim
///    arm64 APK'miz **59 MB**. Sinira takiliyor — yani yapi calissa bile
///    guncelleme dosyasi hic yuklenemiyor.
/// 2. **Uyuyan proje:** ucretsiz Supabase projesi bir sure kullanilmayinca
///    duraklatiliyor. Guncelleme kontrolu ayda birkac kez calisan bir sey;
///    tam da uyumaya en musait kullanim bicimi. Uyuyan proje = sessizce
///    calismayan guncelleme.
///
/// GitHub Releases'te ikisi de yok: dosya siniri 2 GB, depo uyumuyor.
///
/// ## Eski gerekce nicin gecerli degil artik
/// Onceki not "depo private oldugunda API'ye sormak APK'ya GitHub token'i
/// gommeyi gerektirir, o token cikarilabilir" diyordu — dogruydu. Karar
/// degisti: **depo public.** Public deponun release'leri kimlik dogrulamasi
/// istemiyor, yani gomulecek bir sir kalmadi. Uygulamada artik hicbir
/// anahtar durmuyor.
///
/// ## Bunun bedeli
/// Kaynak kodu herkese acik. Bu projede saklanacak bir sey yok: sir yok,
/// sunucu yok, kisisel veri yok.
class GitHubAyarlari {
  /// Depo sahibi. Kisisel hesap — DevLingo, morb ve qrbizde de burada.
  static const String sahip = 'Emre1071';

  static const String depo = 'medya-indirici';

  /// Yayindaki en son surumun okundugu adres.
  ///
  /// `/releases/latest` **taslak ve on-surumleri kendiliginden atliyor**;
  /// yani yarim birakilmis bir release kullaniciya guncelleme olarak
  /// gorunmuyor. Ayrica kimlik dogrulamasi istemiyor (public depo).
  static Uri get sonSurumAdresi =>
      Uri.parse('https://api.github.com/repos/$sahip/$depo/releases/latest');

  /// Deponun release sayfasi — kullaniciya gosterilecek adres.
  static String get surumlerSayfasi =>
      'https://github.com/$sahip/$depo/releases';

  /// Hangi APK indirilecek?
  ///
  /// Her surumde iki APK yayinlaniyor (`arm64-v8a` ve `armeabi-v7a`).
  /// Telefonun mimarisini Dart tarafinda bilmiyoruz — ogrenmek icin
  /// Android'e ayri bir kanal cagrisi gerekirdi.
  ///
  /// **Varsayilan arm64:** 2019 sonrasi butun telefonlar arm64. Eski bir
  /// cihaz soz konusu olursa dogru cozum burayi degistirmek degil,
  /// mimariyi Android tarafindan sormak olur (`Build.SUPPORTED_ABIS`).
  static const String tercihEdilenApk = 'arm64';

  static bool get yapilandirildi => sahip.isNotEmpty && depo.isNotEmpty;
}
