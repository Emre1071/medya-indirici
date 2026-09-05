import '../../cekirdek/github_ayarlari.dart';

/// GitHub'da yayinlanmis "en son surum" kaydi.
///
/// ## `platform` alani nicin kalkti?
/// Supabase doneminde tek bir `surumler` tablosunda birden fazla uygulama
/// yan yana duruyordu ve satirlari `platform` sutunu ayiriyordu. GitHub'da
/// her uygulamanin **kendi deposu** var; ayirt edecek bir sey kalmadi.
class SurumBilgisi {
  /// Yayindaki en son surum, ornegin `1.0.1`.
  final String surum;

  /// APK'nin dogrudan indirme adresi. **Bos olabilir:** release yayinlanmis
  /// ama APK henuz yuklenmemis olabilir. O durumda yalnizca haber veriliyor,
  /// indirme dugmesi gosterilmiyor.
  final String? indirmeAdresi;

  /// Kullaniciya gosterilecek kisa degisiklik notu (release aciklamasi).
  final String? notlar;

  const SurumBilgisi({
    required this.surum,
    this.indirmeAdresi,
    this.notlar,
  });

  /// GitHub `releases/latest` yanitini okur.
  ///
  /// Yanit bizim yazdigimiz bir sema degil; GitHub'in semasi. O yuzden
  /// her alan savunmaci okunuyor — eksik ya da beklenmedik bir alan
  /// yuzunden uygulamanin acilisinda istisna firlamasi kabul edilemez.
  /// Okunamayan yanit icin `null` donuyor ve cagiran taraf bunu
  /// "bilinmiyor" sayiyor.
  static SurumBilgisi? githubdanKur(Map<String, dynamic> j) {
    final etiket = _metin(j['tag_name']);
    if (etiket == null) return null;

    return SurumBilgisi(
      // Etiketler `v1.0.1` bicimiyle yaziliyor; surum karsilastirmasi
      // bastaki `v`'yi sayi sanip okuyamaz ve "guncel" der. Burada
      // temizlenmesi sart.
      surum: etiketiSuruneCevir(etiket),
      indirmeAdresi: _apkAdresi(j['assets']),
      notlar: _metin(j['body']) ?? _metin(j['name']),
    );
  }

  /// `v1.2.3` -> `1.2.3`. Bastaki `v` disinda hicbir sey degistirilmiyor:
  /// okunamayan bir etiket sessizce duzeltilmeye calisilmiyor, oldugu gibi
  /// birakiliyor ve `Surum.yeniMi` onu "yeni degil" sayiyor.
  static String etiketiSuruneCevir(String etiket) {
    final e = etiket.trim();
    if (e.length > 1 && (e[0] == 'v' || e[0] == 'V')) return e.substring(1);
    return e;
  }

  /// Release varliklari arasindan indirilecek APK'yi secer.
  ///
  /// Her surumde iki APK var (arm64 ve armeabi-v7a). Once tercih edilen
  /// mimari araniyor, bulunamazsa herhangi bir `.apk`'ye dusuluyor —
  /// tek APK yayinlanan bir surumde de calissin diye. APK yoksa `null`.
  static String? _apkAdresi(Object? varliklar) {
    if (varliklar is! List) return null;

    String? yedek;
    for (final v in varliklar) {
      if (v is! Map) continue;

      final ad = _metin(v['name'])?.toLowerCase();
      final adres = _metin(v['browser_download_url']);
      if (ad == null || adres == null || !ad.endsWith('.apk')) continue;

      if (ad.contains(GitHubAyarlari.tercihEdilenApk)) return adres;
      yedek ??= adres;
    }
    return yedek;
  }

  /// Bos metin ile "deger yok" ayni sey sayilir — GitHub aciklamasi bos
  /// birakilmis bir release'de `''` gelir, onu adres/not sanmayalim.
  static String? _metin(Object? d) {
    if (d == null) return null;
    final m = d.toString().trim();
    return m.isEmpty ? null : m;
  }

  @override
  String toString() => 'SurumBilgisi($surum)';
}
