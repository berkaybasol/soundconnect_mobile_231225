# Ekipman Pazarı — manuel QA, 20 Eylül 2026

Gerçek Android telefonda mevcut müzisyen oturumu ve çalışan `8080` servisi kullanıldı. Ayrı servis veya yeni port açılmadı. Bu rapor tamamlanan kontrolleri, kalan kapsamı ve korunacak test verisini kaydeder.

**Kullanıcı incelemeden test ilanları veya fotoğrafları temizlenmeyecek.** Yayından kaldırma ve yeniden yayınlama kontrollerinde kayıtlar korundu; veri temizliği yapılmadı.

## Tamamlanan telefon akışları

| Akış | Sonuç ve kanıt |
| --- | --- |
| Eksik ilanı taslak kaydetme, İlanlarım üzerinden yeniden açma | Geçti. Taslak devam ettirildi. [Taslak sonucu](../tmp/marketplace-manual-qa/04-draft-result.png), [İlanlarım](../tmp/marketplace-manual-qa/05-mine.png). |
| Zorunlu alanlar ve fotoğrafsız yayın/kayıt kontrolü | Geçti. Eksik bilgilerle yayın engellendi; yayındaki ilanın bütün fotoğraflarını yerelde kaldırınca kayıt da engellendi. [İlk doğrulama](../tmp/marketplace-manual-qa/01-empty-validation.png), [Fotoğrafsız kayıt engeli](../tmp/marketplace-manual-qa/32-published-no-photos-blocked.png). |
| Gerçek fotoğraf yükleme ve kapak sırası | İki JPEG yüklendi. Yerel seçiciyi iptal etme/yeniden açma, sıralama ve kaydetme geçti. [Yükleme sonucu](../tmp/marketplace-manual-qa/13-upload-result.png), [Kaydedilen fotoğraflar](../tmp/marketplace-manual-qa/15-photos-saved.png). |
| Önizleme, yayınlama ve yeniden açılışta kalıcılık | Geçti. Önizleme incelendi; yayınlanan ilan ana listede göründü ve uygulama yeniden başlatıldıktan sonra korundu. [Yayın onayı önizlemesi](../tmp/marketplace-manual-qa/27-preview-confirm.png), [İlk yayın sonrası ana ekran](../tmp/marketplace-manual-qa/29-published-home.png). |
| Yayındaki ilanın fiyatını ve kapağını düzenleme | Geçti. Son fiyat 11.999,90 TL; ilk fotoğraf gitar olacak şekilde düzenlendi. [Düzenleme](../tmp/marketplace-manual-qa/35-price-cover-edit.png). |
| Kaydedilmemiş değişiklikten çıkış | Geçti. Fotoğrafları yerelde kaldırdıktan sonra kayıt engellendi; düzenlemeye devam etme ve değişiklikleri bırakma denendi. Bırakınca kaydedilmiş fotoğraflar geri geldi. [Korunan kayıt](../tmp/marketplace-manual-qa/34-discard-restored.png). |
| Yayından kaldırmayı iptal etme ve onaylama | Geçti. İptal durumu değiştirmedi. Onaylanan ilan ana pazardan çıktı, İlanlarım içinde kaldı. [Onay penceresi](../tmp/marketplace-manual-qa/36-withdraw-dialog.png), [Ana pazardan çıkış](../tmp/marketplace-manual-qa/38-withdrawn-discovery-empty.png), [İlanlarım kaydı](../tmp/marketplace-manual-qa/39-withdrawn-mine.png). |
| Yeniden yayınlama | Geçti. Kaldırılan ilan düzenleme/önizleme üzerinden yeniden yayınlandı; ilk yayın zamanı değişmedi. [Yeniden yayın sonrası ekran](../tmp/marketplace-manual-qa/41-republished-home.png). |
| İkinci ilanı sıfır ürün olarak yayınlama | Geçti. Efekt pedalı, 2.500,00 TL, Ankara/Çankaya, kargo tercihi ve bir gerçek fotoğrafla yayınlandı. [Yayın sonucu](../tmp/marketplace-manual-qa/56-second-published.png). |
| Fiyat sıralaması | Geçti. Artan sırada pedal önce, azalan sırada gitar önce geldi. [Artan](../tmp/marketplace-manual-qa/59-sort-ascending-result.png), [Azalan](../tmp/marketplace-manual-qa/60-sort-descending-result.png). |
| Ürün durumu, fiyat ve şehir filtreleri | Geçti. Sıfır yalnız pedalı, ikinci el yalnız gitarı; 3.000 TL üst sınırı ve Ankara seçimi yalnız pedalı getirdi. [Sıfır](../tmp/marketplace-manual-qa/61-condition-new-result.png), [İkinci el](../tmp/marketplace-manual-qa/62-condition-used-result.png), [Fiyat](../tmp/marketplace-manual-qa/64-price-ceiling-result.png), [Şehir](../tmp/marketplace-manual-qa/72-city-filter-visible-result.png). |
| Sabit kategori seçici ve arama | Geçti. Gitar ve Bas → Elektro gitar yalnız gitarı getirdi. Bu kategoriyle Pedal araması boş sonuç verdi; filtreler temizlenince arama metni korundu ve pedal bulundu. [Kategori](../tmp/marketplace-manual-qa/67-leaf-category-result.png), [Birleşik boş sonuç](../tmp/marketplace-manual-qa/68-search-pedal-result.png), [Yalnız arama](../tmp/marketplace-manual-qa/69-cleared-category.png). |
| Satıcı profil bağlantısı | Mevcut müzisyen profilini açtı; geri dönüş çalıştı. Farklı hesaplarla kontrol edilmedi. |
| Satıldı geçişi ve koleksiyonlar | İptal durumu korudu; onayla pedal `SOLD` oldu ve pazardan çıktı. Düzenleme/yayınlama düğmeleri yerini durum bilgisine bıraktı. İlanlarım içinde iki kayıt korundu; Satıldı ve Yayında sekmeleri doğru ilanları ayırdı. [Satıldı detayı](../tmp/marketplace-manual-qa/76-sold-result.png), [İki kayıt](../tmp/marketplace-manual-qa/78-two-retained-listings.png), [Satıldı sekmesi](../tmp/marketplace-manual-qa/79-sold-collection-filter.png), [Yayında sekmesi](../tmp/marketplace-manual-qa/80-published-collection-filter.png). |
| Son düzeltmelerin gerçek cihazda kontrolü | Mevcut Flutter oturumuyla hot restart yapıldı; yeni port açılmadı. Arama → klavyeyi gizle → aramayı temizle → filtreyi aç/kapat sonrasında klavye kapalı kaldı. Açıklama odağı gizliyken il seçimi de eski klavyeyi açmadı. İstanbul/Kadıköy'den Ankara'ya geçince ilçe temizlendi; kaydetmeden vazgeçilerek asıl konum korundu. [Ana ekran odağı](../tmp/marketplace-manual-qa/82-home-keyboard-fixed.png), [Editör odağı ve ilçe sıfırlama](../tmp/marketplace-manual-qa/85-editor-keyboard-district-reset-fixed.png), [Güncel çıkış metni](../tmp/marketplace-manual-qa/86-corrected-discard-copy.png), [Korunan son kayıtlar](../tmp/marketplace-manual-qa/87-final-retained-data.png). |

