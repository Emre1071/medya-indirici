import '../alan/varliklar/indirme_isi.dart';
import 'gecmis_deposu.dart';

/// Hicbir sey saklamayan depo — tarayici ve `dart:io` olmayan hedefler.
///
/// Tarayicida zaten `SahteMotor` calisiyor ve gercek dosya inmiyor; sahte
/// bir gecmisi diske yazmanin anlami yok. Sessizce bos donmek dogru
/// davranis: ekranlar "henuz indirme yok" gosteriyor, hicbir yerde hata
/// cikmiyor.
class BosGecmisDeposu implements GecmisDeposu {
  const BosGecmisDeposu();

  @override
  Future<List<IndirmeIsi>> yukle() async => const [];

  @override
  Future<void> kaydet(List<IndirmeIsi> gecmis) async {}

  @override
  Future<void> temizle() async {}
}

/// [gecmisDeposuSec] buraya dusuyor — `dart:io` yoksa.
GecmisDeposu gecmisDeposuAc() => const BosGecmisDeposu();
