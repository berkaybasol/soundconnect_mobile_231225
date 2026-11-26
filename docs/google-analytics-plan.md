# Google Analytics — kullanıcı kararı ve uygulama planı

Karar tarihi: 22 Eylül 2026.
Son durum güncellemesi: 26 Kasım 2026.

## Android üretim derlemesi

GA4 ve SoundConnect canlı ölçümü varsayılan olarak kapalıdır. Android'de üretim ölçümünü içeren paket imzalı `release` olarak, `SOUNDCONNECT_ENVIRONMENT=production` ve açık bir HTTPS `SOUNDCONNECT_BASE_URL` Dart tanımıyla derlenir. Paketleme ortamındaki `SOUNDCONNECT_PRODUCTION_API_ORIGIN` aynı kökeni belirtmelidir. Staging API adresi üretim için reddedilir.

GA4 için Dart tanımı `SOUNDCONNECT_GA4_PROJECT`, paketleme ortamındaki `SOUNDCONNECT_PRODUCTION_GA4_PROJECT` ve Google Services Android yapılandırmasındaki proje eşleşmelidir. Canlı ziyaret ve SoundConnect ilk hafta süresi için `SOUNDCONNECT_LIVE_ANALYTICS_ENABLED=true` kullanılır. Android 7–8'de bu izinli üye süreleri GA4 çalışmadan da gönderilir. Staging'in onaylı debug paketleme koşulları aşağıdadır.

Üretim API kökeni, Firebase projesi ve rapor başlangıcı henüz seçilmedi. Üretimde kullanıma geçmeden önce uygulamadaki aydınlatma metinlerinin eksik şirket, alıcı, aktarım ve saklama alanları tamamlanmalıdır.

## 04.9 · Android v34 ile canlı ziyaretler ve zirveler

Canlı kart ve kaynak geçişinin yapıldığı aydan başlayan zirveler, izinli kullanıcıların SoundConnect’e bildirdiği ziyaretlerden hesaplanır. Daha önceki ayların zirveleri kaydedilmiş GA4 örneklerinden okunur. GA4 aylık aktif kullanım ve bölüm raporlarının kaynağıdır. İlk hafta hesabı SoundConnect’te devam eder. v34’ün staging Android derlemesinde `--dart-define=SOUNDCONNECT_LIVE_ANALYTICS_ENABLED=true` canlı ziyaretleri açar. Varsayılanı kapalıdır. Android API 24–27’de GA4 bileşenleri kapalı olduğu halde bu tercihli SoundConnect yolu kullanılabilir. iOS ve web için mobil ziyaret gönderimi kapalıdır. [Ziyaret istemcisi](../lib/modules/analytics/data/analytics_live_activity.dart)

`2026-11-26-r3` metni üye ve misafirin SoundConnect’e iletilen ön plan ziyaretini de kapsar. Önceki iznin sahibi v34’te yeniden seçim yapar. Önceki ret geçerlidir. Üyenin güncel iznini sunucu doğrular. Misafirin seçimi cihazda tutulur. Misafir izin verdiğinde cihaza iki ayrı rastgele kod atanır. Bunlardan biri GA4, diğeri yalnız SoundConnect canlı sayımı içindir. Geri çekme iki kodu da cihazdan siler. Yeniden izin verilirse yeni kodlar oluşturulur. [Tercih ve sürüm geçişi](../lib/modules/analytics/data/analytics_consent_store.dart) · [Kullanıcının gördüğü açıklama](../assets/privacy/ANALITIK_AYDINLATMA_TASLAGI.md)

Uygulama ön plana geldiğinde ve ön planda yaklaşık dakikada bir izin doğrulanır. Güncel izin varsa sunucuya bir ziyaret bildirilir. Üye isteği oturuma ve hesaba bağlı ölçüm koduna dayanır. Misafir isteği oturum taşımadan canlı sayım kodunu iletir. Çevrimdışı ziyaret kuyruğu yoktur. Arka plana geçildiğinde, hesap değiştiğinde ve izin geri alındığında istemci bekleyen isteği iptal eder. Sunucunun daha önce aldığı ziyaret beş tamamlanmış dakikalık penceresinin sonuna kadar sayılabilir. Aynı üyenin iki cihazı tek üye, iki misafir kurulumu iki ayrı misafir sayılır. [Yaşam döngüsü ve tercih denetimi](../lib/modules/analytics/data/analytics_consent_controller.dart) · [Mobil sınamalar](../test/analytics_consent_controller_test.dart)

