import 'package:flutter/material.dart';

import '../../cekirdek/surum.dart';
import '../../cekirdek/tema.dart';
import '../../servisler/apk_kurucu.dart';
import '../../servisler/guncelleme_servisi.dart';
import '../../servisler/indirme_motoru.dart';
import '../../servisler/kuyruk_yoneticisi.dart';
import '../../servisler/ytdlp_motoru.dart';

/// Ayarlar sekmesi.
///
/// ## Iki ayri "güncelleme" var
/// - **Motor** (yt-dlp): sik guncellenir, birkac MB, uygulamayi yeniden
///   kurmayi gerektirmez. Instagram/YouTube degistiginde cozum budur.
/// - **Uygulama** (APK): nadir, ~59 MB, GitHub Releases'ten iner, kurulum
///   ekrani acilir.
///
/// Ikisini ayni dugmede toplamak, kullaniciyi her kucuk bozulmada 100 MB'lik
/// APK indirmeye zorlardi.
///
/// ## Durumu bu ekran TUTMUYOR
/// Guncelleme sonucu kabukta (`AnaKabuk`) duruyor; burasi yalnizca gosteriyor
/// ve tetikliyor. Ayni durumu iki yerde tutmak, ekrandaki deger ile
/// yururlukteki degerin ayrismasina yol acar.
class AyarlarEkrani extends StatefulWidget {
  final IndirmeMotoru motor;
  final KuyrukYoneticisi kuyruk;
  final GuncellemeSonucu? guncelleme;

  const AyarlarEkrani({
    super.key,
    required this.motor,
    required this.kuyruk,
    required this.guncelleme,
  });

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  final ApkKurucu _kurucu = ApkKurucu();

  String? _motorSurumu;

  /// APK indirme ilerlemesi. `null` ise indirme yok.
  double? _indirmeOrani;

  /// Motor (yt-dlp) guncellemesi suruyor mu?
  bool _motorGuncelleniyor = false;

  @override
  void initState() {
    super.initState();
    _motorSurumunuOku();
  }

  Future<void> _motorSurumunuOku() async {
    final s = await widget.motor.motorSurumu();
    if (!mounted) return;
    setState(() => _motorSurumu = s);
  }

  // ------------------------------------------------------------ guncelleme

