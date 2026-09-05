import 'package:flutter/material.dart';

import '../../cekirdek/tema.dart';

/// Medyanin kapak gorseli.
///
/// ## Kapak yoksa bosluk birakilmiyor
/// Instagram paylasimlarinin bir kismi kapak vermiyor, ag da her zaman
/// calismiyor. Bu durumlarda gri bir bosluk birakmak yerine kaynagin
/// simgesiyle dolu bir yer tutucu ciziliyor: ekranin yerlesimi kaymiyor ve
/// kullanici "yuklenmedi mi, bozuk mu" diye dusunmuyor.
class KapakGorseli extends StatelessWidget {
  final String? adres;
  final String kaynak;
  final double? en;
  final double? boy;
  final double koseYaricap;

  const KapakGorseli({
    super.key,
    required this.adres,
    required this.kaynak,
    this.en,
    this.boy,
    this.koseYaricap = Olculer.kose,
  });

  @override
  Widget build(BuildContext context) {
    final a = adres;

    return ClipRRect(
      borderRadius: BorderRadius.circular(koseYaricap),
      child: SizedBox(
        width: en,
        height: boy,
        child: a == null || a.isEmpty
            ? _yerTutucu()
            : Image.network(
                a,
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => _yerTutucu(),
                loadingBuilder: (context, cocuk, ilerleme) =>
                    ilerleme == null ? cocuk : _yerTutucu(),
              ),
      ),
    );
  }

  Widget _yerTutucu() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Renkler.yuzeyAcik, Renkler.yuzey],
        ),
      ),
      child: Center(
        child: Icon(
          kaynakSimgesi(kaynak),
          color: Renkler.metinSolgun.withValues(alpha: 0.5),
          size: 34,
        ),
      ),
    );
  }
}

/// Kaynak adina karsilik gelen simge.
IconData kaynakSimgesi(String kaynak) => switch (kaynak) {
      'instagram' => Icons.camera_alt_outlined,
      'youtube' => Icons.play_circle_outline,
      'facebook' => Icons.groups_outlined,
      'tiktok' => Icons.music_note_outlined,
      _ => Icons.link,
    };

/// Kaynak adinin kullaniciya gosterilen hali.
String kaynakAdi(String kaynak) => switch (kaynak) {
      'instagram' => 'Instagram',
      'youtube' => 'YouTube',
      'facebook' => 'Facebook',
      'tiktok' => 'TikTok',
      _ => 'Bağlantı',
    };
