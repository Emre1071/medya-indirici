import '../alan/varliklar/surum_bilgisi.dart';
import '../cekirdek/github_ayarlari.dart';
import '../cekirdek/surum.dart';
import '../veri/uzak/surum_kaynagi.dart';

enum GuncellemeDurumu {
  /// Elindeki surum en yenisi
  guncel,

  /// Daha yeni bir surum yayinlanmis
  yeniSurumVar,

  /// Bakilamadi (internet yok, tablo bos, hata). **Sessiz durum.**
  bilinmiyor,
}

class GuncellemeSonucu {
  final GuncellemeDurumu durum;
  final SurumBilgisi? bilgi;

  const GuncellemeSonucu(this.durum, [this.bilgi]);

  bool get yeniVar => durum == GuncellemeDurumu.yeniSurumVar;

  /// Yeni surumun indirilebilir bir adresi var mi?
  /// Adres bos birakilmis olabilir — o zaman yalnizca haber veriyoruz,
  /// indirme dugmesi gostermiyoruz.
  bool get indirilebilir =>
      yeniVar && (bilgi?.indirmeAdresi?.isNotEmpty ?? false);
}

/// "Daha yeni bir surum var mi?" sorusunu yanitlar.
///
/// ## Bu servis ASLA hata firlatmaz
/// DevLingo'daki ayni disiplin: internet yoksa, tablo bossa ya da bulut
/// cevap vermezse **sessizce `bilinmiyor`** doner.
///
/// Gerekcesi burada daha da guclu: bu uygulamanin isi video indirmek ve
/// bunun icin buluta hic ihtiyaci yok. Guncelleme kontrolu basarisiz diye
/// kullaniciya hata gostermek, ilgisiz bir seyden dolayi calisan bir
/// uygulamayi bozuk gostermek olurdu.
///
/// ## Iki ayri guncelleme var, bu onlardan biri
/// - **Uygulama guncellemesi** (bu servis): nadir, ~59 MB APK,
///   GitHub Releases'ten, kurulum ekrani acilir.
/// - **Motor guncellemesi** (yt-dlp): sik, birkac MB, uygulama icinden,
///   yeniden kurulum gerektirmez.
///
/// Instagram/YouTube bir seyi degistirdiginde cozum neredeyse her zaman
/// ikincisidir. Ikisini ayni dugmede toplamak, her kucuk bozulmada 100 MB
/// indirtmek olurdu.
class GuncellemeServisi {
  final SurumKaynagi kaynak;

  /// Testlerde sahte bir kaynak verilebilsin diye disaridan alinabiliyor.
  GuncellemeServisi({SurumKaynagi? kaynak}) : kaynak = kaynak ?? SurumKaynagi();

  Future<GuncellemeSonucu> kontrolEt() async {
    if (!GitHubAyarlari.yapilandirildi) {
      return const GuncellemeSonucu(GuncellemeDurumu.bilinmiyor);
    }

    try {
      final bilgi = await kaynak.getir();
      if (bilgi == null) {
        return const GuncellemeSonucu(GuncellemeDurumu.bilinmiyor);
      }

      final yeni = Surum.yeniMi(mevcut: Surum.simdiki, aday: bilgi.surum);
      return GuncellemeSonucu(
        yeni ? GuncellemeDurumu.yeniSurumVar : GuncellemeDurumu.guncel,
        bilgi,
      );
    } catch (_) {
      // Sebebi ayirt etmiyoruz: kullanici acisindan "internet yok" ile
      // "tablo yok" arasinda fark yok — ikisinde de yapabilecegi bir sey
      // olmadigi icin ekranda hicbir sey gostermiyoruz.
      return const GuncellemeSonucu(GuncellemeDurumu.bilinmiyor);
    }
  }
}
