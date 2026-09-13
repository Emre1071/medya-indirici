import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medya_indirici/alan/varliklar/indirme_isi.dart';
import 'package:medya_indirici/alan/varliklar/indirme_sonucu.dart';
import 'package:medya_indirici/alan/varliklar/medya_bilgisi.dart';
import 'package:medya_indirici/servisler/gecmis_deposu.dart';
import 'package:medya_indirici/servisler/indirme_motoru.dart';
import 'package:medya_indirici/servisler/kuyruk_yoneticisi.dart';

/// Kalici gecmisin kurallari.
///
/// ## Nicin bu testler var
/// Gercek depo `dart:io` ile diske yaziyor ve yalnizca telefonda/masaustunde
/// kosuyor. Sinanmasi gereken sey dosya bicimi degil, **kuyrugun depoyla
/// kurdugu iliski**: neyin ne zaman yazildigi, acilista sayacin nereden
/// devam ettigi, "temizle"nin diski de bosaltip bosaltmadigi. Bunlarin her
/// biri sessizce bozulabilen seyler — hata vermeden yanlis calisirlar.
void main() {
  late _SahteDepo depo;
  late _AninaBitenMotor motor;
  late KuyrukYoneticisi kuyruk;

  setUp(() {
    depo = _SahteDepo();
    motor = _AninaBitenMotor();
    kuyruk = KuyrukYoneticisi(motor, depo: depo);
  });

  tearDown(() => kuyruk.dispose());

  Future<void> soluklan() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('IndirmeIsi serilestirme', () {
    test('gidis-donus temel alanlari koruyor', () {
      const is_ = IndirmeIsi(
        kimlik: 'is_7',
        adres: 'https://instagram.com/reel/DAbC123/',
        tur: IndirmeTuru.ses,
        durum: IsDurumu.bitti,
        bilgi: MedyaBilgisi(
          adres: 'https://instagram.com/reel/DAbC123/',
          baslik: 'Hayırlı akşamlar 🎻',
          kaynak: 'instagram',
          sure: Duration(seconds: 47),
          yukleyen: 'serif',
        ),
        dosyaYolu: 'content://medya/9',
        kayitYeri: 'Music/Medya İndirici',
      );

      final geri = IndirmeIsi.fromJson(is_.toJson())!;

      expect(geri.kimlik, 'is_7');
      expect(geri.tur, IndirmeTuru.ses);
      expect(geri.durum, IsDurumu.bitti);
      expect(geri.dosyaYolu, 'content://medya/9');
      expect(geri.kayitYeri, 'Music/Medya İndirici');
      // Turkce ve emoji bozulmamali: baslik dogrudan ekranda gorunuyor.
      expect(geri.bilgi?.baslik, 'Hayırlı akşamlar 🎻');
      expect(geri.bilgi?.sure, const Duration(seconds: 47));
    });

    test('bozuk kayit null donuyor, firlatmiyor', () {
      // Gecmis dosyasi yarim yazilmis, elle duzenlenmis veya eski bir
      // surumden kalmis olabilir. Tek bir bozuk satir uygulamayi
      // acilmaz hale getirmemeli.
      expect(IndirmeIsi.fromJson(null), isNull);
      expect(IndirmeIsi.fromJson('metin'), isNull);
      expect(IndirmeIsi.fromJson(<String, Object?>{}), isNull);
      expect(IndirmeIsi.fromJson({'kimlik': 'is_0'}), isNull);
      // Sayi duran bir alan `as String?` ile patlardi; suzgecten geciyor.
      expect(
        IndirmeIsi.fromJson({'kimlik': 'is_0', 'adres': 'x', 'dosyaYolu': 5})
            ?.dosyaYolu,
        isNull,
      );
    });

    test('kalite ve format kimlikleri BILEREK yazilmiyor', () {
      const is_ = IndirmeIsi(
        kimlik: 'is_0',
        adres: 'https://instagram.com/reel/1',
        tur: IndirmeTuru.video,
        kalite: MedyaKalitesi(
          etiket: '1080p',
          formatKimlik: 'dash-4',
          uzanti: 'mp4',
        ),
        bilgi: MedyaBilgisi(
          adres: 'https://instagram.com/reel/1',
          baslik: 'Deneme',
          kaynak: 'instagram',
          videoSecenekleri: [
            MedyaKalitesi(etiket: '1080p', formatKimlik: 'dash-4', uzanti: 'mp4'),
          ],
        ),
      );

      // Format kimlikleri suresi dolan seyler: Instagram her cozumlemede
      // farkli kimlik uretebiliyor. Diske yazmak, calismayacagi bilinen
      // bir veriyi saklamak olurdu.
      final yazilan = is_.toJson().toString();
      expect(yazilan, isNot(contains('dash-4')));
      expect(IndirmeIsi.fromJson(is_.toJson())?.kalite, isNull);
    });
  });

  group('KuyrukYoneticisi <-> depo', () {
    test('acilista kalici gecmis okunuyor', () async {
      depo.kayitlar = [_gecmisSatiri('is_3')];

      await kuyruk.yukle();

      expect(kuyruk.gecmis, hasLength(1));
      expect(kuyruk.gecmis.single.kimlik, 'is_3');
    });

    test('🔑 sayac kalici kimliklerin UZERINE aliniyor', () async {
      depo.kayitlar = [_gecmisSatiri('is_5'), _gecmisSatiri('is_2')];

      await kuyruk.yukle();
      final yeni = kuyruk.ekle('https://instagram.com/reel/1', IndirmeTuru.ses);

      // Sayac sifirdan basliyor olsaydi yeni is `is_0` olurdu ve gecmiste
      // duran bir kayitla carpisirdi. Kimlik ayni zamanda bildirim
      // kimligi — carpisma iki indirmenin tek bildirimi ezmesi demek.
      expect(yeni, 'is_6');
      expect(
        kuyruk.gecmis.map((i) => i.kimlik),
        isNot(contains(yeni)),
        reason: 'yeni kimlik gecmistekilerle carpismamali',
      );
    });

    test('biten is diske yaziliyor', () async {
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

      expect(depo.kayitlar, hasLength(1));
      expect(depo.kayitlar.single.kimlik, kimlik);
    });

    test('basarisiz indirme diske YAZILMIYOR', () async {
      final kimlik = kuyruk.ekle('https://instagram.com/reel/1', IndirmeTuru.ses);
      await soluklan();

      motor.hataVer(kimlik, const MotorHatasi('Olmadi'));
      await soluklan();

      // "İndirilenler" indirilmis seylerin listesi; kalici kayit da ayni
      // kurala uymali.
      expect(depo.kayitlar, isEmpty);
      expect(depo.yazmaSayisi, 0);
    });

    test('cikarilamayan dosyanin SEBEBI de tasiniyor', () async {
      final kimlik = kuyruk.ekle('https://instagram.com/reel/1', IndirmeTuru.ses);
      await soluklan();

      motor.bitir(
        kimlik,
        const IndirmeSonucu(
          yol: '/veri/uygulama/ses.opus',
          kayitHatasi: 'IllegalArgumentException: Mismatched extension',
        ),
      );
      await soluklan();

      final is_ = kuyruk.gecmis.single;
      expect(is_.kayitYeri, isNull);
      // Cihaz `adb`'ye baglanamadigi icin "galeride gorunmuyor"
      // sikayetinin sebebini ogrenmenin tek yolu bu.
      expect(is_.kayitHatasi, contains('Mismatched extension'));
      // Yeniden acildiginda da duruyor olmali.
      expect(depo.kayitlar.single.kayitHatasi, contains('Mismatched'));
    });

    test('gecmisi temizlemek KALICI kaydi da siliyor', () async {
      depo.kayitlar = [_gecmisSatiri('is_0')];
      await kuyruk.yukle();

      kuyruk.gecmisiTemizle();
      await soluklan();

      expect(kuyruk.gecmis, isEmpty);
      // Yalnizca bellegi bosaltmak, gecmisin bir sonraki acilista geri
      // gelmesi demek olurdu.
      expect(depo.temizlendi, isTrue);
    });

    test('depo verilmezse kuyruk yine calisiyor', () async {
      final depusuz = KuyrukYoneticisi(_AninaBitenMotor());
      addTearDown(depusuz.dispose);

      await depusuz.yukle();
      expect(depusuz.gecmis, isEmpty);
    });
  });
}

