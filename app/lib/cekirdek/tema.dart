import 'package:flutter/material.dart';

/// Uygulamanin renk paleti (koyu tema).
///
/// DevLingo'nun paletiyle akraba — ayni elden cikmis gibi dursun diye.
/// Ayrildigi yer **vurgu rengi**: orada mavi, burada mor. Iki uygulama
/// telefonda yan yana duracagi icin ilk bakista ayirt edilmeleri gerekiyor.
class Renkler {
  static const arkaPlan = Color(0xFF121417);
  static const yuzey = Color(0xFF1B1F24);
  static const yuzeyAcik = Color(0xFF252B33);
  static const kenarlik = Color(0xFF323A44);

  static const vurgu = Color(0xFF9B7BFF);

  /// Ses ve video **ayri renkler** — kullanici ekrana bakmadan, kas
  /// hafizasiyla dogru dugmeye basabilsin. Paylas menusunden gelip
  /// saniyede karar verilen bir ekran burasi; okumak zorunda kalmamali.
  ///
  /// **Ses zumrut/teal.** Onceki `0xFF3DDC84` (Android yesili) biraz
  /// soluktu; bu ton koyu zeminde daha net duruyor ve yesil ailesinde
  /// kaldigi icin alisilmis "ses = yesil" refleksini bozmuyor.
  ///
  /// ⚠️ **Amber SECILMEDI.** Muzik cagrisimi acisindan iyi bir aday ama
  /// [uyari] rengi de amber; kullanici turuncu/sari bir isareti "dikkat"
  /// diye okumayi ogrendi (motor seridi, "disari cikarilamadi" uyarisi).
  /// Ses dugmesini ayni tona cekmek o ayrimi bozardi.
  static const ses = Color(0xFF2ED3B7);
  static const video = Color(0xFF4DA3FF);

  static const uyari = Color(0xFFFFB86C);
  static const hata = Color(0xFFFF5C5C);

  static const metin = Color(0xFFE8EAED);
  static const metinSolgun = Color(0xFF9AA4B2);
}

/// Arayuz olculeri. Hedef cihaz yine bir Android telefon;
/// mantiksal genislik ~393 piksel varsayiliyor.
class Olculer {
  static const double telefonGenislik = 393;
  static const double telefonYukseklik = 873;

  static const double baslikBuyuk = 20;
  static const double baslik = 16;
  static const double govde = 14;
  static const double kucukBilgi = 12.5;
  static const double etiket = 11.5;

  /// Ses/Video dugmelerinin yuksekligi. Bilerek buyuk: paylas menusunden
  /// gelen kullanici tek eliyle, yururken basiyor olabilir.
  static const double buyukDugme = 64;

  static const double bosluk = 12;
  static const double kenarBosluk = 16;
  static const double kose = 14;
}

ThemeData koyuTema() {
  final taban = ThemeData.dark(useMaterial3: true);

  return taban.copyWith(
    scaffoldBackgroundColor: Renkler.arkaPlan,
    colorScheme: taban.colorScheme.copyWith(
      primary: Renkler.vurgu,
      surface: Renkler.yuzey,
      onSurface: Renkler.metin,
      error: Renkler.hata,
    ),
    cardTheme: const CardThemeData(
      color: Renkler.yuzey,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Renkler.arkaPlan,
      foregroundColor: Renkler.metin,
      elevation: 0,
      centerTitle: true,
    ),
    dividerTheme: const DividerThemeData(
      color: Renkler.kenarlik,
      thickness: 1,
      space: 1,
    ),
    textTheme: taban.textTheme.apply(
      bodyColor: Renkler.metin,
      displayColor: Renkler.metin,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Renkler.yuzey,
      hintStyle: const TextStyle(color: Renkler.metinSolgun),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Olculer.kose),
        borderSide: const BorderSide(color: Renkler.kenarlik),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Olculer.kose),
        borderSide: const BorderSide(color: Renkler.kenarlik),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Olculer.kose),
        borderSide: const BorderSide(color: Renkler.vurgu, width: 1.6),
      ),
    ),
  );
}
