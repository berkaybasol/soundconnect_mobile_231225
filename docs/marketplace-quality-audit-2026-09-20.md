# Pazar kalite denetimi — 20 Eylül 2026

Bu tur mevcut 8080 backend'i, bağlı Vivo V2206 ve kullanıcının test hesaplarıyla
yürütüldü. Önceki müzisyen ilanları ve fotoğrafları korundu. Ayrı backend veya
uygulama portu açılmadı. Otomatik PostgreSQL testleri ayrı Testcontainers
veritabanlarında çalıştı; canlı uygulama veritabanı test fixture'ı olmadı.

## Bulunan ve düzeltilen sorunlar

1. Aynı anda iki önizleme, durum onayı veya şikâyet penceresi açılabiliyordu.
   İşlem kilidi pencere açılmadan alınır; tekrar giriş engellenir.
2. Önizlemedeki çift onay/geç cevap alttaki ekranı da kapatabiliyordu.
   Kapatma yalnız işlemin hâlâ aktif olan rotasına uygulanır.
3. Hata sonrasında şikâyetin içeriği değiştirilince eski idempotency anahtarı
   kullanılıyordu. Aynı içerikli tekrar aynı anahtarı, değişen içerik yeni
   anahtarı kullanır.
4. Medya temizlik adaylarının raw JDBC tarih bağlaması ORM audit zamanı ile
   farklı saat hesabına girebiliyordu. New York saat dilimindeki gerçek PG
   testi 24 saati geçmiş sahipsiz fotoğrafın temizliğinin geciktiğini gösterdi.
   Aday sorgusu artık ORM ile aynı tarih bağlama yolunu kullanır. UTC,
   İstanbul ve New York testleri geçti; genel saat ayarı/veri değiştirilmedi.
5. CI, Docker olmadığında kritik testleri atlayarak yeşil kalabiliyordu.
   Altı zorunlu suite'in gerçekten çalıştığı, boş/eksik/başarısız/atlanmış
   olmadığı XML raporlarından denetlenir.

## Otomatik kanıt

| Kontrol | Sonuç |
| --- | --- |
| Frontend birleşik regresyon | **225/225 geçti** |
| Tüm `lib` ve iki yeni test dosyasının analizi | **Sorun yok** |
| Backend altı kritik PostgreSQL/güvenlik suite'i | **51/51 geçti, 0 atlama** |
| CI rapor doğrulayıcısının regresyonları | **5/5 geçti** |

Frontend'e eklenen 21 test; çift dokunma, kayıp create/update/publish cevabı,
sürüm çakışması, kaydedilmiş fotoğrafın hatalı temizlenmemesi, kaydetme/şikâyet
tekrarları, 41 ilanlı sayfalama, ikinci sayfa hatası ve eski sorgu cevaplarını
kapsar. Birleşik koşuya ortak özel fotoğraf cache'i, upload/recovery/cleanup,
router, dinleyici alt menüsü ve yönetici paneli testleri de dahildir.

Backend 51 testin dağılımı: gerçek JWT/filter→servis→PG **9**, domain ve
eşzamanlı işlemler **20**, medya kotası **3**, JPA/JDBC işlem bütünlüğü **10**,
özel thumbnail yaşam döngüsü **7**, worker veritabanı yetkileri **2**.
Gerçek transaction rollback/commit hatası ve yarışlar sınanır; dış S3/codec
bağımlılıkları dar entegrasyon fixture'larında fake'tir. Gerçek S3 yüklemeleri
ayrıca aşağıdaki uygulama testinde yapıldı.

Kanıtlar: [frontend logu](../tmp/marketplace-quality-frontend-tests.log),
[analiz](../tmp/marketplace-quality-frontend-analyze.log),
[backend birleşik log](../../SoundConnect-Backend/tmp/marketplace-quality-backend-final.log),
[medya transaction raporu](../../SoundConnect-Backend/docs/MediaModule/MarketplaceMediaTransactions.md).

## Mevcut backend ve telefon kontrolleri

| Akış | Kanıtlanan sonuç |
| --- | --- |
| Dinleyici, anonim ve geçersiz JWT | Pazar API'si ve özel fotoğraf erişimi reddedildi. Dinleyici telefonda Pazar düğmesi görmedi. |
| Stüdyo ve mekân sahipliği | Kendi taslağı/ilanı görüldü; başka hesabın taslağı, taslak fotoğrafı ve ilan düzenlemesi reddedildi. |
| Gerçek fotoğraf | İki yeni özel JPEG mevcut S3 üzerinden yüklendi, READY oldu ve kendi taslaklarına bağlandı. |
| Taslak retry | Aynı istek kimliği ikinci ilan üretmedi. |
| Stüdyo yayınlama | Telefonda önizleme→yayınlama geçti; API PUBLISHED durumunu doğruladı. |
| Mekân yayınlama | Gerçek API ile yayınlandı; tekrarlanan yayınlama sürümü artırmadı. Telefonda İlanlarım yalnız mekân kaydını gösterdi. |
| Kaydetme | Stüdyo, mekân ilanını telefondan kaydetti; API koleksiyonunda doğrulandı. |
| Satıcı bağlantıları | Mekânın doğru profili ve doğru boş mesaj ekranı açıldı. Mesaj gönderilmedi. |
| Şikâyet | Stüdyo telefondan yeni mekân QA ilanını şikâyet etti; yönetici kuyruğunda bir OPEN kayıt görüldü. |
| Kanıt bütünlüğü | Satıcı sonradan başlığı değiştirince şikâyet anındaki eski başlık/fotoğraf korundu. |
| Yönetici kararı | Telefonda gerekçe girilip yeni mekân QA ilanı MODERATED yapıldı. Karar ACTIONED filtresinde kalıcı; aynı review isteği ikinci sürüm/karar üretmedi. |
| Karardan sonra erişim | İlan ana listeden/kaydedilenlerden çıktı. Alıcı detay ve fotoğraf için yeni grant alamadı; yönetici kanıt fotoğrafına erişebildi. |
| İşlem yapmadan kapatma | Yeni stüdyo QA ilanına ikinci kontrollü rapor API ile oluşturuldu. Aynı UUID retry tek rapor verdi; DISMISS ilanı PUBLISHED v4 bıraktı. |
| Geçersiz veri | Negatif/fractional kuruş, başka ilanın fotoğrafı ve eski sürüm reddedildi; başarısız istekler kayıt/fotoğrafı değiştirmedi. |

