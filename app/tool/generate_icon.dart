// Uygulama simgesini uretir: "derinlikli nota + indirme oku".
//
// ## Nicin bir betik, hazir bir gorsel degil?
// Simge birkac sabitten ibaret (renk, oran, bosluk). Betik olunca renk
// degistiginde ya da guvenli alan yeniden hesaplandiginda yeniden
// uretiliyor; bir tasarim dosyasini elle acip disa aktarmak gerekmiyor.
// Ustelik uygulama icindeki `SesIndirIkonu` ile ayni fikri paylasiyor —
// ikisinin birbirinden ayrismamasi icin ayni sabitler burada da yazili.
//
// ## Nicin IKI dosya uretiliyor?
// Android'in "adaptive icon" bicimi on plani ve arka plani AYRI istiyor
// ve on plani kendi maskesiyle kirpiyor. On plana zeminli bir gorsel
// verilirse, kirpilan koyu kare arka plan renginin uzerinde kucuk bir
// kutu gibi durur — yani `adaptive_icon_background` bosa gider.
// Bu yuzden:
//   - `app_icon.png`            zeminli   (eski, dairesel olmayan cihazlar)
//   - `app_icon_foreground.png` SAFFAF    (adaptive icon on plani)
//
// ## Calistirma
//   cd app && dart run tool/generate_icon.dart
// Ardindan:
//   dart run flutter_launcher_icons

import 'dart:io';
import 'dart:math' as mat;

import 'package:image/image.dart' as im;

/// Uretilen kenar uzunlugu. 1024 flutter_launcher_icons'in butun
/// mipmap olculerini kayipsiz kuculterek uretmesine yetiyor.
const int olcu = 1024;

/// Koyu grafit zemin — uygulamanin `Renkler.arkaPlan` tonuyla akraba.
final im.Color zemin = im.ColorRgb8(0x12, 0x12, 0x14);

/// Zumrut/teal vurgu. Uygulamadaki `Renkler.ses` ile AYNI deger:
/// simge ile ekrandaki ses dugmesi ayni sey gibi okunmali.
final im.Color vurgu = im.ColorRgb8(0x2E, 0xD3, 0xB7);

/// Tam saydam — saffaf on planda "oyuk" acmak icin.
final im.Color saydam = im.ColorRgba8(0, 0, 0, 0);

/// Kenarlardan birakilan bosluk.
///
/// Android dairesel maskede kosleri kirpiyor; ayrica adaptive icon'un
/// yalnizca ORTA %66'si her cihazda goruntulenmeyi garanti ediyor.
/// %20 bosluk, cizimi 0.60'lik bir kutuya sikistirdigi icin ikisini de
/// karsiliyor.
const double bosluk = 0.20;

void main() {
  final klasor = Directory('assets/icon');
  if (!klasor.existsSync()) klasor.createSync(recursive: true);

  // Zeminli surum: eski (adaptive olmayan) cihazlar bunu kullaniyor.
  final zeminli = im.Image(width: olcu, height: olcu, numChannels: 4);
  im.fill(zeminli, color: zemin);
  _simgeyiCiz(zeminli, oyukRenk: zemin);
  File('assets/icon/app_icon.png')
      .writeAsBytesSync(im.encodePng(zeminli));

  // Saffaf surum: adaptive icon on plani.
  final onPlan = im.Image(width: olcu, height: olcu, numChannels: 4);
  im.fill(onPlan, color: saydam);
  _simgeyiCiz(onPlan, oyukRenk: saydam);
  File('assets/icon/app_icon_foreground.png')
      .writeAsBytesSync(im.encodePng(onPlan));

  stdout.writeln('assets/icon/app_icon.png            (zeminli)');
  stdout.writeln('assets/icon/app_icon_foreground.png (saffaf)');
}

