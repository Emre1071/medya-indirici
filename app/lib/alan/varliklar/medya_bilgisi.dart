/// Bir linkin **cozumlenmis** hali: motor (yt-dlp) linke bakip ne oldugunu
/// soyledikten sonra elimizde kalan bilgi.
///
/// Henuz hicbir sey indirilmedi — bu sadece "ne indirilecek" kartviziti.
class MedyaBilgisi {
  /// Cozumlenen asil link
  final String adres;

  final String baslik;

  /// Kapak gorseli adresi. **Olmayabilir** — bazi paylasimlarda kapak yok,
  /// arayuz o durumda yer tutucu gosterir.
  final String? kapakAdresi;

  /// Toplam sure. Bilinmiyorsa `null` (canli yayin, bozuk ustveri vb.).
  final Duration? sure;

  /// Iceigi paylasan hesap. Dosya adlandirmada ise yarar.
  final String? yukleyen;

  /// Nereden geldigi: `instagram`, `youtube`... Arayuzde rozet olarak cikar.
  final String kaynak;

  /// Secilebilir ses kaliteleri. Bos olabilir.
  final List<MedyaKalitesi> sesSecenekleri;

  /// Secilebilir video kaliteleri. Bos olabilir.
  final List<MedyaKalitesi> videoSecenekleri;

  const MedyaBilgisi({
    required this.adres,
    required this.baslik,
    required this.kaynak,
    this.kapakAdresi,
    this.sure,
    this.yukleyen,
    this.sesSecenekleri = const [],
    this.videoSecenekleri = const [],
  });

  bool get sesVar => sesSecenekleri.isNotEmpty;
  bool get videoVar => videoSecenekleri.isNotEmpty;

  /// Onerilen ses kalitesi: listedeki **en iyisi**.
  /// Motor zaten kaliteye gore sirali dondurecek (en iyi basta).
  MedyaKalitesi? get onerilenSes =>
      sesSecenekleri.isEmpty ? null : sesSecenekleri.first;

  MedyaKalitesi? get onerilenVideo =>
      videoSecenekleri.isEmpty ? null : videoSecenekleri.first;

  /// `0:47` / `1:03:20` bicimi. Sure yoksa bos metin.
  String get sureMetni {
    final s = sure;
    if (s == null) return '';

    final saat = s.inHours;
    final dakika = s.inMinutes.remainder(60);
    final saniye = s.inSeconds.remainder(60);
    final ss = saniye.toString().padLeft(2, '0');

    if (saat > 0) {
      return '$saat:${dakika.toString().padLeft(2, '0')}:$ss';
    }
    return '$dakika:$ss';
  }
}

/// Tek bir indirilebilir kalite secenegi.
class MedyaKalitesi {
  /// Kullaniciya gosterilen etiket: `720p`, `128 kbps` gibi.
  final String etiket;

  /// yt-dlp'nin format kimligi. Motora bunu veriyoruz.
  final String formatKimlik;

  /// Tahmini boyut. **Tahmin** oldugu icin `null` olabilir — yt-dlp her
  /// zaman boyut bildirmiyor. Arayuz bilinmeyeni bos birakir, `0 MB` yazmaz;
  /// yanlis sayi gostermek, hic gostermemekten kotudur.
  final int? boyutBayt;

  /// Kabin turu: `mp4`, `m4a`, `webm`...
  final String uzanti;

  const MedyaKalitesi({
    required this.etiket,
    required this.formatKimlik,
    required this.uzanti,
    this.boyutBayt,
  });

  /// `12.4 MB` bicimi. Boyut bilinmiyorsa bos metin.
  String get boyutMetni {
    final b = boyutBayt;
    if (b == null || b <= 0) return '';

    const mb = 1024 * 1024;
    if (b < mb) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / mb).toStringAsFixed(1)} MB';
  }
}
