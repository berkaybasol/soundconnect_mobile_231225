# SoundConnect — Stüdyo akışı, 14 Eylül 2026

Son Git notu: kullanıcı birikmiş frontend/backend çalışmalarının commit ve push
edilmesini onayladı. Bu belgeyi içeren kapanış commit'i dinleyici sınırlarını,
stüdyo akışını ve aşağıdaki son misafir profil düzeltmesini birlikte kaydeder.
Aşağıdaki eski HEAD ve kirli ağaç kayıtları commit öncesinin tarihsel durumudur;
güncel commit ve uzak dal eşleşmesi iki repoda Git üzerinden kontrol edilmelidir.

Sonraki kod düzeltmesi: etkinlik detayındaki sanatçı/grup ve mekân profil
bağlantıları, kullanıcı misafirse mevcut masa giriş kapısıyla aynı ortak sheet'i
açar: “Profilleri görüntülemek için giriş yap veya üye ol.” Giriş/üyelik düğmeleri
ve geri dönünce etkinlikte kalma davranışı korunur. Oturum, dokunma anında tekrar
okunur; oturum kapandıktan sonra eski callback profil açamaz. Giriş yapmış
kullanıcıların mevcut profil/sahiplik yönlendirmeleri değişmez. Bu, etkinlik
detayındaki istemci yönlendirmesi düzeltmesidir; public API sözleşmesi değişmedi.
Mevcut masa metni, görünümü ve giriş/üyelik rotaları ortak bileşene taşınarak
korundu. Bu son düzeltme için yeni APK kurulmadı; aşağıdaki APK hash'i daha önceki
stüdyo sürümüne aittir. IDE'den güncel kaynakla yeniden çalıştırılmalıdır. Kanıtlar:
`.local-verification/guest-event-profile-gate-20260914/`.

Bu düzeltmenin hedefli regresyonunda altı test dosyasının son sonuçları toplam
352 başarılıdır; bunun 12'si yeni misafir profil erişimi kontrolüdür. İlk koşudaki
dört hedef doğrudan geçti; iki hedefteki eski oturum/fotoğraf test kurulumları
düzeltilerek yalnız bu iki hedef tekrar çalıştırıldı. Üretim kodu iki koşu arasında
değişmedi. Bu sayı yeni bir tam Flutter veya canlı cihaz kabul testi değildir.
`flutter analyze --no-pub lib test` temizdir (77,9 saniye; çıkış kodu 0).

Son çalışma durumu (14 Eylül 21:04): kullanıcı yalnız çalışan SoundConnect
frontend ve backend uygulamalarının durmasını istedi. API PID `444112` kontrollü
kapatıldı, port 8080 boş; `emulator-5554` içindeki SoundConnect uygulaması durdu.
IDE'ler, Flutter daemonları, emülatör ve Docker servisleri açık bırakıldı; veri
silinmedi. Aşağıdaki dağıtımın UP kaydı önceki kontrol anına aittir. Kanıt:
`.local-verification/studio-feed-deploy-20260914/session-stop.json`.

Bu belge, stüdyo akışının kullanıcı onayıyla uygulandığı sonraki oturumu kaydeder.
Önce bu belge, ardından `session-handoff-20260914-listener-boundaries.md` okunmalı.
Önceki belgedeki dinleyici erişim kararları geçerlidir; “stüdyoyu sonra birlikte
konuşacağız” maddesi bu oturumda tamamlanan ürün görüşmesine aittir.

## Ürün kararı ve uygulanan davranış

Stüdyo akışının omurgası takip edilen müzik çevresidir. Bunun yanında açıkça
stüdyo arayan Collab ilanları ve takip dışı müzisyen/grup keşfi korunur. Kullanıcı
önerilen %20–30 aralığını onayladı; ilk uygulamada uygun içerik varsa yaklaşık
%25 ayrılmış pay seçildi. Bu oran üst sınır veya her dört kartta sabit yerleşim
değildir. Teknik politika backend `docs/studio-feed-v1.md` belgesindedir.

