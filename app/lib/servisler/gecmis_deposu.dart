import '../alan/varliklar/indirme_isi.dart';
import 'gecmis_deposu_bos.dart'
    if (dart.library.io) 'gecmis_deposu_dosya.dart' as gerceklestirme;

/// Indirme gecmisini kalici hale getiren katman.
///
/// ## Nicin sqflite degil?
/// `PLAN.md` §6 sqflite diyor; burada bilincli olarak sapildi (ayni cizgi
/// riverpod yerine `ChangeNotifier` kullanilmasinda da izlendi). Gerekce:
///
/// - Veri **tek boyutlu**: is basina bir satir, birkac yuz kayit, sorgu
///   yok, birlestirme yok, en fazla "yeniden eskiye" siralama. SQL'in
///   verdigi hicbir sey kullanilmayacak.
/// - `path_provider` **zaten bagimlilik listesinde** (APK guncellemesi
///   icin). Tek JSON dosyasi sifir yeni paket demek. Projenin cizgisi bu
///   (bkz. `ApkKurucu` basindaki not: 40 satirlik is icin paket yok).
/// - sqflite **web'de calismiyor**; asagidaki ikili yapiyi zorunlu kilmak
///   disinda bir sey kazandirmiyordu.
///
/// ## Hicbir cagri hata firlatmiyor
/// [GuncellemeServisi] ile ayni kural: gecmis dosyasi yarim yazilmis,
/// elle bozulmus veya eski bir surumden kalmis olabilir. Bunun bedeli en
/// fazla "liste bos gorunur" olmali — acilmayan bir uygulama degil.
abstract class GecmisDeposu {
  /// Diskteki gecmis. Dosya yoksa veya bozuksa **bos liste**.
  Future<List<IndirmeIsi>> yukle();

  /// Gecmisi diske yazar. Basarisizlik sessizce yutuluyor.
  Future<void> kaydet(List<IndirmeIsi> gecmis);

  /// Kalici kaydi tamamen siler.
  Future<void> temizle();
}

/// Calisilan hedefe uygun depoyu secer.
///
/// Motor seciminin (`main.dart` → `_motorSec()`) ayni kalibi, ama burada
/// `kIsWeb` yerine **kosullu import** kullaniliyor: `dart:io`'ya bakan kod
/// web derlemesinde calisma aninda degil **derleme aninda** patliyor, yani
/// bir `if` ile kacinilamiyor. Kosullu import o dosyayi web hedefine hic
/// almiyor.
GecmisDeposu gecmisDeposuSec() => gerceklestirme.gecmisDeposuAc();
