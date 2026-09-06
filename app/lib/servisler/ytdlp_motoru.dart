import 'dart:async';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../alan/varliklar/indirme_isi.dart';
import '../alan/varliklar/indirme_sonucu.dart';
import '../alan/varliklar/medya_bilgisi.dart';
import 'indirme_motoru.dart';

/// Telefona gomulu yt-dlp'yi calistiran gercek motor.
///
/// ## Sahte motorla ayni sozlesme
/// [IndirmeMotoru] arayuzunu dolduruyor; ekranlarin hicbiri hangi motorun
/// calistigini bilmiyor. Tarayicida sahte motor, telefonda bu calisiyor.
///
/// ## Hatalar burada TERCUME EDILIYOR
/// Android tarafi ham yt-dlp hata metinlerini yolluyor
/// (`ERROR: [Instagram] xyz: Requested content is not available...`).
/// Bunlar kullaniciya oldugu gibi gosterilemez. [_hataCevir] onlari
/// "ne yapabilirsin" anlatan Turkce cumlelere ceviriyor; ham metin
/// [MotorHatasi.ayrinti] icinde kaliyor.
class YtDlpMotoru implements IndirmeMotoru {
  static const MethodChannel _komut = MethodChannel('medyaindirici/motor');
  static const EventChannel _ilerlemeKanali =
      EventChannel('medyaindirici/motor/ilerleme');

  /// Kullanici sonucun kesinlikle `.mp3` olmasini istiyor mu?
  ///
  /// Varsayilan **kapali**: YouTube ve Instagram zaten calisan bir ses
  /// dosyasi (m4a/opus) veriyor ve o telefonun muzik calarinda sorunsuz
  /// aciliyor. mp3'e cevirmek ffmpeg calistirmak demek — ayni sonuc icin
  /// dakikalarca bekleme. Yalnizca eski cihazlar/araba teybi icin gerekiyor.
  final bool mp3Zorla;

  YtDlpMotoru({this.mp3Zorla = false});

  /// Ilerleme akisi. Butun isler ayni akistan geliyor, `isKimlik` ile
  /// ayrisiyorlar — bu yuzden tek bir yayin paylasiliyor.
  static Stream<Map<Object?, Object?>>? _paylasilanAkis;

  static Stream<Map<Object?, Object?>> get _akis {
    _paylasilanAkis ??= _ilerlemeKanali
        .receiveBroadcastStream()
        .map((o) => o as Map<Object?, Object?>)
        .asBroadcastStream();
    return _paylasilanAkis!;
  }

  @override
  Future<MedyaBilgisi> cozumle(String adres) async {
    try {
      final ham = await _komut.invokeMapMethod<String, Object?>(
        'cozumle',
        {'adres': adres},
      );

      if (ham == null) {
        throw const MotorHatasi('Bağlantı çözümlenemedi.');
      }
      return _bilgiyeCevir(ham);
    } on PlatformException catch (h) {
      throw MotorHatasi(_hataCevir(h.message), h.message);
    }
  }

  @override
  Future<IndirmeSonucu> indir({
    required String isKimlik,
    required MedyaBilgisi bilgi,
    required IndirmeTuru tur,
    MedyaKalitesi? kalite,
    IlerlemeBildirimi? ilerleme,
  }) async {
    // Dosya once uygulamanin kendi klasorune iniyor, indirme bitince
    // Android tarafi onu telefonun Muzik/Filmler klasorune cikariyor.
    //
    // Boyle ayrilmasinin sebebi: yarim kalan bir indirmenin galeride veya
    // muzik calarda bozuk dosya olarak gorunmemesi. Yalnizca tamamlanan
    // dosya disari cikiyor; iptal edilen dosya buradan siliniyor.
    final klasor = await getApplicationDocumentsDirectory();

    StreamSubscription<Map<Object?, Object?>>? abone;
    if (ilerleme != null) {
      abone = _akis.listen((olay) {
        if (olay['isKimlik'] != isKimlik) return;

        final oran = (olay['oran'] as num?)?.toDouble();
        final satir = olay['satir'] as String?;

        // yt-dlp donusturmeye gecince ilerleme yuzdesi durur ve ciktida
        // "[ExtractAudio]" / "[Merger]" satirlari gorunur. Kullaniciya
        // dolu bir cubugun basinda beklemek yerine ne olup bittigini
        // soylemek icin bu satirlari yakaliyoruz.
        final donusturuyor = satir != null &&
            (satir.contains('[ExtractAudio]') ||
                satir.contains('[Merger]') ||
                satir.contains('[VideoConvertor]'));

        ilerleme(
          donusturuyor ? IsDurumu.donusturuluyor : IsDurumu.iniyor,
          donusturuyor ? null : oran,
          null,
        );
      });
    }

    try {
      final ham = await _komut.invokeMapMethod<String, Object?>('indir', {
        'adres': bilgi.adres,
        'tur': tur == IndirmeTuru.ses ? 'ses' : 'video',
        'formatKimlik': kalite?.formatKimlik,
        'isKimlik': isKimlik,
        'hedefKlasor': '${klasor.path}/indirilenler',
        'mp3Zorla': tur == IndirmeTuru.ses && mp3Zorla,
      });

      final yol = ham?['yol'] as String?;
      if (yol == null || yol.isEmpty) {
        throw const MotorHatasi('İndirme tamamlandı ama dosya bulunamadı.');
      }

      // `kayitYeri` bos gelirse dosya disari cikarilamamis demektir; bunu
      // hata saymiyoruz (dosya duruyor) ama arayuz farki gostersin diye
      // `null` olarak tasiyoruz.
      final kayitYeri = ham?['kayitYeri'] as String?;
      return IndirmeSonucu(
        yol: yol,
        kayitYeri: (kayitYeri != null && kayitYeri.isNotEmpty)
            ? kayitYeri
            : null,
      );
    } on PlatformException catch (h) {
      throw MotorHatasi(_hataCevir(h.message), h.message);
    } finally {
      await abone?.cancel();
    }
  }

