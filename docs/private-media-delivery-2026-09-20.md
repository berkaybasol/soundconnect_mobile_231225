# Özel görsel teslimi — 20 Eylül 2026

Bu çalışma, özel görsellerin her ekranda tekrar indirilmesini azaltır ve mevcut
korumalı medya altyapısına küçük görsel üretimini ekler. Mevcut S3 teslim yolu
korunur; özel medya için CloudFront bu değişikliğin kapsamında değildir.
Çalışma zamanı ölçümleri ve cihaz karşılaştırması tamamlandı:
[sonuçlar](photo-loading-investigation-2026-09-20.md#onay-sonrası-uygulanan-iyileştirme-ve-tekrar-ölçümü).
49 frontend testi, odaklı analiz, 185 backend testi ve ek 24 odaklı kontrol
geçti. Aynı telefonda beş gösterimde iki storage GET ve %77,35 daha az görsel
transferi ölçüldü. Bu belge kullanıcı kapasitesi veya yük altında performans
iddiası içermez.

## İstemci sözleşmesi

- Her yeni görsel yükleme/gösterim yetkisi önce mevcut `getAccess` API'sinden
  alınır. RAM'deki baytlara ulaşmak sunucu yetkilendirmesinin yerini tutmaz.
  Ret veya kimlik değişimi sonrası eski görsel gösterilmez.
- `PrivateMediaImageCache`, HTTP yanıtı veya izin sonucunu saklamaz. Yalnız
  immutable nesnenin kodlanmış görüntü baytlarını uygulama içinde tekrar
  kullanır. Anahtar varlık, gerçek varyant, erişim modu ve imzasız immutable
  nesne yolunu içerir; tüm depo tek `AuthSession` nesnesine bağlıdır. Normal
  marketplace ve moderatör erişimi ayrıdır.
- Tamamlanmış signed URL sonuçları cache edilmez. İndirme sürerken URL yalnız
  o işin belleğinde tutulur; diske, kullanıcı hatasına veya loga yazılmaz.
  S3 indirmesi uygulamanın Bearer token'ını taşıyan API istemcisini kullanmaz.
- Kodlanmış bayt deposu 24 MiB / 64 kayıt LRU sınırındadır. En çok 4 paralel
  indirme ve 64 bekleyen iş vardır; her dosyada sunucuyla aynı 20.000.000 byte
  sınırı akış okunurken de uygulanır. İndirme zaman aşımı 30 saniyedir.
  Bu sınırlar, aktif indirmeler ve Flutter'ın çözülmüş görüntü belleği dahil
  toplam uygulama RAM'i için bir üst sınır değildir.
- Bir kaydın ömrü indirme yetkisinin ve oturumun bitişinden kısa olanını aşmaz.
  Logout/oturum değişimi, arka plana geçiş, bellek baskısı ve dispose RAM
  deposunu temizler. İş nesli kontrolleri geç biten indirmelerin eski veriyi
  geri koymasını engeller. Yeniden öne gelince yeni sunucu yetkisi alınır.
- Görsel widget'ı yetki sona erince kendi baytlarını ve tam `MemoryImage` /
  `ResizeImage` anahtarlarını temizler; yalnız kodlanmış depoyu temizlemek
  Flutter'ın çözülmüş görüntü cache'ini temizlemeye yetmez. Decode boyutu ekran
  alanına göre sınırlanır. Küçük görsel henüz üretilmemişse orijinal kullanılır;
  ayrıntı/orijinal tercihi ayrı varyanttır.

Signed GET yanıtındaki `private, no-store, max-age=0` korunur. `no-store`,
HTTP cache'lerinde kalıcı depolamayla birlikte sonraki isteği karşılamak için
RAM'de saklamayı da sınırlar. Buradaki davranış, aynı kullanıcı ve erişim
bağlamında her kullanım için yeni yetki gerektiren, HTTP üstündeki açık uygulama
sözleşmesidir. Genel HTTP cache veya çevrimdışı dosya cache'i değildir.
[RFC 9111 §5.2.2.5](https://www.rfc-editor.org/rfc/rfc9111.html#section-5.2.2.5)
ve [§6](https://www.rfc-editor.org/rfc/rfc9111.html#section-6) bu ayrımı açıklar.

## Sunucu ve depolama sınırı

Yeni küçük görsel, doğrulanmış özel `READY IMAGE` kaynağının aynı immutable
attempt dizinine `thumbnail.jpg` olarak yazılır. DB yalnız
`thumbnail_storage_key` tutar; kalıcı özel URL tutulmaz. Worker işlemi
istek yolundan ayrıdır. Kaynak/visibility/status eşleşmeli CAS, silme sırasında
geç tamamlanan işi bağlamayı engeller; aynı türevi bağlayan ikinci worker
kazanan dosyayı silmez. Orphan temizliği kazanan attempt alt ağacını korur.

Orijinalle aynı modül ACL'si geçildikten sonra yalnız kaynağa ait doğrulanmış
türev anahtarı imzalanır. Özel bucket anahtarları public CDN URL'sine dönüşmez.
Silme akışı thumbnail üreticisinin sınırlı çalışma süresini bekler ve özel
türevi mevcut dayanıklı silme işiyle temizler. Rapor kanıtı referansları
mevcut korumasını sürdürür.

Signed URL, süresi dolana kadar sahibine erişim sağlayan bir capability'dir;
uygulamada erişimin kaldırılması daha önce verilmiş URL'yi anında iptal etmiş
olmaz. Bu değişiklik mevcut kısa imza süresini uzatmaz. Uygulama TTL'si yanıtın
gerçek bitiş zamanını kullanır; imzalayan geçici kimlik daha erken biterse
indirme daha erken reddedilebilir.
[AWS presigned URL davranışı](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html).

## Canlı S3 incelemesi

20 Eylül 2026'da yalnız GET/HEAD metadata çağrıları yapıldı; policy, ACL, IAM,
nesne, CDN veya faturalandırma ayarı değiştirilmedi. Nesne adları, kullanıcı
kimlikleri, erişim anahtarları ve signed URL'ler rapora alınmadı.

| Kontrol | Sonuç |
| --- | --- |
| Public içerik bucket'ı ve özel bucket bölgesi | İkisi de `eu-central-1` |
| Bucket düzeyindeki dört Block Public Access bayrağı | İki bucket'ta da `true` |
| Public içerik bucket'ının policy durumu | `IsPublic=false` |
| Özel bucket policy durumu | `NoSuchBucketPolicy`; bucket düzeyi public engelleri açık |
| Dar public nesne örneği, S3 HEAD | JPEG, 100.730 byte, 200, yaklaşık 235 ms |
| Aynı public örnek, CloudFront HEAD | 200, yaklaşık 640 ms, `Miss from cloudfront`, `ARN56-P2` |
| Dar özel nesne örneği, S3 HEAD | JPEG, 314.980 byte, 200, yaklaşık 188 ms |
| Örneklerin kalıcı `Cache-Control` metadata'sı | İkisinde de yok |
| CloudFront distribution/cache policy okuması | IAM `AccessDenied` (403); gerçek TTL/OAC ayarları doğrulanamadı |

Public içerik adı, bucket'ın doğrudan herkese açık olması demek değildir;
örnek dosya CDN üzerinden erişilebilirken bucket policy public görünmüyordu.
Block Public Access'in anlamı için
[AWS belgesi](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html).
Bu tek bilgisayardan alınmış dar HEAD örnekleri tam indirme, telefon codec
süresi veya bölgesel kullanıcı deneyimi ölçümü değildir.

Kaynak kod yeni public türevlerde `max-age` değerini 300 saniye,
`s-maxage` değerini 3.600 saniye ile sınırlar ve `immutable` direktifini
kaldırır. Bu kod eski nesne metadata'sını geriye dönük değiştirmez. İki
örnekte header olmaması tüm nesnelerin aynı olduğu anlamına gelmez. CDN
Minimum/Default/Maximum TTL değerleri görülmeden gerçek saklama süresi
çıkarılamaz; özellikle Minimum TTL etkisi ayrıca kontrol edilmelidir.
[CloudFront süre yönetimi](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Expiration.html).

## Yayına alma ve sonraki doğrulama

1. Additive `2026-09-20-protected-image-thumbnails.sql` migration'ını uygula;
   worker DB sütun izinlerini ve sınırlı özel thumbnail `PutObject` /
   `DeleteObject` IAM yollarını güncelle. Eski worker'ları durdur/drain et.
2. Özel küçük görsel üretimini açmadan önce **tüm API ve silme worker
   node'larını** yeni üretici bekleme sınırını uygulayan sürüme geçir. Eski
   API/silme worker'ı ile yeni özel thumbnail üreticisi karışımı desteklenmez.
3. Güncel image worker'ı aç; bounded backfill, kaynak fallback ve silme
   akışını doğrula. Ardından frontend'i yayınla. Rollback'te önce yeni üreticiyi
   durdur/drain et; additive alanı aceleyle kaldırma. Ayrıntılı worker izinleri
   backend `docs/MediaModule/IsolatedMediaWorker.md` içindedir.
4. Yetki reddi, hesap değişimi, arka plan, süre aşımı, geç tamamlanan indirme,
   moderator ayrımı, thumbnail/orijinal ve silme yarışlarını test sonuçlarıyla
   doğrula. Cihazda soğuk/sıcak açılış ve yenilemede API süresini, indirilen
   byte'ı, storage isteği sayısını ve ekran akıcılığını ayrı karşılaştır.

Öncelik önce doğru türev boyutu, worker üretim gecikmesi ve tekrar indirmenin
ölçülmesidir. Sonraki altyapı incelemesinde public CDN'nin gerçek cache policy'si,
eski nesne header'ları, hit oranı, coğrafi gecikme ve egress maliyeti birlikte
değerlendirilmelidir. Özel CloudFront gerekirse ayrı bir erişim/iptal ve origin
koruma tasarımıyla ele alınır; public bucket/ACL açmak veya yetki kontrolünü
cache'lemek performans çözümü değildir.
