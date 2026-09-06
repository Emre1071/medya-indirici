import 'package:flutter/foundation.dart';

import '../alan/varliklar/indirme_isi.dart';
import '../alan/varliklar/medya_bilgisi.dart';
import 'indirme_motoru.dart';

/// Indirme kuyrugunu tutar ve sirayla isletir.
///
/// ## Neden `ChangeNotifier`, neden bir paket degil?
/// DevLingo'daki cizgi burada da korunuyor: fazladan bagimlilik yok.
/// `ChangeNotifier` Flutter'in kendi icinde geliyor, kuyruk gibi tek bir
/// paylasilan durum icin fazlasiyla yeterli.
///
/// ## Neden tek tek, ayni anda degil?
/// Ayni anda bes indirme baslatmak telefonun agini ve islemcisini bolerdi;
/// hepsi birden yavaslar, hicbiri bitmez. Ustelik donusturme (ffmpeg)
/// islemci yiyor — paralel calisirsa telefon isinir. Sirayla islemek
/// **toplamda daha hizli bitiriyor** ve ilerleme cubugu anlamli oluyor.
class KuyrukYoneticisi extends ChangeNotifier {
  final IndirmeMotoru motor;

  KuyrukYoneticisi(this.motor);

  final List<IndirmeIsi> _kuyruk = [];
  final List<IndirmeIsi> _gecmis = [];

  /// Su an islenen isin kimligi. Bosta ise `null`.
  String? _calisanKimlik;

  /// Iptali istenen islerin kimlikleri.
  ///
  /// ## Nicin ayri bir kayit tutuluyor?
  /// Motor iptal edildiginde de **hata firlatiyor** (surec olduruldu).
  /// Hata metnine bakip "bu aslinda iptaldi" diye karar vermek kirilgan
  /// olurdu: metin yt-dlp surumune gore degisiyor ve dile bagli. Iptali
  /// biz istedigimiz icin cevabi zaten biliyoruz — burada tutuyoruz.
  final Set<String> _iptalIstenenler = {};

  /// Kimlik uretimi icin sayac.
  ///
  /// `DateTime.now()` yerine sayac: ayni milisaniyede eklenen iki is ayni
  /// kimligi alabilirdi ve kimlik ayni zamanda **bildirim kimligi** olacak —
  /// carpisan iki kimlik, iki indirmenin tek bildirimi ezmesi demek olurdu.
  int _sayac = 0;

  List<IndirmeIsi> get kuyruk => List.unmodifiable(_kuyruk);
  List<IndirmeIsi> get gecmis => List.unmodifiable(_gecmis);
  bool get mesgul => _calisanKimlik != null;

  /// Kuyruga yeni is ekler ve isletmeyi tetikler.
  /// Eklenen isin kimligini doner.
  String ekle(String adres, IndirmeTuru tur, {MedyaKalitesi? kalite}) {
    final kimlik = 'is_${_sayac++}';
    _kuyruk.add(IndirmeIsi(
      kimlik: kimlik,
      adres: adres.trim(),
      tur: tur,
      kalite: kalite,
    ));
    notifyListeners();
    _isletmeyiDurtukle();
    return kimlik;
  }

  /// Onizlemede zaten cozumlenmis bir medyayi kuyruga alir.
  ///
  /// Cozumlemeyi ikinci kez yapmamak icin [bilgi] hazir veriliyor —
  /// kullanici kapagi gormus, secimini yapmis; ayni sorguyu tekrarlamak
  /// hem zaman kaybi hem de kaynak siteye gereksiz istek.
  String ekleCozumlenmis(
    MedyaBilgisi bilgi,
    IndirmeTuru tur, {
    MedyaKalitesi? kalite,
  }) {
    final kimlik = 'is_${_sayac++}';
    _kuyruk.add(IndirmeIsi(
      kimlik: kimlik,
      adres: bilgi.adres,
      tur: tur,
      bilgi: bilgi,
      kalite: kalite,
    ));
    notifyListeners();
    _isletmeyiDurtukle();
    return kimlik;
  }

