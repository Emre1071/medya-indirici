import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'arayuz/kabuk/ana_kabuk.dart';
import 'cekirdek/tema.dart';
import 'servisler/indirme_motoru.dart';
import 'servisler/sahte_motor.dart';
import 'servisler/ytdlp_motoru.dart';

void main() {
  runApp(const MedyaIndiriciUygulamasi());
}

/// ## Motor buradan seciliyor — tek nokta
/// Asama 2'de Android'e gomulu yt-dlp devreye girdiginde degisecek tek
/// satir `_motorSec()` icinde. Ekran kodlarinin hicbiri hangi motorun
/// calistigini bilmiyor; [IndirmeMotoru] arayuzunu goruyorlar.
class MedyaIndiriciUygulamasi extends StatelessWidget {
  const MedyaIndiriciUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medya İndirici',
      debugShowCheckedModeBanner: false,
      theme: koyuTema(),
      // Cerceve `home` yerine `builder`'a konuluyor.
      //
      // `home`'u sarmak yetmiyordu: `Navigator.push` ile acilan sayfalar
      // (onizleme sayfasi) MaterialApp seviyesinde ciziliyor, yani cercevenin
      // DISINDA kaliyor ve tum ekrana yayiliyordu. `builder` yonlendirme
      // katmaninin da ustunde durdugu icin butun sayfalari kapsiyor.
      builder: (context, gezinme) =>
          _telefonCercevesi(gezinme ?? const SizedBox.shrink()),
      home: AnaKabuk(motor: _motorSec()),
    );
  }

  /// Genis ekranda uygulamayi telefon olcusunde ortalar.
  ///
  /// Asama 1'in tek amaci ekranlari tarayicida degerlendirmek. Cerceve
  /// olmadan dugmeler 1900 piksele yayilir ve tasarim hakkinda hicbir sey
  /// soylenemez. Telefonda ekran zaten dar oldugu icin cerceve devreye
  /// girmiyor — yani bu kod telefondaki gorunumu **degistirmiyor**.
  Widget _telefonCercevesi(Widget cocuk) {
    return LayoutBuilder(
      builder: (context, sinirlar) {
        final genisEkran = sinirlar.maxWidth > Olculer.telefonGenislik + 40;
        if (!genisEkran) return cocuk;

        // Yukseklik pencereye sigmiyorsa kisaltiliyor. Sabit 873 birakmak,
        // kisa tarayici penceresinde alt menuyu kirpiyordu — tam da
        // degerlendirilmesi gereken yeri.
        final boy = sinirlar.maxHeight < Olculer.telefonYukseklik + 24
            ? sinirlar.maxHeight
            : Olculer.telefonYukseklik;

        return ColoredBox(
          color: const Color(0xFF0A0C0E),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: Olculer.telefonGenislik,
                height: boy,
                child: cocuk,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Android'de gomulu yt-dlp, diger her yerde sahte motor.
  ///
  /// `dart:io`'daki `Platform` **kullanilmiyor**: web derlemesinde o sinifa
  /// erisim calisma aninda patliyor. `kIsWeb` ve `defaultTargetPlatform`
  /// ikilisi her hedefte guvenle okunabiliyor.
  ///
  /// Tarayicida sahte motor kalmaya devam ediyor — ekran duzenlerini
  /// telefona derleme atmadan denemek icin.
  IndirmeMotoru _motorSec() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return YtDlpMotoru();
    }
    return SahteMotor();
  }
}
