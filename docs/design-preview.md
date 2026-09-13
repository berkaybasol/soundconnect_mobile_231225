# SoundConnect Önizleme

Android tasarım önizlemesi, normal SoundConnect ile telefona yan yana kurulur.
Normal uygulamanın oturumunu veya verilerini kullanmaz. Geçiş, uygulama simgesine
dokunarak ya da Android'in son uygulamalar ekranından yapılır.

## Kullanım

- **Dolu akış:** 58 örnek kart; 14 içerik ailesi, üç ayrı duyuru ve karışık içerik.
- **Kart kataloğu:** 62 görünüm. Tür filtresi ve kart kimliğiyle arama; örneğin
  `announcement-video`, `event-fallback-solo`, `collab-paid-extra`.
- **Sıfırla:** yerel beğeni, yorum, takip, kaydetme, gizleme ve sessize almaları
  başlangıca döndürür; çalan sesi durdurur. Uygulama işlemi yeniden başladığında
  da başlangıç verileri yüklenir.
- Duyuru kartlarındaki **Tüm duyurular** gizlenen duyuruları da içerir.

Tasarım konuşurken kart kimliğini vermek aynı görünümü tekrar bulmayı sağlar.
Yükleme ve bozuk görsel örnekleri özellikle katalogdadır; normal dolu akışa
dahil edilmez. Görseller özgün örnek illüstrasyonlardır. Ses ve video, cihazda
oynatılabilen sekiz saniyelik deneme medyasıdır.

## Paylaşılan uygulama kodu

Önizleme gerçek `MusicianFeedView`, Cubit, kart kayıt sistemi, tema, üst/alt menü,
duyuru dizini/ayrıntısı, yorum/beğenenler ekranı ve ses/video oynatıcılarını kullanır.
Standart repository'ler yalnızca izinli yolları RAM verilerine bağlayan bir
`PreviewApiClient` ile çalışır; bilinmeyen yollar reddedilir, başka istemciye
aktarılmaz. Normal davranışı değiştirmeyen isteğe bağlı eylem/veri kaynağı
parametreleri kullanılır.

Profil, etkinlik, Collab ve sosyal paylaşım ayrıntılarında ilgili kart örneği
incelenir. Bu sürüm tüm uygulama modüllerinin uçtan uca simülasyonu değildir.
Sıralama tasarım incelemesi için sabittir; sunucu sıralaması, yetkilendirme,
gerçek bildirim/istatistik gönderimi ve yük testi bu önizlemenin kapsamı dışındadır.

## Ayrım ve derleme

- Paket: `com.berkayb.soundconnect.soundconnect_23_12_25codx.preview`.
- Başlangıç: `lib/main_preview.dart`; normal bootstrap çağrılmaz.
- Son kullanıcı APK'sında **INTERNET izni yoktur**; ayrı Android UID/veri alanı,
  simge ve launcher vardır. Deep link, paylaşım sağlayıcısı ve arka plan ses
  servisi önizleme manifestinde yoktur; yedekleme kapalıdır.
- Paket/izin/QA durumu, herhangi bir oturum veya repository oluşturulmadan önce
  native kanaldan doğrulanır. Yanlış eşleşme başlangıcı durdurur.
- Flutter motorunda otomatik eklenti kaydı kapalıdır. Yalnızca medya, görsel
  önbelleği ve uygulamaya özel dosya erişiminin gerektirdiği sekiz native eklenti
  açılır; liste başlangıçta doğrulanır. `audio_service` native eklentisi açılmaz;
  normal uygulamanın arka plan motoru önizlemede başlatılmaz.
- Kimlik bilgileri yalnızca RAM'de üretilen geçersiz deneme token'ıdır; gerçek
  güvenli depolama açılmaz. Görsel adaptörü soket açmadan paket içindeki PNG'leri
  sunar; video bellekten, ses uygulamanın özel geçici dosyasından çalınır.
- Örnek medya yalnızca koşullu Android önizleme kaynaklarına eklenir. Normal
  APK'nın varlıklarına eklenmez. Yeni paket/teknoloji bağımlılığı gerekmez.

Derleme, APK denetimi, kurulum ve medya üretim komutları:
[tool/preview/README.md](../tool/preview/README.md).

Telefon entegrasyon testi için izin verilen tek QA giriş noktası
`integration_test/feed_preview_device_test.dart` dosyasıdır. Bu geçici debug
paketinde Flutter test bağlantısı için INTERNET vardır; uygulama içindeki RAM
ve soketsiz medya adaptörleri aynen korunur. Testten sonra aynı `.preview`
paketinin internetsiz kullanıcı sürümü kurulur. Normal uygulamaya APK kurulmaz.

## Doğrulama · 13 Eylül 2026

- 142 regresyon testi ve 13 Android derleme sınırı kontrolü geçti; `lib`, `test`,
  `integration_test` ve `test_driver` statik analizinde sorun yok.
- Vivo V2206 / Android 14 üzerinde 62 katalog görünümü açıldı; gerçek görsel
  bileşenlerinin paket içindeki resimleri çözmesi doğrulandı. Afişli etkinlik,
  varsayılan solo/grup etkinliği ve duyuru ekran görüntüleri ayrıca incelendi.
- Telefon testinde gerçek beğeni/yorum arayüzü, duyuru gizleme/dizini, sıfırlama,
  bellekten video ve uygulamaya özel dosyadan ses oynatma geçti. Video 528 ms,
  ses 875 ms ilerledi; reddedilen beklenmedik API/görsel isteği yok.
- Normal giriş noktası ayrıca derlendi: asıl uygulama kimliği ve `MainActivity`
  korundu, normal APK'ya önizleme medya varlıkları eklenmedi. Bu doğrulama APK'sı
  telefona kurulmadı.
- Teslim edilen profile APK telefona ayrı uygulama olarak kuruldu; kurulu
  pakette `INTERNET` izni bulunmadığı doğrulandı. İki soğuk açılış, normal
  klavyeyle katalog araması ve videodan sonra başka kart arama geçti; video
  internetsiz pakette de görüntü üretip oynadı.
- Asıl uygulamanın Android UID'si `10511`, önizlemenin `10518`; veri dizinleri
  ayrıdır. Asıl uygulamanın kurulum/güncelleme zamanı ve kurulu APK SHA-256 değeri
  başlangıçla aynı kaldı. Sunucuya örnek veri eklenmedi.

Telefon testinin makine tarafından üretilen raporu çalışma alanındaki
`.local-verification/design-preview/device-report.json`, görsel kayıtları aynı
dizinin `screenshots` altındadır. Bu sonuçlar görsel önizlemenin doğrulamasıdır;
üretim sunucusunun algoritma veya yük testi olarak değerlendirilmez.