- Collab keşfi, sorgu limiti uygulanmadan `wantedType=STUDIO` ile daraltılır.
  Önce yerel, sonra diğer şehirlerden uygun açık ilanlar değerlendirilir. Takip
  edilen kişilerin başka türdeki ilanları normal sosyal yayın olarak kalabilir.
- Sanatçı keşfi müzisyen/grup profili, parça ve video/ses yayınlarını kullanır.
  Aynı şehir ek önceliktir; kayıt veya hizmet ihtiyacı anlamına gelmez. Mevcut
  özel fırsat şehirleri/üye şehirleri payload'a taşınmaz.
- En az dört normal seçim slotunda `floor(slots/4)` yararlı içerik payı korunur.
  Arz varsa en az bir açık stüdyo talebi; en az iki ayrılmış slot varsa en az bir
  takip dışı sanatçı keşfi korunur. Böylece biri diğerini tamamen bastırmaz.
- Takip dışı etkinlik ikincil keşiftir. Overthinking ve masa paylaşımları mevcut
  düşük sıklığı korur. Az içerikte kullanılmayan kapasite uygun diğer kaynaklara
  gider; boş kart, mock içerik veya yapay tekrar oluşturulmaz.
- Duyurular mevcut STUDIO hedeflemesini kullanır. Sponsor/duyuru yerleşimi
  korunan içerik dengesini gözetir. Yeni reklam kaynağı/kampanyası bağlanmadı.
- Mevcut kartlar, alt bar, arama, gerçek detaylar, yorum/beğeni, Collab kaydetme,
  gizle/daha az göster/sessize al/şikâyet ve hesap değişimi davranışı kullanılır.
  Stüdyo için profil tamamlama kartı gösterilmez.

Mevcut stüdyo profil/oda/backline/takvim/rezervasyon altyapısı bu yeni sosyal
akıştan ayrıdır. Yönetim özeti, otomatik envanter/rezervasyon yayını veya yeni
hizmet kategorisi eklenmedi. Serbest metinden kayıt/prova/mix/mastering/uzaktan
çalışma ihtiyacı çıkarılmıyor. Gerçek DB'ye örnek içerik eklenmedi.

## Kimlik, API ve erişim

Aktif, doğrulanmış, silinmemiş ve kendisine ait stüdyo profili bulunan tek
kişisel STUDIO rolü, ortak Backstage akışını `/api/v1/feed/studio` üzerinden
kullanır. Algoritma `studio-v1.0.0`; mevcut şema ve renderer yetenekleri korunur.
Akış, kart geri bildirimi, sessize alma/kaldırma/listesi ve telemetri uçları hazır.
Ortak duyuru geri bildirimi ve rate limit altyapısı kullanılır.

HTTP rolüne ek olarak servis güncel DB rol/profil kümesini doğrular. Bekleyen,
reddedilmiş, başka kişisel rolle karışmış hesaplar reddedilir. Dinleyici vetosu
yönetici/stüdyo yetkisiyle aşılamaz. Cursor ve teslimat makbuzları rol/profil
bağlamına bağlıdır; hesap/token değişimindeki geç yanıtlar eski akışı taşımaz.

Önceki OTP/giriş, müzisyen, mekân ve dinleyici düzeltmeleri korunmuştur.
Dinleyicinin stüdyo/Collab/BACKSTAGE erişimi açılmadı. Onaylı
“Stüdyolar Backstage’de” açıklaması, metinleri ve geldiği sayfaya geri dönüş
davranışı geçerlidir. Serbest metin ve bilinen PUBLIC dosya adresleri kabulü
sürer. **Setlist PDF bulgusu kapsam dışındadır; düzeltilmiş sayılmaz.**

## Doğrulama kaydı

Güncel çalışma kanıtları workspace
`.local-verification/studio-feed-20260914/` altındadır. Tam Flutter koşusu:
**5.020 başarılı, 2 isteğe bağlı PNG atlaması**. `flutter analyze --no-pub lib test`
temizdir. Test edilen 79 değişmiş/yeni frontend kaynak/test dosyasının hash'leri
koşu boyunca ve son kontrolde değişmedi.

