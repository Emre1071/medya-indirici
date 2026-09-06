# HAFIZA.md — Medya İndirici proje hafızası

> Oturum başlangıcında **önce bu dosya** okunur; kod taramasıyla yeniden
> keşfedilmesi gereken şeyleri burada tutar (token tasarrufu).
>
> **Yetki sırası:** `PLAN.md` (ürün kararları) → `notlar/KARARLAR.md` (kilitli
> kararlar) → `notlar/ELENENLER.md` (kapanmış tartışmalar) → bu dosya.
> Çelişki varsa yetkili dosya kazanır; burası yalnız **özet ve yön** verir.
> Son güncelleme: 2026-09-05 (**telefonda ilk deneme: çöküyordu** — motor
> hatası uygulamayı öldürüyordu, §4.4; öncesinde Aşama 4 paylaş menüsü
> §4.3, v0.1.0 ve imza anahtarı §11-§12, dağıtım GitHub Releases'e taşındı
> §5, iptal ve MediaStore, derleme engeli §10).

---

## 1. Proje kimliği

- **Medya İndirici** — Instagram / YouTube bağlantısından ses veya video
  indiren **Android** uygulaması.
- Masaüstündeki `Müzik/MP3 Donusturucu/mp3_donusturucu.py` (Python/Tkinter)
  uygulamasının telefon versiyonu. Davranış sorusu çıkarsa **kaynak orası**.
- Arayüz dili **TR**, tek dil. Çeviri altyapısı yok, planlanmıyor.
- Ürün sahibi: Yahya (gidek ve DevLingo ile aynı kişi/makine).
- Çekirdek akış: `Instagram'da Reels → Paylaş → önizleme → Ses/Video → indi`.
  **Üç dokunuş.** Uygulamayı elle açmak ikincil senaryo.
- Ayrışma noktası: **her şey telefonda.** Sunucu yok, PC yok, aracı yok.
  İnternete çıkılan tek yer kaynak sitenin kendi sunucusu (+ sürüm kontrolü
  için GitHub Releases; indirilen dosyalar oraya uğramıyor).

---

## 2. Klasör haritası

| Yol | İçerik |
|---|---|
| `PLAN.md` | Ürün planı, yol haritası, bilinen bedeller, §9 kendini güncelleme |
| `notlar/KARARLAR.md` | Aşama 0'da **kilitlenen** kararlar + gerekçeleri |
| `notlar/ELENENLER.md` | Değerlendirilip vazgeçilen 5 yol — aynı tartışmayı tekrar açma |
| `app/` | Flutter projesi (Android + ekran önizlemesi için web) |
| `app/lib/` | Dart kodu (§3) |
| `app/android/.../kotlin/` | `MainActivity.kt` · `MotorKopru.kt` (motor) · `MedyaKaydedici.kt` (MediaStore) · `PaylasimKoprusu.kt` (paylaş menüsü) |
| `app/test/` | `surum_test.dart` · `kuyruk_test.dart` (iptal) · `surum_kaynagi_test.dart` (GitHub) · `baglanti_test.dart` (link ayıklama) |

✅ **Bu klasör artık bir git deposu** (`main` dalı, 2026-09-05).
Uzak depo: **`Emre1071/medya-indirici`** — **public**.
🔒 Commit ve push **yalnız açık komutla**; kendiliğinden commit atılmaz.
🔒 `Planlama_MP3.txt` **açılmaz ve repoya girmez** — Yahya'nın yerel çalışma
defteri, `.gitignore`'da. (gidek'teki `PLANLAMA.txt` ile aynı kural.)
🔒 **APK repoya girmez** — dağıtım Releases üzerinden; 59 MB'lik dosyalar
git geçmişini geri alınamaz biçimde şişirir.

🔴 **APK bu klasörden derlenemiyor** — yol Türkçe karakter içeriyor. Ayrıntı
ve çözüm: §10.

---

## 3. Flutter mimarisi (`app/lib/`)

```
lib/
├── main.dart                  → MaterialApp + MOTOR SEÇİMİ (tek nokta)
├── cekirdek/
│   ├── tema.dart              Renkler + Olculer tokenları, koyuTema()
│   ├── surum.dart             Surum.simdiki (ELLE) + sayısal karşılaştırma
│   ├── github_ayarlari.dart   sahip/depo + releases/latest adresi
│   └── baglanti.dart          paylaşılan ham metinden linki ayıklar
├── alan/varliklar/            saf veri: medya_bilgisi, indirme_isi,
│                              indirme_sonucu, surum_bilgisi
├── servisler/
│   ├── indirme_motoru.dart    ARAYÜZ (abstract) + MotorHatasi
│   ├── sahte_motor.dart       Aşama 1 — tarayıcıda taklit
│   ├── ytdlp_motoru.dart      gerçek motor — MethodChannel/EventChannel
│   ├── kuyruk_yoneticisi.dart ChangeNotifier, sırayla işletir
│   ├── guncelleme_servisi.dart "yeni sürüm var mı?" — asla hata fırlatmaz
│   ├── motor_hazirlik.dart    motor açılana kadar bekleme (ortak)
│   ├── paylasim_dinleyici.dart paylaş menüsünden gelen metin
│   └── apk_kurucu.dart        APK indir → Android kurulum ekranı
├── veri/uzak/surum_kaynagi.dart  http ile GitHub releases/latest
└── arayuz/
    ├── kabuk/ana_kabuk.dart      3 sekme + PAYLAŞILAN KUYRUK + yönlendirme
    ├── ana/ana_ekran.dart        link kutusu + kuyruk
    ├── onizleme/onizleme_sayfasi.dart  ★ en kritik ekran
    ├── indirilenler/indirilenler_ekrani.dart
    ├── ayarlar/ayarlar_ekrani.dart     iki ayrı güncelleme düğmesi
    └── ortak/                   is_karti, kapak_gorseli, kaynak_rozeti
```

### Motor soyutlaması — mimarinin belkemiği

`IndirmeMotoru` **abstract** sınıfı beş şey vaat ediyor: `hazirMi`, `cozumle`,
`indir`, `iptal`, `motorSurumu`. İki gerçekleştirmesi var:

| | `SahteMotor` | `YtDlpMotoru` |
|---|---|---|
| Nerede | Web + masaüstü (geliştirme) | Yalnız Android |
| Ne yapar | Gecikme, kademeli ilerleme, **hata** ve **iptal** taklidi | Gömülü yt-dlp'yi çağırır |
| Test hilesi | Adreste `hata` geçerse bilerek patlar | — |
| Hazırlık | İlk 2,5 sn `hazirMi() == false` — bekleme şeridi tarayıcıda da denenebilsin | Gerçek kurulum süresi |

