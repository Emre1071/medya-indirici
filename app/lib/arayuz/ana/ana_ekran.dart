import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../cekirdek/tema.dart';
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

  /// Motor (gomulu yt-dlp) calismaya hazir mi? Kabuktan geliyor.
  final bool motorHazir;

  const AnaEkran({
    super.key,
    required this.kuyruk,
    required this.onizlemeyiAc,
    required this.motorHazir,
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
    if (!widget.motorHazir) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Motor hazırlanıyor… Birkaç saniye sonra tekrar dene.',
          ),
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
            if (!widget.motorHazir) const _MotorHazirlaniyor(),
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

                        // Calisan iste "durdur", bekleyen/bitmis iste
                        // "kuyruktan cikar". Ikisi de ayni cagriya gidiyor;
                        // hangisinin gerektigine kuyruk karar veriyor.
                        return IsKarti(
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
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Motor acilirken ekranin ustunde duran serit.
///
/// ## Nicin engelleyici bir ekran degil?
/// Bekleme birkac saniye ve kullanicinin bu sirada yapabilecegi isler var
/// (gecmise bakmak, ayarlari acmak). Uygulamanin onune tam ekran bir
/// bekleme koymak, ilk acilisi oldugundan uzun hissettirirdi. Serit yalniz
/// haber veriyor; asil engelleme "Çözümle"ye basildiginda oluyor.
class _MotorHazirlaniyor extends StatelessWidget {
  const _MotorHazirlaniyor();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Renkler.uyari.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(
        horizontal: Olculer.kenarBosluk,
        vertical: 10,
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Renkler.uyari),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Motor hazırlanıyor… İlk açılışta birkaç saniye sürer.',
              style: TextStyle(
                fontSize: Olculer.kucukBilgi,
                color: Renkler.uyari,
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
