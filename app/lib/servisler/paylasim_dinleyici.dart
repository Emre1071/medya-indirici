import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Paylas menusunden gelen metni Android tarafindan alir.
///
/// ## Iki kanal, iki farkli durum
/// - [ilkPaylasim] — uygulama **paylasimla acildiysa** bekleyen metni verir.
///   Bir kez teslim edilir; ikinci cagride `null` doner.
/// - [akis] — uygulama **acikken** gelen paylasimlar.
///
/// Ayrimin sebebi Android tarafinda: kapali uygulamada niyet Flutter
/// baslamadan once geliyor ve saklanmasi gerekiyor; acik uygulamada
/// `onNewIntent` ile aninda dusuyor. (Ayrinti: `PaylasimKoprusu.kt`)
///
/// ## Android disinda sessizce bos
/// Tarayicida ve masaustunde paylas menusu yok. Kanal cagrisi orada
/// `MissingPluginException` firlatirdi; motor secimindeki ayni kalip
/// kullanilarak ([kIsWeb] + [defaultTargetPlatform]) hic cagrilmiyor.
/// Boylece ekran onizlemesi tarayicida calismaya devam ediyor.
class PaylasimDinleyici {
  static const MethodChannel _komut = MethodChannel('medyaindirici/paylasim');
  static const EventChannel _akisKanali =
      EventChannel('medyaindirici/paylasim/akis');

  /// Bu platformda paylas menusu var mi?
  static bool get destekleniyor =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Uygulama paylasimla acildiysa o metin; degilse `null`.
  Future<String?> ilkPaylasim() async {
    if (!destekleniyor) return null;
    try {
      return await _komut.invokeMethod<String>('ilkPaylasim');
    } on PlatformException {
      // Paylasim alinamamasi uygulamayi bozmaz: kullanici linki elle de
      // yapistirabiliyor. Sessiz gecmek dogru.
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Uygulama acikken gelen paylasimlar.
  Stream<String> get akis {
    if (!destekleniyor) return const Stream<String>.empty();

    return _akisKanali
        .receiveBroadcastStream()
        .map((olay) => olay as String?)
        .where((metin) => metin != null && metin.isNotEmpty)
        .cast<String>();
  }
}
