import 'dart:async';

import 'package:flutter/material.dart';

import '../../cekirdek/baglanti.dart';
import '../../cekirdek/tema.dart';
import '../../servisler/guncelleme_servisi.dart';
import '../../servisler/indirme_motoru.dart';
import '../../servisler/kuyruk_yoneticisi.dart';
import '../../servisler/motor_hazirlik.dart';
import '../../servisler/paylasim_dinleyici.dart';
import '../ana/ana_ekran.dart';
import '../ayarlar/ayarlar_ekrani.dart';
import '../indirilenler/indirilenler_ekrani.dart';
import '../onizleme/onizleme_sayfasi.dart';

/// Uygulamanin kabugu: sekmeler + paylasilan durum.
///
/// ## Kuyruk neden burada duruyor?
/// Uc sekme de ayni kuyruga bakiyor (ana ekran siradakileri, indirilenler
/// bitmisleri, ayarlar temizlemeyi). Kuyrugu sekmelerin icinde tutmak,
/// sekme degisince durumun sifirlanmasi demek olurdu — indirme devam
/// ederken baska sekmeye gecmek en dogal davranis oldugu icin bu hata
/// hemen goze carpardi.
///
/// ## Asama 4 notu
/// Paylas menusunden gelen link de buraya dusecek ve [_onizlemeyiAc]
/// cagrilacak. Yonlendirme tek noktada toplandigi icin o degisiklik
/// bu dosyanin disina tasmayacak.
class AnaKabuk extends StatefulWidget {
  final IndirmeMotoru motor;

  const AnaKabuk({super.key, required this.motor});

  @override
  State<AnaKabuk> createState() => _AnaKabukState();
}

class _AnaKabukState extends State<AnaKabuk> {
  late final KuyrukYoneticisi _kuyruk = KuyrukYoneticisi(widget.motor);
  int _sekme = 0;

  /// Guncelleme kontrolunun sonucu. Kontrol bitene kadar `null`.
  GuncellemeSonucu? _guncelleme;

  /// Indirme motorunun acilis durumu.
  ///
  /// Ilk acilista gomulu Python ve ffmpeg ikilileri aciliyor; bu birkac
  /// saniye suruyor ve o sirada gelen her cagri hata donuyor. Kurulum
  /// tamamen basarisiz da olabiliyor — arayuz "birazdan hazir olacak" ile
  /// "hic acilmayacak" arasindaki farki gostermek zorunda.
  MotorDurumu _motorDurumu = const MotorDurumu.hazirlaniyor();

  final PaylasimDinleyici _paylasim = PaylasimDinleyici();
  StreamSubscription<String>? _paylasimAbonesi;

  @override
  void initState() {
    super.initState();
    _guncellemeyeBak();
    _motoruBekle();

    // Ilk karenin cizilmesi bekleniyor: paylasimla acildiginda onizleme
    // sayfasi hemen aciliyor ve `Navigator` ancak agac kuruldugunda
    // kullanilabilir oluyor.
    WidgetsBinding.instance.addPostFrameCallback((_) => _paylasimiDinle());
  }

  /// Paylas menusunden gelen linkleri karsilar.
  ///
  /// Iki kaynak da ayni yere akiyor: uygulama paylasimla **acildiysa**
  /// bekleyen metin, **aciksa** olay akisi. Ayrimi Android tarafi yapiyor
  /// (`PaylasimKoprusu.kt`); burasi ikisini de ayni sekilde isliyor.
  Future<void> _paylasimiDinle() async {
    final ilk = await _paylasim.ilkPaylasim();
    if (!mounted) return;
    if (ilk != null) _paylasimdanAc(ilk);

    _paylasimAbonesi = _paylasim.akis.listen((metin) {
      if (mounted) _paylasimdanAc(metin);
    });
  }