Kanıt bağlantıları uygulama içi ekranlarla sınırlıdır. Telefonun kişisel fotoğraf galerisini gösteren seçici ekranları bu rapora eklenmedi.

## Kullanıcının incelemesi için korunacak kayıt

| Alan | Son doğrulanan değer |
| --- | --- |
| İlan kimliği | `b99f5411-94c3-4502-99ba-2de5e8f4d513` |
| Durum / sürüm | `PUBLISHED` / `8` |
| Fiyat | `1199990` kuruş — **11.999,90 TL** |
| Ürün durumu | `USED` — İkinci el |
| Konum | İstanbul / Kadıköy |
| Teslim | `PICKUP` — Elden teslim |
| Pazarlık | Açık |
| Fotoğraflar | 2 adet; gitar ilk sırada ve kapak |
| İlk yayın zamanı | `00:53:03.055783 UTC`; yeniden yayınlamada değişmedi |

İkinci ilan **QA TEST - Pedal 2**, kimlik `7cf023f3-c9c2-4770-a1de-78d64f7256e0`: **SOLD / sürüm 3**, 199 karakter açıklama, bir fotoğraf, `NEW`, `250000` kuruş (2.500,00 TL), Ankara / Çankaya, `SHIPPING`, pazarlık kapalı. İlk yayın zamanı `01:11:43.902969 UTC` korundu. Son salt okunur veritabanı kontrolü `01:20:39 UTC` itibarıyla her iki kaydı doğruladı.

Üç bağlı fotoğraf da `READY / IMAGE / PRIVATE / BACKSTAGE`; kalıcı public URL alanları boş. Fotoğraf dosyaları telefonda `Pictures/SoundConnectQA` içinde ve çalışma alanındaki `tmp/marketplace-manual-qa/assets` klasöründe korunuyor. Açık lisans kaynakları ve sahiplik bilgileri [MANIFEST.md](../tmp/marketplace-manual-qa/assets/MANIFEST.md) dosyasında; ilan açıklamaları gerçek satış olmadığını belirtir.

