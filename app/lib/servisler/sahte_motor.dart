import 'dart:async';

import '../alan/varliklar/indirme_isi.dart';
import '../alan/varliklar/indirme_sonucu.dart';
import '../alan/varliklar/medya_bilgisi.dart';
import 'indirme_motoru.dart';

/// Asama 1 motoru: **hicbir sey indirmez, indiriyormus gibi yapar.**
///
/// ## Nicin var
/// Gercek motor Android'e gomulu yt-dlp ile calisacak; tarayicida
/// calistirilamaz. Ekranlari tasarlarken her degisiklikte telefona derleme
/// atmak zaman kaybi olurdu. Bu sinif sayesinde butun arayuz akisi
/// (cozumleme beklemesi, ilerleme cubugu, donusturme asamasi, hata ekrani)
/// tarayicida saniyeler icinde denenebiliyor.
///
/// ## Gercekci olmasi bilerek
/// Gecikmeler, kademeli ilerleme ve **hata uretme** taklit ediliyor.
/// Sadece basarili durumu taklit eden bir sahte motor, hata ekranlarinin
/// hic denenmemesine yol acar — bunlar da en cok gorulen ekranlardir.
class SahteMotor implements IndirmeMotoru {
  /// Icinde `hata` gecen adresler bilerek basarisiz olur.
  /// Hata ekranini denemek icin: kutuya `https://instagram.com/hata` yaz.
  static const String _hataAnahtari = 'hata';

  /// Gercek motorda gomulu Python/ffmpeg ikililerinin acilmasi birkac
  /// saniye suruyor. Burada da taklit ediliyor ki "Motor hazırlanıyor…"
  /// uyarisi tarayicida gorulebilsin — sadece hazir durumu taklit eden bir
  /// sahte motor, o uyarinin hic denenmemesine yol acardi.
  static const Duration _hazirlanmaSuresi = Duration(milliseconds: 2500);

  final DateTime _acilis = DateTime.now();

  /// Iptal istenen islerin kimlikleri. [indir] her adimda buraya bakiyor.
  final Set<String> _iptalEdilenler = {};

  /// `true` yapilirsa motor kurulamamis gibi davraniyor.
  ///
  /// Kurulum hatasi ekrani tarayicida da gorulebilsin diye. Gercek motorda
  /// bu hal en cok "yanlis mimari icin derlenmis APK" durumunda yasaniyor
  /// ve o telefonu elde tutmadan denenemiyor.
  static bool kurulumuBozukTaklitEt = false;

  @override
  Future<MotorDurumu> durum() async {
    if (kurulumuBozukTaklitEt) {
      return const MotorDurumu.kurulamadi(
        'İndirme motoru başlatılamadı (sahte motor denemesi).',
      );
    }
    if (DateTime.now().difference(_acilis) >= _hazirlanmaSuresi) {
      return const MotorDurumu.hazir();
    }
    return const MotorDurumu.hazirlaniyor();
  }

  @override
  Future<void> iptal(String isKimlik) async {
    _iptalEdilenler.add(isKimlik);
  }

  @override
  Future<MedyaBilgisi> cozumle(String adres) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (adres.toLowerCase().contains(_hataAnahtari)) {
      throw const MotorHatasi(
        'Bağlantı çözümlenemedi. Gönderi silinmiş ya da hesap kapalı olabilir.',
        'SahteMotor: adres icinde "hata" gecti',
      );
    }

