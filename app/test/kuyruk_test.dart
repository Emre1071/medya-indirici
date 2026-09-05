import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medya_indirici/alan/varliklar/indirme_isi.dart';
import 'package:medya_indirici/alan/varliklar/indirme_sonucu.dart';
import 'package:medya_indirici/alan/varliklar/medya_bilgisi.dart';
import 'package:medya_indirici/servisler/indirme_motoru.dart';
import 'package:medya_indirici/servisler/kuyruk_yoneticisi.dart';

/// Kuyrugun iptal davranisi.
///
/// ## Nicin bu testler var
/// Iptal, motorun **hata firlatmasiyla** gerceklesiyor: surec olduruluyor,
/// `indir` istisna atiyor. Yani "kullanici durdurdu" ile "indirme bozuldu"
/// ayni yoldan geliyor ve ikisini karistirmak kolay — karistirilirsa
/// kullanici durdurdugu indirmede kirmizi bir hata mesaji gorur.
///
/// Bu ayrimin dogrulugu ancak kod yazilirken sinanabiliyor: gercek motor
/// yalnizca telefonda calisiyor, burada koslamiyor. Testler kuyrugun
/// kendisini sinamak icin sahte bir motor kullaniyor.
void main() {
  late _KontrolluMotor motor;
  late KuyrukYoneticisi kuyruk;

  setUp(() {
    motor = _KontrolluMotor();
    kuyruk = KuyrukYoneticisi(motor);
  });

  tearDown(() => kuyruk.dispose());

  /// Bekleyen mikro gorevlerin islemesine izin verir.
  ///
  /// Kuyruk isleri `async` isletiyor; `ekle` cagrisi donerken indirme
  /// henuz baslamamis oluyor. Testin gercek bir bekleme suresine bagli
  /// olmamasi icin yalnizca sira devrediliyor.
  Future<void> soluklan() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('calisan is durdurulunca motora iptal gidiyor', () async {
    final kimlik = kuyruk.ekle('https://instagram.com/reel/1', IndirmeTuru.ses);
    await soluklan();

    expect(kuyruk.kuyruk.single.durum, IsDurumu.iniyor,
        reason: 'is baslamis olmali');

    await kuyruk.sil(kimlik);
    await soluklan();

    expect(motor.iptalEdilenKimlikler, [kimlik],
        reason: 'kuyruk motora ayni is kimligiyle iptal gondermeli');
  });

  test('durdurulan is hata degil, iptal olarak gorunuyor', () async {
    final kimlik = kuyruk.ekle('https://instagram.com/reel/1', IndirmeTuru.ses);
    await soluklan();

    await kuyruk.sil(kimlik);
    await soluklan();

    final is_ = kuyruk.kuyruk.single;
    expect(is_.durum, IsDurumu.iptal);
    expect(is_.hataMesaji, isNull,
        reason: 'kullanici kendi durdurdugu iste hata mesaji gormemeli');
    expect(kuyruk.gecmis, isEmpty,
        reason: 'iptal edilen is indirilenler listesine girmemeli');
  });

  test('durdurulduktan sonra gelen ilerleme karti geri diriltmiyor', () async {
    final kimlik = kuyruk.ekle('https://instagram.com/reel/1', IndirmeTuru.ses);
    await soluklan();

    await kuyruk.sil(kimlik);

    // Motor surecinin olmesi zaman aliyor; o sirada yolda kalmis bir
    // ilerleme bildirimi gelebiliyor.
    motor.ilerlemeYolla(kimlik, IsDurumu.iniyor, 0.9);
    await soluklan();

    expect(kuyruk.kuyruk.single.durum, IsDurumu.iptal);
  });

  test('cozumleme sirasinda durdurulan is indirmeye hic baslamiyor', () async {
    motor.cozumlemeyiBeklet = true;

    final kimlik = kuyruk.ekle('https://instagram.com/reel/1', IndirmeTuru.ses);
    await soluklan();

    expect(kuyruk.kuyruk.single.durum, IsDurumu.cozumleniyor);

    await kuyruk.sil(kimlik);
    await soluklan();

    // Cozumleme durdurma emrinden SONRA tamamlaniyor.
    motor.cozumlemeyiBitir();
    await soluklan();

    expect(motor.baslayanKimlikler, isEmpty,
        reason: 'durdurulan is icin indirme hic baslamamali');
    expect(kuyruk.kuyruk.single.durum, IsDurumu.iptal);
  });

  test('bekleyen is silinince listeden cikiyor, motora iptal gitmiyor',
      () async {
    kuyruk.ekle('https://instagram.com/reel/1', IndirmeTuru.ses);
    final ikinci =
        kuyruk.ekle('https://instagram.com/reel/2', IndirmeTuru.video);
    await soluklan();

    expect(kuyruk.kuyruk.length, 2);

    await kuyruk.sil(ikinci);
    await soluklan();

    expect(kuyruk.kuyruk.length, 1);
    expect(motor.iptalEdilenKimlikler, isEmpty,
        reason: 'hic baslamamis is icin motoru rahatsiz etmeye gerek yok');
  });

  test('iptalden sonra siradaki is calismaya basliyor', () async {
    final birinci = kuyruk.ekle('https://instagram.com/reel/1', IndirmeTuru.ses);
    final ikinci =
        kuyruk.ekle('https://instagram.com/reel/2', IndirmeTuru.video);
    await soluklan();

    await kuyruk.sil(birinci);
    await soluklan();

    expect(motor.baslayanKimlikler, contains(ikinci),
        reason: 'kuyruk iptalden sonra tikanmamali');
  });

  test('biten iste kayit yeri tasiniyor', () async {
    final kimlik = kuyruk.ekle('https://instagram.com/reel/1', IndirmeTuru.ses);
    await soluklan();

    motor.bitir(
      kimlik,
      const IndirmeSonucu(
        yol: 'content://medya/1',
        kayitYeri: 'Music/Medya İndirici',
      ),
    );
    await soluklan();

    final is_ = kuyruk.gecmis.single;
    expect(is_.durum, IsDurumu.bitti);
    expect(is_.kayitYeri, 'Music/Medya İndirici');
    expect(is_.dosyaYolu, 'content://medya/1');
  });

  test('disari cikarilamayan dosyada kayit yeri bos kaliyor', () async {
    final kimlik = kuyruk.ekle('https://instagram.com/reel/1', IndirmeTuru.ses);
    await soluklan();

    motor.bitir(kimlik, const IndirmeSonucu(yol: '/veri/uygulama/ses.m4a'));
    await soluklan();

    expect(kuyruk.gecmis.single.kayitYeri, isNull,
        reason: 'arayuz "telefonda gorunmuyor" uyarisini buna gore veriyor');
  });
}

