import 'package:flutter/material.dart';

import '../../cekirdek/tema.dart';
import '../../servisler/kuyruk_yoneticisi.dart';
import '../ortak/is_karti.dart';

/// Tamamlanmis indirmelerin listesi.
///
/// ## Asama 1'de "Aç" gercek dosya acmiyor
/// Sahte motor gercek dosya uretmiyor; dugme yerinde duruyor ama uyari
/// veriyor. Dugmeyi hic koymamak, yerlesimi Asama 5'te yeniden
/// tasarlamak demek olurdu — simdiden yerini ayirmak daha ucuz.
class IndirilenlerEkrani extends StatelessWidget {
  final KuyrukYoneticisi kuyruk;

  const IndirilenlerEkrani({super.key, required this.kuyruk});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: kuyruk,
      builder: (context, _) {
        final gecmis = kuyruk.gecmis;

        if (gecmis.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open,
                      size: 46, color: Renkler.metinSolgun),
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

        return ListView.separated(
          padding: const EdgeInsets.all(Olculer.kenarBosluk),
          itemCount: gecmis.length,
          separatorBuilder: (_, _) => const SizedBox(height: Olculer.bosluk),
          itemBuilder: (context, i) {
            final is_ = gecmis[i];
            return IsKarti(
              is_: is_,
              eylem: IconButton(
                tooltip: 'Aç',
                icon: const Icon(Icons.open_in_new, size: 18),
                color: Renkler.metinSolgun,
                onPressed: () {
                  // Dosyayi baska bir uygulamada acmak henuz bagli degil
                  // (Asama 5'in kalan parcasi). Dosya artik telefonun ortak
                  // klasorunde oldugu icin kullanici onu muzik calarindan
                  // veya dosya yoneticisinden acabilir — mesaj da nereye
                  // bakacagini soyluyor.
                  final yer = is_.kayitYeri;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        yer != null
                            ? 'Dosya telefonun "$yer" klasöründe. '
                                'Uygulama içinden açma henüz bağlanmadı.'
                            : 'Bu dosya telefonun klasörlerine '
                                'çıkarılamadı, uygulamanın içinde duruyor.',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
