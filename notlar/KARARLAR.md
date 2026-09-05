# Kararlar (Aşama 0 — kilitlendi)

| Konu | Karar |
|---|---|
| **Uygulama adı** | **Medya İndirici** |
| **İlk sürüm kapsamı** | **Instagram + YouTube** (Facebook/TikTok Aşama 7) |
| **Mimari** | **Tamamen telefonda.** Sunucu yok, PC yok, Supabase yok. |
| **İndirme motoru** | `youtubedl-android` (Python + yt-dlp + ffmpeg uygulamaya gömülü) |
| **Hedef platform** | **Android.** Web sadece ekran tasarımı önizlemesi için. |
| **Dosya nereye** | Telefonun Müzik / Filmler / İndirilenler klasörüne (MediaStore) |
| **Dağıtım** | APK, kendi cihazına kurulum. Google Play hedeflenmiyor. |
| **Format seçimi** | Kullanıcı sadece "Ses" / "Video" seçer. mp3'e çevirme, ses-video birleştirme arka planda otomatik. |
| **Kendi kendini güncelleme** | **Var — GitHub Releases üzerinden.** İki katmanlı: yt-dlp motoru (sık, küçük, APK'sız) + uygulama APK'sı (nadir, GitHub Releases). Detay: `PLAN.md` §9 · Supabase'den dönüş gerekçesi aşağıda |
| **Kaynak kodu** | **Public GitHub deposu** (`Emre1071/medya-indirici`). Güncelleme mekanizmasının anahtarsız çalışması buna bağlı. |

---

## Neden bu mimari seçildi

Kullanıcının asıl kullanım anı: **Instagram'da Reels izlerken, telefonda, dışarıda.**
Bilgisayarın başında değil. Bu yüzden bilgisayara bağlı her çözüm yanlış:

- Her seferinde "PC açık mıydı?" endişesi
- Ev WiFi'ı zorunluluğu (mobil veriyle çalışmaz)
- Güvenlik duvarı izni, değişen IP adresi, port ayarları
- Supabase kullanılsa bile: aylık veri sınırı + PC yine açık olmak zorunda

Telefonda çözüm bunların **hepsini birden** ortadan kaldırıyor.

**Ek kazanç:** Instagram veri merkezi IP'lerini (kiralık sunucular) engelliyor,
telefon bağlantısını normal kullanıcı sanıyor. Yani telefonda çalışan sürüm
daha az bozuluyor. İleride kullanıcının kendi oturumu da eklenebilir.

---

## Karşılığında kabul edilen bedeller

| Bedel | Değerlendirme |
|---|---|
| APK ~70-150 MB | Bir kere kurulur, kabul edildi |
| Web'de gerçek indirme yok | Test doğrudan telefonda yapılacak, kabul edildi |
| Flutter↔Android köprüsü yazılmalı | ~yarım günlük ek iş, kabul edildi |
| Uzun videolarda ısınma/pil | Kısa Reels'te fark edilmiyor, kabul edildi |
| Google Play'e konulamaz | Zaten hedef değil |

---

## Değişen beklenti: web testi

İlk konuşmada "önce web'den test ederiz" denmişti. **Bu mimaride mümkün değil** —
tarayıcı Python ve ffmpeg çalıştıramaz.

Yerine: Aşama 1'de ekran tasarımları sahte veriyle web'de gösterilecek
(hızlı bakıp "şöyle mi olsun" demek için). Gerçek indirme testi Aşama 2'den
itibaren doğrudan telefonda yapılacak.


---

## Supabase tekrar elendi — dağıtım GitHub Releases'e geçti (2026-09-05)

Supabase Storage sürüm dağıtımı için seçilmişti (aşağıdaki bölüm o kararı
anlatıyor). **İki somut engelde durdu:**

| Engel | Ayrıntı |
|---|---|
| **50 MB dosya sınırı** | Ücretsiz planın yükleme sınırı 50 MB. arm64 APK'mız **59,1 MB**. Yapı çalışsa bile güncelleme dosyası hiç yüklenemiyor. |
| **Uyuyan proje** | Ücretsiz Supabase projesi bir süre kullanılmayınca duraklatılıyor. Güncelleme kontrolü ayda birkaç kez çalışan bir şey — tam da uykuya en müsait kullanım biçimi. Uyuyan proje = sessizce çalışmayan güncelleme. |

İkincisi birincisinden daha sinsi: dosya sınırı hemen belli olur, uyuyan
proje ise **çalışıyor sanılırken** çalışmaz. Kullanıcı güncelleme
gelmediğini fark etmez.

**GitHub Releases'te ikisi de yok:** dosya sınırı 2 GB, depo uyumuyor.

### "GitHub değil Supabase" gerekçesi neden düştü

Eski not (`veri/uzak/surum_kaynagi.dart` içinde yazılıydı) şunu diyordu:

> Depo private olduğunda GitHub Releases API'sine sormak, APK'ya bir GitHub
> token'ı gömmeyi gerektirir — o token APK'dan çıkarılabileceği için depoyu
> private tutmanın anlamı kalmaz.

Doğruydu, ama dayandığı varsayım değişti: **depo public.** Public deponun
release'leri kimlik doğrulaması istemiyor, yani gömülecek bir sır yok.

### Bu değişimin getirdikleri

| | Kazanç |
|---|---|
| **Sır kalmadı** | Uygulamada artık hiçbir anahtar yok. Supabase `anon` anahtarı da (kodda durması sorun değildi ama gereksizdi) silindi. |
| **Bağımlılık azaldı** | `postgrest` çıktı, yerine `http` geldi — zaten postgrest'in altındaki paketti. Net **4 bağımlılık** eksildi. |
| **Aylık trafik derdi bitti** | Supabase'in ~5 GB sınırı yüzünden "ayda 30-60 indirme" hesabı yapılıyordu. GitHub Releases'te böyle bir hesap yok. |
| **Sürüm geçmişi görünür** | Eski APK'lar duruyor; Supabase'de yer dolmasın diye hep aynı dosya adı kullanılıp eskiler siliniyordu. |

### Bedeli

**Kaynak kodu herkese açık.** Bu projede saklanacak bir şey yok: sır yok,
sunucu yok, kişisel veri yok. Yine de bilinçli bir karar — kişisel çalışma
notları (`Planlama_MP3.txt`) `.gitignore` ile dışarıda tutuluyor.

---

## Supabase geri döndü — ama farklı bir rolde
*(⚠️ Bu bölüm tarihî kayıt. Yukarıdaki 2026-09-05 kararı bunu geçersiz kıldı;
neden böyle düşünüldüğünü unutmamak için duruyor.)*

Supabase önce **dosya aktarımı** için değerlendirilip elenmişti
(bkz. `ELENENLER.md` §4). Şimdi **sürüm dağıtımı** için plana girdi.
Bunlar aynı şey değil:

| | Elenen kullanım | Kabul edilen kullanım |
|---|---|---|
| Ne taşınıyor | Her indirilen video/müzik | Sadece sürüm bilgisi + nadiren APK |
| Sıklık | Günde onlarca | Ayda birkaç |
| PC gerektirir mi | ✅ Evet — asıl sorun buydu | ❌ Hayır |
| Trafik sınırı riski | Yüksek | Düşük |

Yani Supabase'in elenme sebebi "Supabase kötü" değildi; **her dosyayı
üzerinden geçirmek** kötüydü. Sürüm dağıtımı tam da Supabase'in
zahmetsizce yaptığı iş.

**Ayrıca:** kullanıcı bu mekanizmayı kendi yazdığı iki uygulamada
zaten çalıştırıyor. Bu, plandaki en düşük riskli parça.