  /// Isi kuyruktan cikarir; **calisan is ise gercekten durdurur.**
  ///
  /// Tek kapi olmasi bilincli: cagiran taraf isin o an calisip
  /// calismadigini bilmek zorunda kalmasin. Iki durum farkli davraniyor:
  ///
  /// - **Bekleyen is** listeden silinir, iz birakmaz.
  /// - **Calisan is** motora iptal edilir ve listede `iptal` durumuyla
  ///   kalir. Silinip yok olsaydi kullanici "durdur"a bastiktan sonra
  ///   isin gercekten durup durmadigini goremezdi; kart duruyor, uzerinde
  ///   "İptal edildi" yaziyor ve ikinci dokunusla listeden cikiyor.
  Future<void> sil(String kimlik) async {
    if (kimlik != _calisanKimlik) {
      _kuyruk.removeWhere((i) => i.kimlik == kimlik);
      notifyListeners();
      return;
    }

    // Ekrana hemen yansiyor: motor surecinin gercekten olmesi bir saniye
    // surebiliyor, o sure boyunca ilerleme cubugu dolmaya devam ederse
    // dugme calismamis gibi gorunur.
    _iptalIstenenler.add(kimlik);
    _guncelle(kimlik, (i) => i.kopyala(durum: IsDurumu.iptal));

    await motor.iptal(kimlik);
  }

