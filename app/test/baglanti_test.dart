import 'package:flutter_test/flutter_test.dart';
import 'package:medya_indirici/cekirdek/baglanti.dart';

/// Paylasilan metinden link ayiklama.
///
/// ## Nicin test ediliyor
/// Bu, paylas menusu akisindaki **tek karar noktasi**. Yanlis ayiklanan
/// bir adres motora gidiyor ve oradan "Bu bağlantı desteklenmiyor" diye
/// donuyor — kullanici da uygulamanin Instagram'i desteklemedigini sanmis
/// oluyor. Hatanin kaynagi gorunmuyor.
///
/// Ornekler gercek paylasim metinlerinin bicimine gore yazildi:
/// Instagram aciklama + link, YouTube baslik + kisa adres.
void main() {
  group('Instagram', () {
    test('aciklama metninin icinden linki cikariyor', () {
      const paylasim = 'Şerif Ruç on Instagram: "Hayırlı akşamlar 🎻🎸"\n'
          'https://www.instagram.com/reel/DAbC123/?igsh=MXY5aA==';

      expect(
        Baglanti.ayikla(paylasim),
        'https://www.instagram.com/reel/DAbC123/?igsh=MXY5aA==',
      );
    });

    test('sondaki esittir kirpilmiyor', () {
      // `?igsh=...==` parametresi esittir ile bitiyor; kirpilirsa adres
      // bozulur ve gonderi bulunamaz.
      const paylasim = 'https://www.instagram.com/reel/X/?igsh=abcd==';
      expect(Baglanti.ayikla(paylasim), endsWith('igsh=abcd=='));
    });

    test('aciklamadaki baska link degil, gonderi linki seciliyor', () {
      // Aciklamalarda sik sik profil/bagis linki geciyor ve metinde ONCE
      // geliyor. Ilk bulunani almak yanlis seyi indirmek olurdu.
      const paylasim = 'Destek ol: https://linktr.ee/birisi\n'
          'https://www.instagram.com/reel/DOGRU/';

      expect(Baglanti.ayikla(paylasim), 'https://www.instagram.com/reel/DOGRU/');
    });
  });

  group('YouTube', () {
    test('baslikla birlikte gelen kisa adresi cikariyor', () {
      const paylasim = 'İsmail YK - Her Şeyin Yalan\n'
          'https://youtu.be/dQw4w9WgXcQ?si=AbCdEf';

      expect(Baglanti.ayikla(paylasim), 'https://youtu.be/dQw4w9WgXcQ?si=AbCdEf');
    });

    test('mobil alt alan adi taniniyor', () {
      const paylasim = 'https://m.youtube.com/watch?v=abc123';
      expect(Baglanti.tanidikMi(paylasim), isTrue);
    });
  });

  group('metin temizligi', () {
    test('yalnizca linkten olusan paylasim', () {
      expect(
        Baglanti.ayikla('https://www.instagram.com/reel/X/'),
        'https://www.instagram.com/reel/X/',
      );
    });

    test('bastaki ve sondaki bosluklar sorun cikarmiyor', () {
      expect(
        Baglanti.ayikla('  https://youtu.be/abc  '),
        'https://youtu.be/abc',
      );
    });

    test('sondaki noktalama kirpiliyor', () {
      expect(Baglanti.ayikla('(bkz. https://youtu.be/abc)'), 'https://youtu.be/abc');
      expect(Baglanti.ayikla('şuna bak: https://youtu.be/abc.'), 'https://youtu.be/abc');
      expect(Baglanti.ayikla('"https://youtu.be/abc"'), 'https://youtu.be/abc');
    });

    test('bolu isareti korunuyor', () {
      // Adresin kendi parcasi; noktalama sanip atilirsa adres degisir.
      expect(
        Baglanti.ayikla('https://www.instagram.com/reel/X/'),
        endsWith('/'),
      );
    });
  });

  group('link bulunamayan durumlar', () {
    test('duz metinde link yok', () {
      expect(Baglanti.ayikla('bunu bir indirsene'), isNull);
    });

    test('bos metin', () {
      expect(Baglanti.ayikla(''), isNull);
      expect(Baglanti.ayikla('   '), isNull);
    });

    test('null', () {
      expect(Baglanti.ayikla(null), isNull);
    });

    test('semasiz adres link sayilmiyor', () {
      // Motor da bunu kabul etmiyor; burada yakalamak, kullaniciya
      // "bağlantı bulunamadı" demeyi mumkun kiliyor.
      expect(Baglanti.ayikla('instagram.com/reel/X'), isNull);
    });
  });

  group('tanidik alan denetimi', () {
    test('alt alan adlari sayiliyor', () {
      expect(Baglanti.tanidikMi('https://www.instagram.com/reel/X'), isTrue);
    });

    test('benzer ama baska bir alan sayilmiyor', () {
      // `contains` ile yazilsaydi bu adres Instagram sanilirdi.
      expect(Baglanti.tanidikMi('https://instagram.com.sahte.net/x'), isFalse);
    });

    test('tanimadigimiz site yine de deneniyor', () {
      // yt-dlp bizim listemizden cok daha fazla siteyi taniyor; reddetmek
      // yerine denemek dogru, asil karari motor veriyor.
      expect(
        Baglanti.ayikla('https://vimeo.com/123456'),
        'https://vimeo.com/123456',
      );
    });
  });
}
