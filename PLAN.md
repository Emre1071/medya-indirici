# Medya İndirici — Flutter (Android)

Mevcut Python/Tkinter "MP3 Dönüştürücü" uygulamasının telefon versiyonu.
**Instagram / YouTube** linkinden ses veya sesli video indirir.

> **Mimari kararı: HER ŞEY TELEFONDA.**
> Sunucu yok, bilgisayar yok, aracı yok, internet ayarı yok.
> İndirme motoru uygulamanın içine gömülü.
> *(Tek istisna: sürüm kontrolü GitHub Releases'e bakıyor — §9.
> İndirilen dosyalar oraya uğramıyor.)*

---

## 1. Nasıl Çalışıyor

Masaüstü uygulamandaki iki program — `yt-dlp` (linki çözer) ve `ffmpeg`
(dönüştürür) — telefon uygulamasının **içine paketleniyor**.

Bunu mümkün kılan şey: Android için Python çalışma ortamını + yt-dlp'yi + ffmpeg'i
tek pakette sunan **`youtubedl-android`** kütüphanesi. Kanıtlanmış bir yöntem —
*Seal* gibi gerçek uygulamalar bu şekilde çalışıyor.

```
┌─────────────── Telefon (tek başına) ───────────────┐
│                                                     │
│   Flutter arayüz  (Dart)                            │
│         ↕  MethodChannel / EventChannel  (köprü)    │
│   Android katmanı (Kotlin)                          │
│         ↓                                           │
│   youtubedl-android                                 │
│     ├── Python + yt-dlp   → linki çözer, indirir    │
│     └── ffmpeg            → dönüştürür / birleştirir│
│                                                     │
└─────────────────────────────────────────────────────┘
```

İnternete çıkılan tek yer: Instagram/YouTube'un kendi sunucuları. Aracı yok.

### Bunun gizli avantajı
Instagram, veri merkezi IP'lerini (kiralık sunucuları) hızla engeller ama telefon
bağlantısını normal kullanıcı sanar. Yani telefonda çalışan sürüm **daha az bozulur**.
Ayrıca ileride kullanıcının kendi Instagram oturumu eklenip kapalı hesap
içerikleri de indirilebilir — sunucuyla bu çok daha riskli olurdu.

---

## 2. "Dönüştürme" Çoğu Zaman Gereksiz

Önemli sadeleştirme: YouTube ve Instagram **hazır ses dosyası** sunuyor (m4a/opus).
Sadece sesi indirdiğinde elinde çalışan bir müzik dosyası oluyor — telefonun müzik
çalarında, WhatsApp'ta her yerde açılır. ffmpeg'e hiç dokunulmaz, saniyeler sürer.

ffmpeg sadece şu üç durumda devreye girer:

| Durum | ffmpeg gerekli mi |
|---|---|
| Instagram Reels → MP4 (sesli) | ❌ Hayır — tek parça geliyor, direkt iner |
| Herhangi bir video → sadece ses | ❌ Hayır — hazır ses dosyası indirilir |
| Sonuç **kesinlikle `.mp3`** olmalı (araba teybi vb.) | ✅ Evet |
| YouTube → yüksek kaliteli MP4 | ✅ Evet — video ve ses ayrı gelir, birleştirilir |

Arayüzde bu gizlenecek: kullanıcı sadece **"Ses"** veya **"Video"** seçer,
gerekiyorsa ffmpeg arka planda sessizce çalışır.

---

## 3. Uygulama Akışı

```
Instagram → Reels → Paylaş → "Medya İndirici"
      ↓  link otomatik gelir
   Uygulama linki çözer (2-3 saniye)
      ↓
   ┌──────────────────────┐
   │   [kapak görseli]    │
   │   Şerif Ruç on Reels │
   │   0:47               │
   ├──────────────────────┤
   │  🎵  Ses İndir       │
   │  🎬  Video İndir     │
   └──────────────────────┘
      ↓  seçim
   İndirir (+ gerekiyorsa dönüştürür)
      ↓
   Telefonun Müzik / Filmler klasörüne kaydeder
      ↓
   Bildirim: "İndirildi ✓  [Aç]  [Paylaş]"
```

Toplam **üç dokunuş**. Uygulamayı elle açmaya gerek yok.

---

## 4. Ekranlar

1. **Ana ekran** — link yapıştırma kutusu, "Panodan yapıştır", indirme kuyruğu
2. **Önizleme sayfası** — kapak, başlık, süre, kalite seçimi, Ses/Video butonları
   *(paylaşımdan gelindiğinde doğrudan bu ekran açılır)*
3. **İndirilenler** — geçmiş listesi, aç / paylaş / sil
4. **Ayarlar** — varsayılan format, kayıt klasörü, kalite, yt-dlp güncelleme

---

## 5. Kullanılacak Yapı Taşları