**Seçim tek satırda:** `main.dart` → `_motorSec()`.
`dart:io`'daki `Platform` **kullanılmıyor** — web derlemesinde çalışma anında
patlıyor. Yerine `kIsWeb` + `defaultTargetPlatform`. Bu kalıbı bozma.

**Hiçbir ekran hangi motorun çalıştığını bilmiyor.** Yeni bir kaynak/motor
eklenecekse arayüzü doldur, `_motorSec()`'e ekle; arayüz kodu değişmez.

### Durum yönetimi — kütüphane yok, bilinçli karar

- `KuyrukYoneticisi extends ChangeNotifier`. Riverpod/Bloc/Provider **yok**.
- ⚠️ Bu, `PLAN.md` §5'teki "riverpod" satırından **bilinçli sapma** —
  DevLingo çizgisi korundu: tek paylaşılan durum için paket taşımaya değmez.
  Planı okuyup "riverpod ekleyeyim" deme; kararı Yahya değiştirmedikçe geçerli.
- Kuyruk **`AnaKabuk`'ta** duruyor, sekmelerin içinde değil: sekme değişince
  indirme sıfırlanmasın diye.

### Kuyruk davranışı (`kuyruk_yoneticisi.dart`)

- **Aynı anda tek iş.** Paralel indirme ağı ve işlemciyi bölüyor; sırayla
  toplamda daha hızlı bitiyor ve ilerleme çubuğu anlam taşıyor.
- İş kimliği **sayaçtan** üretiliyor (`is_0`, `is_1`), `DateTime.now()`'dan
  değil: kimlik aynı zamanda bildirim kimliği olacak, çakışma iki indirmenin
  tek bildirimi ezmesi demek.
- **İlerleme kısılıyor:** oran %1'den az değiştiyse `notifyListeners()` yok.
  Ama **durum değişimi her zaman geçiyor** (`iniyor → donusturuluyor`
  kaçırılırsa ekran yalan söyler).
- Biten iş kuyruktan çıkıp `_gecmis`'e geçiyor.

### İptal — tek kapı, üç koruma

`sil(kimlik)` hem "kuyruktan çıkar" hem "çalışanı durdur" demek. Çağıran
taraf işin o an çalışıp çalışmadığını bilmek zorunda değil:

- **Bekleyen iş** listeden silinir, motora hiç gidilmez.
- **Çalışan iş** için `motor.iptal(kimlik)` çağrılır; iş listede `iptal`
  durumuyla **kalır** (silinip yok olsaydı kullanıcı durdurmanın işe yarayıp
  yaramadığını göremezdi), ikinci dokunuşla çıkar.

🔑 **`isKimlik` artık kuyruktan geliyor.** Eskiden `YtDlpMotoru` kendi iç
sayacını kullanıyordu; dışarıdan "şu işi durdur" demek bu yüzden mümkün
değildi. `indir()` imzası kimliği zorunlu alıyor.

Üç ayrı koruma var, üçü de gerçek bir yarışı kapatıyor:

1. **Çözümleme sırasında iptal** — `_isle`, `cozumle` bittikten sonra
   indirmeye başlamadan önce iptal kaydına bakıyor. Bakmasaydı kullanıcı
   "Bağlantı çözümleniyor…" derken durdurduğunda dosya yine inerdi.
2. **Sonuçlanmış iş dirilmiyor** — `_ilerlemeBildir`, durumu
   `iptal`/`bitti`/`hata` olan işin bildirimini atıyor. Motor sürecinin
   ölmesi bir saniye sürebiliyor ve yolda kalmış bir "iniyor" bildirimi
   kartı geri çalıştırıyor gösterirdi. *(Bu, testin yakaladığı gerçek bir
   hataydı — kod ilk halinde bu bildirimi geçiriyordu.)*
3. **İptal hata sayılmıyor** — motor iptalde de istisna fırlatıyor.
   Ayrım hata metnine bakarak değil, `_iptalIstenenler` kaydından
   yapılıyor: metin yt-dlp sürümüne göre değişir, kayıt değişmez.

### Bilinen tuzaklar (kodu okurken şaşırma)

- `IndirmeIsi.kopyala` her alanda `?? this.x` kullanıyor → bir alanı
  **`null`'a geri çekmek mümkün değil** (ör. `oran`'ı belirsize döndürmek).
  Gerekirse `kopyala` imzası değişmeli.
- `IndirmeIsi.calisyor` getter adı böyle yazılmış (`calisiyor` değil).
  Bilerek dokunulmadı; yeniden adlandırma çağrı yerlerini kırar.
- `MedyaKalitesi.boyutMetni` ve `MedyaBilgisi.sureMetni` bilinmeyeni **boş
  metin** döndürüyor — `0 MB` yazmak yanlış bilgidir; bu kural her yerde.

---

## 4. Android katmanı — uygulamanın kalbi

### Kanallar

| Kanal | Tür | Ne taşır |
|---|---|---|
| `medyaindirici/motor` | MethodChannel | `hazirMi`, `motorSurumu`, `cozumle`, `indir`, `motoruGuncelle`, `iptal` |
| `medyaindirici/motor/ilerleme` | EventChannel | `{isKimlik, oran, kalanSaniye, satir}` |
| `medyaindirici/kurulum` | MethodChannel | `kurulumIzniVarMi`, `izinEkraniniAc`, `apkKur` |
| `medyaindirici/paylasim` | MethodChannel | `ilkPaylasim` — açılışta bekleyen paylaşım metni |
| `medyaindirici/paylasim/akis` | EventChannel | uygulama açıkken gelen paylaşımlar |

İlerleme akışı **tek ve paylaşılan** (`YtDlpMotoru._paylasilanAkis`); işler
`isKimlik` ile ayrışıyor. `indir` artık düz yol değil
`{yol, kayitYeri}` haritası döndürüyor (§4.1).

### 4.1 Dosyanın telefonda görünmesi — `MedyaKaydedici.kt`

yt-dlp dosyayı uygulamanın **kendi** klasörüne indiriyor; orası diğer
uygulamalara kapalı. Dosya iner, "İndirildi" yazar, ama müzik çalarda ve
galeride **görünmez** — kullanıcı açısından indirme hiç olmamış gibidir.
`MedyaKaydedici` indirme bittikten sonra dosyayı ortak klasöre çıkarıyor.

- **Çıkarma indirme BİTTİKTEN sonra.** Sırasında yapılsaydı yarım dosya
  müzik çalarda görünürdü. İptal edilen dosya da hiç çıkmıyor, siliniyor.