Telefon örnekleri: [yayınlanan stüdyo ilanı](../tmp/marketplace-manual-qa/quality-21-studio-published.png),
[kaydedilen ilan ve alıcı aksiyonları](../tmp/marketplace-manual-qa/quality-24-buyer-actions.png),
[satıcı mesaj hedefi](../tmp/marketplace-manual-qa/quality-25-seller-chat.png),
[mekânın kendi ilanları](../tmp/marketplace-manual-qa/quality-33-venue-ownership.png),
[dinleyici görünümü](../tmp/marketplace-manual-qa/quality-36-listener-home.png),
[yönetici kanıt fotoğrafı](../tmp/marketplace-manual-qa/quality-40-report-evidence.png),
[kalıcı karar](../tmp/marketplace-manual-qa/quality-45-admin-resolved.png).

Yönetici hesabının kayıtlı adı `basol` olarak doğrulandı; verilen şifreyle hem
API hem telefon girişi başarılı oldu. Şifreler rapora veya yardımcı dosyalara
yazılmadı. Test sonunda telefon önceki `bugrasahin` müzisyen hesabına döndü;
[son Pazar ekranında](../tmp/marketplace-manual-qa/quality-47-restored-musician.png)
stüdyo QA ilanı ve önceki gitar görünür, moderasyon uygulanan mekân ilanı yoktur.

Ham, hassas veri içermeyen kontrol günlüğü
[`quality-api-results.jsonl`](../tmp/marketplace-manual-qa/quality-api-results.jsonl)
96 gözlem içerir. İki ilk kontrol test yürütücüsü kaynaklıdır ve sonraki
kontrollerde açıklanıp doğrulanmıştır: bir cihaz adımında yayın yerine taslak
kaydetme düğmesine basılması ve moderasyon durum adının yanlışlıkla REMOVED
beklenmesi (gerçek sözleşme MODERATED). Bunlar uygulama arızası olarak sayılmadı;
ham geçmişten silinmedi. Son yayınlama ve moderasyon kontrolleri geçti.

## Ortam gözlemi

İlk izole Gradle denemesinde yalnız build dizinini ayırmak yetmedi; geliştirme
çıktıları değişip DevTools yenilemesi tetiklendi. Telefonun yayın isteği ağ
hatasına düştü; taslak ve fotoğraf korundu. Sonraki testler ayrı Gradle proje
önbelleği, açık çıktı dizinleri ve kök dışına yazmayı engelleyen kontrolle
çalıştırıldı. Mevcut backend aynı PID/8080 üzerinde toparlandı. Başlangıçta
LocationSeeder'ın 85 saniyelik çalışması sırasında readiness 503 gözlendi;
başlangıç tamamlanınca readiness 200 oldu. Geçici teşhis log ayarı kaldırıldı.

Bu olay bir üretim kapasite ölçümü değildir. Yerel debug/DevTools başlangıç
maliyeti gerçek kullanıcı yüküyle karıştırılmamalıdır.

## Korunan QA kayıtları ve sınırlar

- Önceki gitar: `b99f5411-94c3-4502-99ba-2de5e8f4d513`, PUBLISHED v8, iki fotoğraf.
- Önceki pedal: `7cf023f3-c9c2-4770-a1de-78d64f7256e0`, SOLD v3, bir fotoğraf.
- Yeni stüdyo: `f9459e9a-1623-4921-885b-2bfd6ac64842`, PUBLISHED v4, bir fotoğraf.
- Yeni mekân: `fe344839-e7cf-4f73-a96c-442f5460ac45`, MODERATED v4, bir fotoğraf.
- Kontrollü şikâyet: `616b7cbc-35a9-4c47-8a71-8be45d3c8d2e`, ACTIONED v1.
- Kapatılan kontrollü şikâyet: `a3c1969c-dfc2-4b2a-b2b5-6e24b34ee782`, DISMISSED.

Son kontrol: mevcut backend readiness **200**, dinleyici Pazar API erişimi
**403**. Dört ilan ve beş fotoğraf kendi hesaplarında/kanıt referanslarında
korundu. Yeni mekân ilanının görünmemesi test edilen moderasyon sonucudur;
fiziksel silme değildir. Geçici kimlik doğrulama/VM bağlantı dosyaları temizlendi.

Kullanıcı incelemeden ilan/fotoğraf temizliği yapılmadı. Bu rapor production
quality için test edilen kapsamı belgeler; on binlerce eşzamanlı kullanıcı
garantisi değildir. Staging'de release build, hedef trafikle yük/soak testi,
gerçek worker/S3 gecikmeleri, dağıtım/rollback ve izleme kontrolleri yayın
öncesinde ayrıca yapılmalı. Bu tur tüm uygulamanın uçtan uca onayı değildir.
