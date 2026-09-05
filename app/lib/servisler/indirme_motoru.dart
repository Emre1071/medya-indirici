import '../alan/varliklar/indirme_isi.dart';
import '../alan/varliklar/indirme_sonucu.dart';
import '../alan/varliklar/medya_bilgisi.dart';

/// Kullaniciya gosterilebilir hata.
///
/// Motor katmani teknik ayrintiyi (yigin izi, yt-dlp cikti metni) **disariya
/// sizdirmaz**; kullaniciya ne yapabilecegini anlatan bir cumle verir.
/// Teknik ayrinti [ayrinti] alaninda kalir — kayit/hata ayiklama icin.
class MotorHatasi implements Exception {
  final String mesaj;
  final String? ayrinti;

  const MotorHatasi(this.mesaj, [this.ayrinti]);

  @override
  String toString() => mesaj;
}

/// Ilerleme bildirimi. Motor calisirken bunu tekrar tekrar cagirir.
typedef IlerlemeBildirimi = void Function(
  IsDurumu durum,
  double? oran,
  String? hiz,
);

/// Linki cozup indiren katmanin sozlesmesi.
///
/// ## Neden arayuz (abstract) ?
/// Iki gerceklestirmesi olacak:
/// - [SahteMotor] — Asama 1. Ekranlari tarayicida, telefon olmadan
///   gelistirebilmek icin. Gercekten indirmez, taklit eder.
/// - `YtDlpMotoru` — Asama 2. Android tarafindaki gomulu yt-dlp'yi
///   MethodChannel uzerinden cagirir.
///
/// Arayuz sayesinde Asama 2'de **ekran kodlarinin tek satiri degismeyecek**;
/// yalnizca hangi motorun kuruldugu degisecek.
abstract class IndirmeMotoru {
  /// Motor calismaya hazir mi?
  ///
  /// Gercek motorda ilk acilista gomulu Python ve ffmpeg ikililerinin
  /// acilmasi birkac saniye suruyor. O sirada gelen her cagri hata doner —
  /// bu yuzden arayuz once buraya bakip kullaniciyi bekletiyor. Sahte
  /// motorda kisa bir taklit gecikmesi var ki bekleme ekrani tarayicida da
  /// denenebilsin.
  Future<bool> hazirMi();

  /// Adrese bakip ne oldugunu soyler. Henuz indirme yok.
  ///
  /// Basarisizsa [MotorHatasi] firlatir.
  Future<MedyaBilgisi> cozumle(String adres);

  /// Indirir (gerekiyorsa donusturur ve telefonun ortak klasorune cikarir).
  ///
  /// [isKimlik] **cagiran taraftan** geliyor: iptal ve ilerleme bildirimleri
  /// bu kimlikle eslesiyor. Motorun kendi ic sayacini kullansaydi disaridan
  /// "su isi iptal et" demek mumkun olmazdi.
  ///
  /// [ilerleme] cagrisi **sik** gelir; arayuz tarafi bunu dogrudan
  /// `setState`'e baglamamali, kisilmali (bkz. kuyruk yonetimi).
  ///
  /// Iptal edilirse de [MotorHatasi] firlatir — cagiran taraf iptali kendi
  /// kaydindan bilir, hata metnini ayristirmasi gerekmez.
  Future<IndirmeSonucu> indir({
    required String isKimlik,
    required MedyaBilgisi bilgi,
    required IndirmeTuru tur,
    MedyaKalitesi? kalite,
    IlerlemeBildirimi? ilerleme,
  });

  /// Suren indirmeyi durdurur. Bilinmeyen kimlik sessizce yok sayilir —
  /// is zaten bitmis olabilir ve bu bir hata degil.
  Future<void> iptal(String isKimlik);

  /// Motorun (yt-dlp) kendi surumu. Ayarlar ekraninda gosterilir.
  /// Bilinmiyorsa `null`.
  Future<String?> motorSurumu();
}