## Bulunan ve giderilen sorunlar

- **Kapak etiketi kırpılması:** 128 px fotoğraf kutusunda iki sıra oku arasına sığmayan `Kapak` yazısı fotoğraf üstünde ayrı rozete taşındı. Kaldırma düğmesiyle çakışmıyor; sıra oklarının dokunma alanları 48×48 px.
- **Büyük yazıda pazarlık metni taşması:** Detaydaki `Pazarlığa açık` metni esnek alana alındı. 320 px genişlik ve 2× yazıda taşma giderildi.
- **Yayındaki ilan için yanlış çıkış açıklaması:** Metin artık “Kaydedilmemiş değişikliklerin bırakılır. Son kaydettiğin ilan veya taslak korunur.” şeklinde.
- **Seçim penceresinden sonra eski klavyenin geri açılması:** Editörde kategori, il, ilçe, önizleme ve yerel fotoğraf seçici; ana ekranda filtre, kategori ve sayfa geçişleri; filtrede iç seçimler açılmadan önce gerçek odak düğümü bırakılıyor. İl/ilçe/kategori seçimi, önizleme ve gezinme dönüşlerinde eski odağın ve klavyenin geri gelmediği regresyon testleriyle doğrulandı. Ana ekran filtre dönüşü ve editörde il seçimi ayrıca güncel kodla telefonda tekrar geçti.

## Otomatik doğrulama

Son birleşik koşu **33/33 geçti**: 14 kategori seçici ve 19 ekran testi. `lib/modules/marketplace`, `test/marketplace_category_picker_test.dart` ve `test/marketplace_widget_test.dart` için son odaklı analizde sorun bulunmadı. Son telefon kontrolünden sonra uygulamanın yakın tarihli 500 log satırında Flutter hata, RenderFlex taşma veya yakalanmamış/fatal exception işareti bulunmadı; bu tarama önceki bütün oturumlar için garanti değildir.

Kapsam; kategori hiyerarşisi/arama/geri dönüş, sabit Kategoriler düğmesi, yalnız kategori filtresinin sıfırlanması, filtrelerin korunması, taslak kaydı, 320 px normal/2× yazıda fotoğraf sıralama ve kaldırma, oturum değişimi, özel fotoğraf görünürlüğü ve seçim/önizleme dönüşünde klavye odağını içeriyor.

## Henüz manuel doğrulanmayan kapsam

Bu bölüm ilk müzisyen turunun tarihsel sınırıdır. Aynı gün tamamlanan ek
[kalite denetimi](marketplace-quality-audit-2026-09-20.md), gerçek stüdyo/mekân/
dinleyici/yönetici oturumlarını, kaydetme, doğru satıcıya mesaj ekranı açma,
şikâyet, moderasyon ve kesinti/çakışma regresyonlarını ayrıca belgeler.

- Stüdyo, mekân ve dinleyici rolleriyle ayrı gerçek oturumlar.
- Farklı hesaplar arasında kaydetme/kayıttan çıkarma, satıcıya mesaj ve şikâyet akışları; mesaj veya şikâyet gönderilmedi.
- Ağ kesintisi, yükleme sırasında bağlantı kaybı ve eşzamanlı düzenleme/çakışma senaryoları.
- Moderasyon işlemleri.

## Backend gözlemi

Mevcut backend health/readiness `UP`; PostgreSQL, Redis ve RabbitMQ sağlıklı. Bu QA sırasında backend kodu, saat dilimi ayarı veya doğrudan veritabanı verisi değiştirilmedi; ilan değişiklikleri uygulama üzerinden yapıldı.

Ayrı teknik takip: yerel JVM–JDBC saat dilimi birleşimi medya ham zaman alanlarında üç saatlik sapma oluşturuyor. ORM dönüşümü mevcut upload/verify kontrollerinde bunu dengeliyor. Ham JDBC temizlik aday seçimi ile ORM yaşam döngüsü kontrolünün aynı zamanı kullandığı ayrıca incelenmeli; bu testte erken süre bitişi veya erken fotoğraf silme gözlenmedi. Bu gözlem global saat dilimini değiştirmek için yeterli kabul edilmedi.

Bu sonuçlar müzisyen oturumundaki belirtilen akışlarla sınırlıdır; tüm roller için tamamlanmış manuel kabul testi anlamına gelmez.
