import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../alan/varliklar/indirme_isi.dart';
import 'gecmis_deposu.dart';

/// Gecmisi uygulamanin kendi klasorundeki tek bir JSON dosyasinda tutar.
///
/// ## Nerede duruyor
/// `getApplicationDocumentsDirectory()/gecmis.json` — uygulamanin ozel
/// alani. Disari acik degil, uygulama kaldirilinca siliniyor. Ayni klasor
/// indirmelerin gecici olarak indigi yer (`YtDlpMotoru.indir`), yani yeni
/// bir izin veya yeni bir yol gerekmiyor.
///
/// ## Atomik yazma
/// Once `.yariminda` uzantili gecici dosyaya yaziliyor, sonra asil adin
/// uzerine tasiniyor. Dogrudan yazilsaydi, yazma sirasinda uygulama
/// oldurulen bir telefonda (Android arka plan uygulamalarini rahatca
/// olduruyor) geride **yarim bir JSON** kalirdi ve butun gecmis okunamaz
/// hale gelirdi. Ayni kalip `ApkKurucu`'da da kullaniliyor.
class DosyaGecmisDeposu implements GecmisDeposu {
  /// Dosya bicimi surumu.
  ///
  /// Ileride alan eklenip cikarildiginda eski dosyayi **sessizce
  /// yoksaymak** icin. Surum kontrolu olmasaydi, tanimadigi alanlarla
  /// karsilasan bir surum ya cokerdi ya da yanlis veri gosterirdi.
  static const int _surum = 1;

  static const String _dosyaAdi = 'gecmis.json';

  File? _onbellek;

  Future<File> _dosya() async {
    final mevcut = _onbellek;
    if (mevcut != null) return mevcut;

    final klasor = await getApplicationDocumentsDirectory();
    final dosya = File('${klasor.path}/$_dosyaAdi');
    _onbellek = dosya;
    return dosya;
  }

  @override
  Future<List<IndirmeIsi>> yukle() async {
    try {
      final dosya = await _dosya();
      if (!await dosya.exists()) return const [];

      final ham = jsonDecode(await dosya.readAsString());
      if (ham is! Map) return const [];
      if (ham['surum'] != _surum) return const [];

      final isler = ham['isler'];
      if (isler is! List) return const [];

      // Bozuk tek bir satir butun listeyi dusurmuyor: `fromJson` `null`
      // donuyor ve o satir eleniyor.
      final sonuc = <IndirmeIsi>[];
      for (final satir in isler) {
        final is_ = IndirmeIsi.fromJson(satir);
        if (is_ != null) sonuc.add(is_);
      }
      return sonuc;
    } catch (_) {
      // Okunamayan gecmis = bos gecmis. Kullanicinin indirme yapmasini
      // engellemesi icin hicbir sebep yok.
      return const [];
    }
  }

  @override
  Future<void> kaydet(List<IndirmeIsi> gecmis) async {
    try {
      final dosya = await _dosya();
      final gecici = File('${dosya.path}.yariminda');

      await gecici.writeAsString(
        jsonEncode({
          'surum': _surum,
          'isler': gecmis.map((i) => i.toJson()).toList(),
        }),
        flush: true,
      );
      await gecici.rename(dosya.path);
    } catch (_) {
      // Yazilamayan gecmis, indirmeyi basarisiz saymak icin sebep degil.
      // Dosya bir sonraki kayitta yeniden denenecek.
    }
  }

  @override
  Future<void> temizle() async {
    try {
      final dosya = await _dosya();
      if (await dosya.exists()) await dosya.delete();
    } catch (_) {
      // Silinemediyse bir sonraki `kaydet` zaten uzerine yazacak.
    }
  }
}

/// [gecmisDeposuSec] buraya dusuyor — `dart:io` varken.
GecmisDeposu gecmisDeposuAc() => DosyaGecmisDeposu();
