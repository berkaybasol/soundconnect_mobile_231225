# Ekipman Pazarı — ilk sürüm

20 Eylül 2026

Müzisyen, stüdyo ve mekân hesaplarının sıfır veya ikinci el müzik ekipmanı ilanı
oluşturduğu bağımsız Backstage modülü. Başlangıç ekranı ve alt bardaki **Pazar**
girişi bu modülü açar. Dinleyici ekranlarına eklenmez; karışık kişisel roller de
erişim alamaz. Sunucu mevcut hesap durumu, doğrulama, rol ve gerçek profil
sahipliğini yeniden kontrol eder.

## Kapsam

- Kategoriler, arama, fiyat/sıfır–ikinci el/konum filtreleri ve sıralama.
- İlan taslağı, fotoğraf sıralaması, yayınlama, düzenleme, satıldı işaretleme,
  yayından kaldırma ve taslaktan devam etme.
- Kaydedilen ilanlar, kendi ilanları, satıcı profili ve mevcut DM üzerinden iletişim.
- Bildirim gönderme ve yetkili yöneticinin kayıtlı kanıt üzerinden karar vermesi.

Ödeme, sipariş, tahsilat, teslimat takibi veya alım garantisi yoktur. Elden/kargo
seçimi satıcının teslim tercihidir. Mesajlaşma mevcut sohbeti açar; kullanıcı
adına otomatik mesaj göndermez. Ürün durumu yalnız **Sıfır / İkinci el**;
kozmetik ve çalışma durumu satıcının açıklamasında yer alır.

## Katalog ve ortak altyapı

