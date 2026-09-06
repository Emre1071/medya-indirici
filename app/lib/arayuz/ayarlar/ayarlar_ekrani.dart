import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// Motorun acilis durumu. Kurulum basarisizsa sebep burada gosteriliyor.
  final MotorDurumu motorDurumu;

  /// Kurulumu bastan denemek icin; kabuk yeniden bekleyip durumu tazeliyor.
  final Future<void> Function() motoruYenidenDene;

  const AyarlarEkrani({
    super.key,
    required this.motor,
    required this.kuyruk,
    required this.guncelleme,
    required this.motorDurumu,
    required this.motoruYenidenDene,
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
        // Motor kurulamadiysa EN USTE cikiyor: kullanicinin bu ekrani
        // acmasinin sebebi buyuk ihtimalle o.
        if (widget.motorDurumu.kurulamadiMi) ...[
          _baslik('Sorun'),
          _motorKurulamadi(),
          const Divider(height: 24),
        ],
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

  /// Motor kurulamadiginda gosterilen bolum.
  ///
  /// ## Nicin teknik ayrinti da veriliyor?
  /// Kurulum hatasinin sebebi disaridan gorunmuyor ve cihaz `adb`'ye
  /// baglanamadiginda (USB hata ayiklama kapali) log da alinamiyor. Ayrinti
  /// **kopyalanabilir** olsun ki kullanici onu iletebilsin; boylece
  /// uygulama kendi tanisini kendi koyuyor.
  ///
  /// Ayrinti kendiliginden acilmiyor: normal kullaniciya yigin izi
  /// gostermek onu korkutur, isine de yaramaz.
  Widget _motorKurulamadi() {
    final durum = widget.motorDurumu;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Olculer.kenarBosluk, 0, Olculer.kenarBosluk, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, size: 18, color: Renkler.hata),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  durum.hata ?? 'İndirme motoru başlatılamadı.',
                  style: const TextStyle(
                    fontSize: Olculer.govde,
                    color: Renkler.hata,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.refresh, color: Renkler.vurgu),
          title: const Text('Motoru yeniden başlat'),
          subtitle: const Text(
            'Uygulamayı kapatmadan tekrar dener',
            style: TextStyle(fontSize: Olculer.kucukBilgi),
          ),
          onTap: _motoruYenidenBaslat,
        ),
        if (durum.ayrinti != null)
          ListTile(
            leading: const Icon(Icons.bug_report_outlined,
                color: Renkler.metinSolgun),
            title: const Text('Teknik ayrıntıyı göster'),
            subtitle: const Text(
              'Sorunu bildirirken bu metni ilet',
              style: TextStyle(fontSize: Olculer.kucukBilgi),
            ),
            onTap: () => _ayrintiyiGoster(durum.ayrinti!),
          ),
      ],
    );
  }

  Future<void> _motoruYenidenBaslat() async {
    final motor = widget.motor;
    if (motor is YtDlpMotoru) await motor.motoruYenidenKur();

    await widget.motoruYenidenDene();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.motorDurumu.hazirMi
              ? 'Motor hazır.'
              : 'Motor hâlâ başlatılamıyor.',
        ),
      ),
    );
  }

  void _ayrintiyiGoster(String ayrinti) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Renkler.yuzey,
        title: const Text('Teknik ayrıntı'),
        content: SingleChildScrollView(
          child: SelectableText(
            ayrinti,
            style: const TextStyle(
              fontSize: Olculer.etiket,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: ayrinti));
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Panoya kopyalandı.')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Kopyala'),
          ),
        ],
      ),
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