| İş | Çözüm |
|---|---|
| İndirme motoru | `youtubedl-android` (Python + yt-dlp + ffmpeg gömülü) |
| Flutter ↔ Android köprüsü | MethodChannel (komut) + EventChannel (ilerleme yüzdesi) |
| Paylaş menüsünde çıkma | AndroidManifest `ACTION_SEND` + `receive_sharing_intent` |
| Dosya kaydetme | MediaStore → Müzik / Filmler / İndirilenler klasörü |
| Arka planda indirme | `flutter_foreground_task` — uygulama kapansa da devam eder |
| Bildirimler | `flutter_local_notifications` — ilerleme çubuğu + "Aç" butonu |
| Geçmiş kaydı | yerel veritabanı (sqflite / drift) |
| Durum yönetimi | riverpod |

---

## 6. Yol Haritası

| Aşama | İş | Sonuç |
|---|---|---|
| **0** | ✅ Kararlar verildi | `notlar/KARARLAR.md` |
| **1** | Flutter projesi + ekran tasarımları (sahte veriyle) | Ekranlar görülebilir |
| **2** | Android köprüsü: motoru göm, tek bir indirme çalıştır | Telefonda ilk gerçek indirme |
| **3** | Arayüzü motora bağla: çözümle → önizle → indir | Elle link yapıştırıp indirme ✅ |
| **4** | Paylaş menüsü entegrasyonu | Instagram'dan paylaş → açılıyor ✅ |
| **5** | Dosya kaydetme, bildirim, arka plan | Günlük kullanılabilir |
| **6** | Kuyruk, geçmiş, ayarlar | Bitmiş uygulama |
| **7** | **Kendi kendini güncelleme** (GitHub Releases) — bkz. §9 | APK'yı elle taşımaya son |
| **8** | *(isteğe bağlı)* Facebook, TikTok, X + kapalı hesap desteği | Genişletme |

Aşama 1-2 ~1 gün · 3-4 ~1 gün · 5-6 cila.

**Kritik aşama 2.** Motorun telefonda çalıştığını en erken orada göreceğiz.
Bir aksilik çıkacaksa orada çıkar, o yüzden öne aldım.

---

## 7. Bilinen Bedeller

**Uygulama boyutu ~59 MB** (ölçüldü: arm64 59,1 MB · armeabi-v7a 52,3 MB).
Python ve ffmpeg gömülü olduğu için. İlk tahmin 70-150 MB'tı; mimari başına
ayrı APK üretmek beklenenden çok kazandırdı. Bir kere kurulur, sorun değil.

**Web sürümü gerçek indirme yapamaz.**
Tarayıcı Python/ffmpeg çalıştıramaz. Web'de sadece **ekran tasarımlarını**
görebiliriz (Aşama 1). Gerçek test doğrudan telefonda yapılacak.

**Google Play kabul etmez.**
YouTube indirme politikası nedeniyle. Dağıtım APK ile — kendi telefonuna
kurmak sorunsuz. (Bilinmeyen kaynaklara izin verilmesi gerekir, bir kerelik.)

**Telefon ısınır / pil harcar.**
Sadece uzun video dönüştürmelerinde. Kısa Reels'te fark edilmez.

**yt-dlp güncel tutulmalı.**
Instagram/YouTube değiştikçe bozulur. İyi haber: kullanılan kütüphane yt-dlp'yi
**uygulama içinden güncelleyebiliyor** — Ayarlar'a "Motoru Güncelle" düğmesi
konacak, uygulamayı yeniden kurmaya gerek kalmayacak.

**Kapalı/özel hesap içerikleri** giriş bilgisi ister. Herkese açık Reels sorunsuz.
Bu Aşama 7'de ele alınacak.

Telif: kendi içeriğin veya izinli içerik için kullan; platform şartlarını sen değerlendir.

---

## 8. Klasör Yapısı

```
Müzik/MedyaIndirici/          ← git deposu kökü (public: Emre1071/medya-indirici)
├── PLAN.md          ← bu dosya (ürün kararları)
├── HAFIZA.md        ← oturum başında ilk okunan bağlam dosyası
├── .gitignore
├── app/             ← Flutter projesi (android + ekran önizlemesi için web)
└── notlar/
    ├── KARARLAR.md  ← verilen kararlar ve gerekçeleri
    └── ELENENLER.md ← değerlendirilip vazgeçilen yollar
```


---

## 9. Kendi Kendini Güncelleme (GitHub Releases)

Uygulama Google Play'de olmayacağı için güncellemeyi kendisi halletmeli.
**Bu iş DevLingo'da zaten çözülmüş durumda** — o yapı buraya taşınacak,
sıfırdan tasarlanmayacak.

### Hazır olan parçalar (`DevLingo/lib/` içinden)

| Dosya | Görevi |
|---|---|
| `alan/varliklar/surum_bilgisi.dart` | Buluttaki sürüm kaydının karşılığı |
| `veri/uzak/surum_kaynagi.dart` | GitHub `releases/latest` ucunu okur |
| `cekirdek/surum.dart` | Sürüm numarası + doğru karşılaştırma (`1.0.10 > 1.0.2`) |
| `servisler/guncelleme_servisi.dart` | "Yeni sürüm var mı?" — asla hata fırlatmaz |
| `servisler/apk_kurucu.dart` | APK'yı indirir, Android'in kurulum ekranına verir |
| `AndroidManifest.xml` | `REQUEST_INSTALL_PACKAGES` + `FileProvider` |

