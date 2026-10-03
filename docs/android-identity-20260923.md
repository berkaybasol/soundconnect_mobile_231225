# Android kalıcı uygulama kimliği

23 Eylül 2026'da kullanıcı aşağıdaki kalıcı teknik kimliği açıkça onayladı.

| Kullanım | Değer |
| --- | --- |
| Normal Android applicationId / Firebase Android package name | `tr.com.soundconnect.app` |
| Ayrı önizleme applicationId | `tr.com.soundconnect.app.preview` |
| Android uygulama görünen adı | `SoundConnect` |
| Firebase'de kaydedilen takma ad | `SoundConnect Android` |
| Firebase proje kimliği | `soundconnect-fa50e` |

## Yapılan değişiklik

- Gradle normal/preview uygulama kimlikleri ve normal uygulama etiketi güncellendi.
- Önizleme çalışma zamanı denetimi ve APK doğrulama/kurulum araçlarının hedef
  paketleri güncellendi. Normal ve önizleme uygulamaları ayrı veri alanları kullanır.
- Android App Links şablonu, ilgili mevcut test beklentisi ve yerel kabul
  aracının hedef paketi eşlendi. Landing üretim örneği kalıcı kimliğe uyarlandı.
- Önceki Firebase çalışmasının iOS 15 ayarıyla uyuşmayan mevcut app-link testinin
  iOS 13 beklentileri 15'e hizalandı; iOS uygulama kodu veya kurulumu değiştirilmedi.
- Geçmiş test kayıtları ve oturum kanıtları tarihsel kayıt olarak korundu.

Android Kotlin namespace'i ve `MainActivity`/`PreviewActivity` sınıflarının tam
adları `com.berkayb.soundconnect.soundconnect_23_12_25codx` altında kaldı.
Dart paketi ve mevcut ses bildirim kanalı adı da değişmedi. Bunlar cihazın veya
Firebase'in uygulamayı tanıdığı applicationId değildir; sırf aynı metni içeriyorlar
diye topluca değiştirilmemelidir. Dosya paylaşım sağlayıcısı yetkilileri
`${applicationId}` üzerinden yeni kimliğe uyarlanır.

## Yerel kurulum etkisi

Android, eski geliştirme paketini ve yeni kimliği iki ayrı uygulama olarak görür.
Yeni APK eski uygulamanın üzerine güncelleme olarak kurulmaz; yerel oturum,
tercihler ve önbellek otomatik aktarılmaz, yeniden giriş gerekebilir. Sunucudaki
kullanıcı hesabı/veriler değişmez. Bu işlem eski uygulamayı kaldırmadı veya
verilerini silmedi; cihazlara kurulum yapılmadı.

## Doğrulama

- Normal Android debug APK derlendi. APK içinden `tr.com.soundconnect.app`,
  `SoundConnect` etiketi, doğru `MainActivity` sınıfı ve
  `tr.com.soundconnect.app.collab_share_files` sağlayıcısı doğrulandı.
- Önizleme debug APK derlendi. Mevcut `tool/preview/verify_apk.ps1` doğrulaması
  geçti: `tr.com.soundconnect.app.preview`, `SoundConnect Önizleme`, doğru
  `PreviewActivity`, `QA=False`, `INTERNET=False` ve manifest izolasyonu.
- `test/feed_preview_isolation_test.dart` ve
  `test/app_link_platform_config_test.dart` içindeki **7 mevcut test geçti**.
- Önizleme kimlik dosyası ve bu iki testte odaklı analiz temiz; değişen Dart
  dosyalarında biçim kontrolü ve `git diff --check` geçti. Yeni test eklenmedi.
- PowerShell araçlarının sözdizimi, App Links JSON kimliği ve yeni belge
  bağlantıları doğrulandı. Bağımsız referans incelemesinde çalışan Android
  uygulama kimliği olarak unutulmuş eski değer bulunmadı; namespace, sınıf ve
  ses kanalındaki eski isimler bilinçli olarak korundu.
- APK ve komut kanıtları proje içindeki
  `.local-verification/android-identity-20260923/` klasörüne kaydedildi.
  `normal-debug.apk` ve `preview-debug.apk` ayrı tutuluyor; standart
  `build/app/outputs/flutter-apk/app-debug.apk` yolu normal APK'ya geri alındı
  ve SHA-256 eşleşmesi doğrulandı.

## Kalan işler

- Firebase Android kaydı 23 Eylül'de kullanıcı ekran görüntüsüyle doğrulandı:
  `tr.com.soundconnect.app` / `SoundConnect Android`. Kullanıcı dosyayı indirdi;
  proje/paket eşleşmesi doğrulanarak `android/app/google-services.json` konumuna
  kopyalandı. Orijinal indirilen dosya korundu, Git ignore doğrulandı. Firebase
  Android app ID: `1:646456363075:android:f7789be07d99127601acf6`.
- Dosya eklendikten sonra `SOUNDCONNECT_PUSH_ENABLED=true` ile normal debug
  derleme geçti; APK'daki proje/gönderici/Firebase uygulama kimlikleri doğrulandı.
  Yeni kanıtlar `.local-verification/firebase-android-config-20260923/` altında.
  Standart `build/app/outputs/flutter-apk/app-debug.apk` artık bu push açık normal
  derlemedir; önceki kimlik geçişinin push kapalı/preview kanıtları korunmuştur.
- Gerçek FCM teslimi ve yeni kimlikle cihaz kabulü ayrıca tamamlanmalı.
- Play kaydı/yayını, gerçek mağaza adresi ve imza sertifikası doğrulanmadı.
  App Links şablonu hâlâ sertifika placeholder'ı içerir; canlıya yayımlanmadı.
- iOS kimliği ve Apple/Firebase entegrasyonu kullanıcının isteğiyle uygulamanın
  genel geliştirmesi tamamlanana kadar ertelendi; bu Android kararından iOS
  kimliği türetilmemeli veya iOS kaydı oluşturulmamalı.
