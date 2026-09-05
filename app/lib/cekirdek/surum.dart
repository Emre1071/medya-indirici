/// Uygulamanin surumu ve surum karsilastirmasi.
///
/// DevLingo'daki `cekirdek/surum.dart` ile **ayni yaklasim** — oradaki
/// gerekce burada da gecerli: `package_info_plus` bir platform eklentisidir,
/// tek bir sayiyi okumak icin kirilacak bir yer eklemeye degmez.
///
/// **Bedeli:** surum burada ELLE yaziliyor, `pubspec.yaml` ile ayni kalmali.
/// Unutmaya acik oldugu icin bir test bunu bagliyor
/// (`test/surum_test.dart`): pubspec ile bu sabit ayrisirsa test kirmizi yanar.
///
/// **Surum yukseltirken:** once `pubspec.yaml` -> `version:`, sonra buradaki
/// [simdiki]. Testi calistir, yesilse dogru yapmissin.
class Surum {
  /// Bu derlemenin surumu. `pubspec.yaml` ile AYNI olmali.
  static const String simdiki = '0.1.0';

  /// `1.0.2` > `1.0.10` gibi metin karsilastirma tuzagina dusmemek icin
  /// parcalar **sayi olarak** kiyaslanir.
  ///
  /// Doner: `a > b` ise pozitif, `a < b` ise negatif, esitse 0.
  static int karsilastir(String a, String b) {
    final pa = _parcala(a);
    final pb = _parcala(b);

    // '1.0' ile '1.0.0' esit sayilir: eksik parca 0 kabul edilir.
    final uzunluk = pa.length > pb.length ? pa.length : pb.length;

    for (var i = 0; i < uzunluk; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }

  /// [aday], [mevcut]'tan yeni mi?
  ///
  /// **Okunamayan surum "yeni degil" sayilir.** Bozuk bir kayit yuzunden her
  /// acilista "guncelleme var" demek, uyarinin tamamini guvenilmez yapar.
  static bool yeniMi({required String mevcut, required String aday}) {
    if (_parcala(aday).isEmpty) return false;
    return karsilastir(aday, mevcut) > 0;
  }

  /// `'1.2.3+4'` -> `[1, 2, 3]`. Yapi numarasi (`+4`) surum kiyasina girmez;
  /// o Android'in kendi ic sayaci.
  static List<int> _parcala(String surum) {
    final govde = surum.trim().split('+').first;
    if (govde.isEmpty) return const [];

    final parcalar = <int>[];
    for (final p in govde.split('.')) {
      final sayi = int.tryParse(p.trim());
      if (sayi == null) return const [];
      parcalar.add(sayi);
    }
    return parcalar;
  }
}
