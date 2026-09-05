/// Paylasilan ham metinden indirilecek adresi ayiklar.
///
/// ## Nicin ayri bir is?
/// Paylas menusunden gelen sey **temiz bir link degil.** Instagram
/// paylasimi genelde soyle geliyor:
///
/// ```
/// Şerif Ruç on Instagram: "Hayırlı akşamlar 🎻🎸"
/// https://www.instagram.com/reel/DAbC123/?igsh=MXY5aA==
/// ```
///
/// YouTube ise cogu zaman baslik + kisa adres yolluyor. Bu metni oldugu
/// gibi motora vermek "Unsupported URL" ile biter; kullanici da neden
/// olmadigini anlamaz.
class Baglanti {
  /// Desteklenen kaynaklarin alan adlari.
  ///
  /// Metinde birden fazla adres varsa **bunlara oncelik veriliyor**.
  /// Instagram paylasimlari aciklama icinde baska linkler tasiyabiliyor
  /// (profil adresi, bagis linki, reklam); ilk bulunani almak yanlis
  /// gonderiyi indirmek olurdu.
  static const Set<String> tanidikAlanlar = {
    'instagram.com',
    'instagr.am',
    'youtube.com',
    'youtu.be',
    'youtube-nocookie.com',
    'facebook.com',
    'fb.watch',
    'tiktok.com',
  };

  /// Bosluga kadar giden http(s) adresi.
  ///
  /// Tirnak ve aci parantez de sinir sayiliyor: paylasim metinlerinde
  /// adres cogu zaman tirnak icinde ya da HTML kirintisi yaninda geliyor.
  static final RegExp _adresKalibi = RegExp(
    r'''https?://[^\s<>"'`]+''',
    caseSensitive: false,
  );

  /// Adresin sonuna yapisan noktalama.
  ///
  /// `=` **bilerek yok**: Instagram'in `?igsh=MXY5aA==` gibi parametreleri
  /// esittir ile bitiyor, onu kirpmak adresi bozar.
  static const String _sondakiNoktalama = '.,;:!?"\'`)]}»>';

  /// Ham metinden indirilecek adresi cikarir. Bulunamazsa `null`.
  static String? ayikla(String? hamMetin) {
    if (hamMetin == null) return null;

    final adresler = _adresKalibi
        .allMatches(hamMetin)
        .map((e) => _kirp(e.group(0)!))
        .where((e) => e.isNotEmpty)
        .toList();

    if (adresler.isEmpty) return null;

    for (final adres in adresler) {
      if (tanidikMi(adres)) return adres;
    }

    // Tanidik alan yoksa ilk adres deneniyor. Reddetmek yerine denemek
    // dogru: yt-dlp bizim listemizden cok daha fazla siteyi taniyor ve
    // asil karari o veriyor.
    return adresler.first;
  }

  /// Adres desteklenen bir kaynaga mi ait?
  static bool tanidikMi(String adres) {
    final sunucu = _sunucu(adres);
    if (sunucu == null) return false;

    // `www.instagram.com` ve `m.youtube.com` gibi alt alanlar da sayiliyor;
    // ama `instagram.com.sahte.net` sayilmamali — bu yuzden duz `contains`
    // degil, nokta sinirina bakan bir karsilastirma.
    for (final alan in tanidikAlanlar) {
      if (sunucu == alan || sunucu.endsWith('.$alan')) return true;
    }
    return false;
  }

  static String? _sunucu(String adres) {
    final u = Uri.tryParse(adres);
    if (u == null || !u.hasAuthority) return null;
    return u.host.toLowerCase();
  }

  /// Adresin sonundaki noktalamayi atar.
  ///
  /// `(bkz. https://youtu.be/abc)` gibi bir metinde kapanis parantezi
  /// adrese yapisiyor ve adresi bozuyor.
  static String _kirp(String adres) {
    var son = adres.length;
    while (son > 0 && _sondakiNoktalama.contains(adres[son - 1])) {
      son--;
    }
    return adres.substring(0, son);
  }
}