  /// Suren indirmeyi Android tarafinda gercekten olduruyor.
  ///
  /// Kotlin tarafi `destroyProcessById` ile yt-dlp surecini kesiyor ve
  /// yarim inen dosyalari siliyor. Bilinmeyen kimlik hata sayilmiyor:
  /// kullanici "durdur"a bastigi anda is bitmis olabilir ve bu, ekranda
  /// hata gostermeyi hak eden bir durum degil.
  @override
  Future<void> iptal(String isKimlik) async {
    try {
      await _komut.invokeMethod<void>('iptal', {'isKimlik': isKimlik});
    } on PlatformException {
      // Sessiz gecmek dogru: iptal edilemeyen bir is zaten ya bitmis ya da
      // hic baslamamistir.
    }
  }

  @override
  Future<String?> motorSurumu() async {
    try {
      return await _komut.invokeMethod<String>('motorSurumu');
    } on PlatformException {
      return null;
    }
  }

  /// Kurulumu bastan dener.
  ///
  /// Kurulum gecici bir sebeple (yer yoktu, sonra acildi) basarisiz
  /// olduysa uygulamayi kapatip acmaya gerek kalmasin diye.
  Future<void> motoruYenidenKur() async {
    try {
      await _komut.invokeMethod<void>('motoruYenidenKur');
    } on PlatformException {
      // Sonuc `durum()` ile okunuyor; burada hata gostermeye gerek yok.
    }
  }

  /// Motor (yt-dlp) kendini gunceller. Uygulamanin yeniden kurulmasi
  /// gerekmez — Instagram/YouTube degisikliklerinin cozumu budur.
  Future<String?> motoruGuncelle() async {
    try {
      return await _komut.invokeMethod<String>('motoruGuncelle');
    } on PlatformException catch (h) {
      throw MotorHatasi(
        'Motor güncellenemedi. İnternetini kontrol edip tekrar dene.',
        h.message,
      );
    }
  }

  /// Motorun acilis durumu.
  ///
  /// Android tarafi hem "hazir mi" hem de "kurulum neden basarisiz oldu"
  /// bilgisini birlikte veriyor. Ikisini ayirmak sart: kurulum basarisizsa
  /// beklemenin anlami yok ve kullaniciya sebebi gosterilmeli.
  @override
  Future<MotorDurumu> durum() async {
    try {
      final ham = await _komut.invokeMapMethod<String, Object?>('motorDurumu');
      if (ham == null) return const MotorDurumu.hazirlaniyor();

      if (ham['hazir'] == true) return const MotorDurumu.hazir();

      final hata = ham['hata'] as String?;
      if (hata == null || hata.isEmpty) {
        return const MotorDurumu.hazirlaniyor();
      }

      final rapor = ham['rapor'] as String?;
      return MotorDurumu.kurulamadi(
        _kurulumHatasiCevir(hata),
        // Ham metin kullaniciya gosterilmiyor ama saklaniyor: cihazdan log
        // alinamadiginda taninin tek kaynagi bu.
        ayrinti: rapor == null || rapor.isEmpty ? hata : '$hata\n\n$rapor',
      );
    } on PlatformException {
      return const MotorDurumu.hazirlaniyor();
    } on MissingPluginException {
      // Kanal yoksa (beklenmedik derleme) beklemeye devam etmek yanlis
      // olurdu; ama bunu "kurulamadi" sayip kullaniciyi korkutmak da
      // dogru degil. Motorun kendi hata mesaji zaten cozumlemede cikacak.
      return const MotorDurumu.hazirlaniyor();
    }
  }