Taşınırken korunacak tasarım kararları:
- **Ağ katmanı en sade haliyle** — DevLingo'da `supabase_flutter` yerine
  `postgrest` seçilmişti (platform eklentisi taşımamak için). Aynı çizgi
  burada bir adım daha ileri gitti: GitHub düz JSON döndürdüğü için özel
  istemciye hiç gerek kalmadı, `http` yetiyor.
- **Güncelleme kontrolü asla hata fırlatmaz** — internet yoksa sessizce
  "bilinmiyor" der, uygulamanın açılmasını engellemez
- **APK önce geçici ada indirilir, bitince asıl adına taşınır** — yarım kalan
  indirme "hazır" sanılıp kurulmaya çalışılmasın
- **Sürüm sabiti elle yazılır, bir test `pubspec.yaml` ile karşılaştırır** —
  ikisi ayrışırsa test kırmızı yanar

### İki katmanlı güncelleme — bu uygulamaya özel

Burada DevLingo'dan farklı bir durum var: **iki ayrı şey güncelleniyor.**

| | Motor güncellemesi | Uygulama güncellemesi |
|---|---|---|
| **Ne güncellenir** | yt-dlp | Uygulamanın kendisi (APK) |
| **Niçin gerekir** | Instagram/YouTube sayfasını değiştirdi, indirme bozuldu | Yeni özellik, arayüz değişikliği, hata düzeltme |
| **Ne sıklıkta** | Sık — ayda birkaç kez | Nadir |
| **Boyut** | Birkaç MB | ~59 MB (ölçüldü) |
| **Nereden** | yt-dlp'nin kendi kaynağından, uygulama içinden | GitHub Releases |
| **Yeniden kurulum** | ❌ Gerekmez | ✅ Gerekir (kurulum ekranı açılır) |

Bu ayrım önemli: **bozulmaların büyük çoğunluğu motor güncellemesiyle çözülür**
ve APK indirmeye hiç gerek kalmaz. Ayarlar'da iki ayrı düğme olacak:

```
Ayarlar
 ├── 🔄  Motoru Güncelle        (yt-dlp — hızlı, birkaç MB)
 └── ⬆️  Uygulamayı Güncelle    (yeni sürüm varsa görünür)
```

### GitHub tarafı

Depo: **`Emre1071/medya-indirici`** — public.

- **Sürüm kaydı `releases/latest`** — ayrı bir tablo yok, sürüm bilgisi
  release'in kendisi. Okunan alanlar: `tag_name` (sürüm), `body`
  (değişiklik notu), `assets[].browser_download_url` (APK adresi).
- **Etiket biçimi `v0.1.0`** — baştaki `v` istemcide temizleniyor.
- **APK'lar release varlığı olarak yükleniyor:**
  `app-arm64-v8a-release.apk` ve `app-armeabi-v7a-release.apk`.
  Uygulama arm64 olanı seçiyor (2019 sonrası tüm telefonlar).
- **Kimlik doğrulaması yok.** Depo public olduğu için release'ler anonim
  okunuyor; uygulamada gömülü hiçbir anahtar yok.
- **Eski sürümler duruyor.** Supabase'de yer dolmasın diye hep aynı dosya
  adı kullanılıp eskiler siliniyordu; burada öyle bir zorunluluk yok.

### Niçin Supabase değil

Supabase Storage önce seçilmişti, iki engelde durdu: ücretsiz planın
**50 MB yükleme sınırı** (APK'mız 59 MB) ve **projenin inaktif kalınca
uykuya geçmesi** — ayda birkaç kez çalışan bir güncelleme kontrolü tam da
uykuya en müsait kullanım biçimi. Ayrıntı: `notlar/KARARLAR.md`.

Aylık trafik hesabı da bu kararla ortadan kalktı: GitHub Releases'te
indirme sayısı için bir bütçe tutmak gerekmiyor. Yine de sık olan
güncelleme (motor) zaten APK gerektirmiyor; ağır indirme nadir yaşanacak.

### Akış

```
Uygulama açılır
   ↓ (sessizce, arka planda)
GitHub'daki 'releases/latest' adresine bakar
   ↓
Yeni sürüm var mı?  ── hayır/bilinmiyor ──→ hiçbir şey gösterme
   ↓ evet
Ayarlar'da rozet + "Yeni sürüm: 1.1.0" notu
   ↓ kullanıcı basar
"Bilinmeyen kaynak" izni var mı? ── yoksa ──→ izin ekranına yönlendir
   ↓ var
APK indirilir (ilerleme çubuğu)
   ↓
Android kurulum ekranı açılır → kullanıcı onaylar → bitti
```

Kullanıcıya zorla güncelleme dayatılmıyor; sadece haber veriliyor.