Backend ilgili regresyonunun en son paket sonuçları birlikte değerlendirildiğinde
**189 test paketi, 1.532 başarılı, 0 başarısız, 0 hata, 0 atlama** doğrulandı.
Bu sayı tek koşu veya bütün backend testlerinin sonucu değildir:

- `runs/regression-01`: 188 paket / 1.525 test; ilk koşuda yeni controller testinin
  6 karma rol senaryosu başarısızdı. Test fixture'ında ID'siz roller entity
  eşitliği nedeniyle Set içinde tek role düşüyordu; istek yalnız STUDIO yetkisi
  taşıyordu. Her test rolüne ayrı ID ve oluşturulan yetki kümesine assertion
  eklendi. Üretim erişim kuralını değiştirmek gerekmedi.
- `runs/studio-final-01`: düzeltilen controller'ın 24 testi ve ek sponsor/duyuru
  testinin 7 senaryosu; toplam 31 başarılı. Controller'ın ilk koşu sonuçları
  bu son sonuçlarla değiştirildi; 24 test toplama ikinci kez eklenmedi.
- İki koşu arasında yalnız bu test düzeltmesi ve yeni sponsor test dosyası var;
  üretim kodu aynı. Her koşuda tüm main/test Java kaynakları derlendi, kaynak
  hash'leri koşu boyunca sabit kaldı. Önceki ilgili regresyonların 163 farklı
  test paketinin tamamı kapsamda. JUnit XML ve kaynak manifestleri saklandı.

Kapsam; tüm feed testleri, ilgili promotion/Collab/stüdyo/bildirim/yorum/beğeni/
engagement/profil medya-resolver/arama testleri ve seçili dinleyici medya
sınırlarıdır. PostgreSQL sağlayıcı testleri gerçek sorgularla izole test
veritabanında çalıştı; yanlış türde çok sayıda yeni ilanın uygun stüdyo talebini
sorgu limitinden düşürmemesi, yerel/ülke çapı geri dolum, şehir mahremiyeti ve
ikincil etkinlik davranışı doğrulandı. Normal API/gerçek DB kullanılmadı.

Yük testi çalıştırılmadı; kapasite/üretim performansı iddiası yoktur. Java
derlemesindeki mevcut uyarılar sürer. Yerel sonuç toplayıcının ilk sürümündeki
sözlük toplamı hatası düzeltilip ilk özet orijinal JUnit XML'den yeniden
hesaplandı; hatalı özet de kanıt olarak korundu. Son birleşik sonuç
`backend-final-verification.json` ile kaydedilir.

## Dağıtım öncesi Git kaydı

Bu bölüm sonraki commit/push isteğinden önceki durumu kaydeder. Her iki repo
`feature/local-simulation` dalındaydı:

- Frontend başlangıç HEAD: `47d3079`.
- Backend başlangıç HEAD: `1ec3fa2`.

Önceki oturumun değişiklikleri ve yeni stüdyo akışı çalışma ağaçlarındaydı;
o aşamada commit/push yapılmamıştı ve ağaçlar temiz değildi. Başlangıçtaki 140 değişmiş/yeni
dosyanın kopyası ve hash kaydı kanıt dizinindeki `baseline/` ve
`baseline-manifest.json` içindedir. Mevcut işlerin üzerine reset/checkout yapma.

İlk uygulama kapanışında APK/API dağıtımı yapılmamıştı. Kullanıcının sonraki
“APK'ya kur, gerekeni yap” talebiyle **14 Eylül 20:23 itibarıyla aşağıdaki normal
APK ve API dağıtımı tamamlandı**. Bu kayıt önceki dağıtılmadı durumunu günceller.

## Sonraki dağıtım: emülatör ve normal API

- Kullanıcı `emulator-5554` emülatörünü açtı ve `adb reverse tcp:8080 tcp:8080`
  bağlantısını kurdu; bağlantı doğrulandı. Fiziksel Vivo telefon bağlı değildi,
  bu tur telefona kurulum yapılmadı.
