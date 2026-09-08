# Etkinlik detayında misafir yorum erişimi

## Davranış

- Oturum açmamış ziyaretçi etkinlik detayını ve herkese açık etkinliğin
  yorumlarını/yanıtlarını okuyabilir. Yorum alanı yerine `Yorum yapmak için
  giriş yap veya üye ol.` ve mevcut giriş/üyelik yollarına giden düğmeler görünür.
- Keşif ve etkinlik detayındaki `Üye Ol` aynı üyelik seçeneklerini açar.
  `Google ile devam et` seçeneği `Yakında` etiketiyle pasiftir ve istek göndermez.
  `E-posta ile devam et` mevcut kayıt akışını açar. Giriş yolu değişmez.
- Misafir için yorum editörü, gönderme ve yanıtlama işlemleri gösterilmez.
  Gönderme işlevleri ayrıca güncel oturumu kontrol eder. Eksik oturum yöneticisi
  güvenli biçimde misafir kabul edilir.
- Oturum açıldığında editör kullanılabilir hale gelir. Oturum kapanınca veya
  hesap değişince taslak ve önceki görüntüleyiciye ait yorum/yanıt önbelleği
  temizlenir, açık yanıt penceresi kapanır. Eski callback yeni hesap adına
  yorum gönderemez, geç yanıt yeni hesabın taslağını silemez.
- Yanıt penceresinde yalnız `Gönder` veya klavyenin gönder eylemi işlem yapar.
  Geri, dışarı dokunma, sürükleme ve `Vazgeç` taslağı göndermez. Yanıt hedefi
  listedeki sıra numarasıyla değil yorum kimliğiyle sabitlenir.
- Uzun metin ve büyük yazı ayarında misafir yönlendirmeleri alt alta yerleşir.
  Etkinlik tasarımı, paylaşım ve profil bağlantısı kararları değişmez.

## Sunucu sınırı

EVENT okumaları yalnız şu yollardan yapılır:

- `GET /api/v1/events/{eventId}/comments`
- `GET /api/v1/events/{eventId}/comments/{commentId}/replies`

Sunucu yalnız yayınlanmış mekan etkinliklerini döndürür. Mekan onaylı, sahibi
aktif ve e-postası doğrulanmış olmalıdır. Yanıt ebeveyni ilgili etkinliğe ait
bir ana yorum olmalıdır. Başka etkinlik veya içerik türüne ait yorum kimliği
bu yollardan okunamaz. Geçmiş etkinlikleri okumaya yedi günlük keşif sınırı
uygulanmaz.

Genel yorum yolları ve tüm yazma/silme işlemleri mevcut oturum korumasını
korur. Başka içerik türlerinin yorum erişimi açılmaz. Görünümdeki kapatma
sunucudaki yetki denetiminin yerine geçmez.

Ortak yorum durum yönetiminde geç yükleme sonuçları, kapanmış ekrana yanıt ve
çift gönderim korunur. Varsayılan davranış diğer ekranlar için değişmez,
`clearExisting: true` oturum değişiminde önceki görüntüleyicinin içeriğini
hemen temizlemek için kullanılır.

## Çalıştırma ve kısa manuel kontrol

Yeni okuma yolları için backend yeniden başlatılmalı, uygulamada hot restart
yapılmalıdır. Şema geçişi veya veritabanı sıfırlama gerekmez.

1. Çıkış yaparak etkinliği aç. Yorumlar okunabilmeli, yazı alanı yerine giriş
   ve üyelik yönlendirmesi görünmeli. Giriş kendi ekranını açmalı. Üyelik
   seçeneklerinde Google pasif olmalı, e-posta seçimi kayıt ekranını açmalı.
2. Giriş yaparak aynı etkinliği aç. Yorum gönderimi çalışmalı.
3. Bir yanıta yazı yazıp `Vazgeç` de. Gönderim yapılmamalı. Açıkça `Gönder`
   ile gönderilen yanıt yalnız seçilen ana yoruma bağlanmalı.

## Doğrulama

155 etkinlik detayı davranış/regresyon testi, 46 yorum durum yönetimi/veri
katmanı/mevcut ekran testi ve 50 misafir keşif/açılış testi geçti. Dört gerçek
Flutter önizlemesi `.local-verification/event-comment-guest-access/` altında,
görsel üretim testi de geçti. Üretim dosyalarının statik analizi temiz.

Sunucuda 58 test geçti. Gerçek güvenlik zinciriyle anonim yazma engeli ve
özel yorumların kapalı kalması kontrol edildi. İzole PostgreSQL testleri
etkinlik uygunluğunu, ebeveyn yorum kimliğini, mevcut yorum/kimlik gizleme
okuyucusunun kilitlemesini ve silinmiş yorum metni davranışını doğruladı.
Canlı veritabanı değiştirilmedi, test kapsayıcıları kaldırıldı.

### Ortak üyelik seçenekleri revizyonu

Keşif (47), etkinlik detayı (155), ortak üyelik seçenekleri (9) ve görsel
üretim (1) dahil 212 test geçti. Google için pasif erişilebilirlik durumu ve
dokunma eyleminin olmaması, mevcut kayıt yolu, çift açılma/gönderim,
geri/dışarı/Kapat ile iptal, kapanmış pencereye eski callback ve 320 pikselde
%200 yazı boyutu kontrol edildi. Statik analiz temiz. Normal ve büyük yazılı
önizlemeler `.local-verification/registration-options/` altında incelendi.
Bu revizyon yalnız frontend değişikliğidir.
