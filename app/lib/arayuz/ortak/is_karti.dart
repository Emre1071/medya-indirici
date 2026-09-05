import 'package:flutter/material.dart';

import '../../alan/varliklar/indirme_isi.dart';
import '../../cekirdek/tema.dart';
import 'kapak_gorseli.dart';

/// Kuyrukta ve gecmiste gorunen tek satirlik is karti.
class IsKarti extends StatelessWidget {
  final IndirmeIsi is_;

  /// Sagdaki dugme. Kuyrukta "sil", gecmiste "ac" oluyor.
  final Widget? eylem;

  const IsKarti({super.key, required this.is_, this.eylem});

  @override
  Widget build(BuildContext context) {
    final sesMi = is_.tur == IndirmeTuru.ses;
    final turRengi = sesMi ? Renkler.ses : Renkler.video;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Renkler.yuzey,
        borderRadius: BorderRadius.circular(Olculer.kose),
        border: Border.all(color: Renkler.kenarlik),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KapakGorseli(
                adres: is_.bilgi?.kapakAdresi,
                kaynak: is_.bilgi?.kaynak ?? '',
                en: 52,
                boy: 52,
                koseYaricap: 10,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      is_.gosterilecekAd,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: Olculer.govde,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          sesMi ? Icons.music_note : Icons.movie_outlined,
                          size: 13,
                          color: turRengi,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            is_.durumMetni,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Olculer.kucukBilgi,
                              color: is_.durum == IsDurumu.hata
                                  ? Renkler.hata
                                  : Renkler.metinSolgun,
                            ),
                          ),
                        ),
                        if (is_.hiz != null && is_.durum == IsDurumu.iniyor)
                          Text(
                            is_.hiz!,
                            style: const TextStyle(
                              fontSize: Olculer.kucukBilgi,
                              color: Renkler.metinSolgun,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              ?eylem,
            ],
          ),
          // Bitmis iste dosyanin nereye kaydedildigi yaziyor.
          //
          // Bu satir kozmetik degil: "İndirildi" demek yetmiyor, kullanici
          // dosyayi telefonda nerede arayacagini bilmeli. Disari
          // cikarilamamis dosya ayrica uyari rengiyle isaretleniyor —
          // indirme basarili ama dosya muzik calarda gorunmeyecek.
          if (is_.durum == IsDurumu.bitti) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(
                  is_.kayitYeri != null
                      ? Icons.folder_outlined
                      : Icons.folder_off_outlined,
                  size: 13,
                  color: is_.kayitYeri != null
                      ? Renkler.metinSolgun
                      : Renkler.uyari,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    is_.kayitYeri ??
                        'Telefonun klasörlerine çıkarılamadı, '
                            'uygulama içinde duruyor',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Olculer.etiket,
                      color: is_.kayitYeri != null
                          ? Renkler.metinSolgun
                          : Renkler.uyari,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (is_.calisyor) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                // Donusturme asamasinda yuzde yok — belirsiz cubuk gosteriliyor.
                // Sahte bir yuzde uydurmak "takildi mi?" sorusunu dogurur.
                value: is_.durum == IsDurumu.donusturuluyor ? null : is_.oran,
                minHeight: 4,
                backgroundColor: Renkler.yuzeyAcik,
                valueColor: AlwaysStoppedAnimation(turRengi),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
