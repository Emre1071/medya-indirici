import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../cekirdek/tema.dart';
import '../../servisler/indirme_motoru.dart';
import '../../servisler/kuyruk_yoneticisi.dart';
import '../ortak/is_karti.dart';

/// Ana sekme: link yapistirma kutusu + su anki indirme kuyrugu.
///
/// ## Bu ekran ikinci derecede onemli
/// Asil akis paylas menusunden geliyor ve [OnizlemeSayfasi]'na dusuyor.
/// Burasi "elimde bir link var, uygulamayi actim" durumu icin — daha seyrek
/// ama tarayicida gelistirme yaparken tek giris kapisi oldugu icin
/// Asama 1'de en cok kullanilan ekran bu olacak.
class AnaEkran extends StatefulWidget {
  final KuyrukYoneticisi kuyruk;

  /// Adres girilip "Çözümle" denince cagrilir; onizleme sayfasini acmak
  /// kabugun isi (yonlendirme tek yerden yonetiliyor).
  final void Function(String adres) onizlemeyiAc;

  /// Motorun (gomulu yt-dlp) acilis durumu. Kabuktan geliyor.
  final MotorDurumu motorDurumu;

  const AnaEkran({
    super.key,
    required this.kuyruk,
    required this.onizlemeyiAc,
    required this.motorDurumu,
  });

  @override
  State<AnaEkran> createState() => _AnaEkraniState();
}

class _AnaEkraniState extends State<AnaEkran> {
  final TextEditingController _girdi = TextEditingController();

  @override
  void dispose() {
    _girdi.dispose();
    super.dispose();
  }

  Future<void> _panodanYapistir() async {
    final pano = await Clipboard.getData(Clipboard.kTextPlain);
    final metin = pano?.text?.trim();
    if (metin == null || metin.isEmpty) return;

    _girdi.text = metin;

    // Panodaki sey zaten bir bagalantiysa dogrudan onizlemeye geciyoruz.
    // Kullanici linki kopyalamis ve uygulamayi acmis — niyeti belli,
    // bir de "Çözümle" dedirtmek gereksiz bir adim olurdu.
    if (_baglantiMi(metin)) _cozumle();
  }

