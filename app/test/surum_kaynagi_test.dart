import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as ag;
import 'package:http/testing.dart';
import 'package:medya_indirici/alan/varliklar/surum_bilgisi.dart';
import 'package:medya_indirici/cekirdek/github_ayarlari.dart';
import 'package:medya_indirici/cekirdek/surum.dart';
import 'package:medya_indirici/servisler/guncelleme_servisi.dart';
import 'package:medya_indirici/veri/uzak/surum_kaynagi.dart';

/// GitHub Releases'ten surum okuma.
///
/// ## Nicin test ediliyor
/// Yanit **bizim yazdigimiz bir sema degil**, GitHub'in semasi. Alan adlari
/// (`tag_name`, `browser_download_url`) elle yazildi ve bir harf hatasi
/// derleyiciye takilmaz — sessizce "guncelleme yok" der. Kullanici da
/// hicbir zaman guncelleme almadigini fark etmez.
///
/// Ayrica etiketten surume cevirme (`v1.2.0` -> `1.2.0`) atlanirsa
/// karsilastirma her zaman "guncel" doner; yani en sinsi hata bu yolda.
void main() {
  /// GitHub'in verdigi bicimde bir yanit.
  ///
  /// **Basliktaki `charset=utf-8` onemli:** `http` paketi charset
  /// belirtilmemis yanitlari latin1 sayiyor. GitHub her zaman UTF-8
  /// gonderiyor (JSON'un kendi sarti da bu) ve kod bodyBytes'i UTF-8
  /// cozuyor. Basligi atlayan bir test, uretimde olmayan bir durumu
  /// sinamis olurdu.
  ag.Response yanitUret(Map<String, dynamic> govde, [int kod = 200]) =>
      ag.Response(
        jsonEncode(govde),
        kod,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );

  /// GitHub'in gercek yanitinin ilgili alanlari.
  Map<String, dynamic> ornekYanit({
    String etiket = 'v1.2.0',
    List<Map<String, String>>? varliklar,
    String govde = 'İptal düğmesi eklendi.',
  }) {
    return {
      'tag_name': etiket,
      'name': 'Surum $etiket',
      'body': govde,
      'assets': varliklar ??
          [
            {
              'name': 'app-armeabi-v7a-release.apk',
              'browser_download_url': 'https://ornek/armeabi.apk',
            },
            {
              'name': 'app-arm64-v8a-release.apk',
              'browser_download_url': 'https://ornek/arm64.apk',
            },
          ],
    };
  }

  group('SurumBilgisi.githubdanKur', () {
    test('etiketin basindaki v temizleniyor', () {
      final b = SurumBilgisi.githubdanKur(ornekYanit(etiket: 'v1.2.0'));
      expect(b?.surum, '1.2.0');
    });

    test('v olmadan yazilmis etiket de calisiyor', () {
      final b = SurumBilgisi.githubdanKur(ornekYanit(etiket: '1.2.0'));
      expect(b?.surum, '1.2.0');
    });

    test('arm64 APK seciliyor, listede once armeabi gelse bile', () {
      final b = SurumBilgisi.githubdanKur(ornekYanit());
      expect(b?.indirmeAdresi, 'https://ornek/arm64.apk');
    });

    test('arm64 yoksa eldeki APK kullaniliyor', () {
      final b = SurumBilgisi.githubdanKur(ornekYanit(varliklar: [
        {
          'name': 'app-armeabi-v7a-release.apk',
          'browser_download_url': 'https://ornek/armeabi.apk',
        },
      ]));
      expect(b?.indirmeAdresi, 'https://ornek/armeabi.apk');
    });

    test('APK olmayan varliklar secilmiyor', () {
      // Release'e cogu zaman kaynak arsivleri de ekleniyor.
      final b = SurumBilgisi.githubdanKur(ornekYanit(varliklar: [
        {
          'name': 'kaynak.zip',
          'browser_download_url': 'https://ornek/kaynak.zip',
        },
      ]));
      expect(b?.indirmeAdresi, isNull,
          reason: 'APK yoksa indirme dugmesi hic gosterilmemeli');
    });

    test('bos aciklama not sayilmiyor', () {
      final b = SurumBilgisi.githubdanKur(ornekYanit(govde: '   '));
      expect(b?.notlar, 'Surum v1.2.0',
          reason: 'aciklama bossa release adina dusulmeli');
    });

    test('etiketi olmayan yanit okunamaz sayiliyor', () {
      expect(SurumBilgisi.githubdanKur({'name': 'bozuk'}), isNull);
    });
  });

  group('SurumKaynagi', () {
    test('dogru adrese gidiyor ve surumu okuyor', () async {
      Uri? gidilen;
      final kaynak = SurumKaynagi(
        istemci: MockClient((istek) async {
          gidilen = istek.url;
          return yanitUret(ornekYanit());
        }),
      );

      final bilgi = await kaynak.getir();

      expect(gidilen, GitHubAyarlari.sonSurumAdresi);
      expect(gidilen.toString(), contains('/releases/latest'));
      expect(bilgi?.surum, '1.2.0');
    });

    test('hic release yoksa (404) hata degil, bos sonuc', () async {
      final kaynak = SurumKaynagi(
        istemci: MockClient((_) async => ag.Response('{}', 404)),
      );

      // Ilk release yayinlanana kadar yasanacak normal durum.
      expect(await kaynak.getir(), isNull);
    });

    test('Turkce release notu bozulmuyor', () async {
      final govde = 'İptal düğmesi ve şarkı klasörü eklendi.';
      final kaynak = SurumKaynagi(
        istemci: MockClient((_) async => ag.Response.bytes(
              utf8.encode(jsonEncode(ornekYanit(govde: govde))),
              200,
            )),
      );

      final bilgi = await kaynak.getir();
      expect(bilgi?.notlar, govde);
    });

    test('beklenmedik durum kodu istisna firlatiyor', () async {
      // Cevirmek `GuncellemeServisi`'nin isi; kaynak yalnizca okur.
      final kaynak = SurumKaynagi(
        istemci: MockClient((_) async => ag.Response('', 500)),
      );

      expect(kaynak.getir(), throwsA(isA<Exception>()));
    });
  });

  group('GuncellemeServisi', () {
    test('daha yeni surum yayinlanmissa haber veriyor', () async {
      final servis = GuncellemeServisi(
        kaynak: SurumKaynagi(
          istemci: MockClient(
            (_) async => yanitUret(ornekYanit()),
          ),
        ),
      );

      final sonuc = await servis.kontrolEt();

      expect(sonuc.durum, GuncellemeDurumu.yeniSurumVar);
      expect(sonuc.indirilebilir, isTrue);
      expect(sonuc.bilgi?.indirmeAdresi, 'https://ornek/arm64.apk');
    });

    test('elimizdeki surum yayindakiyle ayniysa guncel diyor', () async {
      final servis = GuncellemeServisi(
        kaynak: SurumKaynagi(
          istemci: MockClient(
            (_) async => yanitUret(ornekYanit(etiket: 'v${Surum.simdiki}')),
          ),
        ),
      );

      expect((await servis.kontrolEt()).durum, GuncellemeDurumu.guncel);
    });

    test('ag yoksa sessizce bilinmiyor donuyor', () async {
      final servis = GuncellemeServisi(
        kaynak: SurumKaynagi(
          istemci: MockClient((_) async => throw const SocketExceptionTaklidi()),
        ),
      );

      // Guncelleme kontrolu basarisiz diye calisan uygulamayi bozuk
      // gostermek yok — ekranda hicbir sey degismiyor.
      final sonuc = await servis.kontrolEt();
      expect(sonuc.durum, GuncellemeDurumu.bilinmiyor);
      expect(sonuc.yeniVar, isFalse);
    });

    test('APK yuklenmemis release indirilebilir sayilmiyor', () async {
      final servis = GuncellemeServisi(
        kaynak: SurumKaynagi(
          istemci: MockClient(
            (_) async => yanitUret(ornekYanit(varliklar: [])),
          ),
        ),
      );

      final sonuc = await servis.kontrolEt();
      expect(sonuc.yeniVar, isTrue);
      expect(sonuc.indirilebilir, isFalse,
          reason: 'adres yokken indirme dugmesi gosterilmemeli');
    });
  });
}

/// Ag hatasi taklidi.
///
/// Gercek `SocketException` `dart:io`'dan geliyor; bu test dosyasi
/// tarayicida da kosabilsin diye oradan bagimsiz tutuluyor.
class SocketExceptionTaklidi implements Exception {
  const SocketExceptionTaklidi();
}
