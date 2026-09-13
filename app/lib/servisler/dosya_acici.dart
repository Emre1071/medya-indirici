import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Inen dosyayi telefonun kendi uygulamalarinda acar veya paylasir.
///
/// ## Nicin motor arayuzunun icinde degil
/// [IndirmeMotoru] "linkten dosya uret" sozlesmesi; dosyayi acmak indirme
/// isi degil. Ayri tutulunca `SahteMotor` degismek zorunda kalmiyor ve
/// motor arayuzu dar kaliyor.
///
/// ## Android disinda sessizce kapali
/// `PaylasimDinleyici` ile ayni kalip: tarayicida kanal cagrisi
/// `MissingPluginException` atardi, o yuzden hic cagrilmiyor. `dart:io`
/// `Platform` kullanilmiyor — web derlemesinde erisilemiyor.
class DosyaAcici {
  static const MethodChannel _kanal = MethodChannel('medyaindirici/dosya');

  /// Bu hedefte dosya acilabiliyor mu?
  static bool get destekleniyor =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Dosyayi uygun bir uygulamada acar.
  ///
  /// Basarisizlikta **kullaniciya gosterilecek** Turkce cumle doner;
  /// basarida `null`. Istisna firlatmiyor: "Aç" dugmesi, basilinca kirmizi
  /// bir hata ekrani acacak bir sey degil.
  Future<String?> ac(String yol) => _calistir('dosyaAc', yol);

  /// Dosyayi paylasim menusune verir.
  Future<String?> paylas(String yol) => _calistir('dosyaPaylas', yol);

  Future<String?> _calistir(String yontem, String yol) async {
    if (!destekleniyor) {
      return 'Dosya açma yalnızca telefonda çalışıyor.';
    }

    try {
      await _kanal.invokeMethod<bool>(yontem, {'yol': yol});
      return null;
    } on PlatformException catch (h) {
      return _hataCevir(h.code);
    } on MissingPluginException {
      // Kanal yoksa (beklenmedik derleme) kullaniciyi teknik bir metinle
      // karsilamak yerine yapabilecegi seyi soyluyoruz.
      return 'Dosya açılamadı. Uygulamayı güncellemeyi dene.';
    }
  }

  /// Android tarafinin hata kodunu kullanicinin anlayacagi cumleye cevirir.
  ///
  /// Ayrim kod uzerinden yapiliyor, hata metni uzerinden degil: metin
  /// Android surumune gore degisir, kod degismez. (Ayni gerekce
  /// `KuyrukYoneticisi._iptalIstenenler` icin de gecerli.)
  String _hataCevir(String kod) => switch (kod) {
        'DOSYA_YOK' =>
          'Dosya bulunamadı. Telefondan silinmiş olabilir; listeden '
              'kaldırmak için geçmişi temizleyebilirsin.',
        'UYGULAMA_YOK' =>
          'Bu dosyayı açabilecek bir uygulama bulunamadı. Bir müzik '
              'çalar veya video oynatıcı kurmayı dene.',
        _ => 'Dosya açılamadı.',
      };
}
