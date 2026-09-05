import 'medya_bilgisi.dart';

/// Kullanicinin indirmek istedigi tur.
enum IndirmeTuru {
  /// Sadece ses. Cogu zaman **donusturme bile gerekmez** — kaynaklar hazir
  /// ses dosyasi sunuyor (m4a/opus), o dogrudan iniyor. ffmpeg yalnizca
  /// kullanici illa `.mp3` isterse devreye giriyor.
  ses,

  /// Sesli video. Instagram/Facebook'ta tek parca gelir (donusturme yok),
  /// YouTube'da video ve ses ayri gelir (ffmpeg birlestirir).
  video,
}

/// Bir isin hangi asamada oldugu.
///
/// `donusturuluyor` ayri bir asama cunku kullanici acisindan **hissedilir
/// bir bekleme**: yuzde 100'e ulasmis ama dosya hala hazir degil. Bunu
/// "indiriliyor" icinde gostermek, ilerleme cubugu dolu dururken hicbir sey
/// olmuyormus izlenimi verir.
enum IsDurumu {
  bekliyor,
  cozumleniyor,
  iniyor,
  donusturuluyor,
  bitti,
  hata,
  iptal,
}

/// Kuyruktaki tek bir indirme isi.
///
/// **Degismez (immutable).** Ilerleme geldiginde nesne degistirilmiyor,
/// [kopyala] ile yenisi uretiliyor. Sebep: ayni isi hem kuyruk listesi hem
/// bildirim hem de gecmis ekrani okuyor; ortak nesneyi yerinde degistirmek,
/// hangi ekranin ne zaman yenilendigini takip edilemez hale getirir.
class IndirmeIsi {
  /// Benzersiz kimlik. Bildirim kimligi olarak da kullanilacak.
  final String kimlik;

  final String adres;
  final IndirmeTuru tur;
  final IsDurumu durum;

  /// Cozumleme bitince dolar. Oncesinde `null` — bu yuzden kuyrukta is
  /// once sadece adresiyle gorunur, saniyeler sonra basligi ve kapagi gelir.
  final MedyaBilgisi? bilgi;

  /// Secilen kalite. `null` ise "onerileni kullan".
  final MedyaKalitesi? kalite;

  /// 0.0 - 1.0 arasi. Bilinmiyorsa `null` (belirsiz ilerleme cubugu).
  final double? oran;

  /// Anlik hiz metni, motordan geldigi gibi: `1.2 MB/s`.
  final String? hiz;

  /// Bitince dosyanin telefondaki yeri.
  final String? dosyaYolu;

  /// Dosyanin cikarildigi klasorun kullaniciya gosterilen adi
  /// (`Music/Medya İndirici`). `null` ise dosya disari cikarilamadi ve
  /// uygulamanin kendi klasorunde kaldi — kullanici onu muzik calarda
  /// bulamaz, bu yuzden ekranda ayirt ediliyor.
  final String? kayitYeri;

  /// Hata durumunda **kullaniciya gosterilecek** mesaj.
  /// Teknik yigin izi degil; ne yapabilecegini anlatan cumle.
  final String? hataMesaji;

  const IndirmeIsi({
    required this.kimlik,
    required this.adres,
    required this.tur,
    this.durum = IsDurumu.bekliyor,
    this.bilgi,
    this.kalite,
    this.oran,
    this.hiz,
    this.dosyaYolu,
    this.kayitYeri,
    this.hataMesaji,
  });

  bool get bitmis => durum == IsDurumu.bitti;
  bool get calisyor =>
      durum == IsDurumu.cozumleniyor ||
      durum == IsDurumu.iniyor ||
      durum == IsDurumu.donusturuluyor;

  /// Kuyrukta gosterilecek ad. Baslik henuz gelmediyse adresin kendisi.
  String get gosterilecekAd => bilgi?.baslik ?? adres;

  String get durumMetni => switch (durum) {
        IsDurumu.bekliyor => 'Sirada',
        IsDurumu.cozumleniyor => 'Baglantı çözümleniyor…',
        IsDurumu.iniyor => 'İndiriliyor',
        IsDurumu.donusturuluyor => 'Dönüştürülüyor…',
        IsDurumu.bitti => 'Tamamlandı',
        IsDurumu.hata => hataMesaji ?? 'Hata',
        IsDurumu.iptal => 'İptal edildi',
      };

  IndirmeIsi kopyala({
    IsDurumu? durum,
    MedyaBilgisi? bilgi,
    MedyaKalitesi? kalite,
    double? oran,
    String? hiz,
    String? dosyaYolu,
    String? kayitYeri,
    String? hataMesaji,
  }) {
    return IndirmeIsi(
      kimlik: kimlik,
      adres: adres,
      tur: tur,
      durum: durum ?? this.durum,
      bilgi: bilgi ?? this.bilgi,
      kalite: kalite ?? this.kalite,
      oran: oran ?? this.oran,
      hiz: hiz ?? this.hiz,
      dosyaYolu: dosyaYolu ?? this.dosyaYolu,
      kayitYeri: kayitYeri ?? this.kayitYeri,
      hataMesaji: hataMesaji ?? this.hataMesaji,
    );
  }
}
