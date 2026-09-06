import 'package:flutter/material.dart';

import '../../cekirdek/tema.dart';

/// Ses indirmeyi anlatan ikon: **müzik notası + indirme oku.**
///
/// ## Nicin tek bir nota yetmiyor
/// Yalniz nota "burada muzik var" der; indirmeyi anlatmaz. Onizleme
/// ekraninda kullanicinin uc saniyede verecegi karar "ses mi, video mu"
/// oldugu icin ikonun **eylemi** de tasimasi gerekiyor. Kucuk asagi ok
/// bunu tek bakista veriyor.
///
/// ## Rozet zemine oturuyor
/// Ok, vurgu renginde dolu bir daire icinde ve okun kendisi [zemin]
/// renginde — yani daire notanin uzerinden "kesilmis" gibi duruyor.
/// Zemin disaridan veriliyor cunku ikon iki farkli yuzeyde kullaniliyor:
/// onizleme dugmesinin renkli zemini ve is kartinin duz yuzeyi. Sabit bir
/// renk verilseydi birinde daire yamali gorunurdu.
///
/// ## Kucuk boyutta rozet gizleniyor
/// Is kartindaki durum ikonu 13 piksel; o olcekte ok bir leke olur, bilgi
/// vermez. Esik widget'in kendi icinde: cagiran taraf boyut disinda bir
/// sey dusunmek zorunda kalmasin.
class SesIndirIkonu extends StatelessWidget {
  /// Ana notanin boyutu.
  final double boyut;

  final Color renk;

  /// Rozetin oturdugu yuzeyin rengi (okun rengi de bu olur).
  final Color zemin;

  /// Rozetin okunabilir kaldigi en kucuk olcu.
  static const double _rozetEsigi = 18;

  const SesIndirIkonu({
    super.key,
    this.boyut = 26,
    this.renk = Renkler.ses,
    this.zemin = Renkler.yuzey,
  });

  @override
  Widget build(BuildContext context) {
    final nota = Icon(Icons.music_note, size: boyut, color: renk);
    if (boyut < _rozetEsigi) return nota;

    // Oranlar 26 px'e (buton olcusu) gore secildi; tarayicida buyutulup
    // denendi. Daha kucuk rozet okunmuyor, daha buyugu notayi yutuyor.
    final rozet = boyut * 0.56;

    return SizedBox(
      width: boyut,
      height: boyut,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: nota),
          Positioned(
            right: -boyut * 0.10,
            bottom: -boyut * 0.04,
            child: Container(
              width: rozet,
              height: rozet,
              decoration: BoxDecoration(
                color: renk,
                shape: BoxShape.circle,
                // Ince zemin halkasi: rozet notanin govdesine degdiginde
                // ikisi birbirine yapisip okunmaz hale geliyordu.
                border: Border.all(color: zemin, width: rozet * 0.10),
              ),
              child: Icon(
                Icons.arrow_downward_rounded,
                size: rozet * 0.72,
                color: zemin,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
