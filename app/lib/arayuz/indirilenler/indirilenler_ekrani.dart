import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../alan/varliklar/indirme_isi.dart';
import '../../cekirdek/tema.dart';
import '../../servisler/dosya_acici.dart';
import '../../servisler/kuyruk_yoneticisi.dart';
import '../ortak/is_karti.dart';

/// Tamamlanmis indirmelerin listesi.
///
/// ## "Aç" artik gercek dosyayi aciyor
/// Uzun sure yalnizca "dosya su klasorde" diyen bir uyari gosteriyordu;
/// kullaniciyi muzik calarina yollamak, uc dokunusluk akisin sonuna
/// dorduncu bir arama eklemek demekti. Kanal `DosyaAcici` uzerinden
/// Android'e gidiyor (bkz. `DosyaKoprusu.kt`).
///
/// ## Disari cikarilamamis dosya ayri davraniyor
/// `kayitYeri` bossa dosya uygulamanin icinde kalmis demektir; baska bir
/// uygulama onu goremez. O satirda "Aç" yerine **sebebi gosteren** bir
/// dugme duruyor — tanimadan cozum yok (bkz. `IndirmeIsi.kayitHatasi`).
class IndirilenlerEkrani extends StatefulWidget {
  final KuyrukYoneticisi kuyruk;

  const IndirilenlerEkrani({super.key, required this.kuyruk});

  @override
  State<IndirilenlerEkrani> createState() => _IndirilenlerEkraniState();
}

class _IndirilenlerEkraniState extends State<IndirilenlerEkrani> {
  final DosyaAcici _acici = DosyaAcici();

  Future<void> _ac(IndirmeIsi is_) async {
    final yol = is_.dosyaYolu;
    if (yol == null || yol.isEmpty) {
      _bildir('Bu indirmenin dosya yolu kayıtlı değil.');
      return;
    }

    final hata = await _acici.ac(yol);
    if (!mounted || hata == null) return;
    _bildir(hata);
  }

  void _bildir(String metin) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(metin)));
  }

  /// Dosya nicin disari cikarilamadi — ham metin, kopyalanabilir.
  ///
  /// Kendiliginden gosterilmiyor: yigin izi kullaniciya bir sey soylemez.
  /// Ama cihaz `adb`'ye baglanamadigi icin (§4.5) telefondan tani almanin
  /// tek yolu bu. Ayni kalip motor kurulum hatasinda ve basarisiz
  /// indirmede zaten kullaniliyor.
  void _kayitHatasiniGoster(String ayrinti) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Renkler.yuzey,
        title: const Text('Dosya telefona çıkarılamadı'),
        content: SingleChildScrollView(
          child: SelectableText(
            ayrinti,
            style: const TextStyle(
              fontSize: Olculer.etiket,
              color: Renkler.metinSolgun,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: ayrinti));
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ayrıntı kopyalandı.')),
              );
            },
            child: const Text('Kopyala'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.kuyruk,
      builder: (context, _) {
        final gecmis = widget.kuyruk.gecmis;

        if (gecmis.isEmpty) return const _BosGecmis();

        return ListView.separated(
          padding: const EdgeInsets.all(Olculer.kenarBosluk),
          itemCount: gecmis.length,
          separatorBuilder: (_, _) => const SizedBox(height: Olculer.bosluk),
          itemBuilder: (context, i) {
            final is_ = gecmis[i];
            final kayitHatasi = is_.kayitHatasi;

            // Dosya disari cikmadiysa acmaya calismak anlamsiz: baska bir
            // uygulama uygulamanin ozel klasorunu goremiyor. Onun yerine
            // sebep gosteriliyor.
            final cikarilamadi = is_.kayitYeri == null;

            final kart = IsKarti(
              is_: is_,
              eylem: cikarilamadi
                  ? IconButton(
                      tooltip: 'Neden çıkarılamadı?',
                      icon: const Icon(Icons.error_outline, size: 18),
                      color: Renkler.uyari,
                      onPressed: kayitHatasi == null
                          ? () => _bildir(
                                'Bu dosya telefonun klasörlerine '
                                'çıkarılamadı, uygulamanın içinde duruyor.',
                              )
                          : () => _kayitHatasiniGoster(kayitHatasi),
                    )
                  : IconButton(
                      tooltip: 'Aç',
                      icon: const Icon(Icons.open_in_new, size: 18),
                      color: Renkler.metinSolgun,
                      onPressed: () => _ac(is_),
                    ),
            );

            // Cikarilmis dosyada karta dokunmak da aciyor: listedeki asil
            // eylem bu, kucuk bir ikona nisan almak zorunda kalmamali.
            if (cikarilamadi) return kart;
            return InkWell(
              borderRadius: BorderRadius.circular(Olculer.kose),
              onTap: () => _ac(is_),
              child: kart,
            );
          },
        );
      },
    );
  }
}

class _BosGecmis extends StatelessWidget {
  const _BosGecmis();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 46, color: Renkler.metinSolgun),
            SizedBox(height: 14),
            Text(
              'Henüz indirme yok',
              style: TextStyle(
                fontSize: Olculer.baslik,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'İndirdiklerin burada birikecek.',
              style: TextStyle(
                fontSize: Olculer.kucukBilgi,
                color: Renkler.metinSolgun,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