[Pan Music](https://www.panmusic.com.tr/) ürün grupları düzen için referans alındı.
13 ana grup ve 112 seçilebilir ürün türü bulunur. Geleneksel çalgılar, canlı ses,
sahne ışığı ve donanımı kapsamı tamamlar. Yazılım/lisans, kitap ve dekorasyon
ürünleri kapsam dışıdır. Boyut, tel sayısı gibi ayrıntılar kategori dalı değildir.

Kaynak `SoundConnect-Backend/src/main/resources/marketplace-category-seed.json`.
Kodlar ve kimlikler sabittir; ilanlar kategori kimliğini saklar. Backline ve
Instrument modelleri, tabloları ve envanter akışları bağımsız kalır. Stüdyo
envanterinden aktarma bu sürüme eklenmedi.

Konumda mevcut City/District verisi kullanılır; mahalle veya açık adres alınmaz.
İlan kendi districtId değerini saklar ve sunucu şehri buradan türetir. Profil
konumu değişince ilan konumu kendiliğinden değişmez. Fotoğraflar mevcut medya
yükleme, doğrulama, kurtarma ve kalıcı silme işleyişini kullanır.

## Veri ve erişim kuralları

- TRY fiyatı tam sayı kuruş olarak tutulur. En fazla 8 fotoğraf; hesap başına
  30 taslak ve aynı anda 20 yayındaki ilan sınırı vardır.
- İlk yayın tarihi düzenlemede ve yeniden yayında korunur; düzenleme sıralamayı yükseltmez.
- Sürüm kontrolü eşzamanlı düzenlemelerde başka değişikliğin ezilmesini önler.
  Taslak oluşturma istemci istek kimliğiyle tekrar edilebilir.
- Kategori ağacında yalnız etkin alt tür seçilir. Liste sayfası ve metin sınırları sunucuda doğrulanır.
- Normal listelerde yalnız yayındaki, hâlâ uygun bir satıcı profiline ait ilanlar görünür.
  Taslaklar, satılan ve kaldırılan ilanlar satıcının kendi ekranında kalır.
- Fotoğraf sahipliği `MARKETPLACE + ilanId`; tür IMAGE, görünürlük PRIVATE,
  hedef BACKSTAGE. Kullanıcıdan fotoğraf URL'si kabul edilmez.
- Fotoğraf erişimi her imzalı URL isteğinde denetlenir. Mevcut kısa ömürlü imzalı
  URL modeli kullanılır; fotoğraflar kamusal disk önbelleğine yazılmaz. Kopyalanan
  imzalı bağlantı kendi süresi bitene kadar geçerlidir.
- Şikâyet anındaki ilan içeriği ve fotoğraf referansları inceleme için korunur;
  satıcının sonradan yaptığı değişiklik inceleme kaydını değiştirmez.
- İstemci temizleme kuyruğu ve sunucu referans kontrolü birlikte çalışır. Bağlı
  fotoğraf silinmez. İstemcinin terk ettiği bağlanmamış hazır fotoğraflar 24 saat
  sonra sunucu temizliğine adaydır; kaydedilmiş taslak fotoğrafları korunur.

## Üretime geçiş ve doğrulama

Backend SQL migration'ları API/worker güncellemesinden önce uygulanmalıdır;
istemci sürümü bu güncellemeler tamamlandıktan sonra dağıtılır:

1. `scripts/db/2026-09-20-marketplace-domain.sql`
2. `scripts/db/2026-09-20-marketplace-media.sql`

Yeni yönetici izni `MANAGE_MARKETPLACE_REPORTS`. UI oturumundaki izinler yeni giriş
veya normal oturum yenilemesiyle güncellenir; sunucu güncel veritabanı iznini esas alır.
Bu çalışma üretim veritabanına migration veya dağıtım uygulamaz.

Cihaz kabulü için: üç Backstage profiliyle ilan yayınlama/düzenleme/satıldı;
dinleyiciden rota ve fotoğraf erişiminin reddi; yükleme ortasında bağlantı kesilmesi;
aynı ilanın iki cihazdan düzenlenmesi; oturum değişirken açık ekran/fotoğrafların
kapanması; farklı şehir seçince eski ilçenin temizlenmesi; bildirimden yönetici
kararına kadar akış kontrol edilir.

### Tamamlanan otomatik doğrulama

- Tüm `lib` ve yeni pazar test dosyalarının Flutter analizi: **sorun yok**.
- Son birleşik frontend koşusu: **167 test geçti**. Pazar repository/controller/widget,
  yönetici erişimi ve karar sözleşmesi; rota, alt bar, oturum, deep link, kapalı
  profil akışları ve etkinlik keşfi regresyonları dahildir.
- 390 ve 320 piksel genişlikte örnek verili pazar ekranı render edildi, görüntüler
  incelendi; taşma bulunmadı. Bunlar test fixture'larıdır, canlı ilanlar değildir.
- Backend ilan/moderasyon kapsamı: **79 test geçti**; 11 gerçek, geçici PostgreSQL
  senaryosu, 62 HTTP yetkilendirme vakası ve 6 katı tam sayı JSON sözleşmesi.
- Medya ve ortak altyapı kapsamı: ayrı koşularda **75 hedefli test geçti**;
  21 yeni medya vakası ve gerçek PostgreSQL kota yarışı/migration/yeniden
  oluşturulan profil kontrolleri dahildir. Son PostgreSQL tekrar koşusu da geçti.
- Backend derlemesi ve iki repository'nin `git diff --check` kontrolü geçti.

İlk otomatik doğrulama aşamasında gerçek cihaz yolculuğu henüz yürütülmemişti.
20 Eylül'deki manuel QA'da mevcut müzisyen oturumunda gerçek cihaz, çalışan yerel
API ve depolama üzerinden fotoğraflı ilan oluşturma, yayınlama, düzenleme,
yayından kaldırma/yeniden yayınlama ve satıldı geçişi tamamlandı.
[Manuel QA raporu](marketplace-manual-qa-2026-09-20.md) kanıtları ve kalan rol/ağ
senaryolarını içerir. Üretime dağıtım yapılmadı; yerel test ilanları kullanıcı
incelemesi için korunuyor.

### Yerel cihaz hazırlığı — 20 Eylül 2026

- İki migration mevcut yerel PostgreSQL'e uygulandı; 13 grup ve 112 alt kategori doğrulandı.
- Mevcut IntelliJ backend'i (8080) ve Android Studio'nun bağlı telefon oturumu kullanıldı.
- Cihaz kontrolünde bulunan kullanıcı sütunu uyumsuzluğu (`user_name`) düzeltildi;
  gerçek şemaya uyarlanan 11 PostgreSQL testi yeniden geçti.
- İlk hazırlık kontrolünde Pazar'ın kategorileri, boş liste ve yeni ilan formu açıldı.
  Sonraki manuel QA'da fotoğraf içeren iki test ilanı oluşturuldu: biri yayında, diğeri
  satıldı durumunda korundu.
- Yerel backend sağlık kontrolü başarılı. Müzisyen oturumundaki tamamlanan cihaz
  akışları manuel QA raporunda; diğer roller ve kesinti/çakışma senaryoları bekliyor.

### Tasarım uyumu — 20 Eylül 2026

- Pazar'a özel tema kapsamı, Collab'ın da kullandığı ortak `BackstagePalette`
  yüzeylerini ve mevcut marka gradient/çerçeve bileşenlerini kullanır.
- Ana ekran, ilan kartları, detay, editör, filtre, şikâyet ve koleksiyon
  ekranlarının tipografi, aralık ve aksiyon hiyerarşisi birlikte düzenlendi.
- Editör bölümlere ayrıldı; kaydetme/önizleme aksiyonları sabit alt alana taşındı.
  Dar ekranda marka/model alanları alt alta gelir. Fiyatlar açık ve koyu temada
  yüksek kontrastlı metinle gösterilir.
- 320/390 piksel, açık/koyu tema ve büyük metni içeren 48 görsel senaryo geçti.
  Örnek ilanlar yalnız test verisidir. Mevcut 17 Pazar davranış testi de geçti.
- Mevcut Collab/stüdyo ekranları ve Pazar'ın iş kuralları değiştirilmedi.

### Kategori gezinmesi — 20 Eylül 2026

- Ana ekran, filtre ve ilan formu ortak, iki seviyeli kategori seçicisini kullanır.
  Ana kategoriye dokunmak alt ürün türlerini açar; kök listede alt türler sıralanmaz.
- Filtrede tüm kategoriler, bir grubun tüm ilanları veya belirli bir ürün türü
  seçilebilir. İlan formu yalnız alt ürün türünü kabul eder.
- Seçim yeniden açılınca mevcut dal korunur. Geri düğmesi ana gruplara döner;
  kapatma/iptal mevcut filtreyi değiştirmez. Seçilen alt türün tam yolu gösterilir.
- Türkçe karakterlerle arama desteklenir. Klavye açıkken başlık ve sonuçlar birlikte
  kayabilir; 640×360 ekran, 200 piksel klavye ve 2× yazı ölçeği testi geçti.
- Son düzenlemeden sonra 14 kategori ve 11 ekran testi geçti; Pazar modülü ve ilgili
  testlerin analizi temiz. Mevcut telefon oturumunda ana ekran, filtre ve ilan formu
  üzerinde grup/alt tür, geri dönüş ve seçili dal görsel olarak kontrol edildi.
- Mevcut kategori API'si kullanıldı; Backline, Instrument veya veritabanı değişmedi.
- Ana ekranda `Kategoriler` düğmesi satırın başında sabit kalır; yalnız sağdaki hızlı
  kategori düğmeleri yatay kayar. Genel düğme seçili alt türü koruyarak ana grupları
  açar; `Tüm kategoriler` seçimi diğer filtreleri değiştirmeden kategoriyi temizler.
  Bu erişim değişikliğinden sonra 27 kategori/ekran testi ve analiz geçti; 320 piksel
  genişlikte 1,5× yazı, yatay kaydırma ve mevcut telefon oturumu kontrol edildi.

### Kalite denetimi — 20 Eylül 2026

Gerçek test hesaplarıyla rol/sahiplik, S3 fotoğraf, stüdyo yayınlama, kaydetme,
satıcı bağlantıları ve yönetici moderasyonu denetlendi. Çift pencere/çift geri
dönüş, değişen şikâyet retry anahtarı ve medya temizliği saat bağlama sorunu
düzeltildi. Son frontend regresyonu 225/225, backend kritik PostgreSQL/güvenlik
regresyonu 51/51 (0 atlama), CI rapor doğrulayıcısı 5/5; analiz temiz.
[Kapsam, telefon kanıtları ve kalan yayın öncesi işler](marketplace-quality-audit-2026-09-20.md).
