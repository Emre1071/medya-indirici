import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medya_indirici/cekirdek/surum.dart';

/// DevLingo'daki ayni testin karsiligi.
///
/// [Surum.simdiki] elle yaziliyor (gerekcesi `cekirdek/surum.dart` icinde).
/// Elle yazilan her sey unutulur; bu test unutmayi **derleme hatasina**
/// cevirmiyor ama testi kirmiziya dusuruyor — yani surum yukseltirken
/// pubspec'i degistirip sabiti unutmak sessizce gecmiyor.
///
/// Sessizce gecerse ne olurdu: yeni surum yayinlanir, ama uygulama kendini
/// hala eski surum sanar ve **kendi guncellemesini surekli teklif eder**
/// (Asama 7). Kullanici guncelledigi halde uyari gitmez.
void main() {
  test('Surum.simdiki, pubspec.yaml ile ayni olmali', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    final satir = pubspec
        .split('\n')
        .map((s) => s.trim())
        .firstWhere(
          (s) => s.startsWith('version:'),
          orElse: () => '',
        );

    expect(satir, isNotEmpty, reason: 'pubspec.yaml icinde version: yok');

    // `version: 0.1.0+1` -> `0.1.0`
    final pubspecSurumu = satir.substring('version:'.length).trim().split('+').first;

    expect(
      Surum.simdiki,
      pubspecSurumu,
      reason: 'pubspec.yaml surumu ile cekirdek/surum.dart ayrismis. '
          'Ikisini de guncelle.',
    );
  });

  group('Surum.karsilastir', () {
    test('sayisal karsilastirma yapar, metin siralamasi degil', () {
      // Metin olarak kiyaslansaydi '1.0.10' < '1.0.2' cikardi.
      expect(Surum.karsilastir('1.0.10', '1.0.2'), greaterThan(0));
    });

    test('eksik parca 0 sayilir', () {
      expect(Surum.karsilastir('1.0', '1.0.0'), 0);
    });

    test('yapi numarasi kiyasa girmez', () {
      expect(Surum.karsilastir('1.2.3+9', '1.2.3+1'), 0);
    });
  });

  group('Surum.yeniMi', () {
    test('daha buyuk surum yeni sayilir', () {
      expect(Surum.yeniMi(mevcut: '1.0.0', aday: '1.0.1'), isTrue);
    });

    test('ayni surum yeni degil', () {
      expect(Surum.yeniMi(mevcut: '1.0.0', aday: '1.0.0'), isFalse);
    });

    test('okunamayan surum yeni sayilmaz', () {
      // Bozuk bir kayit yuzunden her acilista "guncelleme var" dememeli.
      expect(Surum.yeniMi(mevcut: '1.0.0', aday: 'bozuk'), isFalse);
      expect(Surum.yeniMi(mevcut: '1.0.0', aday: ''), isFalse);
    });
  });
}