- Normal `lib/main.dart` debug APK başarıyla üretildi ve `adb install -r` ile
  emülatöre kuruldu. Paket
  `com.berkayb.soundconnect.soundconnect_23_12_25codx`, sürüm `1.0.0+1`.
  Bu emülatörde ilk kurulumdu; uninstall/clear-data yapılmadı.
- APK: `build/normal/soundconnect-debug.apk`; SHA-256:
  `0e8d782489fb3ffd8a6eec9c908add0e7d7d54e2e7ca8d76c4970bf710be8d81`.
  Önizleme/mock giriş noktası kullanılmadı. Test edilen 79 değişmiş/yeni frontend
  kaynak/test dosyası build öncesi/sonrası aynı.
- Normal API ve media-worker JAR'ları üretildi. İlk normal çıktı derlemesi
  başarısızdı; ayrı çıktı klasöründe Java derlemesi geçti. Önbellekte bulunmayan
  bir bağımlılık çevrimiçi çözümlendikten sonra üçüncü paketleme başarılı oldu.
  Kaynak kodunda düzeltme yapılmadı; 1.965 backend dosyası son test manifestiyle
  aynı. Önceki JAR'lar hash doğrulamasıyla `rollback/` içinde korundu.
- Eski API PID `433068` kimlik/port kontrolünden sonra Spring Boot admin JMX ile
  kontrollü kapatıldı. Süreç ve port boşaldıktan sonra yeni paket normal
  `SoundConnect-Backend/build/libs/soundconnect-api.jar` yoluna yerleştirildi.
- Yeni API **PID `444112`**, port **8080**, readiness **UP**. API JAR SHA-256:
  `0e34d9584be298f6eb6a29918e4ef9daef5978a340e4129cc8b7eb6bcc15b830`.
  Worker JAR normal yerine kopyalandı; worker süreci ayrıca başlatılmadı.
- Başlatıcı, mevcut `scripts/dev.ps1` dosyasından yalnız `Import-DotEnv`
  fonksiyonunu AST ile alıp çalıştırdı; inherited environment değerleri aynı
  sözleşmeyle ezildi. Eski/yeni süreçte resolved JWT ve process JWT ayarının
  `.env.local` ile eşitliği yalnız boolean sonuçla doğrulandı; secret yazdırılmadı.
- `local` profili, `ddl-auto=validate`, mevcut seed kapatma seçenekleri korundu.
  Migration/reset/restore, mock hesap/içerik veya Docker servis değişikliği yok.
  Yeni API başlangıç/kontrol günlüğünde ERROR/JWT hatası 0, stderr boş.

Emülatörde normal açılış, yeni API sonrasında soğuk açılış ve şehir seçicide
sunucudan gelen şehirlerin görünmesi doğrulandı. Uygulama misafir etkinlik ana
ekranında bırakıldı; uygulama süreci çalışıyor, incelenen süreç günlüğünde fatal
ve unhandled Flutter hatası yok. **Oturum açılmış stüdyo akışı veya 30–40 hesaplı
manuel kabul turu yapılmadı.** Hesap oluşturulmadı. Bu yeni emülatörde korunacak
eski hesap oturumu yoktu; fiziksel telefon oturumunun durumu bu tur ölçülmedi.

Dağıtım kanıtları workspace `.local-verification/studio-feed-deploy-20260914/`
altında: APK/paket/hash, build ve source manifestleri, backend başlatma/sağlık/JWT
eşitliği, rollback JAR'ları ve emülatör PNG/XML/`device-validation.json` kayıtları.
Otomatik testler bu dağıtım turunda yeniden çalıştırılmadı; üstteki test sonuçları
aynı kaynak sürümünün doğrulamasıdır. Eski altı fiziksel cihaz kontrolünü veya
5.001/711 test sayısını bu emülatör dağıtımıyla karıştırma.

Sonraki işlemde önce güncel port/süreç ve cihaz kontrol edilmeli;
`scripts/dev.ps1` ortam yükleme sözleşmesi korunmalı. İkinci API başlatma veya
JWT ortamını değiştirerek oturum düşürme. Log/APK/geçici kanıtları Git'e alma.
Kullanıcı kapsamlı manuel kabul
turu için farklı bir planı olduğunu söyledi; yeni talebini bekle.