/// Notayi ve indirme okunu cizer.
///
/// [oyukRenk] rozetin halkasi ve okun kendisi icin kullaniliyor. Zeminli
/// surumde zemin rengi ("kesilmis" gibi durur), saffaf surumde tam
/// saydam (gercekten delik acar). Ikisi de ayni gorunuyor cunku adaptive
/// arka plan zaten ayni koyu ton.
void _simgeyiCiz(im.Image g, {required im.Color oyukRenk}) {
  final kenar = olcu * bosluk;
  final alan = olcu - kenar * 2;

  // Birim (0..1) koordinati piksele cevirir.
  double x(double b) => kenar + b * alan;
  double y(double b) => kenar + b * alan;
  double o(double b) => b * alan;

  // ---- Ikili nota -------------------------------------------------
  // Iki govde, iki bacak ve onlari birlestiren kalin bir kiris.
  // Kalin hatlar bilincli: simge 48 piksele kadar kuculuyor, ince
  // cizgiler o olcekte kayboluyor.

  // Oranlar cizilip goz ile denendi. Butun sekil 0..1 kutusunun
  // ICINDE kaliyor — kutu zaten %20 boslukla daraltilmis alan, yani
  // tasma dogrudan guvenli alani deler.
  final govdeYaricap = o(0.120);
  final bacakKalinlik = o(0.070);
  final kirisKalinlik = o(0.110);

  // Sol govde ve bacak
  im.fillCircle(g,
      x: x(0.155).round(),
      y: y(0.695).round(),
      radius: govdeYaricap.round(),
      color: vurgu,
      antialias: true);
  _kalinCizgi(g, x(0.268), y(0.695), x(0.268), y(0.175), bacakKalinlik, vurgu);

  // Sag govde ve bacak (biraz yukarida — nota ciftine hareket katiyor)
  im.fillCircle(g,
      x: x(0.475).round(),
      y: y(0.615).round(),
      radius: govdeYaricap.round(),
      color: vurgu,
      antialias: true);
  _kalinCizgi(g, x(0.588), y(0.615), x(0.588), y(0.095), bacakKalinlik, vurgu);

  // Kiris: iki bacagin tepesini birlestiriyor.
  _kalinCizgi(g, x(0.268), y(0.165), x(0.588), y(0.085), kirisKalinlik, vurgu);

  // ---- Indirme oku ------------------------------------------------
  // Sag alt bosluga oturuyor; uygulama icindeki `SesIndirIkonu` ile ayni
  // fikir, boylece simge ve ekran birbirini tekrar ediyor.

  // Rozet sag alt kosede ve yalnizca sag BACAGIN ucuna deger kadar
  // yakin. Ilk denemede govdenin ustune biniyordu ve nota gövdesi
  // hilal gibi kaliyordu; ustelik disari tasip guvenli alani deliyordu.
  final rozetMerkezX = x(0.775);
  final rozetMerkezY = y(0.780);
  final rozetYaricap = o(0.185);

  // Once oyuk halka: rozet notanin bacagina degdiginde ikisi birbirine
  // yapisip okunmaz hale geliyor.
  im.fillCircle(g,
      x: rozetMerkezX.round(),
      y: rozetMerkezY.round(),
      radius: (rozetYaricap + o(0.030)).round(),
      color: oyukRenk,
      antialias: true);

  im.fillCircle(g,
      x: rozetMerkezX.round(),
      y: rozetMerkezY.round(),
      radius: rozetYaricap.round(),
      color: vurgu,
      antialias: true);

  // Ok: govde + ucgen bas, oyuk renginde.
  final okYari = rozetYaricap * 0.52;
  _kalinCizgi(g, rozetMerkezX, rozetMerkezY - okYari, rozetMerkezX,
      rozetMerkezY + okYari * 0.15, rozetYaricap * 0.30, oyukRenk);

  im.fillPolygon(g, vertices: [
    im.Point(rozetMerkezX - okYari * 0.85, rozetMerkezY + okYari * 0.02),
    im.Point(rozetMerkezX + okYari * 0.85, rozetMerkezY + okYari * 0.02),
    im.Point(rozetMerkezX, rozetMerkezY + okYari * 0.95),
  ], color: oyukRenk);
}

/// Yuvarlak uclu kalin cizgi.
///
/// `image` paketinde hazir bir "kalin yuvarlak uclu cizgi" yok; dortgen
/// govde + iki uctaki daire ile kuruluyor. Yuvarlak uclar onemli: keskin
/// uclar bu olcekte nota bacaklarini kirik gosteriyor.
void _kalinCizgi(im.Image g, double x1, double y1, double x2, double y2,
    double kalinlik, im.Color renk) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final uzunluk = mat.sqrt(dx * dx + dy * dy);
  if (uzunluk == 0) return;

  // Cizgiye dik birim vektor, yarim kalinlik kadar olceklenmis.
  final nx = -dy / uzunluk * (kalinlik / 2);
  final ny = dx / uzunluk * (kalinlik / 2);

  im.fillPolygon(g, vertices: [
    im.Point(x1 + nx, y1 + ny),
    im.Point(x2 + nx, y2 + ny),
    im.Point(x2 - nx, y2 - ny),
    im.Point(x1 - nx, y1 - ny),
  ], color: renk);

  for (final uc in [[x1, y1], [x2, y2]]) {
    im.fillCircle(g,
        x: uc[0].round(),
        y: uc[1].round(),
        radius: (kalinlik / 2).round(),
        color: renk,
        antialias: true);
  }
}
