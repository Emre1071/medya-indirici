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

  /// Adrese yapisan, icerikle ilgisi olmayan takip parametreleri.
  ///
  /// Bunlar paylasan kisiyi ve paylasim yolunu isaretliyor; gonderiyi
  /// bulmak icin gerekli degiller. Instagram'in `igsh`'i bir **paylasim
  /// jetonu** ve bazi durumlarda istegi "tanimadigim bir baglantidan
  /// geldi" konumuna dusuruyor.
  ///
  /// ⚠️ Listeye eklerken dikkat: `v` (YouTube video kimligi) ve `t`
  /// (baslangic saniyesi) gibi parametreler icerigin KENDISINI belirliyor,
  /// silinirse adres bozulur.
  static const Set<String> _takipParametreleri = {
    'igsh',
    'igshid',
    'stkn',
    'si',
    'feature',
    'fbclid',
    'gclid',
    'share_id',
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_content',
    'utm_term',
  };

  /// Ham metinden indirilecek adresi cikarir. Bulunamazsa `null`.
  ///
  /// Adres ayrica [temizle] ile takip parametrelerinden arindiriliyor.
  static String? ayikla(String? hamMetin) {
    if (hamMetin == null) return null;

    final adresler = _adresKalibi
        .allMatches(hamMetin)
        .map((e) => _kirp(e.group(0)!))
        .where((e) => e.isNotEmpty)
        .toList();

    if (adresler.isEmpty) return null;

    for (final adres in adresler) {
      if (tanidikMi(adres)) return temizle(adres);
    }

    // Tanidik alan yoksa ilk adres deneniyor. Reddetmek yerine denemek
    // dogru: yt-dlp bizim listemizden cok daha fazla siteyi taniyor ve
    // asil karari o veriyor.
    return temizle(adresler.first);
  }

  /// Adresten takip parametrelerini atar.
  ///
  /// Cozumlenemeyen adres **oldugu gibi** doner: burada amac temizlemek,
  /// adresi dogrulamak degil. Ayristirma hatasi yuzunden calisan bir
  /// baglantiyi elemek yanlis olurdu.
  static String temizle(String adres) {
    final u = Uri.tryParse(adres);
    if (u == null || !u.hasAuthority) return adres;
    if (u.queryParameters.isEmpty) return adres;

    final kalan = <String, String>{};
    u.queryParameters.forEach((anahtar, deger) {
      if (!_takipParametreleri.contains(anahtar.toLowerCase())) {
        kalan[anahtar] = deger;
      }
    });

    if (kalan.length == u.queryParameters.length) return adres;
    if (kalan.isNotEmpty) return u.replace(queryParameters: kalan).toString();

    // Hicbiri kalmadi: soru isareti de gitmeli.
    //
    // `replace(queryParameters: null)` ISE YARAMAZ — `Uri.replace` icin
    // `null` "bu parcayi degistirme" demek, yani sorgu oldugu gibi kalir.
    // Sorguyu gercekten atmanin yolu adresi parcalarindan yeniden kurmak.
    return Uri(
      scheme: u.scheme,
      userInfo: u.userInfo.isEmpty ? null : u.userInfo,
      host: u.host,
      port: u.hasPort ? u.port : null,
      path: u.path,
      fragment: u.fragment.isEmpty ? null : u.fragment,
    ).toString();
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