## 04.2 · Tercihin uygulanması

Üye tercihi `/api/v1/users/me/analytics-preference` üzerinden hesapta saklanır. Misafir seçimi ve izin sonrasında üretilen iki ayrı kod cihazda, API ortamına ve metin sürümüne bağlı saklanır. İzin geri alındığında cihaz her iki kodu siler. Üye için sunucunun ürettiği güncel izin kodu kullanılır. Eski SoundConnect etkinlik, mekân ve duyuru gözlemcisi normal uygulamada kayıtlı değildir. Önceki kurulumdan kalan gözlem kuyruğu ve kurulum kodu başlangıçta temizlenir.

Üye oturumu geri yüklendiğinde ve uygulama ön plana geldiğinde tercih yeniden okunur. Ön planda açık tercih dakikada bir kontrol edilir. Kullanıcı kendi cihazında izni geri çektiğinde devam eden okuma yerel kapatmayı geciktirmez. Ağ kesikse geri çekme aynı hesap ve tercih sürümü için cihazda saklanır. Uygulama ön planda kaldığında istemci sunucuya yazmayı 2, 5, 15, 30, ardından en fazla 60 saniye arayla dener. Arka planda zamanlayıcı durur. Kullanıcı döndüğünde işlem yeniden denenir. Sunucuda daha yeni bir karar varsa eski ret otomatik olarak üzerine yazılmaz. [Tercih denetleyicisi](../lib/modules/analytics/data/analytics_consent_controller.dart)

Android v26 normal staging paketinde GA4 veri toplama native manifestte kalıcı olarak devre dışıdır. Tercih kaydı ve ret sayıları çalışır. Kullanıcı 26 Kasım'da staging test verilerinin mevcut `soundconnect-fa50e` projesine gitmesini kabul etti. Google Analytics mülkü `555431534`, Android veri akışı `15826745393`. Canlıya geçişten önce veri sıfırlama ayrıca değerlendirilecek.

Staging v29 kullanıcı APK'sı için mevcut derleme ayarlarına `--dart-define=SOUNDCONNECT_GA4_PROJECT=soundconnect-fa50e` eklenir. Gradle yalnız öngörülen debug paketini, `https://api-staging.soundconnect.com.tr` adresini ve aynı kimlikteki Firebase yapılandırmasını kabul eder. Bayraksız derlemelerde, prod ve iOS'ta ölçüm kapalıdır. [Staging derleme koşulları](../android/app/build.gradle.kts)

Firebase Android SDK'sı çalışma zamanında açılan toplama tercihini süreçler arasında saklar. Flutter motoru açılırken GA4 başlatılmaz. FCM'nin analitik bağlayıcısı manifestten çıkarılır, bildirim servisi çalışır. SDK, yükleme için kendi receiver ve servis kayıtlarını kontrol eder. Android 9 ve sonrasında işletim sisteminin bu bileşenleri çalıştırmasını uygulamanın `AppComponentFactory` sınıfı denetler. Süreç o anda geçerli izni doğrulamamışsa ölçüm bileşeni çalışmaz. **Android API 24–27** üzerinde kullanıcı tercihini kaydedebilir ve üye seçimi yönetici toplamlarına girer. Bu sürümlerde `AppComponentFactory` desteği bulunmadığından ölçüm bileşenleri manifestte ve native kanalda kapalıdır. [Android bileşen denetimi](../android/app/src/main/kotlin/com/berkayb/soundconnect/soundconnect_23_12_25codx/AnalyticsComponentFactory.kt)