- **API 29+:** MediaStore kaydı açılır (`RELATIVE_PATH` = `Music/Medya
  İndirici` ya da `Movies/Medya İndirici`), dosya o kaydın akışına yazılır.
  Kopyalama boyunca `IS_PENDING = 1` — yarım dosya oynatıcılara görünmüyor.
  **İzin gerekmiyor:** uygulama kendi eklediği medyayı izinsiz yazabiliyor.
  Android 13'ün `READ_MEDIA_*` izinleri *başkalarının* medyasını okumak
  için, bizim işimiz yazmak.
- **API 24–28:** ortak klasöre düz dosya + `MediaScannerConnection`.
  Burada `WRITE_EXTERNAL_STORAGE` **gerekiyor**; `MainActivity` açılışta
  istiyor, manifestte `maxSdkVersion="28"` ile sınırlı (yeni telefonlarda
  gereksiz izin sorusu çıkmasın diye).
- **Ad çakışması ele alınıyor** — aynı Reels'i iki kez indirmek sıradan.
  Android sürümleri farklı davrandığı için `(1)`, `(2)`… eki kendimiz
  ekliyoruz.
- 🔑 **Başarısızlık sessiz değil.** Çıkarılamayan dosya **silinmiyor**,
  uygulamanın klasöründe kalıyor ve `kayitYeri` `null` dönüyor. `IsKarti`
  bunu uyarı rengiyle ayrı gösteriyor. "İndirildi" deyip kullanıcıyı boş
  yere aratmak en kötü sonuç olurdu.
- ⚠️ API 29+'ta dönen `yol` bir **`content://` adresi**, düz dosya yolu
  değil — kapsamlı depolamada düz yol yok. "Aç/Paylaş" bağlanırken buna
  göre `Intent` kurulacak.

### 4.2 Motor hazırlık durumu

Bekleme mantığı **`servisler/motor_hazirlik.dart`**'ta (750 ms aralık, üst
sınır ~30 sn). İki yerden çağrılıyor: `AnaKabuk`'un uyarı şeridi ve
paylaş menüsünden açılan `OnizlemeSayfasi`.

- **Yoklama, çünkü** Android tarafı "hazır oldum" diye haber vermiyor; tek
  bir bayrak için ayrı EventChannel açmaya değmez.
- **Üst sınır var, çünkü** kurulum başarısız da olabiliyor (yer yok, ikili
  açılamadı). Sınır dolunca vazgeçilip **yine de devam ediliyor** — motorun
  kendi Türkçe hata mesajı, sonsuza kadar "hazırlanıyor" yazan bir
  ekrandan çok daha bilgilendirici.
- `devamEdilsinMi` geri çağrısı `mounted` ile besleniyor: kapanmış bir
  ekran için 30 saniye yoklamaya devam etmek boşuna.
- Hazır değilken `AnaEkran`'da uyarı şeridi var ve "Çözümle" engelleniyor
  (yazılan adres kutuda kalıyor). **Engelleyici tam ekran yok:** bekleme
  birkaç saniye, kullanıcı bu sırada geçmişe/ayarlara bakabilmeli.

### 4.3 Paylaş menüsü entegrasyonu (Aşama 4)

Instagram/YouTube → **Paylaş** → *Medya İndirici* → doğrudan önizleme.
Planın hedeflediği **üç dokunuş** akışı artık kapalı.

**Paket eklenmedi.** `receive_sharing_intent` aynı işi yapıyor ama iOS'u,
dosya/görsel paylaşımını ve kendi yaşam döngüsünü de getiriyor; bize gereken
tek şey `text/plain`. `PaylasimKoprusu.kt` 60 satır ve zaten var olan
MethodChannel kalıbına oturuyor — projenin bağımlılık çizgisi bu.

⚠️ **v0.1.0'da bu özellik YOK.** Release, Aşama 4'ten önce alınmıştı;
telefonda paylaş menüsünde görünmemesinin sebebi manifest hatası değil,
kurulu APK'nın eski olmasıydı. Paylaş menüsünü denemek için **yeni bir APK
kurmak şart.**

**Manifest:** `ACTION_SEND` + `category.DEFAULT` + `text/plain`.
`*/*` **bilerek yazılmadı** — fotoğraf, PDF, kişi kartı paylaşımında da
listede çıkmak, indiremeyeceği şeyler için menüyü kirletmek olurdu.

🔴 **`launchMode="singleTop"` bu akışın şartı.** Olmasaydı her paylaşımda
uygulamanın ikinci bir kopyası açılır ve `onNewIntent` hiç tetiklenmezdi.
Manifest'te zaten vardı; silinmemeli.

**İki yol var, ikisi de gerekli:**

| Uygulama | Ne oluyor | Nereden geliyor |
|---|---|---|
| **Kapalı** (soğuk açılış) | Niyet Flutter başlamadan geliyor, Kotlin tarafında bekletiliyor | `ilkPaylasim` — bir kez teslim edilir |
| **Açık** (sıcak açılış) | `onNewIntent` tetikleniyor | olay akışı |

