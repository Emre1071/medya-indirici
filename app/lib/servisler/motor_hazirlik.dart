import 'indirme_motoru.dart';

/// Motor hazir olana kadar bekler.
///
/// ## Nicin yoklama (polling)?
/// Android tarafi "hazir oldum" diye kendiliginden haber vermiyor; kurulum
/// `MainActivity` icinde uygulama acilirken basliyor ve bitisi bir kanal
/// olayina baglanmis degil. Tek bir bayrak icin ayri bir EventChannel
/// acmak yerine saniyede birden az sikliktaki bu yoklama yeterli —
/// bekleme zaten birkac saniye suruyor.
///
/// ## Ust sinir nicin var?
/// Motor kurulumu **basarisiz da olabiliyor** (yer yok, ikili acilamadi).
/// Sonsuza kadar sormak, ekranda sonsuza kadar "hazırlanıyor" yazmasi
/// demek olurdu. Sinir dolunca vazgeciliyor ve **cagiran taraf yine de
/// devam ediyor**: motorun kendi hata mesaji ("İndirme motoru henüz
/// hazırlanıyor…") belirsiz bir beklemeden cok daha bilgilendirici.
///
/// Iki yerden cagriliyor — ana ekranin uyari seridi ve paylas menusunden
/// acilan onizleme sayfasi. Ayni bekleme mantiginin iki kopyasi olmasin
/// diye burada duruyor.
class MotorHazirlik {
  static const Duration varsayilanAralik = Duration(milliseconds: 750);

  /// ~30 saniye.
  static const int varsayilanDenemeSiniri = 40;

  /// Motor hazir olana kadar bekler.
  ///
  /// Doner: motor gercekten hazirsa `true`, sinir dolduysa `false`.
  ///
  /// [devamEdilsinMi] her denemeden once soruluyor; `false` derse bekleme
  /// birakiliyor. Ekranlar bunu `mounted` ile besliyor — kapanmis bir
  /// ekran icin 30 saniye boyunca yoklamaya devam etmek bosuna.
  static Future<bool> bekle(
    IndirmeMotoru motor, {
    Duration aralik = varsayilanAralik,
    int denemeSiniri = varsayilanDenemeSiniri,
    bool Function()? devamEdilsinMi,
  }) async {
    for (var deneme = 0; deneme < denemeSiniri; deneme++) {
      if (devamEdilsinMi != null && !devamEdilsinMi()) return false;

      if (await motor.hazirMi()) return true;

      await Future<void>.delayed(aralik);
    }
    return false;
  }
}
