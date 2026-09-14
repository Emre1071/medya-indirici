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
  /// Basarisizlikta [AcmaHatasi] doner, basarida `null`. Istisna
  /// firlatmiyor: "Aç" dugmesi, basilinca kirmizi bir hata ekrani acacak
  /// bir sey degil.
  ///
  /// [tur] isin `ses`/`video` alani. Android tarafi MIME cozemezse yedek
  /// degeri buna gore seciyor; tahmin etmek yanlis uygulamalari listeye
  /// sokar ya da dogrularini eler.
  Future<AcmaHatasi?> ac(String yol, {required String tur}) =>
      _calistir('dosyaAc', yol, tur);

  /// Dosyayi paylasim menusune verir.
  Future<AcmaHatasi?> paylas(String yol, {required String tur}) =>
      _calistir('dosyaPaylas', yol, tur);

  Future<AcmaHatasi?> _calistir(String yontem, String yol, String tur) async {
    if (!destekleniyor) {
      return const AcmaHatasi('Dosya açma yalnızca telefonda çalışıyor.');
    }

    try {
      await _kanal.invokeMethod<bool>(yontem, {'yol': yol, 'tur': tur});
      return null;
    } on PlatformException catch (h) {
      // 🔑 Ayrinti YUTULMUYOR. Android tarafi denedigi butun yollari ve
      // her birinin nicin tutmadigini dokuyor; cihaz `adb`'ye
      // baglanamadigi icin sebebi ogrenmenin baska yolu yok. Kullaniciya
      // kendiliginden gosterilmiyor, karta dokununca kopyalaniyor.
      return AcmaHatasi(_hataCevir(h.code), ayrinti: h.details as String?);
    } on MissingPluginException {
      // Kanal yoksa (beklenmedik derleme) kullaniciyi teknik bir metinle
      // karsilamak yerine yapabilecegi seyi soyluyoruz.
      return const AcmaHatasi(
        'Dosya açılamadı. Uygulamayı güncellemeyi dene.',
      );
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

/// Dosya acilamadiginda donen sonuc.
///
/// [mesaj] kullaniciya gosteriliyor; [ayrinti] denenen yollarin dokumu ve
/// yalnizca istendiginde aciliyor. Ayrimin gerekcesi `MotorHatasi` ile
/// ayni: ham metin kullaniciya yapabilecegi hicbir sey soylemiyor, ama
/// sorunu cozen tek sey o.
class AcmaHatasi {
  final String mesaj;
  final String? ayrinti;

  const AcmaHatasi(this.mesaj, {this.ayrinti});
}