Metin okunduğu anda temizleniyor; temizlenmezse aynı gönderi ikinci kez
önizlemeye düşerdi. Dinleyici henüz bağlanmamışken paylaşım gelirse
bekletiliyor (`onListen`'de teslim ediliyor) — yoksa araya denk gelen
paylaşım kaybolurdu.

**Android dışında sessizce boş:** `PaylasimDinleyici.destekleniyor`
(`kIsWeb` + `defaultTargetPlatform`, motor seçimiyle aynı kalıp). Tarayıcıda
kanal çağrısı `MissingPluginException` atardı; hiç çağrılmıyor.

#### Link ayıklama (`cekirdek/baglanti.dart`)

🔑 **Gelen şey temiz bir link değil.** Instagram şöyle paylaşıyor:

```
Şerif Ruç on Instagram: "Hayırlı akşamlar 🎻🎸"
https://www.instagram.com/reel/DAbC123/?igsh=MXY5aA==
```

Bu metni olduğu gibi motora vermek "Unsupported URL" ile biter ve kullanıcı
uygulamanın Instagram'ı desteklemediğini sanır — hatanın kaynağı görünmez.

- **Tanıdık alan adına öncelik.** Açıklamalarda sık sık profil/bağış linki
  geçiyor ve metinde *önce* geliyor; ilk bulunanı almak yanlış gönderiyi
  indirmek olurdu.
- **Tanımadığımız site yine de deneniyor** — yt-dlp bizim listemizden çok
  daha fazla siteyi tanıyor, asıl kararı o veriyor.
- **Sondaki noktalama kırpılıyor** (`(bkz. https://…)` → kapanış parantezi).
  Ama `=` kırpılmıyor: Instagram'ın `?igsh=…==` parametresi eşittirle
  bitiyor, kırpmak adresi bozar.
- **Alan denetimi nokta sınırına bakıyor**, düz `contains` değil —
  `instagram.com.sahte.net` Instagram sayılmamalı.
- Link yoksa kullanıcıya "Paylaşılan metinde bir bağlantı bulunamadı"
  deniyor. Sessiz kalmak "uygulama açıldı ve hiçbir şey olmadı" demek olurdu.

`test/baglanti_test.dart` bu kuralların hepsini gerçek paylaşım
metinleriyle tutuyor.

#### Yönlendirme

`AnaKabuk._paylasimdanAc` linki ayıklayıp önizlemeyi açıyor. Önce
`popUntil(isFirst)` çağrılıyor: üst üste paylaşım yapılırsa önizleme
sayfaları birikmesin, geri tuşu eski gönderiler arasında gezdirmesin.

İlk paylaşım `addPostFrameCallback` içinde işleniyor — `Navigator` ancak
ağaç kurulduktan sonra kullanılabiliyor.

#### Önizlemede motor beklemesi

Paylaşımla açıldığında uygulama **yeni başlamış** oluyor ve motor hâlâ
açılıyor olabiliyor. Beklemeden çözümlemeye kalkışılsa asıl akışın ilk
adımında kırmızı bir hata ekranı çıkardı; oysa yapılması gereken tek şey
birkaç saniye beklemek.

`OnizlemeSayfasi._baslat()` önce `hazirMi()`'ye bakıyor. Hazırsa **hiçbir
bekleme görünmüyor**, doğrudan iskelete geçiyor. Değilse "Motor
hazırlanıyor…" durumu çıkıyor ve hazır olur olmaz çözümleme kendiliğinden
başlıyor. "Tekrar dene" düğmesi de `_baslat`'a bağlı — hazırlık durumunu
yeniden kontrol etsin diye.

### 4.4 🔴 Motor hatası uygulamayı ÖLDÜRMEZ

Telefonda ilk denemede uygulama açılır açılmaz çöküyordu ("Sürekli
durduruluyor"). Bulunan kesin açık:

```kotlin
} catch (h: Exception) {   // ← YANLIŞ
```

Gömülü ikili açılamadığında JVM **`UnsatisfiedLinkError`** fırlatıyor ve o
bir `Error`, `Exception` **değil** — `catch (Exception)` onu kaçırıyor.
Havuz iş parçacığında yakalanmayan bir `Throwable` ise Android'in varsayılan
işleyicisine gidip **sürecin tamamını öldürüyor.** Yani motor açılamazsa
uygulama açılır açılmaz kapanıyor.

**Kural: motorun çökmesi uygulamayı çökertmez.** `MotorKopru` ve
`MedyaKaydedici` içindeki her yakalama artık `Throwable`; `MainActivity`'nin
açılış adımları da tek tek sarmalanmış. En kötü ihtimalle kullanıcı "motor
çalışmıyor" mesajı görür, kapanan bir uygulama değil.

⚠️ Bu dosyalarda `catch (Exception)` yazma — hepsi gömülü ikiliye giden
çağrılar.

**`@Volatile` eklendi:** `hazir` ve `kurulumHatasi` havuz iş parçacığında
yazılıp ana iş parçacığında okunuyordu. İşaretlenmezse ana iş parçacığı
eski değeri önbellekten okuyabiliyor ve motor hazır olduğu halde arayüz
sonsuza kadar "hazırlanıyor" gösterebiliyor.

#### Hata artık ekranda

`hazirMi() → bool` yerine `durum() → MotorDurumu` geldi. Düz `bool` iki hâli
ayırt edemiyordu:

| Hâl | Arayüz |
|---|---|
| `hazirlaniyor` | sarı şerit + dönen çark, beklemek doğru |
| `hazir` | — |
| `kurulamadi` | **kırmızı şerit + sebep**, beklemenin anlamı yok |

`MotorHazirlik.bekle` kurulum başarısız olur olmaz vazgeçiyor — eskiden motor
hiç açılmayacak olsa bile 30 saniye yoklanıyor, kullanıcı da uygulamanın
takıldığını sanıyordu.

`YtDlpMotoru._kurulumHatasiCevir` ham hatayı yapılabilir bir şeye çeviriyor.
En olası sebep **yanlış mimari**: telefonun işlemcisine uymayan APK
kurulmuşsa gömülü ikili açılamıyor, o yüzden mesaj "arm64 sürümünü kur"
diyor.

`SahteMotor.kurulumuBozukTaklitEt = true` ile bu ekran tarayıcıda denenebilir.

### 4.5 Motor kurulumu başarısız — tanı uygulamanın içinde

Çökme düzeldikten sonra telefonda sıradaki engel çıktı: uygulama açılıyor,
paylaş menüsü ve link ayıklama **çalışıyor**, ama `YoutubeDL.init()`
başarısız oluyor.

🔴 **Cihaz `adb`'ye bağlanamıyor** (Redmi Note 9 Pro, USB hata ayıklama
kapalı — Windows onu yalnızca MTP aygıtı olarak görüyor). Yani logcat yok.
Bu yüzden **tanı uygulamanın içine kondu**: kurulum başarısız olduğunda
`MotorKopru.ortamRaporu()` şunları topluyor —

- cihaz modeli, Android sürümü, **`Build.SUPPORTED_ABIS`**
- `nativeLibraryDir` listesi — 🔑 gömülü ikililer kurulumda diske
  **açılmış mı?** Açılmamışsa `init()` zaten çalışamaz.
- boş alan (açma işlemi ~150 MB istiyor)
- istisnanın **tüm sebep zinciri** — `YoutubeDLException` asıl sebebi
  (IOException, ZipException) sarmalıyor ve dıştaki mesaj çoğu zaman boş

Rapor Ayarlar → "Sorun" bölümünde, **kopyalanabilir** halde duruyor.
Kullanıcıya kendiliğinden gösterilmiyor (yığın izi kimseye bir şey
söylemez), ama bildirirken iletilebiliyor.

Ayrıca **"Motoru yeniden başlat"** eklendi: kurulum geçici bir sebeple
(yer yoktu, sonra açıldı) başarısız olduysa uygulamayı kapatıp açmaya
gerek kalmıyor. `MotorKopru.kur()` artık yeniden çağrılabilir
(`kurulumSuruyor` ile çift çalışma engelli).

#### Paketleme tarafı elendi

Yayınlanan APK incelendi, üçü de doğru: `extractNativeLibs=true`,
kütüphaneler DEFLATE ile sıkıştırılmış (yani kurulumda diske açılıyor),
`lib/arm64-v8a/` altında `libpython.zip.so` · `libffmpeg.zip.so` ·
`libqjs.so` eksiksiz. Cihaz da arm64. **Sorun paketlemede değil,
çalışma anında.**

### `MotorKopru.kt` — neden böyle yazıldı

- `getInfo`/`execute` **bloklayan** çağrılar → 2 iş parçacıklı havuz.
  Sonuçlar `Handler(Looper.getMainLooper())` ile ana parçacığa dönüyor
  (`Result` ve `EventSink` yalnız oradan çağrılabilir).
- **`hazir` bayrağı:** motor kurulumu ilk açılışta birkaç saniye sürüyor ve
  başarısız olabiliyor. Hazır değilken çağrı `MOTOR_HAZIR_DEGIL` hatası
  döndürüyor — sessizce çalışmamış gibi yapmıyor. Kurulum
  `MainActivity.configureFlutterEngine` içinde **hemen** başlatılıyor.
- 🔑 **İndirilen dosya "önce/sonra farkı" ile bulunuyor.** yt-dlp üretilen
  dosyanın yolunu döndürmüyor; başlıktan tahmin güvenilmez. İndirmeden önce
  klasör listeleniyor, sonra yeni ne oluştuysa o dönüyor. Bu liste `try`
  bloğunun **dışında** duruyor: iptal temizliği `catch` içinde ona bakıyor.
- **İptal `iptalEdilenler` kümesiyle ayırt ediliyor.** Süreç öldürülünce
  `execute` istisna fırlatıyor ve bu istisna "kullanıcı durdurdu" ile
  "indirme bozuldu" arasında ayrım yapmıyor. İptal edilen işte yarım
  dosyalar (`.part`, birleştirme parçaları) siliniyor — bırakılsaydı bir
  sonraki indirmenin "yeni oluşan dosya" araması onları bulurdu.
- Format listesi ses/video diye ayrılıyor, **en iyisi başa** sıralanıyor —
  arayüz listenin ilkini "önerilen" sayıyor.
- `kaynakBul()` yt-dlp çıkarıcı adını `instagram/youtube/facebook/tiktok/diger`
  kısa adlarına çeviriyor; arayüzdeki rozet buna bakıyor.

### Hata çevirisi — kural

Ham yt-dlp metni **asla kullanıcıya gösterilmiyor.**
`YtDlpMotoru._hataCevir()` onu "ne yapabilirsin" anlatan Türkçe cümleye
çeviriyor; ham metin `MotorHatasi.ayrinti` içinde kalıyor.
Yeni hata kalıbı görülürse eklenecek yer orası.

### `mp3Zorla` — varsayılan **kapalı**

Kaynaklar zaten çalışan bir ses dosyası (m4a/opus) veriyor. mp3'e çevirmek
ffmpeg çalıştırmak, yani dakikalarca bekleme demek. Yalnız araba teybi /
eski cihaz için. `YtDlpMotoru({this.mp3Zorla = false})`.

### Gradle ve manifest — dokunulmaması gereken satırlar

- 🔴 `packaging { jniLibs { useLegacyPackaging = true } }` — gömülü Python ve
  ffmpeg ikilileri APK içinden **doğrudan çalıştırılıyor**; sıkıştırılmış
  halde çalıştırılamazlar. Silinirse motor hiç açılmaz.
- 🔴 `AndroidManifest.xml`'deki `INTERNET` izni **elle yazılmış olmalı.**
  Flutter bu izni yalnız debug/profile manifestine koyuyor; release APK'da
  yoksa uygulama **hata bile vermeden** internete çıkamaz. (DevLingo'da yaşandı.)
- `minSdk = maxOf(flutter.minSdkVersion, 24)` — gömülü Python 3.8 API 24
  altında çalışmıyor.
- 🔴 **Mimari seçimi gradle'da DEĞİL, komutta.** `ndk.abiFilters` ve
  `splits.abi` alanlarını Flutter'ın Gradle eklentisi kendisi dolduruyor;
  ikisi de elle yazıldığı için AGP "Conflicting configuration" deyip
  derlemeyi durduruyordu — **uygulamanın uzun süre hiç derlenememesinin
  sebebi buydu.** İkisi de kaldırıldı, seçim `--target-platform`'a taşındı
  (§9). x86/x86_64 hâlâ dışarıda (yalnız emülatör için, her biri ~25 MB
  Python+ffmpeg ekliyor); emülatör gerekirse komuta `android-x64` eklenir.
  Release'e yüklenecek dosya: `app-arm64-v8a-release.apk`.
- ✅ **Doğrulanmış APK boyutları:** arm64-v8a **59,1 MB**,
  armeabi-v7a **52,3 MB** (release). `PLAN.md` §7'deki 70-150 MB tahmininin
  altında. Yine de Supabase'in 50 MB yükleme sınırının **üstünde** — dağıtımın
  GitHub Releases'e taşınmasının sebebi bu (§5).
- `aria2c` **bilerek eklenmedi** — boyut ekliyor, CDN'ler zaten hızlı.
- `youtubedl-android` sürümü: **0.18.1** (library + ffmpeg).
- FileProvider yetkilisi: `${applicationId}.dosyalar`,
  yollar `android/app/src/main/res/xml/dosya_yollari.xml`.
- ✅ `buildTypes.release` **kalıcı upload anahtarıyla** imzalıyor
  (§12). `key.properties` yoksa debug anahtarına düşüyor ve uyarı basıyor —
  depoyu klonlayan biri derleyebilsin ama ürettiği APK'nın dağıtılamayacağını
  görsün diye.

---

## 5. İki katmanlı güncelleme (Aşama 7 altyapısı hazır)

| | Motor güncellemesi | Uygulama güncellemesi |
|---|---|---|
| Ne | yt-dlp | APK'nın kendisi |
| Nereden | yt-dlp'nin kaynağından, uygulama içinden | **GitHub Releases** |
| Sıklık / boyut | Sık, birkaç MB | Nadir, ~59 MB |
| Yeniden kurulum | ❌ | ✅ kurulum ekranı |

**Bozulmaların çoğunun çözümü soldaki.** Ayarlar'da iki ayrı satır olması bu
yüzden; tek düğmede toplamak her küçük bozulmada 59 MB indirtmek olurdu.

### Supabase çıktı, GitHub Releases geldi (2026-09-05)

Supabase Storage iki engelde durdu: ücretsiz planın **50 MB yükleme sınırı**
(arm64 APK'mız 59,1 MB) ve **projenin inaktif kalınca uykuya geçmesi** —
ayda birkaç kez çalışan bir güncelleme kontrolü tam da uykuya en müsait
kullanım biçimi. İkincisi daha sinsi: dosya sınırı hemen belli olur, uyuyan
proje **çalışıyor sanılırken** çalışmaz.

🔑 **Eski "GitHub değil Supabase" gerekçesi düştü.** O gerekçe "private depo
API'ye sormak için APK'ya token gömmeyi gerektirir" diyordu — doğruydu, ama
dayandığı varsayım değişti: **depo public**. Public deponun release'leri
kimlik doğrulaması istemiyor, yani gömülecek sır yok.

Sonuç: **uygulamada artık hiçbir anahtar durmuyor.**
`cekirdek/supabase_ayarlari.dart` silindi, yerine `cekirdek/github_ayarlari.dart`.

### Sürüm katmanı — bilinmesi gerekenler

- `GuncellemeServisi.kontrolEt()` **asla hata fırlatmaz** → internet yoksa
  sessizce `bilinmiyor`. Güncelleme kontrolü yüzünden çalışan uygulamayı
  bozuk göstermek yok.
- `SurumKaynagi` **`postgrest` değil `http`** kullanıyor. GitHub düz JSON
  döndürdüğü için özel istemciye gerek yok; `http` zaten postgrest'in
  altındaki paketti, yani bağımlılık **azaldı** (net −4 paket).
  `dart:io` kullanılmadı: tarayıcıda çalışmıyor ve güncelleme kontrolü
  uygulama açılırken koşuyor.
- 🔑 **`tag_name` baştaki `v` temizleniyor** (`v1.2.0` → `1.2.0`).
  Atlanırsa `Surum.yeniMi` etiketi okuyamaz ve **her zaman "güncel" der** —
  güncelleme sessizce hiç gelmez. Bu yolun en sinsi hatası; test var.
- **404 hata değil.** Henüz release yayınlanmamış depoda GitHub 404 dönüyor;
  `SurumKaynagi` bunu `null` (= bilinmiyor) sayıyor.
- **`/releases/latest` taslak ve ön-sürümleri kendiliğinden atlıyor** —
  yarım bırakılmış bir release kullanıcıya güncelleme olarak görünmüyor.
- **APK seçimi `arm64` adına bakıyor** (`GitHubAyarlari.tercihEdilenApk`).
  Telefonun mimarisini Dart tarafında bilmiyoruz. Eski cihaz sorun olursa
  doğru çözüm burayı değiştirmek değil, `Build.SUPPORTED_ABIS`'i Android
  tarafından sormak.
- **Anonim istek sınırı saatte 60.** Uygulama açılışta bir kez soruyor;
  sınıra takılırsa sonuç "bilinmiyor" olur, kullanıcı bir şey görmez.
- `SurumBilgisi`'nden **`platform` alanı kalktı** — Supabase'de tek tabloda
  iki uygulama vardı, GitHub'da her uygulamanın kendi deposu var.
- `ApkKurucu` önce `*.yariminda` adına indirip bitince asıl ada taşıyor —
  yarım APK "hazır" sanılıp kuruluma verilmesin diye.
- `Surum.simdiki` **elle** yazılıyor (`'0.1.0'`), `pubspec.yaml` ile aynı
  kalmalı; `test/surum_test.dart` ikisini bağlıyor. Sürüm yükseltirken:
  önce `pubspec.yaml`, sonra `cekirdek/surum.dart`, sonra testi koştur.

---

## 6. Tasarım kararları (`cekirdek/tema.dart`)

- Koyu tema, vurgu **mor** (`#9B7BFF`) — DevLingo mavi; ikisi telefonda yan
  yana duracağı için ilk bakışta ayrılmalı.
- 🔑 **Ses yeşil, video mavi.** Ayrı renk bilinçli: paylaş menüsünden gelen
  kullanıcı saniyede karar veriyor, kas hafızasıyla doğru düğmeye basmalı.
- `Olculer.buyukDugme = 64` — tek elle, yürürken basılıyor.
- Ham renk/ölçü yazma; `Renkler` ve `Olculer` sabitlerini kullan.
- **Telefon çerçevesi `home`'a değil `builder`'a konuldu:** `Navigator.push`
  ile açılan sayfalar (önizleme) MaterialApp seviyesinde çiziliyor, `home`
  sarılırsa çerçevenin dışında kalıyorlardı. Çerçeve yalnız geniş ekranda
  (tarayıcı) devreye giriyor; telefondaki görünümü değiştirmiyor.
- Önizleme ekranının ölçütü **üç saniye**: tek soru sorulur (ses mi video mu),
  kalite seçimi okun arkasında gizli, ok yalnız birden fazla seçenek varsa
  görünüyor.
- Kapak yoksa boşluk değil, kaynak simgeli yer tutucu çiziliyor.

---

## 7. Aşama durumu (`PLAN.md` §6)

| Aşama | Durum |
|---|---|
| **0** Kararlar | ✅ `notlar/KARARLAR.md` kilitli |
| **1** Ekranlar + sahte veri | ✅ 3 sekme + önizleme + sahte motor çalışıyor (tarayıcıda `flutter run -d chrome`) |
| **2** Android köprüsü | 🔶 **APK derleniyor ✅ (2026-09-05, ilk kez), cihazda hâlâ DENENMEDİ** — telefonda gerçek indirme yapılmadı |
| **3** Arayüz ↔ motor | ✅ kod tarafı bağlı (kuyruk → motor → önizleme); gerçek indirme testi Aşama 2 ile birlikte bekliyor |
| **4** Paylaş menüsü | ✅ **bitti** — `ACTION_SEND` filtresi + `PaylasimKoprusu.kt` + link ayıklama (§4.3). Paket eklenmedi |
| **5** MediaStore + bildirim + arka plan | 🔶 **MediaStore yazıldı ✅** (§4.1) — bildirim ve arka planda indirme yok |
| **6** Kuyruk / geçmiş / ayarlar cilası | 🔶 kuyruk, geçmiş ve **iptal** var; kalıcı kayıt (sqflite) yok, "Aç/Paylaş" gerçek dosya açmıyor |
| **7** Kendini güncelleme | ✅ **bitti** — depo açıldı, kalıcı imza anahtarı üretildi, **v0.1.0 yayında** (§11, §12). Zincir API üzerinden uçtan uca doğrulandı |
| **8** Facebook/TikTok/kapalı hesap | ❌ (`kaynakBul` zaten tanıyor, gerisi yok) |

### Sıradaki iş
**Gerçek cihazda ilk indirme** — hâlâ tek doğrulanmamış nokta ve artık
biriken iş çok. APK derleniyor ve imzalı, kurulacak sürüm hazır.

Telefonda sınanacaklar (hiçbiri cihazda denenmedi):
1. Motorun açılması ve "Motor hazırlanıyor…" durumunun geçmesi
2. Instagram → Paylaş → uygulama listede çıkıyor mu, önizleme açılıyor mu
3. Çözümleme → indirme → **iptal**
4. Dosyanın müzik çalarda / galeride görünmesi (MediaStore)

Kalan aşamalar: **5** (bildirim + arka planda indirme) ve **6**
(kalıcı geçmiş, "Aç/Paylaş").

### Açık kalan kararlar (Yahya'da)
1. **Keystore yedeği** (§12) — tek kopya diskte duruyor, kaybı geri dönüşsüz
2. **Projenin ASCII bir yola taşınması** (§10) — derleme için şart
3. Uygulama ikonu (`ic_launcher` hâlâ Flutter varsayılanı)
4. armeabi-v7a APK'sı da release'e eklensin mi (şu an yalnız arm64 yayında)

---

## 8. Geliştirme standartları

- **Türkçe isimlendirme.** Sınıf, dosya, değişken, klasör — hepsi Türkçe
  (`kuyruk_yoneticisi.dart`, `MedyaBilgisi`, `cozumle`). Bu kod tabanının
  üslubu, koru.
- 🔑 **Kod içinde ASCII, kullanıcıya tam Türkçe.** Yorumlar ve tanımlayıcılar
  Türkçe karakter kullanmıyor (`gomulu`, `Asama`, `cozumle`); ama kullanıcıya
  görünen her metin tam Türkçe (`'Bağlantı çözümleniyor…'`). İkisini karıştırma.
- Yorum **"ne yaptığını" değil "neden böyle"** olduğunu anlatır. Mevcut
  dosyalardaki uzun gerekçe blokları bilinçli; silme.
- Kullanıcıya gösterilen hata **her zaman** ne yapabileceğini söyler; teknik
  ayrıntı `ayrinti` alanında kalır.
- Yeni paket eklemeden önce iki kez düşün: bu proje bağımlılıktan bilerek
  kaçınıyor (bkz. `ApkKurucu` başındaki not — 40 satırlık iş için paket yok).
  Mevcut tüm bağımlılıklar: `http`, `path_provider`, `cupertino_icons`
  (+ dev: `flutter_lints` 6.0.0). Dart SDK `^3.12.2`.
- Yeni ekran = mevcut düzeni izle: `alan/varliklar/<ad>.dart` → `servisler/`
  → `arayuz/<ad>/<ad>_ekrani.dart`; ortak parçalar `arayuz/ortak/`.
- **Kuyruk/motor davranışı değiştirilirse `test/kuyruk_test.dart` de
  değişir.** Gerçek motor yalnız telefonda koşuyor; bu testler sahte bir
  motorla kuyruğun kendi mantığını (özellikle iptal yarışlarını) tutan tek
  ağ. Yazılırken bir gerçek hata yakaladılar, süs değiller.

### Token tasarrufu — sonraki oturumlar için

- **Önce bu dosyayı oku**, sonra yalnız dokunacağın dilimi aç.
- Bir işi anlamak için genelde 3 dosya yeter:
  `servisler/indirme_motoru.dart` (sözleşme) → ilgili motor → ilgili ekran.
- `build/`, `.dart_tool/`, `pubspec.lock`, `android/app/src/main/java/`
  (üretilmiş `GeneratedPluginRegistrant`) **hiç okunmaz**.
- `PLAN.md` bölümlere ayrılmış; tamamını okumak yerine ilgili başlığı çek
  (§2 ffmpeg ne zaman gerekir, §6 yol haritası, §9 güncelleme).
- Geniş arama gerekiyorsa `Grep`/`Glob`; tam dosya dökümü aldırma.
- Bu dosya ile gerçek çelişirse: **kodu bu dosyaya uydurma** — önce burayı
  güncelle ve durumu bildir.

---

## 9. Ortam ve komutlar

- Flutter SDK: **`C:\flutter`** (stable, revision `84fc5cbb…`).
  ⚠️ `flutter` PATH'te **yok** — komutlar tam yolla çağrılmalı.
- Uygulama klasörü: `MedyaIndirici/app`.

```powershell
C:\flutter\bin\flutter pub get
C:\flutter\bin\flutter test        # 46 test (surum 7 + kuyruk 8 + surum_kaynagi 15 + baglanti 16)
C:\flutter\bin\dart analyze        # temiz olmalı — "No issues found!"
C:\flutter\bin\flutter run -d chrome --web-port=8099   # SAHTE motor, ekran bakışı
C:\flutter\bin\flutter run -d <cihaz>                  # telefonda GERÇEK motor

# APK — mimari seçimi BURADA (gradle'da değil, bkz. §4 gradle notu).
# ÖNCE §10'u oku: bu komut Türkçe karakterli yoldan ÇALIŞMAZ.
C:\flutter\bin\flutter build apk --release --split-per-abi `
    --target-platform android-arm,android-arm64
# çıktı: build\app\outputs\flutter-apk\app-arm64-v8a-release.apk  (59 MB)
```

`analyze` ve `test` Türkçe karakterli yoldan **sorunsuz çalışıyor**;
engel yalnızca APK derlemesinde.

**Tarayıcıda gerçek indirme olmaz** — orada `SahteMotor` çalışır. Denenebilir
akışlar: adrese `hata` yazarak hata ekranı, ilk 2,5 saniyede "Motor
hazırlanıyor…" şeridi, indirme sırasında durdurma düğmesi.
**Paylaş menüsü tarayıcıda denenemez** — yalnız Android'de çalışıyor
(§4.3); link ayıklama tarafı testlerle tutuluyor.

Derleme çıktısındaki `llvm-strip: ... not recognized as a valid object file`
satırları **zararsız** — gömülü `libpython.zip.so` / `libffmpeg.zip.so`
dosyaları ELF değil, sıkıştırılmış yük. Derleme yine `EXIT=0` veriyor.

---

## 10. 🔴 Derleme engeli — proje yolundaki Türkçe karakterler

APK bu klasörden **derlenemiyor**. Yol `Masaüstü` ve `Müzik` içeriyor;
iki ayrı araç birden buna takılıyor:

1. **AGP** yapılandırmada duruyor: *"Your project path contains non-ASCII
   characters."*
2. `android.overridePathCheck=true` ile AGP susturulunca bu sefer
   **Dart'ın AOT üreteci** düşüyor: `Unable to read file: ...app.dill`
   (yol hata metninde bozuk çıkıyor — kodlama sorunu).

Yani `overridePathCheck` **çözüm değil**, denendi ve engeli bir adım
öteye taşımaktan başka işe yaramadı. O yüzden `gradle.properties`'e
eklenmedi.

**Çözüm: projeyi ASCII bir yola taşımak.** Örnek: `C:\dev\MedyaIndirici`.
Kodda hiçbir değişiklik gerekmiyor; yalnız `android/local.properties`
yeniden üretilir (`sdk.dir=C:/dev/tools/android-sdk`).

**Geçici yol** (taşımadan derlemek gerekirse): klasörü ASCII bir yere
kopyalayıp orada derlemek. 2026-09-05'te doğrulama böyle yapıldı —
`build`, `.dart_tool`, `.idea` hariç kopyalanır, `local.properties`
yazılır, derleme orada koşar. Bu bir çözüm değil, ölçüm yöntemi.

### Ortam
- Android SDK: `C:\dev\tools\android-sdk` (`android/local.properties`)
- NDK 28.2.13676358, Gradle derlemesi ~90 sn

---

## 11. GitHub deposu ve release

| Adım | Durum |
|---|---|
| Yerel git deposu (`main`) | ✅ |
| `.gitignore` (APK, anahtarlar, `local.properties`, `Planlama_MP3.txt`) | ✅ |
| GitHub CLI (`gh` 2.100.0) + oturum (`Emre1071`) | ✅ |
| Uzak depo — **github.com/Emre1071/medya-indirici** (public) | ✅ push edildi |
| Kalıcı imza anahtarı | ✅ §12 |
| **İlk release `v0.1.0` + arm64 APK** | ✅ yayında |

Release: <https://github.com/Emre1071/medya-indirici/releases/tag/v0.1.0>

**Zincir uçtan uca doğrulandı** (uygulamanın gittiği API'ye sorularak):
`tag_name = v0.1.0` · taslak/ön-sürüm değil · Türkçe notlar bozulmamış ·
`app-arm64-v8a-release.apk` istemcinin arm64 süzgecine takılıyor ·
indirme adresi çözülüyor.

`Surum.simdiki` de `0.1.0` olduğu için uygulama "güncel" diyor — ilk
release'te olması gereken davranış, sahte güncelleme uyarısı çıkmıyor.

⚠️ **Depo adı ve hesap koda gömülü.** `lib/cekirdek/github_ayarlari.dart`
içinde `sahip = 'Emre1071'`, `depo = 'medya-indirici'`. Depo taşınır veya
yeniden adlandırılırsa **o dosya da değişmeli**, yoksa uygulama güncellemeyi
hiç bulamaz (sessizce "güncel" der).

### Release yayınlama akışı

APK derlemesi Türkçe karakterli yoldan çalışmıyor (§10), o yüzden derleme
ASCII bir yolda yapılır:

```powershell
# 1) Sürüm numarasını yükselt: pubspec.yaml + lib/cekirdek/surum.dart
#    (ikisi ayrışırsa surum_test.dart kırmızı yanar)
C:\flutter\bin\flutter test

# 2) ASCII bir yolda derle
C:\flutter\bin\flutter build apk --release --split-per-abi `
    --target-platform android-arm,android-arm64

# 3) Release olustur — etiket 'v' ile baslar, istemci onu temizliyor
gh release create v0.1.0 `
    build\app\outputs\flutter-apk\app-arm64-v8a-release.apk `
    build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk `
    --title "v0.1.0" --notes "Değişiklik notu — kullanıcıya bu metin görünür"
```

🔑 **Release notu doğrudan kullanıcıya gösteriliyor** (Ayarlar ekranında,
`body` alanından). Teknik commit dökümü değil, "ne değişti" cümlesi yazılmalı.

✅ **İmza artık kalıcı anahtarla** (§12) — derleme makinesinde
`android/key.properties` durduğu sürece ek bir şey yapmak gerekmiyor.

---

## 12. 🔑 İmza anahtarı (keystore)

| | |
|---|---|
| Dosya | `C:\Users\eavci\AnahtarDeposu\medya-indirici-upload.jks` |
| Tür / boyut | PKCS12 · RSA 4096 · 10.000 gün geçerli |
| Takma ad | `medya-indirici` |
| Sertifika | `CN=Medya Indirici, O=Piri Teknoloji, C=TR` |
| SHA-256 | `78:62:DC:EE:A0:FC:7D:0D:2E:8D:F3:9E:EF:0C:54:EB:0F:13:B7:02:B5:73:8A:E5:50:59:84:2F:74:35:EF:5D` |
| Parolalar | `app/android/key.properties` içinde (repoda **yok**) |

### 🔴 Bu anahtar kaybedilirse geri dönüşü yok

Android, bir uygulamanın güncellemesini **yalnızca aynı anahtarla**
imzalanmışsa kabul ediyor. Anahtar giderse:

- Yeni sürüm yayınlansa bile kurulmaz ("uygulama zaten yüklü" hatası).
- Tek çıkış yolu kullanıcının uygulamayı **kaldırıp yeniden kurması** —
  indirme geçmişi ve ayarları gider.

**Şu an tek kopya bu diskte.** Yedeklenmeli: keystore dosyası **ve**
`key.properties` (parolasız keystore işe yaramaz) birlikte, repo dışında
bir yere.

### Neden depo ağacının dışında

`.gitignore` zaten `*.jks`, `*.keystore` ve `key.properties` satırlarını
içeriyor (hem kökte hem `app/android/.gitignore`'da). Ama anahtar bir kez
sızarsa geri alınamaz — public depoda git geçmişinden temizlemek bile
yetmez, çünkü çekilmiş olabilir. İki savunma hattı: dosya ağacın dışında
**ve** desenler yok sayılıyor.

### Gradle nasıl bağlı

`android/app/build.gradle.kts` başında `key.properties` okunuyor,
`signingConfigs.release` oradan besleniyor. **Dosya yoksa debug anahtarına
düşülüyor ve derlemede uyarı basılıyor** — depoyu klonlayan biri (anahtarı
olmayan) yine derleyip deneyebilsin, ama ürettiği APK'nın dağıtılamayacağını
görsün diye. Sessizce debug'a düşmek en kötüsü olurdu.

### İmzayı doğrulama

`keytool -printcert -jarfile` **boş döner** — modern APK'lar v1 (JAR) ile
değil v2 şemasıyla imzalanıyor. Doğru araç `apksigner`:

```powershell
& "C:\dev\tools\android-sdk\build-tools\36.0.0\apksigner.bat" `
    verify --print-certs -v <apk yolu>
```

Beklenen: `Signer #1 certificate DN: CN=Medya Indirici, O=Piri Teknoloji, C=TR`.
`CN=Android Debug` görürsen APK **dağıtılamaz**, `key.properties` okunmamış.
