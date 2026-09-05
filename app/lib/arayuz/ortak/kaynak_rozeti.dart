import 'package:flutter/material.dart';

import '../../cekirdek/tema.dart';
import 'kapak_gorseli.dart';

/// Icerigin nereden geldigini gosteren kucuk rozet.
///
/// Onemli, cunku ayni ekran hem Instagram hem YouTube icin aciliyor ve
/// ikisinde **secenekler farkli** (YouTube'da cok kalite var, Instagram'da
/// genelde tek). Kullanici neye baktigini bilmezse, secenek sayisindaki
/// bu farki hata sanabilir.
class KaynakRozeti extends StatelessWidget {
  final String kaynak;

  const KaynakRozeti({super.key, required this.kaynak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Renkler.yuzeyAcik,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Renkler.kenarlik),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kaynakSimgesi(kaynak), size: 13, color: Renkler.metinSolgun),
          const SizedBox(width: 5),
          Text(
            kaynakAdi(kaynak),
            style: const TextStyle(
              fontSize: Olculer.etiket,
              color: Renkler.metinSolgun,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