  /// Kurulum hatasini kullanicinin yapabilecegi bir seye cevirir.
  ///
  /// En olasi sebep **yanlis mimari**: telefonun islemcisine uymayan bir
  /// APK kurulmussa gomulu ikili acilamiyor. Ham `UnsatisfiedLinkError`
  /// metnini gostermek kullaniciya hicbir sey soylemez.
  String _kurulumHatasiCevir(String ham) {
    final m = ham.toLowerCase();

    if (m.contains('unsatisfiedlink') ||
        m.contains('dlopen') ||
        m.contains('.so') ||
        m.contains('library')) {
      return 'İndirme motoru bu telefonda açılamadı. Kurulan APK '
          'telefonun işlemcisine uygun olmayabilir — arm64 sürümünü kur.';
    }
    if (m.contains('space') || m.contains('enospc')) {
      return 'İndirme motoru açılamadı: telefonda yer kalmamış. '
          'Biraz yer açıp uygulamayı yeniden başlat.';
    }
    return 'İndirme motoru başlatılamadı. Uygulamayı kapatıp yeniden '
        'açmayı, olmazsa yeniden kurmayı dene.';
  }

  // ------------------------------------------------------------- cevirmeler

  MedyaBilgisi _bilgiyeCevir(Map<String, Object?> h) {
    final sureSaniye = (h['sureSaniye'] as num?)?.toInt();

    return MedyaBilgisi(
      adres: h['adres'] as String? ?? '',
      baslik: h['baslik'] as String? ?? 'Adsız',
      kapakAdresi: h['kapakAdresi'] as String?,
      sure: sureSaniye == null ? null : Duration(seconds: sureSaniye),
      yukleyen: h['yukleyen'] as String?,
      kaynak: h['kaynak'] as String? ?? 'diger',
      sesSecenekleri: _kaliteleriCevir(h['sesSecenekleri']),
      videoSecenekleri: _kaliteleriCevir(h['videoSecenekleri']),
    );
  }

  List<MedyaKalitesi> _kaliteleriCevir(Object? ham) {
    if (ham is! List) return const [];

    return ham.whereType<Map<Object?, Object?>>().map((k) {
      return MedyaKalitesi(
        etiket: k['etiket'] as String? ?? 'bilinmiyor',
        formatKimlik: k['formatKimlik'] as String? ?? '',
        uzanti: k['uzanti'] as String? ?? '',
        boyutBayt: (k['boyutBayt'] as num?)?.toInt(),
      );
    }).toList();
  }

  /// Ham yt-dlp hatasini kullanicinin anlayacagi cumleye cevirir.
  ///
  /// Eslesmeyen hatalar icin genel bir cumle donuyor — ham metni ekrana
  /// basmak, kullaniciya yapabilecegi hicbir sey soylemedigi gibi
  /// uygulamayi bozuk gosterir.
  String _hataCevir(String? ham) {
    final m = (ham ?? '').toLowerCase();

    if (m.contains('iptal')) {
      return 'İndirme durduruldu.';
    }
    if (m.contains('motor_hazir_degil') ||
        m.contains('hazır değil') ||
        m.contains('hazir degil')) {
      return 'İndirme motoru henüz hazırlanıyor. Birkaç saniye sonra tekrar dene.';
    }
    if (m.contains('login') ||
        m.contains('rate-limit') ||
        m.contains('rate limit') ||
        m.contains('sign in')) {
      return 'Bu içerik giriş yapmayı gerektiriyor. Kapalı bir hesap olabilir.';
    }
    if (m.contains('private') || m.contains('not available')) {
      return 'İçeriğe ulaşılamadı. Gönderi silinmiş veya hesap kapalı olabilir.';
    }
    if (m.contains('unsupported url') || m.contains('no video')) {
      return 'Bu bağlantı desteklenmiyor. Gönderi bağlantısı olduğundan emin ol.';
    }
    if (m.contains('unable to download') ||
        m.contains('network') ||
        m.contains('timed out') ||
        m.contains('connection')) {
      return 'İnternet bağlantısı sorunlu görünüyor. Tekrar dene.';
    }
    if (m.contains('no space') || m.contains('enospc')) {
      return 'Telefonda yer kalmamış. Biraz yer açıp tekrar dene.';
    }
    return 'İndirme başarısız oldu. Motoru güncellemeyi dene (Ayarlar).';
  }
}