    final youtube = adres.contains('youtu');
    return youtube ? _sahteYoutube(adres) : _sahteInstagram(adres);
  }

  @override
  Future<IndirmeSonucu> indir({
    required String isKimlik,
    required MedyaBilgisi bilgi,
    required IndirmeTuru tur,
    MedyaKalitesi? kalite,
    IlerlemeBildirimi? ilerleme,
  }) async {
    ilerleme?.call(IsDurumu.iniyor, 0, null);

    // Kademeli indirme taklidi. Her adimda iptal kontrolu var: gercek
    // motorda da indirme parca parca ilerledigi icin iptal ancak bir
    // sonraki parcada etkisini gosteriyor.
    for (var adim = 1; adim <= 20; adim++) {
      await Future<void>.delayed(const Duration(milliseconds: 130));
      _iptalEdildiyseDur(isKimlik);

      final oran = adim / 20;
      ilerleme?.call(IsDurumu.iniyor, oran, '${(1.2 + adim % 4 * 0.3).toStringAsFixed(1)} MB/s');
    }

    // Donusturme yalnizca gercekten gerektiginde yasanir; taklidi de oyle
    // olmali ki arayuz "her indirmede donusturme var" varsayimina gore
    // tasarlanmasin.
    if (_donusturmeGerekir(bilgi, tur)) {
      ilerleme?.call(IsDurumu.donusturuluyor, null, null);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      _iptalEdildiyseDur(isKimlik);
    }

    final sesMi = tur == IndirmeTuru.ses;
    final uzanti = sesMi ? 'm4a' : 'mp4';

    return IndirmeSonucu(
      yol: '/sahte/indirilenler/${_dosyaAdiYap(bilgi.baslik)}.$uzanti',
      // Gercek motorda burasi MediaStore'a cikarilan klasor oluyor.
      kayitYeri: sesMi ? 'Music/Medya İndirici' : 'Movies/Medya İndirici',
    );
  }

  /// Iptal istendiyse isi keser ve kimligi kayittan dusurur.
  void _iptalEdildiyseDur(String isKimlik) {
    if (!_iptalEdilenler.remove(isKimlik)) return;
    throw const MotorHatasi('İndirme durduruldu.', 'SahteMotor: iptal');
  }

  @override
  Future<String?> motorSurumu() async => '2026.08.11 (sahte)';

  /// Instagram tek parca verir -> donusturme yok.
  /// YouTube video isteginde ses ve goruntu ayri gelir -> birlestirme var.
  bool _donusturmeGerekir(MedyaBilgisi bilgi, IndirmeTuru tur) =>
      bilgi.kaynak == 'youtube' && tur == IndirmeTuru.video;

  MedyaBilgisi _sahteInstagram(String adres) => MedyaBilgisi(
        adres: adres,
        kaynak: 'instagram',
        baslik: 'Hayırlı akşamlar 🎻🎸',
        yukleyen: 'huseyincan6302',
        sure: const Duration(seconds: 47),
        kapakAdresi: null,
        sesSecenekleri: const [
          MedyaKalitesi(
            etiket: '128 kbps',
            formatKimlik: 'audio-hq',
            uzanti: 'm4a',
            boyutBayt: 760 * 1024,
          ),
        ],
        videoSecenekleri: const [
          MedyaKalitesi(
            etiket: '1080p',
            formatKimlik: 'video-1080',
            uzanti: 'mp4',
            boyutBayt: 9 * 1024 * 1024,
          ),
          MedyaKalitesi(
            etiket: '720p',
            formatKimlik: 'video-720',
            uzanti: 'mp4',
            boyutBayt: 5 * 1024 * 1024,
          ),
        ],
      );

  MedyaBilgisi _sahteYoutube(String adres) => MedyaBilgisi(
        adres: adres,
        kaynak: 'youtube',
        baslik: 'İsmail YK - Her Şeyin Yalan',
        yukleyen: 'İsmail YK',
        sure: const Duration(minutes: 4, seconds: 12),
        kapakAdresi: null,
        sesSecenekleri: const [
          MedyaKalitesi(
            etiket: '160 kbps',
            formatKimlik: '251',
            uzanti: 'webm',
            boyutBayt: 5 * 1024 * 1024,
          ),
          MedyaKalitesi(
            etiket: '128 kbps',
            formatKimlik: '140',
            uzanti: 'm4a',
            boyutBayt: 4 * 1024 * 1024,
          ),
        ],
        videoSecenekleri: const [
          MedyaKalitesi(
            etiket: '1080p',
            formatKimlik: '137+140',
            uzanti: 'mp4',
            boyutBayt: 78 * 1024 * 1024,
          ),
          MedyaKalitesi(
            etiket: '720p',
            formatKimlik: '22',
            uzanti: 'mp4',
            boyutBayt: 41 * 1024 * 1024,
          ),
          MedyaKalitesi(
            etiket: '480p',
            formatKimlik: '135+140',
            uzanti: 'mp4',
            boyutBayt: 22 * 1024 * 1024,
          ),
        ],
      );

  /// Dosya adinda sorun cikaran karakterleri temizler.
  /// Gercek motorda da ayni is yapilacak — Windows/Android dosya
  /// sistemlerinin kabul etmedigi karakterler farkli, en dar kume seciliyor.
  static String _dosyaAdiYap(String baslik) {
    final temiz = baslik.replaceAll(RegExp(r'[\/:*?"<>|]'), '_').trim();
    return temiz.isEmpty ? 'indirme' : temiz;
  }
}
