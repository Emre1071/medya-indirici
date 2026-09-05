import 'package:flutter/material.dart';

import '../../alan/varliklar/indirme_isi.dart';
import '../../alan/varliklar/medya_bilgisi.dart';
import '../../cekirdek/tema.dart';
import '../../servisler/indirme_motoru.dart';
import '../../servisler/motor_hazirlik.dart';
import '../ortak/kapak_gorseli.dart';
import '../ortak/kaynak_rozeti.dart';

/// Uygulamanin **en kritik ekrani**: paylas menusunden gelindiginde
/// dogrudan burasi aciliyor.
///
/// ## Tasarim olcutu: uc saniye
/// Kullanici Instagram'da video izlerken paylasa basti; aklinda tek bir
/// soru var — "ses mi, video mu". Bu ekran o soruyu sorup cevabi alacak,
/// baska hicbir sey istemeyecek. Kalite secimi **gizli** (ok tusunun
/// arkasinda) cunku vakalarin cogunda en iyisi zaten dogru cevap.
///
/// ## Cozumleme beklerken ekran bos kalmiyor
/// Motorun cevabi 1-3 saniye surebiliyor. O sure boyunca donen bir carkla
/// bos ekran gostermek yerine, gelecek yerlesimin iskeleti ciziliyor —
/// bekleme daha kisa hissediliyor ve ekran cevap gelince ziplamiyor.
class OnizlemeSayfasi extends StatefulWidget {
  final String adres;
  final IndirmeMotoru motor;

  /// Kullanici secimini yapinca cagrilir; kuyruga ekleme isini
  /// bu sayfa degil, cagiran taraf yapiyor.
  final void Function(MedyaBilgisi bilgi, IndirmeTuru tur, MedyaKalitesi? kalite)
      secildi;

  const OnizlemeSayfasi({
    super.key,
    required this.adres,
    required this.motor,
    required this.secildi,
  });

  @override
  State<OnizlemeSayfasi> createState() => _OnizlemeSayfasiState();
}

class _OnizlemeSayfasiState extends State<OnizlemeSayfasi> {
  MedyaBilgisi? _bilgi;
  String? _hata;

  /// Motorun acilmasi bekleniyor mu?
  bool _motorBekleniyor = false;

  /// Kullanicinin elle sectigi kaliteler. `null` ise "onerileni kullan".
  MedyaKalitesi? _secilenSes;
  MedyaKalitesi? _secilenVideo;

  @override
  void initState() {
    super.initState();
    _baslat();
  }

  /// Once motorun hazir olmasini bekler, sonra cozumler.
  ///
  /// ## Nicin bekleme gerekiyor
  /// Bu sayfa paylas menusunden **dogrudan** aciliyor ve o an uygulama
  /// yeni baslamis oluyor: gomulu Python/ffmpeg ikilileri hala aciliyor
  /// olabiliyor. Beklemeden cozumlemeye kalkisilsa motor
  /// `MOTOR_HAZIR_DEGIL` hatasi doner ve kullanici, asil akisin ilk
  /// adiminda kirmizi bir hata ekraniyla karsilasirdi — uygulama bozuk
  /// gorunurdu. Oysa yapmasi gereken tek sey birkac saniye beklemek.
  ///
  /// Bekleme **yalnizca gerektiginde** goruluyor: motor zaten hazirsa
  /// `hazirMi()` aninda `true` donuyor ve ekran dogrudan iskelete geciyor.
  Future<void> _baslat() async {
    if (await widget.motor.hazirMi()) {
      await _cozumle();
      return;
    }

    if (!mounted) return;
    setState(() => _motorBekleniyor = true);

    await MotorHazirlik.bekle(widget.motor, devamEdilsinMi: () => mounted);
    if (!mounted) return;

    setState(() => _motorBekleniyor = false);

    // Sinir dolup motor yine hazir olmadiysa bile deneniyor: motorun kendi
    // hata mesaji, belirsiz bir beklemeden daha bilgilendirici.
    await _cozumle();
  }