Misafir tercihi cihazdan veya üye tercihi sunucudan doğrulanınca Android kanalı SDK'yı açar. İzin yokken çalışmayan SDK'yı kapatmak için SDK başlatılmaz. Arka plana geçiş toplama işlemini duraklatır. Normal geri çekmede SDK ölçümü durdurur ve yerel veriyi sıfırlar. Süreç ölümü sonrası eski analitik kodu yeni koddan farklıysa yükleme bileşenleri kapatılır. Yeni aktör izin verdikten sonra eski veriler temizlenir ve örnek kimliğinin boş olduğu doğrulanır. Ardından yeni kimlikle ölçüm başlayabilir. Temizlik doğrulanıncaya kadar ölçüm kapalı kalır. [Android rıza ve veri temizleme akışı](../android/app/src/main/kotlin/com/berkayb/soundconnect/soundconnect_23_12_25codx/AnalyticsConsentChannel.kt) · [Firebase Android API](https://firebase.google.com/docs/reference/android/com/google/firebase/analytics/FirebaseAnalytics)

### Android staging sonuçları · 26 Kasım 2026

| Paket | Cihaz ve Google tarafında gözlenen |
| --- | --- |
| v26, ilk staging | Tercih ve yönetici sayacının ilk kabul paketi. GA4 bu pakette kapalı. |
| v27, deney | Android ölçüm servisi ve alıcısı çıkarıldığında SDK olay çağrısını almasına rağmen gönderim yapamadı. |
| v28, deney | İzinli müzisyenin `foreground_visit` olayı için 05:54:00.563 TSİ HTTP 204 alındı. Aynı dakika doğru Android akışının Firebase DebugView ekranında `profile_type=musician` görüldü. İkinci oturumdan geri çekme sonrası soğuk açılışta SDK kapalıydı. Retli müzisyen Android bildirim iznini verdi ve bağımsız FCM cihaz kaydı tamamlandı. [Cihaz ve iletim kaydı](../../artifacts/ready-for-prod-04/04-2/ga4-v28-staging.json) |
| v29, kullanıcı APK'sı | Retli hesabın soğuk açılışında SDK başlatılmadı. Kullanıcı yeniden izin verdi. Eski veriler temizlendi, yeni ziyaret 06:06:29.508 TSİ HTTP 204 aldı. Aynı Android akışında DebugView, 06:06:28–29 TSİ `foreground_visit` ve `profile_type=musician` değerlerini gösterdi. [Son paket doğrulaması](../../artifacts/ready-for-prod-04/04-2/apk-verification-v29.json) · [Cihaz ve iletim kaydı](../../artifacts/ready-for-prod-04/04-2/ga4-v29-staging.json) |

v29'un ayrı bir denemesinde yalnız Google Play Services HTTPS erişimi geçici olarak kapatıldı. 06:08:29.752'de izinliyken üretilen ziyaret sıraya girdi ve aktarım zaman aşımına uğradı. Uygulama durdurulmuşken aynı deneme hesabına ait bağımsız, kimliği doğrulanmış staging oturumu izni geri aldı. Emülatör sunucudaki retle yeniden açıldığında SDK başlamadı. Kullanıcı ayarlardan yeniden izin verince Google Play Services eski depodaki 13 kaydı temizledi. Ağ geri geldiğinde 06:10:06.457'de HTTP 204 alan veri paketindeki tek ziyaret 06:10:05.032'de gerçekleşmişti. Paket yeni kullanıcı kodunu ve yeni örnek kimliğini taşıyordu. Eski ziyaret bu pakette yoktu. Bu deneme Google aktarımı temizlik tamamlanıncaya kadar durdurulduğunda elde edilen sonucu doğrular. İzin geri çekme, Google'a daha önce teslim edilen verileri silmez. [Çevrimdışı kuyruk doğrulaması](../../artifacts/ready-for-prod-04/04-2/ga4-v29-staging.json)

Yönetici panelindeki izin ve ret sayıları sunucunun güncel üye tercihlerinden hesaplanır. Misafirin cihazdaki seçimi sayaca gönderilmez. Staging denemelerinde kullanılan üye hesapları da güncel tercihlerine göre bu toplamlara girer.

Bir telefon kapalıyken başka oturumda verilen karar, bu telefona en erken sonraki sunucu okumasında ulaşır. Google Play Services'e önceki izin sırasında teslim edilen bir paketin gönderim zamanını Google yönetir. Ağın uygulama yeniden açılmadan geri geldiği durumda işletim sistemi kuyruğundaki aktarımın uzaktan iptal edildiğine ilişkin kabul kaydı yoktur.

## 04.3–04.4 · Bölüm süresi ve ilk anlamlı eylem

v30'da SoundConnect'in ilk hafta sunucu işlemesini kapsayan üye metin sürümü `2026-11-26-r2` oldu. O sürümde eski izni olan üyeden yeniden izin istendi, önceki ret ve misafir tercihi korundu. v34’te üyenin ve misafirin yeni ölçüm yapabilmesi için güncel r3 izni gerekir. r2 döneminde alınmış geçerli ilk hafta kayıtları raporda korunur.

Android'in izinli ölçüm kanalı ön plandaki tek bölüme `section_time` olayı yazar. `section` yedi değerden birini alır. `duration_ms` gözlenen milisaniyedir. `profile_type` bakan üyenin türünü veya `guest` değerini taşır. Masa görünümünde `table_view` liste, ön izleme, sohbet veya oluşturmayı ayırır. Profil görünümünde `viewed_profile_type` ve sayısal `is_own_profile` bulunur. Keşfet kartından açılan etkinlik detayı `navigation_source=discover` ile Keşfet'te kalır. Bildirim ve profil bağlantılarından açılan aynı etkinlik Diğer'e geçer. DM, rezervasyon işlemi, işletme yönetimi ve ayarlar Diğer'dir. Kullanıcı metni, ilan numarası, içerik kimliği ve rota argümanları olaya eklenmez. [Bölüm eşlemesi](../lib/modules/analytics/presentation/section_navigation.dart)

Saat yalnız native SDK güncel rızayı doğruladıktan sonra başlar. Bölüm değişimi önceki aralığı bitirir. Ön planda süre 30 saniyede bir gönderilir. Uygulamanın etkileşimi kaybetmesi ve arka plana geçiş geçerli son aralığı bitirir. Hesap değişimi ve geri çekme kalan parçayı bırakır. Süre monoton saatle ölçülür. İşletim sistemi yaşam döngüsü bildirmeden süreci öldürürse son kontrol noktasından sonraki kısım eksik kalabilir. İki dakikayı aşan tek bir gözlenmemiş boşluk kullanım süresine eklenmez. [Süre hesabı](../lib/modules/analytics/data/analytics_section.dart) · [Rıza ve uygulama durumu](../lib/modules/analytics/data/analytics_measurement.dart)

Üye için aynı aralığın başlangıcı, süresi, rastgele örnek kodu ve mevcut analitik izin kodu kimliği doğrulanmış ilk hafta uç noktasına iletilir. Sunucu bu özeti cihazlar arasında birleştirir. **Sekiz dakikayı aşma** için kaynak SoundConnect'tir. Genel bölüm raporunun kaynağı GA4'tür. Pencere kapanınca istemci aynı izin kodu için bölüm sürelerini ilk hafta uç noktasına göndermeyi bırakır. Bir ağ hatasında, aynı ön plan ve izin sürüyorsa aynı örnek koduyla bir kez yeniden dener. Misafir süreleri bu hesap servisine gitmez.

İlk anlamlı eylemin türü ve gerçekleştiği an sunucudaki başarılı ürün işleminden gelir. İzinli üye ön plana geldiğinde, devam eden izin doğrulandığında ve başarılı ürün değişikliklerinden sonra telefon bekleyen ilk eylemi sunucudan ister. Aynı izin kodu ve oturum hâlâ geçerliyse `meaningful_action` olayını yalnız sabit `action_type`, `profile_type` ve gerçek işlem zamanının UTC milisaniye değeri olan `occurred_at_ms` ile GA4'e verir. Sunucu tek teslim hakkı tanır. Telefon bu hakkı aldıktan sonra bağlantı kesilirse GA4 kopyası eksik kalabilir. İlk hafta raporu sunucunun başarılı işlem kaydını kullanır. [Üye istekleri](../lib/modules/analytics/data/first_week_measurement.dart) · [İzin ve aktarım testleri](../test/analytics_section_test.dart)

## Eylül ayında onaylanan karar

Kullanıcı, Firebase proje oluşturma ekranındaki **Enable Google Analytics for
this project** seçeneğini açık bırakacağını belirtti. Analytics'i SoundConnect
için gerekli görüyor ve bu kararın diğer oturumlarda unutulmamasını istedi.

Amaç, günlük aktif kullanım, ilgi gören ekranlar/özellikler ve bildirimlerin
uygulamaya geri dönüşe katkısı gibi ölçümleri kullanarak ürünü yönetmek.
Bu belge kurulum için takip kaydıdır; Analytics entegrasyonu bu kararla otomatik
olarak tamamlanmış sayılmaz.

Firebase projesinin adı için kullanıcının güncel tercihi **SoundConnect**.
Bu proje ileride canlı uygulamada kullanılacak şekilde hazırlanacak. Kullanıcı
profesyonel ve yönetilebilir bir sonuç istiyor; henüz yayın veya üretime dağıtım
talep etmiyor. Gerçek kullanıcılar gelmeden geliştirme/test ortamı ayrımı
tamamlanmalı; proje adı tek başına bir kalite veya ortam izolasyonu sağlamaz.

## 23 Eylül 2026 kaydı

- 23 Eylül 2026 tarihli kullanıcı ekran görüntüsü Firebase projesinin oluştuğunu
  doğruluyor: görünen ad `soundconnect`, proje kimliği `soundconnect-fa50e`,
  plan **Spark**. Sonraki ekran görüntüsü Android uygulama kaydını da doğruladı:
  `tr.com.soundconnect.app` / `SoundConnect Android`. İndirilen yapılandırma
  dosyası proje/paket eşleşmesi kontrol edilerek `android/app/google-services.json`
  konumuna eklendi ve Git ignore doğrulandı. Backend için yerel Google oturumu,
  Java kimlik doğrulaması ve FCM validate-only bağlantısı geçti. Daha sonra yerel
  backend ve gerçek Android cihazda DM için arka plan, işlem kapalı, ön plan,
  izin reddi ve çevrimiçi çıkış kontrolleri de tamamlandı. Bu teslim testleri
  Analytics SDK/ölçüm doğrulaması değildir.
  Android istemci ayar dosyasının eklenmesi, Analytics ölçüm entegrasyonunun
  tamamlandığı anlamına gelmiyor.
- Kullanıcı 23 Eylül'de kalıcı Android kimliğini `tr.com.soundconnect.app` olarak
  onayladı. Firebase ve Analytics uygulama eşlemesinde bu değer kullanılacak;
  `tr.com.soundconnect.app.preview` önizleme kimliğiyle karıştırılmamalı.
- Kullanıcı Analytics açıkken önerilen ayarlarla sihirbazı tamamladığını belirtti.
  Önceki ekranda Analytics location `Türkiye` seçiliydi. Son veri paylaşımı
  seçimleri tek tek yeniden doğrulanmadı; asistanın önerdiği özel seçimlerin
  uygulandığını varsayma. Analytics hesabı/mülk kimliği ve bağlantı ayarları
  ayrıca kontrol edilecek.
- Flutter `pubspec.yaml` içinde `firebase_core` ve `firebase_messaging` var;
  `firebase_analytics` henüz ekli değil.
- Android `android/app/src/main/AndroidManifest.xml` dosyasında
  `firebase_analytics_collection_enabled=false` bulunuyor.
- iOS `ios/Runner/Info.plist` içinde Analytics toplama ayarı bulunmuyor; mevcut
  `FirebaseMessagingAutoInitEnabled=false` yalnız Messaging ile ilgili.
- Firebase başlangıcı push sağlayıcısında, Android Google Services eklentisi ise
  push derleme bayrağına bağlı. Analytics entegrasyonunda ortak Firebase
  başlangıcının push'tan bağımsız çalışması değerlendirilmeli.
- Uygulamanın `lib/modules/analytics/data/analytics_tracker.dart` içinde kendi
  backend'ine (`/api/v1/analytics/observations`) veri gönderen mevcut bir
  `AnalyticsTracker` sistemi var. Bu, Firebase Analytics entegrasyonu değildir.
- Analytics olayları, kullanıcı tercihleri ve gerçek cihaz raporlaması için
  tamamlanmış bir entegrasyon/kabul kaydı yok.
- Bu belgenin güncellenmesi uygulama kodunu veya veri toplama ayarlarını
  değiştirmedi; Firebase projesini kullanıcı kendi hesabında oluşturdu.

## 23 Eylül'deki iş listesi

- [x] Firebase projesinin oluştuğunu ve proje kimliğini ekran görüntüsünden
  doğrula: `soundconnect-fa50e` (23 Eylül 2026).
- [ ] Analytics hesabı/mülk bağlantısını, son veri paylaşımı seçimlerini ve
  raporlama ayarlarını doğrulayıp bu belgeye kaydet. Gizli anahtar veya kimlik
  doğrulama dosyası ekleme.
- [ ] Ölçüm planını hazırla: hangi ekranların ve ürün olaylarının ölçüleceği,
  olay adları/parametreleri ve bildirimden geri dönüşün nasıl değerlendirileceği.
  Mevcut backend analitiğiyle sorumlulukları belirle ve çift sayımı önle.
  Kullanıcıya yararını basit örneklerle açıkla.
- [ ] Flutter Analytics entegrasyonunu Android ve iOS için kur; veri toplama
  tercihlerini, oturum/hesap değişimindeki kimlik temizliğini ve test/canlı veri
  ayrımını tasarla. Ortak Firebase başlangıcını ve Android yapılandırmasını
  yalnız push bayrağına bağlı kalmayacak şekilde düzenle; Analytics tercihi ile
  bildirim iznini ayrı tut. Android'deki kapalı toplama ayarını ve iOS toplama
  politikasını yalnız bu akış hazır olduğunda bilinçli biçimde düzenle.
- [ ] Ölçüm alanlarını gözden geçir: özel mesajlar, şifreler, erişim/FCM tokenları,
  e-posta/telefon gibi doğrudan kimlik bilgileri ve ghost kimliğini açığa
  çıkaracak içerikler Analytics olaylarına taşınmamalı.
- [ ] FCM bildirim ölçümünü ayrıca doğrula. Mevcut backend HTTP v1 gönderimlerinin
  Analytics etiketlerini ve mobil açılma olaylarını destekleyip desteklemediğini
  kontrol et. Sağlayıcının kabulü, telefonda görünme, bildirime dokunma ve uygulama
  içi okunma durumlarını birbirinin kanıtı sayma; her mesajın bütün aşamalarının
  Analytics'te otomatik görüneceğini varsayma.
- [ ] Gerçek cihazda DebugView/raporlarla ölçümü doğrula: beklenen olaylar,
  yinelenen olaylar, veri toplama tercihi, çıkış/hesap değişimi ve test verilerinin
  canlı raporlardan ayrılması. Sonuçları kaydettikten sonra tamamlandı işaretle.

## 23 Eylül'de belirlenen ilerleme sırası

**23 Eylül 2026 güncel kullanıcı kararı:** Analytics entegrasyonuna, uygulamanın
bütün bildirim çalışmaları tamamlanana kadar geçilmeyecek. Önce DM bildirimleri
bütün profil türleri ve ilgili hata/hesap/ağ koşullarında doğrulanacak; bu kabul
tamamlanmadan yeni bildirim modülüne geçilmeyecek.

Analytics kurulumu bütün bildirim çalışmaları sonrasına ertelenmiş açık iştir;
modül aralarında başlatılmaz ve sonraki oturumlarda unutulmaz.
Bu kayıt, şimdi ayrıca Analytics kodlamasına başlandığı anlamına gelmez.

23 Eylül 2026'da kullanıcı iOS entegrasyonunun uygulamanın genel geliştirmesi
tamamlandıktan sonra yapılmasını istedi. Yukarıdaki iOS Analytics kurulumu ve
iPhone doğrulaması da o aşamaya ertelenmiştir. Şimdiki Android/backend
çalışmaları iOS kurulumunu beklemez; iOS maddeleri tamamlandı işaretlenmez.

## Resmî başvuru kaynakları

- [Google Analytics for Firebase](https://firebase.google.com/docs/analytics)
- [Flutter ile Analytics başlangıcı](https://firebase.google.com/docs/analytics/get-started?platform=flutter)
- [FCM teslim ve raporlama kapsamı](https://firebase.google.com/docs/cloud-messaging/understand-delivery)
