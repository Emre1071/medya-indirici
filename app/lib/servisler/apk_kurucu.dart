import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Guncelleme APK'sini indirir ve Android'in kurulum ekranina teslim eder.
///
/// DevLingo'daki `ApkKurucu` ile ayni yapi — orada calistigi dogrulanmis
/// bir cozum oldugu icin yeniden tasarlanmadi.
///
/// ## Uc adim, ucu de basarisiz olabilir
/// 1. **Izin** — `REQUEST_INSTALL_PACKAGES` manifestte olsa bile Android 8'den
///    beri kullanicinin ayrica sistem ayarindan onaylamasi gerekiyor.
/// 2. **Indirme** — ag kesilebilir, adres yanlis olabilir.
/// 3. **Kurulum** — dosya bozuksa Android reddeder.
///
/// Her adim ayri bir hata mesaji veriyor. "Guncelleme basarisiz" demek
/// yetmez; kullanici hangi adimda takildigini bilmeli.
///
/// ## Bu uygulamada APK buyuk
/// DevLingo birkac MB'ti, bu ~100 MB olacak (Python + ffmpeg gomulu).
/// Bu yuzden ilerleme bildirimi burada kozmetik degil **gerekli**: yuzde
/// gostermeden 100 MB indirtmek, kullaniciya uygulamanin donduguu hissi verir.
class ApkKurucu {
  static const MethodChannel _kanal = MethodChannel('medyaindirici/kurulum');

  /// Indirilen dosyanin adi. Her seferinde ayni ad kullaniliyor:
  /// eski guncelleme dosyalari birikip telefonu doldurmasin.
  static const String _dosyaAdi = 'MedyaIndirici-guncelleme.apk';

  /// Kullanici "bilinmeyen kaynaklardan kurulum" iznini vermis mi?
  Future<bool> izinVarMi() async {
    if (!Platform.isAndroid) return false;
    final sonuc = await _kanal.invokeMethod<bool>('kurulumIzniVarMi');
    return sonuc ?? false;
  }

  /// Sistemin izin ekranini acar. Kullanici oradan donunce tekrar denenir.
  Future<void> izinEkraniniAc() async {
    if (!Platform.isAndroid) return;
    await _kanal.invokeMethod<void>('izinEkraniniAc');
  }

  /// APK'yi indirir, dosya yolunu doner.
  ///
  /// **Once gecici ada yaziliyor, bitince asil adina tasiniyor.** Neden:
  /// indirme yarida kesilirse (ag gitti, uygulama kapandi) geriye yarim bir
  /// APK kalirdi; bir sonraki denemede o yarim dosya "hazir" sanilip
  /// kuruluma verilebilirdi. Yarim dosya asla asil adi almiyor.
  Future<String> indir(
    String adres, {
    void Function(double oran)? ilerleme,
  }) async {
    final klasor = await getTemporaryDirectory();
    final hedef = File('${klasor.path}/$_dosyaAdi');
    final gecici = File('${hedef.path}.yariminda');

    if (gecici.existsSync()) gecici.deleteSync();
    if (hedef.existsSync()) hedef.deleteSync();

    final istemci = HttpClient();
    try {
      final istek = await istemci.getUrl(Uri.parse(adres));
      final yanit = await istek.close();

      if (yanit.statusCode != 200) {
        throw Exception('Sunucu ${yanit.statusCode} dondu');
      }

      final toplam = yanit.contentLength;
      var inen = 0;
      final akis = gecici.openWrite();

      await for (final parca in yanit) {
        akis.add(parca);
        inen += parca.length;
        // contentLength bilinmiyorsa -1 gelir; o zaman oran hesaplanamaz.
        if (toplam > 0) ilerleme?.call(inen / toplam);
      }

      await akis.flush();
      await akis.close();

      if (inen == 0) throw Exception('Dosya bos indi');

      await gecici.rename(hedef.path);
      return hedef.path;
    } finally {
      istemci.close(force: true);
    }
  }

  /// Kurulum ekranini acar. Buradan sonrasi Android'in ve kullanicinin isi —
  /// "Kur" dedigi an uygulamamiz kapanip yenisi kuruluyor.
  Future<void> kur(String dosyaYolu) async {
    await _kanal.invokeMethod<bool>('apkKur', {'yol': dosyaYolu});
  }
}