  Future<void> _cozumle() async {
    setState(() {
      _hata = null;
      _bilgi = null;
    });

    try {
      final b = await widget.motor.cozumle(widget.adres);
      if (!mounted) return;
      setState(() => _bilgi = b);
    } on MotorHatasi catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.mesaj);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Bağlantı çözümlenemedi. İnternetini kontrol et.');
    }
  }

  void _indir(IndirmeTuru tur) {
    final b = _bilgi;
    if (b == null) return;

    final kalite = tur == IndirmeTuru.ses
        ? (_secilenSes ?? b.onerilenSes)
        : (_secilenVideo ?? b.onerilenVideo);

    widget.secildi(b, tur, kalite);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İndir')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Olculer.kenarBosluk),
          child: _govde(),
        ),
      ),
    );
  }

  Widget _govde() {
    if (_hata != null) return _hataGorunumu(_hata!);
    if (_motorBekleniyor) return const _MotorBekleniyor();
    if (_bilgi == null) return const _Iskelet();
    return _hazirGorunum(_bilgi!);
  }

  // ------------------------------------------------------------------ hata

  Widget _hataGorunumu(String mesaj) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.link_off, size: 46, color: Renkler.metinSolgun),
          const SizedBox(height: 14),
          Text(
            mesaj,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: Olculer.govde),
          ),
          const SizedBox(height: 8),
          // Adres gosteriliyor: kullanici yanlis seyi paylasmis olabilir
          // (ornegin profil linki, gonderi linki degil). Neyi denedigimizi
          // gormeden bunu anlamasi mumkun degil.
          Text(
            widget.adres,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: Olculer.kucukBilgi,
              color: Renkler.metinSolgun,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _baslat,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ hazir

  Widget _hazirGorunum(MedyaBilgisi b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: KapakGorseli(adres: b.kapakAdresi, kaynak: b.kaynak),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    KaynakRozeti(kaynak: b.kaynak),
                    if (b.sureMetni.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        b.sureMetni,
                        style: const TextStyle(
                          fontSize: Olculer.kucukBilgi,
                          color: Renkler.metinSolgun,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  b.baslik,
                  style: const TextStyle(
                    fontSize: Olculer.baslikBuyuk,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                if (b.yukleyen != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    b.yukleyen!,
                    style: const TextStyle(
                      fontSize: Olculer.govde,
                      color: Renkler.metinSolgun,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Olculer.bosluk),
        if (b.sesVar)
          _BuyukDugme(
            simge: Icons.music_note,
            baslik: 'Ses İndir',
            altBaslik: _altBaslik(_secilenSes ?? b.onerilenSes),
            renk: Renkler.ses,
            basildi: () => _indir(IndirmeTuru.ses),
            kaliteBasildi: b.sesSecenekleri.length > 1
                ? () => _kaliteSec(b.sesSecenekleri, IndirmeTuru.ses)
                : null,
          ),
        if (b.sesVar && b.videoVar) const SizedBox(height: 10),
        if (b.videoVar)
          _BuyukDugme(
            simge: Icons.movie_outlined,
            baslik: 'Video İndir',
            altBaslik: _altBaslik(_secilenVideo ?? b.onerilenVideo),
            renk: Renkler.video,
            basildi: () => _indir(IndirmeTuru.video),
            kaliteBasildi: b.videoSecenekleri.length > 1
                ? () => _kaliteSec(b.videoSecenekleri, IndirmeTuru.video)
                : null,
          ),
        if (!b.sesVar && !b.videoVar)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Bu bağlantıda indirilebilir bir içerik bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Renkler.metinSolgun),
            ),
          ),
      ],
    );
  }

  /// Dugmenin altinda gorunen kalite + boyut bilgisi.
  /// Boyut bilinmiyorsa sadece kalite yaziliyor — `0 MB` yazmak yanlis bilgi.
  String _altBaslik(MedyaKalitesi? k) {
    if (k == null) return '';
    final boyut = k.boyutMetni;
    return boyut.isEmpty ? k.etiket : '${k.etiket} · $boyut';
  }

  Future<void> _kaliteSec(
    List<MedyaKalitesi> secenekler,
    IndirmeTuru tur,
  ) async {
    final secili =
        tur == IndirmeTuru.ses ? _secilenSes : _secilenVideo;

    final sonuc = await showModalBottomSheet<MedyaKalitesi>(
      context: context,
      backgroundColor: Renkler.yuzey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              tur == IndirmeTuru.ses ? 'Ses kalitesi' : 'Video kalitesi',
              style: const TextStyle(
                fontSize: Olculer.baslik,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final k in secenekler)
              ListTile(
                leading: Icon(
                  (secili ?? secenekler.first) == k
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: tur == IndirmeTuru.ses ? Renkler.ses : Renkler.video,
                ),
                title: Text(k.etiket),
                subtitle: k.boyutMetni.isEmpty
                    ? null
                    : Text('${k.boyutMetni} · ${k.uzanti}'),
                onTap: () => Navigator.of(context).pop(k),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (sonuc == null || !mounted) return;
    setState(() {
      if (tur == IndirmeTuru.ses) {
        _secilenSes = sonuc;
      } else {
        _secilenVideo = sonuc;
      }
    });
  }
}

/// Ses / Video dugmesi.
///
/// Sagindaki ok, kalite secimini aciyor ve **yalnizca birden fazla secenek
/// varsa** goruluyor. Instagram'da tek kalite oldugunda ok cikmiyor;
/// basilinca hicbir sey olmayan bir dugme gostermek, arayuze olan guveni
/// azaltir.
class _BuyukDugme extends StatelessWidget {
  final IconData simge;
  final String baslik;
  final String altBaslik;
  final Color renk;
  final VoidCallback basildi;
  final VoidCallback? kaliteBasildi;

  const _BuyukDugme({
    required this.simge,
    required this.baslik,
    required this.altBaslik,
    required this.renk,
    required this.basildi,
    this.kaliteBasildi,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Olculer.buyukDugme,
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: renk.withValues(alpha: 0.14),
              borderRadius: BorderRadius.horizontal(
                left: const Radius.circular(Olculer.kose),
                right: Radius.circular(kaliteBasildi == null ? Olculer.kose : 0),
              ),
              child: InkWell(
                onTap: basildi,
                borderRadius: BorderRadius.circular(Olculer.kose),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(simge, color: renk, size: 26),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            baslik,
                            style: TextStyle(
                              fontSize: Olculer.baslik,
                              fontWeight: FontWeight.w600,
                              color: renk,
                            ),
                          ),
                          if (altBaslik.isNotEmpty)
                            Text(
                              altBaslik,
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
              ),
            ),
          ),
          if (kaliteBasildi != null) ...[
            const SizedBox(width: 2),
            Material(
              color: renk.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(Olculer.kose),
              ),
              child: InkWell(
                onTap: kaliteBasildi,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(Olculer.kose),
                ),
                child: SizedBox(
                  width: 48,
                  height: Olculer.buyukDugme,
                  child: Icon(Icons.tune, color: renk, size: 20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Motor acilirken gosterilen bekleme durumu.
///
/// ## Nicin iskelet degil de bu?
/// Iskelet "veri birazdan gelecek" demek ve saniyeler icinde dolacagi
/// varsayimina dayaniyor. Motor kurulumu ise ilk acilista daha uzun
/// surebiliyor. Dolmayan bir iskelet takilmis izlenimi verir; burada ne
/// beklendigi acikca yaziliyor ve bunun **bir kerelik** oldugu soyleniyor,
/// cunku kullanici bunu yalnizca uygulamayi ilk actiginda gorecek.
class _MotorBekleniyor extends StatelessWidget {
  const _MotorBekleniyor();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              valueColor: AlwaysStoppedAnimation(Renkler.vurgu),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Motor hazırlanıyor…',
            style: TextStyle(
              fontSize: Olculer.baslik,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'İlk açılışta birkaç saniye sürer.\nHazır olunca bağlantı '
            'kendiliğinden çözümlenecek.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Olculer.kucukBilgi,
              color: Renkler.metinSolgun,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cozumleme beklenirken gosterilen iskelet.
class _Iskelet extends StatelessWidget {
  const _Iskelet();

  @override
  Widget build(BuildContext context) {
    Widget kutu({double? boy, double? en, double kose = 8}) => Container(
          height: boy,
          width: en,
          decoration: BoxDecoration(
            color: Renkler.yuzey,
            borderRadius: BorderRadius.circular(kose),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: kutu(kose: Olculer.kose),
        ),
        const SizedBox(height: 14),
        kutu(boy: 22, en: 110),
        const SizedBox(height: 10),
        kutu(boy: 20, en: double.infinity),
        const SizedBox(height: 6),
        kutu(boy: 20, en: 200),
        const Spacer(),
        const Center(
          child: Text(
            'Bağlantı çözümleniyor…',
            style: TextStyle(
              fontSize: Olculer.govde,
              color: Renkler.metinSolgun,
            ),
          ),
        ),
        const SizedBox(height: 10),
        kutu(boy: Olculer.buyukDugme, kose: Olculer.kose),
        const SizedBox(height: 10),
        kutu(boy: Olculer.buyukDugme, kose: Olculer.kose),
      ],
    );
  }
}
