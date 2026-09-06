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

/// Motorun acilis durumu.
///
/// ## Nicin duz `bool` degil?
/// Uc ayri hal var ve ucu de kullaniciya farkli sey soylemeli:
///
/// - **hazirlaniyor** — gomulu ikililer aciliyor, birkac saniye surecek.
///   Beklemek dogru.
/// - **hazir** — is gorulebilir.
/// - **kurulamadi** — kurulum BASARISIZ oldu, beklemenin anlami yok.
///
/// Duz `bool` ile son iki hal ayirt edilemiyordu: motor hic acilmasa da
/// arayuz "hazırlanıyor" deyip duruyor, kullanici da uygulamanin
/// takildigini saniyordu. Oysa yapabilecegi bir sey olabilir (dogru APK'yi
/// kurmak, yer acmak) — ama once sebebi gormesi gerek.
class MotorDurumu {
  final bool hazirMi;

  /// Kurulum basarisizsa **kullaniciya gosterilecek** cumle. Ham teknik
  /// metin degil; ne yapabilecegini anlatir.
  final String? hata;

  /// Teknik ayrinti: istisna zinciri + ortam raporu.
  ///
  /// Kullaniciya kendiliginden gosterilmiyor (anlamsiz gelir) ama Ayarlar'dan
  /// okunup kopyalanabiliyor. Cihaz `adb`'ye baglanamadiginda taninin tek
  /// kaynagi bu — o yuzden atilmiyor.
  final String? ayrinti;

  const MotorDurumu.hazirlaniyor()
      : hazirMi = false,
        hata = null,
        ayrinti = null;

  const MotorDurumu.hazir()
      : hazirMi = true,
        hata = null,
        ayrinti = null;

  const MotorDurumu.kurulamadi(String this.hata, {this.ayrinti})
      : hazirMi = false;

  bool get kurulamadiMi => hata != null;

  /// Beklemeye devam etmenin anlami var mi?
  bool get bekleniyorMu => !hazirMi && hata == null;
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
  /// Motorun acilis durumu.
  ///
  /// Gercek motorda ilk acilista gomulu Python ve ffmpeg ikililerinin
  /// acilmasi birkac saniye suruyor; bu sirada gelen her cagri hata doner.
  /// Kurulum tamamen basarisiz da olabiliyor — arayuz ikisini ayirt
  /// edebilsin diye [MotorDurumu] donuyor, duz `bool` degil.
  ///
  /// Sahte motorda kisa bir taklit gecikmesi var ki bekleme ekrani
  /// tarayicida da denenebilsin.
  Future<MotorDurumu> durum();

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