  void _cozumle() {
    final adres = _girdi.text.trim();
    if (adres.isEmpty) return;

    // Motor hazir degilken cozumlemeye kalkismak, kullaniciya teknik bir
    // hata gostermek olurdu. Yazdigi adres kutuda kaliyor: birkac saniye
    // sonra tekrar basmasi yetiyor, bastan yapistirmak zorunda degil.
    //
    // Kurulum basarisiz olduysa "biraz sonra dene" demek yalan olurdu;
    // o durumda sebep gosteriliyor.
    final durum = widget.motorDurumu;
    if (!durum.hazirMi) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            durum.hata ?? 'Motor hazırlanıyor… Birkaç saniye sonra tekrar dene.',
          ),
          backgroundColor: durum.kurulamadiMi ? Renkler.hata : null,
        ),
      );
      return;
    }

    if (!_baglantiMi(adres)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu bir bağlantı değil. Linki yapıştır.')),
      );
      return;
    }

    widget.onizlemeyiAc(adres);
    _girdi.clear();
    FocusScope.of(context).unfocus();
  }

  /// Basarisiz indirmenin teknik ayrintisini gosterir ve kopyalatir.
  ///
  /// Cihaz `adb`'ye baglanamadiginda (USB hata ayiklama kapali) yt-dlp'nin
  /// ciktisina ulasmanin baska yolu yok. Ayni kalip motor kurulum hatasinda
  /// da kullaniliyor ve orada sorunu tek seferde cozdurmustu.
  void _ayrintiyiGoster(String ayrinti) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Renkler.yuzey,
        title: const Text('İndirme neden olmadı'),
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

  /// Kaba bir kontrol — amac yanlis yapistirmayi yakalamak, adresi
  /// dogrulamak degil. Gercek dogrulamayi motor yapiyor; burada fazla
  /// katı davranmak, destekledigimiz ama kalibina uymayan adresleri
  /// bosuna reddetmek olurdu.
  bool _baglantiMi(String metin) =>
      metin.startsWith('http://') || metin.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.kuyruk,
      builder: (context, _) {
        final kuyruk = widget.kuyruk.kuyruk;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.motorDurumu.hazirMi)
              _MotorSeridi(durum: widget.motorDurumu),
            Padding(
              padding: const EdgeInsets.all(Olculer.kenarBosluk),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _girdi,
                    onSubmitted: (_) => _cozumle(),
                    textInputAction: TextInputAction.go,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: 'Video bağlantısını yapıştır',
                      prefixIcon: const Icon(Icons.link, size: 20),
                      suffixIcon: IconButton(
                        tooltip: 'Panodan yapıştır',
                        icon: const Icon(Icons.content_paste, size: 20),
                        onPressed: _panodanYapistir,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _cozumle,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Çözümle'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: kuyruk.isEmpty
                  ? const _BosKuyruk()
                  : ListView.separated(
                      padding: const EdgeInsets.all(Olculer.kenarBosluk),
                      itemCount: kuyruk.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Olculer.bosluk),
                      itemBuilder: (context, i) {
                        final is_ = kuyruk[i];

                        // Hatali iste karta dokunmak teknik ayrintiyi
                        // aciyor. Kendiliginden gosterilmiyor (kullaniciya
                        // bir sey soylemez) ama cihazdan log alinamadiginda
                        // "indirme neden olmadi" sorusunun tek cevabi o.
                        final ayrinti = is_.hataAyrinti;

                        // Calisan iste "durdur", bekleyen/bitmis iste
                        // "kuyruktan cikar". Ikisi de ayni cagriya gidiyor;
                        // hangisinin gerektigine kuyruk karar veriyor.
                        final kart = IsKarti(
                          is_: is_,
                          eylem: is_.calisyor
                              ? IconButton(
                                  tooltip: 'İndirmeyi durdur',
                                  icon: const Icon(Icons.stop_circle_outlined,
                                      size: 20),
                                  color: Renkler.uyari,
                                  onPressed: () =>
                                      widget.kuyruk.sil(is_.kimlik),
                                )
                              : IconButton(
                                  tooltip: 'Kuyruktan çıkar',
                                  icon: const Icon(Icons.close, size: 18),
                                  color: Renkler.metinSolgun,
                                  onPressed: () =>
                                      widget.kuyruk.sil(is_.kimlik),
                                ),
                        );

                        if (ayrinti == null) return kart;
                        return InkWell(
                          borderRadius:
                              BorderRadius.circular(Olculer.kose),
                          onTap: () => _ayrintiyiGoster(ayrinti),
                          child: kart,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Motor hazir degilken ekranin ustunde duran serit.
///
/// ## Iki ayri hali var, ikisi farkli sey soyluyor
/// - **Hazirlaniyor** — sari, donen cark. Beklemek dogru.
/// - **Kurulamadi** — kirmizi, cark yok. Beklemenin anlami yok; sebep
///   yaziyor ve kullanici ne yapabilecegini goruyor.
///
/// Ikisini ayirmak sart: motor hic acilmayacakken sonsuza kadar donen bir
/// cark gostermek, uygulamanin takildigi izlenimini verir ve kullanici
/// yapabilecegi seyi (dogru APK'yi kurmak, yer acmak) hic ogrenemez.
///
/// ## Nicin engelleyici bir ekran degil?
/// Bekleme birkac saniye ve kullanicinin bu sirada yapabilecegi isler var
/// (gecmise bakmak, ayarlari acmak). Uygulamanin onune tam ekran bir
/// bekleme koymak, ilk acilisi oldugundan uzun hissettirirdi. Serit yalniz
/// haber veriyor; asil engelleme "Çözümle"ye basildiginda oluyor.
class _MotorSeridi extends StatelessWidget {
  final MotorDurumu durum;

  const _MotorSeridi({required this.durum});

  @override
  Widget build(BuildContext context) {
    final bozuk = durum.kurulamadiMi;
    final renk = bozuk ? Renkler.hata : Renkler.uyari;

    return Container(
      width: double.infinity,
      color: renk.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(
        horizontal: Olculer.kenarBosluk,
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bozuk)
            Icon(Icons.error_outline, size: 16, color: renk)
          else
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(renk),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bozuk
                  ? '${durum.hata}\n\nAyrıntı ve yeniden deneme: Ayarlar.'
                  : 'Motor hazırlanıyor… İlk açılışta birkaç saniye sürer.',
              style: TextStyle(
                fontSize: Olculer.kucukBilgi,
                color: renk,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kuyruk bosken gorunen aciklama.
///
/// Bos ekrana "Henüz bir şey yok" yazmak bilgi vermiyor. Asil kullanim
/// bicimi (paylas menusu) burada anlatiliyor — kullanicinin uygulamayi
/// nasil kullanacagini ogrenecegi tek yer burasi.
class _BosKuyruk extends StatelessWidget {
  const _BosKuyruk();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.download_outlined,
                size: 46, color: Renkler.metinSolgun),
            const SizedBox(height: 16),
            const Text(
              'Kuyruk boş',
              style: TextStyle(
                fontSize: Olculer.baslik,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            _adim(1, 'Instagram veya YouTube\'da videoyu aç'),
            _adim(2, 'Paylaş düğmesine bas'),
            _adim(3, 'Listeden "Medya İndirici"yi seç'),
            const SizedBox(height: 14),
            const Text(
              'Ya da bağlantıyı yukarıya yapıştır.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Olculer.kucukBilgi,
                color: Renkler.metinSolgun,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adim(int no, String metin) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Renkler.yuzeyAcik,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$no',
              style: const TextStyle(
                fontSize: Olculer.etiket,
                fontWeight: FontWeight.w600,
                color: Renkler.vurgu,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              metin,
              style: const TextStyle(
                fontSize: Olculer.govde,
                color: Renkler.metinSolgun,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
