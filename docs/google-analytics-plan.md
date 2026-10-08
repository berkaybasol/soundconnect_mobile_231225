# Google Analytics — kullanıcı kararı ve uygulama planı

Karar tarihi: 22 Eylül 2026.
Son durum güncellemesi: 23 Eylül 2026.

## Onaylanan karar

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

## Son doğrulanmış durum

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

## Açık işler

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

## İlerleme sırası

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