/// Indirmeyi testin istedigi anda bitiren sahte motor.
///
/// Gercek `SahteMotor` kendi temposunda ilerliyor; iptali tam istenen anda
/// sinamak icin burada kontrol testte.
class _KontrolluMotor implements IndirmeMotoru {
  final List<String> baslayanKimlikler = [];
  final List<String> iptalEdilenKimlikler = [];

  final Map<String, Completer<IndirmeSonucu>> _bekleyenler = {};
  final Map<String, IlerlemeBildirimi> _ilerlemeler = {};

  /// `true` ise cozumleme [cozumlemeyiBitir] cagrilana kadar asili kalir.
  bool cozumlemeyiBeklet = false;
  Completer<MedyaBilgisi>? _cozumleme;

  @override
  Future<MotorDurumu> durum() async => const MotorDurumu.hazir();

  @override
  Future<MedyaBilgisi> cozumle(String adres) {
    final bilgi = MedyaBilgisi(
      adres: adres,
      baslik: 'Deneme',
      kaynak: 'instagram',
    );

    if (!cozumlemeyiBeklet) return Future.value(bilgi);

    final bekleyen = Completer<MedyaBilgisi>();
    _cozumleme = bekleyen;
    return bekleyen.future;
  }

  void cozumlemeyiBitir() {
    _cozumleme?.complete(
      const MedyaBilgisi(
        adres: 'https://instagram.com/reel/1',
        baslik: 'Deneme',
        kaynak: 'instagram',
      ),
    );
    _cozumleme = null;
  }

  @override
  Future<IndirmeSonucu> indir({
    required String isKimlik,
    required MedyaBilgisi bilgi,
    required IndirmeTuru tur,
    MedyaKalitesi? kalite,
    IlerlemeBildirimi? ilerleme,
  }) {
    baslayanKimlikler.add(isKimlik);
    if (ilerleme != null) _ilerlemeler[isKimlik] = ilerleme;

    // Indirme testin bitirmesini bekliyor.
    final bekleyen = Completer<IndirmeSonucu>();
    _bekleyenler[isKimlik] = bekleyen;

    ilerleme?.call(IsDurumu.iniyor, 0, null);
    return bekleyen.future;
  }

  @override
  Future<void> iptal(String isKimlik) async {
    iptalEdilenKimlikler.add(isKimlik);

    // Gercek motor da boyle davraniyor: surec olduruluyor ve `indir`
    // istisna firlatiyor.
    _bekleyenler.remove(isKimlik)?.completeError(
          const MotorHatasi('İndirme durduruldu.'),
        );
  }

  @override
  Future<String?> motorSurumu() async => 'deneme';

  void bitir(String isKimlik, IndirmeSonucu sonuc) {
    _bekleyenler.remove(isKimlik)?.complete(sonuc);
  }

  void ilerlemeYolla(String isKimlik, IsDurumu durum, double oran) {
    _ilerlemeler[isKimlik]?.call(durum, oran, null);
  }
}