IndirmeIsi _gecmisSatiri(String kimlik) => IndirmeIsi(
      kimlik: kimlik,
      adres: 'https://instagram.com/reel/$kimlik',
      tur: IndirmeTuru.ses,
      durum: IsDurumu.bitti,
      kayitYeri: 'Music/Medya İndirici',
    );

/// Bellekte tutan sahte depo — diske dokunmuyor.
class _SahteDepo implements GecmisDeposu {
  List<IndirmeIsi> kayitlar = [];
  int yazmaSayisi = 0;
  bool temizlendi = false;

  @override
  Future<List<IndirmeIsi>> yukle() async => kayitlar;

  @override
  Future<void> kaydet(List<IndirmeIsi> gecmis) async {
    kayitlar = List.of(gecmis);
    yazmaSayisi++;
  }

  @override
  Future<void> temizle() async {
    kayitlar = [];
    temizlendi = true;
  }
}

/// Indirmeyi testin istedigi anda bitiren sahte motor.
class _AninaBitenMotor implements IndirmeMotoru {
  final Map<String, Completer<IndirmeSonucu>> _bekleyenler = {};

  @override
  Future<MotorDurumu> durum() async => const MotorDurumu.hazir();

  @override
  Future<MedyaBilgisi> cozumle(String adres) async => MedyaBilgisi(
        adres: adres,
        baslik: 'Deneme',
        kaynak: 'instagram',
      );

  @override
  Future<IndirmeSonucu> indir({
    required String isKimlik,
    required MedyaBilgisi bilgi,
    required IndirmeTuru tur,
    MedyaKalitesi? kalite,
    IlerlemeBildirimi? ilerleme,
  }) {
    final bekleyen = Completer<IndirmeSonucu>();
    _bekleyenler[isKimlik] = bekleyen;
    return bekleyen.future;
  }

  void bitir(String kimlik, IndirmeSonucu sonuc) =>
      _bekleyenler.remove(kimlik)?.complete(sonuc);

  void hataVer(String kimlik, MotorHatasi hata) =>
      _bekleyenler.remove(kimlik)?.completeError(hata);

  @override
  Future<void> iptal(String isKimlik) async {}

  @override
  Future<String?> motorSurumu() async => 'test';
}
