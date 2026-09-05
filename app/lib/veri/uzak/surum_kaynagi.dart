import 'dart:convert';

import 'package:http/http.dart' as ag;

import '../../alan/varliklar/surum_bilgisi.dart';
import '../../cekirdek/github_ayarlari.dart';

/// GitHub Releases'ten en son surumu okur.
///
/// ## Nicin `postgrest` degil de `http`?
/// Supabase doneminde `postgrest` kullaniliyordu. GitHub'in API'si duz
/// JSON dondurdugu icin ozel bir istemciye gerek kalmadi ve bagimlilik
/// **azaldi**: `http` zaten `postgrest`'in altinda duran paketti, yani
/// dogrudan kullanmak agaci buyutmuyor, kucultuyor.
///
/// `dart:io` ile de yazilabilirdi ama o tarayicida calismiyor; guncelleme
/// kontrolu uygulama acilirken kosuyor ve web surumu ekran onizlemesi icin
/// ayakta tutuluyor.
///
/// ## Kimlik dogrulamasi yok
/// Depo public oldugu icin release'ler anonim okunabiliyor. Uygulamada
/// gomulu **hicbir anahtar yok** (gerekce: [GitHubAyarlari]).
///
/// Bunun tek bedeli GitHub'in anonim istek siniri: saatte 60 istek. Bu
/// uygulama acilista bir kez soruyor; sinira ancak dakikada bir acip
/// kapatarak yaklasilir, o durumda da sonuc "bilinmiyor" oluyor —
/// yani kullanici hicbir sey gormuyor.
class SurumKaynagi {
  final ag.Client _istemci;

  /// [istemci] disaridan verilebiliyor: testler sahte bir istemciyle
  /// gercek aga cikmadan kosuyor.
  SurumKaynagi({ag.Client? istemci}) : _istemci = istemci ?? ag.Client();

  /// En son yayinlanmis surum. Yoksa ya da okunamazsa `null`.
  ///
  /// Ag hatasinda **istisna firlatiyor**; onu "bilinmiyor"a cevirmek
  /// `GuncellemeServisi`'nin isi. Burasi yalnizca okumakla sorumlu.
  Future<SurumBilgisi?> getir() async {
    final yanit = await _istemci.get(
      GitHubAyarlari.sonSurumAdresi,
      headers: const {
        // GitHub'in kendi tavsiyesi: yanit semasinin ileride sessizce
        // degismemesi icin surum acikca isteniyor.
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );

    // Henuz hic release yayinlanmamis depoda GitHub 404 donuyor.
    // Bu bir hata degil, "ortada surum yok" demek — ilk release
    // yayinlanana kadar yasanacak normal durum.
    if (yanit.statusCode == 404) return null;

    if (yanit.statusCode != 200) {
      throw Exception('GitHub ${yanit.statusCode} dondu');
    }

    // Yanit UTF-8; `yanit.body` gelen basligi dogru okumazsa Turkce
    // release notlari bozuk gorunurdu.
    final govde = jsonDecode(utf8.decode(yanit.bodyBytes));
    if (govde is! Map<String, dynamic>) return null;

    return SurumBilgisi.githubdanKur(govde);
  }
}
