/// Indirme bittiginde motorun geri verdigi bilgi.
///
/// ## Nicin duz `String` yol degil?
/// Dosya iki farkli yerde bitebiliyor ve **kullanici acisindan bu fark
/// buyuk**:
///
/// - Telefonun Muzik/Filmler klasorune cikarildiysa muzik calarda,
///   galeride, WhatsApp'ta gorunur. Istenen sonuc budur.
/// - Cikarilamadiysa (izin yok, yer yok, eski Android) dosya uygulamanin
///   kendi klasorunde kalir; indirme basarili ama **kullanici dosyayi
///   hicbir yerde bulamaz**.
///
/// Ikisini ayni `String` ile temsil etmek, ikinci durumu sessizce basarili
/// gostermek olurdu. [kayitYeri] doluysa dosya disari cikti.
class IndirmeSonucu {
  /// Dosyanin yeri.
  ///
  /// Android 10 ve ustunde disari cikarilan dosya icin bu bir `content://`
  /// adresi olur (MediaStore kaydi), duz dosya yolu degil — kapsamli
  /// depolamada (scoped storage) baska uygulamalarin dosyasina duz yolla
  /// erisilemiyor. Eski surumlerde ve cikarilamayan dosyalarda duz yol.
  final String yol;

  /// Kullaniciya gosterilecek klasor adi: `Music/Medya İndirici`.
  ///
  /// `null` ise dosya disari cikarilamadi, uygulamanin kendi klasorunde.
  final String? kayitYeri;

  const IndirmeSonucu({required this.yol, this.kayitYeri});

  bool get disaAktarildi => kayitYeri != null;
}