  Future<void> _indirVeKur(String adres) async {
    // 1) Izin. Yoksa sistem ayarina yonlendirip birakiyoruz — izin ekranindan
    //    donusu yakalamak yerine kullanicidan tekrar basmasini istiyoruz;
    //    bu, izin akisinin en az kirilan hali.
    if (!await _kurucu.izinVarMi()) {
      if (!mounted) return;
      final gecti = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Renkler.yuzey,
          title: const Text('İzin gerekiyor'),
          content: const Text(
            'Android, uygulamaların kendi güncellemesini kurabilmesi için '
            'ayrı bir izin istiyor. Açılacak ekrandan "Medya İndirici"ye '
            'izin ver, sonra buraya dönüp tekrar dene.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('İzin ekranını aç'),
            ),
          ],
        ),
      );
      if (gecti == true) await _kurucu.izinEkraniniAc();
      return;
    }

    // 2) Indirme
    setState(() => _indirmeOrani = 0);
    try {
      final yol = await _kurucu.indir(
        adres,
        ilerleme: (oran) {
          if (!mounted) return;
          // Yuzde 1'den kucuk degisikliklerde ekrani yenilemiyoruz.
          if (_indirmeOrani == null || (oran - _indirmeOrani!).abs() >= 0.01) {
            setState(() => _indirmeOrani = oran);
          }
        },
      );

      if (!mounted) return;
      setState(() => _indirmeOrani = null);

      // 3) Kurulum
      await _kurucu.kur(yol);
    } catch (h) {
      if (!mounted) return;
      setState(() => _indirmeOrani = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Güncelleme indirilemedi: $h'),
          backgroundColor: Renkler.hata,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _baslik('Güncelleme'),
        _motorGuncellemesi(),
        _uygulamaGuncellemesi(),
        const Divider(height: 24),
        _baslik('İndirmeler'),
        ListTile(
          leading: const Icon(Icons.delete_sweep_outlined,
              color: Renkler.metinSolgun),
          title: const Text('Geçmişi temizle'),
          subtitle: const Text(
            'Listeyi boşaltır, dosyaları silmez',
            style: TextStyle(fontSize: Olculer.kucukBilgi),
          ),
          onTap: () {
            widget.kuyruk.gecmisiTemizle();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Geçmiş temizlendi.')),
            );
          },
        ),
        const Divider(height: 24),
        _baslik('Hakkında'),
        const ListTile(
          leading: Icon(Icons.info_outline, color: Renkler.metinSolgun),
          title: Text('Medya İndirici'),
          subtitle: Text(
            'Sürüm ${Surum.simdiki}',
            style: TextStyle(fontSize: Olculer.kucukBilgi),
          ),
        ),
        // Uyari yalnizca sahte motor calisirken gorunuyor. Telefonda
        // gercek motor var; orada bu yazi yalan olurdu.
        if (widget.motor is! YtDlpMotoru)
          const Padding(
            padding: EdgeInsets.fromLTRB(
                Olculer.kenarBosluk, 8, Olculer.kenarBosluk, 24),
            child: Text(
              'Bu sürüm sahte motorla çalışıyor: bağlantılar gerçekten '
              'indirilmiyor, yalnızca akış deneniyor. Gerçek indirme '
              'telefondaki sürümde.',
              style: TextStyle(
                fontSize: Olculer.kucukBilgi,
                color: Renkler.uyari,
              ),
            ),
          )
        else
          const SizedBox(height: 24),
      ],
    );
  }

  /// Motor (yt-dlp) guncellemesi satiri.
  ///
  /// **Bozulmalarin cogunun cozumu burasi.** Instagram veya YouTube sayfa
  /// yapisini degistirdiginde indirme calismaz hale gelir; yt-dlp bunu
  /// gunler icinde duzeltir. Kullanicinin yapmasi gereken tek sey buraya
  /// basmak — uygulamayi yeniden kurmasi gerekmiyor.
  ///
  /// Sahte motorda (tarayici) bu dugme pasif: guncellenecek bir sey yok.
  Widget _motorGuncellemesi() {
    final gercekMotor = widget.motor is YtDlpMotoru;

    if (_motorGuncelleniyor) {
      return const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
        title: Text('Motor güncelleniyor…'),
        subtitle: Text(
          'Birkaç MB, sürmesi kısa',
          style: TextStyle(fontSize: Olculer.kucukBilgi),
        ),
      );
    }

    return ListTile(
      leading: Icon(
        Icons.sync,
        color: gercekMotor ? Renkler.vurgu : Renkler.metinSolgun,
      ),
      title: const Text('Motoru güncelle'),
      subtitle: Text(
        _motorSurumu == null
            ? 'Sürüm okunuyor…'
            : 'Şu anki sürüm: $_motorSurumu',
        style: const TextStyle(fontSize: Olculer.kucukBilgi),
      ),
      trailing: gercekMotor ? null : const _YakindaRozeti(),
      enabled: gercekMotor,
      onTap: gercekMotor ? _motoruGuncelle : null,
    );
  }

  Future<void> _motoruGuncelle() async {
    setState(() => _motorGuncelleniyor = true);
    try {
      await (widget.motor as YtDlpMotoru).motoruGuncelle();
      await _motorSurumunuOku();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Motor güncellendi.')),
      );
    } catch (h) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$h'), backgroundColor: Renkler.hata),
      );
    } finally {
      if (mounted) setState(() => _motorGuncelleniyor = false);
    }
  }

  /// Uygulama guncellemesi satiri.
  ///
  /// Uc ayri hali var ve ucu de farkli sey soyluyor:
  /// - **Indirme suruyor** → ilerleme cubugu
  /// - **Yeni surum var** → surum + not + indirme dugmesi
  /// - **Yok / bilinmiyor** → sessiz bilgi satiri
  ///
  /// "Bilinmiyor" durumunda hata gostermiyoruz: guncelleme kontrolu
  /// basarisiz diye calisan bir uygulamayi bozuk gostermenin anlami yok.
  Widget _uygulamaGuncellemesi() {
    final g = widget.guncelleme;

    if (_indirmeOrani != null) {
      return ListTile(
        leading: const Icon(Icons.downloading, color: Renkler.vurgu),
        title: const Text('Güncelleme indiriliyor…'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _indirmeOrani,
              minHeight: 4,
              backgroundColor: Renkler.yuzeyAcik,
            ),
          ),
        ),
        trailing: Text('%${((_indirmeOrani ?? 0) * 100).round()}'),
      );
    }

    if (g != null && g.indirilebilir) {
      final notlar = g.bilgi?.notlar;
      return ListTile(
        leading: const Icon(Icons.system_update, color: Renkler.vurgu),
        title: Text('Yeni sürüm: ${g.bilgi!.surum}'),
        subtitle: Text(
          notlar == null || notlar.isEmpty
              ? 'İndirip kurmak için dokun'
              : notlar,
          style: const TextStyle(fontSize: Olculer.kucukBilgi),
        ),
        trailing: const Icon(Icons.download, color: Renkler.vurgu),
        onTap: () => _indirVeKur(g.bilgi!.indirmeAdresi!),
      );
    }

    // Yeni surum var ama indirme adresi verilmemis: yalnizca haber ver.
    if (g != null && g.yeniVar) {
      return ListTile(
        leading: const Icon(Icons.system_update, color: Renkler.uyari),
        title: Text('Yeni sürüm var: ${g.bilgi!.surum}'),
        subtitle: const Text(
          'İndirme bağlantısı henüz yayınlanmamış',
          style: TextStyle(fontSize: Olculer.kucukBilgi),
        ),
        enabled: false,
      );
    }

    return const ListTile(
      leading: Icon(Icons.check_circle_outline, color: Renkler.metinSolgun),
      title: Text('Uygulama güncel'),
      subtitle: Text(
        'Yeni sürüm çıktığında burada görünür',
        style: TextStyle(fontSize: Olculer.kucukBilgi),
      ),
      enabled: false,
    );
  }

  Widget _baslik(String metin) => Padding(
        padding: const EdgeInsets.fromLTRB(Olculer.kenarBosluk, 8, 0, 4),
        child: Text(
          metin.toUpperCase(),
          style: const TextStyle(
            fontSize: Olculer.etiket,
            fontWeight: FontWeight.w700,
            color: Renkler.metinSolgun,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _YakindaRozeti extends StatelessWidget {
  const _YakindaRozeti();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Renkler.yuzeyAcik,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'yakında',
        style: TextStyle(
          fontSize: Olculer.etiket,
          color: Renkler.metinSolgun,
        ),
      ),
    );
  }
}
