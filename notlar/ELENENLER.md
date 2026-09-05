# Değerlendirilip Vazgeçilen Yollar

Yeniden aynı tartışmaya girmemek için, neden elendiklerinin kaydı.

## 1. PC'de sunucu + telefon ev WiFi'ından bağlanır
İlk plandı. Python kodu neredeyse aynen taşınacağı için en hızlı yol gibi görünüyordu.

**Elenme sebebi:** Kullanıcının asıl kullanım anı dışarıda, telefonda.
PC'nin açık olma zorunluluğu ve ev WiFi'ı şartı kullanımı öldürüyor.
Ayrıca güvenlik duvarı izni, değişen yerel IP, port ayarı gibi sürekli
bakım isteyen ayrıntılar var.

## 2. PC + Tailscale (ev dışından erişim)
1. maddenin "her yerden çalışsın" hali.

**Elenme sebebi:** Ağ sorununu çözüyor ama PC'nin açık olma zorunluluğunu
çözmüyor. Asıl sorun oydu.

## 3. VPS (kiralık sunucu, ~5€/ay)
7/24 açık olurdu.

**Elenme sebebi:** Aylık ücret. Üstelik Instagram ve YouTube veri merkezi
IP'lerini engelliyor — çerez/oturum bakımı gerektirir, yani ücret ödeyip
üstüne daha kırılgan bir sistem elde ediliyor.

## 4. Supabase üzerinden aktarım
Telefon ile PC birbirini aramasın, ortada posta kutusu olsun.

**Elenme sebebi:** Ağ ayarlarını gerçekten güzel çözüyordu, ancak:
- PC yine açık olmak zorunda (Supabase Edge Functions'ta yt-dlp/ffmpeg çalışmaz)
- Dosya iki kez yolculuk ediyor (PC→Supabase→telefon); ev bağlantılarının
  **yükleme** hızı yavaş olduğundan gereksiz bekleme
- Ücretsiz planın aylık trafik sınırı var; dosyayı silmek depolamayı kurtarır
  ama harcanan trafiği geri getirmez

Telefonda çözüm seçilince tamamen gereksiz hale geldi.

## 5. Linki Dart ile kendimiz çözelim (youtube_explode_dart vb.)
Sunucusuz olurdu ve paket boyutu küçük kalırdı.

**Elenme sebebi:** YouTube için bir seçenek var ama **Instagram için yok** —
sıfırdan yazmak gerekirdi. Instagram tarafını sık değiştirdiği için birkaç ayda
bir bozulur ve her seferinde elle bakım ister. Sürdürülemez.