  void gecmisiTemizle() {
    _gecmis.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------- isletme

  void _isletmeyiDurtukle() {
    if (_calisanKimlik != null) return;

    // `firstOrNull` package:collection'dan gelir; tek bir arama icin paket
    // eklemeye degmez (bkz. sinif basindaki bagimlilik notu).
    IndirmeIsi? sonraki;
    for (final i in _kuyruk) {
      if (i.durum == IsDurumu.bekliyor) {
        sonraki = i;
        break;
      }
    }
    if (sonraki == null) return;

    _calisanKimlik = sonraki.kimlik;
    _isle(sonraki);
  }

  Future<void> _isle(IndirmeIsi is_) async {
    try {
      // 1) Cozumleme — onizlemeden gelmisse atlanir.
      var bilgi = is_.bilgi;
      if (bilgi == null) {
        _guncelle(is_.kimlik, (i) => i.kopyala(durum: IsDurumu.cozumleniyor));
        bilgi = await motor.cozumle(is_.adres);
        _guncelle(is_.kimlik, (i) => i.kopyala(bilgi: bilgi));
      }

      // Cozumleme de bir bekleme ve kullanici o sirada da durdurabiliyor
      // (kart "Baglantı çözümleniyor…" derken durdurma dugmesi duruyor).
      // Kontrol edilmezse cozumleme bitip indirme baslardi: kullanici
      // durdurdugunu sanirken dosya inmeye devam ederdi.
      if (_iptalIstenenler.contains(is_.kimlik)) return;

      // 2) Indirme
      final sonuc = await motor.indir(
        isKimlik: is_.kimlik,
        bilgi: bilgi,
        tur: is_.tur,
        kalite: is_.kalite,
        ilerleme: (durum, oran, hiz) =>
            _ilerlemeBildir(is_.kimlik, durum, oran, hiz),
      );

      // Iptal istendiyse sonuc ne olursa olsun "iptal" yaziyor. Yaris
      // durumunda (dosya tam iptal aninda bitti) kullaniciya "Tamamlandı"
      // demek, bastigi dugmenin ise yaramadigi izlenimi verirdi.
      if (_iptalIstenenler.contains(is_.kimlik)) return;

      _guncelle(
        is_.kimlik,
        (i) => i.kopyala(
          durum: IsDurumu.bitti,
          oran: 1,
          dosyaYolu: sonuc.yol,
          kayitYeri: sonuc.kayitYeri,
        ),
      );
      _gecmiseTasi(is_.kimlik);
    } on MotorHatasi catch (e) {
      if (_iptalIstenenler.contains(is_.kimlik)) return;
      _guncelle(
        is_.kimlik,
        (i) => i.kopyala(
          durum: IsDurumu.hata,
          hataMesaji: e.mesaj,
          // Ham ayrinti saklaniyor: kullanici karta dokunup kopyalayabilsin.
          hataAyrinti: e.ayrinti,
        ),
      );
    } catch (e) {
      if (_iptalIstenenler.contains(is_.kimlik)) return;
      // Beklenmeyen hata da kullaniciya anlamli bir cumleyle gosterilir;
      // ham istisna metni ekrana basilmaz.
      _guncelle(
        is_.kimlik,
        (i) => i.kopyala(
          durum: IsDurumu.hata,
          hataMesaji: 'Beklenmeyen bir sorun oldu. Tekrar deneyin.',
        ),
      );
    } finally {
      _iptalIstenenler.remove(is_.kimlik);
      _calisanKimlik = null;
      _isletmeyiDurtukle();
    }
  }

  /// Ilerleme bildirimi **kisiliyor**.
  ///
  /// Motor saniyede onlarca kez ilerleme yollayabilir. Her birinde butun
  /// dinleyicileri uyandirmak, ekrani gereksiz yere yeniden cizer ve
  /// telefonu isitir. Gozle gorulur bir degisiklik yoksa (yuzde 1'den az)
  /// haber verilmiyor — ama **durum degisimi her zaman geciyor**, cunku
  /// "indiriliyor -> donusturuluyor" gecisi kacirilirsa ekran yalan soyler.
  void _ilerlemeBildir(
    String kimlik,
    IsDurumu durum,
    double? oran,
    String? hiz,
  ) {
    final dizin = _kuyruk.indexWhere((i) => i.kimlik == kimlik);
    if (dizin == -1) return;

    final eski = _kuyruk[dizin];

    // Sonuclanmis is geri diriltilmiyor.
    //
    // Motor surecinin olmesi bir saniye surebiliyor ve yolda kalmis bir
    // "iniyor" bildirimi bu sirada gelebiliyor. Onlenmezse kullanicinin
    // durdurdugu kart yeniden indiriliyor gorunur — dugme calismamis
    // gibi. Ayni koruma biten ve hata alan isler icin de gecerli.
    if (eski.durum == IsDurumu.iptal ||
        eski.durum == IsDurumu.bitti ||
        eski.durum == IsDurumu.hata) {
      return;
    }
    final durumDegisti = eski.durum != durum;
    final oranDegisti = oran != null &&
        (eski.oran == null || (oran - eski.oran!).abs() >= 0.01);

    _kuyruk[dizin] = eski.kopyala(durum: durum, oran: oran, hiz: hiz);

    if (durumDegisti || oranDegisti) notifyListeners();
  }

  void _guncelle(String kimlik, IndirmeIsi Function(IndirmeIsi) donustur) {
    final dizin = _kuyruk.indexWhere((i) => i.kimlik == kimlik);
    if (dizin == -1) return;
    _kuyruk[dizin] = donustur(_kuyruk[dizin]);
    notifyListeners();
  }

  /// Biten is kuyruktan cikip gecmise geciyor.
  ///
  /// Kuyrukta birakmak, ekranin zamanla bitmis islerle dolmasina yol acardi;
  /// kullanici "sirada ne var" sorusunun cevabini goremez hale gelirdi.
  void _gecmiseTasi(String kimlik) {
    final dizin = _kuyruk.indexWhere((i) => i.kimlik == kimlik);
    if (dizin == -1) return;
    _gecmis.insert(0, _kuyruk.removeAt(dizin));
    notifyListeners();
  }
}