  /// Paylasilan ham metinden linki cikarip onizlemeyi acar.
  ///
  /// Gelen sey temiz bir link degil: Instagram aciklama metniyle birlikte
  /// yolluyor (bkz. [Baglanti]).
  void _paylasimdanAc(String hamMetin) {
    final adres = Baglanti.ayikla(hamMetin);

    if (adres == null) {
      // Kullanici bir sey paylasti ama icinde link yok — ornegin duz bir
      // yorum metni. Sessiz kalmak "uygulama acildi ve hicbir sey olmadi"
      // demek olurdu.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paylaşılan metinde bir bağlantı bulunamadı.'),
        ),
      );
      return;
    }

    // Ust uste paylasim yapilirsa onizleme sayfalari birikmesin: her
    // seferinde koke donuluyor. Aksi halde geri tusu eski gonderilerin
    // arasinda gezdirirdi.
    Navigator.of(context).popUntil((rota) => rota.isFirst);
    _onizlemeyiAc(adres);
  }

  /// Motorun acilmasini bekleyip sonucu ekranlara verir.
  ///
  /// Bekleme mantigi [MotorHazirlik]'te — ayni is onizleme sayfasinda da
  /// gerekiyor. Sinir dolup motor hala acilmadiysa **hazir kabul ediliyor**:
  /// gercek sebep motorun kendi hata mesajindan gelsin, ekranda sonsuza
  /// kadar "hazırlanıyor" yazmasin. Kurulum acikca basarisiz olduysa o
  /// durum oldugu gibi tasiniyor ve sebep ekranda goruluyor.
  Future<void> _motoruBekle() async {
    final sonuc = await MotorHazirlik.bekle(
      widget.motor,
      devamEdilsinMi: () => mounted,
    );
    if (!mounted) return;

    setState(() {
      _motorDurumu = sonuc.bekleniyorMu ? const MotorDurumu.hazir() : sonuc;
    });
  }

  /// Acilista **sessizce** bakiliyor.
  ///
  /// Hicbir sey beklenmiyor, hicbir sey engellenmiyor: servis hata
  /// firlatmiyor ve sonuc gelmezse ekranda hicbir sey degismiyor.
  /// Kullanici bu kontrolun yapildigini yalnizca yeni surum varsa fark eder.
  Future<void> _guncellemeyeBak() async {
    final sonuc = await GuncellemeServisi().kontrolEt();
    if (!mounted) return;
    setState(() => _guncelleme = sonuc);
  }

  @override
  void dispose() {
    _paylasimAbonesi?.cancel();
    _kuyruk.dispose();
    super.dispose();
  }

  Future<void> _onizlemeyiAc(String adres) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnizlemeSayfasi(
          adres: adres,
          motor: widget.motor,
          secildi: (bilgi, tur, kalite) {
            _kuyruk.ekleCozumlenmis(bilgi, tur, kalite: kalite);

            // Secim yapilinca ana sekmeye donuluyor: is kuyruga girdi,
            // kullanicinin gormesi gereken yer orasi.
            setState(() => _sekme = 0);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ekranlar = [
      AnaEkran(
        kuyruk: _kuyruk,
        onizlemeyiAc: _onizlemeyiAc,
        motorDurumu: _motorDurumu,
      ),
      IndirilenlerEkrani(kuyruk: _kuyruk),
      AyarlarEkrani(
        motor: widget.motor,
        kuyruk: _kuyruk,
        guncelleme: _guncelleme,
        motorDurumu: _motorDurumu,
        motoruYenidenDene: _motoruBekle,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medya İndirici'),
      ),
      body: SafeArea(
        child: IndexedStack(index: _sekme, children: ekranlar),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _kuyruk,
        builder: (context, _) {
          final calisan = _kuyruk.kuyruk.where((i) => i.calisyor).length;

          return NavigationBar(
            selectedIndex: _sekme,
            onDestinationSelected: (i) => setState(() => _sekme = i),
            backgroundColor: Renkler.yuzey,
            indicatorColor: Renkler.vurgu.withValues(alpha: 0.18),
            destinations: [
              NavigationDestination(
                // Calisan indirme sayisi rozette gosteriliyor: kullanici
                // baska sekmedeyken de isin surdugunu gorebilsin.
                icon: Badge(
                  isLabelVisible: calisan > 0,
                  label: Text('$calisan'),
                  child: const Icon(Icons.download_outlined),
                ),
                selectedIcon: const Icon(Icons.download),
                label: 'İndir',
              ),
              const NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: 'İndirilenler',
              ),
              NavigationDestination(
                // Yeni surum varsa noktali rozet. Kullanici Ayarlar'a
                // girmeyi akil etmeden guncellemeden haberdar olsun diye.
                icon: Badge(
                  isLabelVisible: _guncelleme?.yeniVar ?? false,
                  child: const Icon(Icons.settings_outlined),
                ),
                selectedIcon: const Icon(Icons.settings),
                label: 'Ayarlar',
              ),
            ],
          );
        },
      ),
    );
  }
}
