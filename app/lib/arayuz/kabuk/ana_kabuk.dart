import 'package:flutter/material.dart';

import '../../cekirdek/tema.dart';
import '../../servisler/guncelleme_servisi.dart';
import '../../servisler/indirme_motoru.dart';
import '../../servisler/kuyruk_yoneticisi.dart';
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

  /// Indirme motoru calismaya hazir mi?
  ///
  /// Ilk acilista gomulu Python ve ffmpeg ikilileri aciliyor; bu birkac
  /// saniye suruyor ve o sirada gelen her cagri hata donuyor. Kullanici
  /// tam o anda link yapistirirsa anlamsiz bir hata gormesin diye durum
  /// burada tutulup ekranlara veriliyor.
  bool _motorHazir = false;

  @override
  void initState() {
    super.initState();
    _guncellemeyeBak();
    _motoruBekle();
  }

  /// Motor hazir olana kadar araliklarla soruyor.
  ///
  /// ## Nicin yoklama (polling)?
  /// Android tarafi "hazir oldum" diye kendiliginden haber vermiyor;
  /// kurulum `MainActivity` icinde uygulama acilirken basliyor ve bitisi
  /// bir kanal olayina baglanmis degil. Tek bir bayrak icin ayri bir
  /// EventChannel acmak yerine saniyede birden az sikliktaki bu yoklama
  /// yeterli — bekleme zaten birkac saniye suruyor.
  ///
  /// Ust sinir var: motor kurulumu **basarisiz da olabiliyor** (yer yok,
  /// ikili acilamadi). Sonsuza kadar sormak, ekranda sonsuza kadar
  /// "hazırlanıyor" yazmasi demek olurdu. Sinir dolunca hazir kabul
  /// ediliyor ve gercek sebep motorun kendi hata mesajindan geliyor.
  static const int _hazirlikDenemeSiniri = 40; // ~30 saniye

  Future<void> _motoruBekle() async {
    for (var deneme = 0; deneme < _hazirlikDenemeSiniri; deneme++) {
      if (!mounted) return;

      if (await widget.motor.hazirMi()) {
        if (!mounted) return;
        setState(() => _motorHazir = true);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 750));
    }

    if (!mounted) return;
    setState(() => _motorHazir = true);
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
        motorHazir: _motorHazir,
      ),
      IndirilenlerEkrani(kuyruk: _kuyruk),
      AyarlarEkrani(
        motor: widget.motor,
        kuyruk: _kuyruk,
        guncelleme: _guncelleme,
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
