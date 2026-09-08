# Etkinlik planları ve dinleyici paylaşımları

## Ürün sınırları

- `Gidiyorum` ve `Düşünüyorum` birer kişisel plandır, etkinliğe gerçekten katılım kanıtı değildir.
- Aktif ve doğrulanmış dinleyici veya müzisyen kendi tercihini etkinlik detayından değiştirebilir. Dinleyici paylaşımındaki `Ben de gidiyorum` da aynı kişisel kontrolleri açar.
- Profil paylaşımı yalnız dinleyicilere özeldir. Müzisyen profilinde paylaşım veya yeni bir `Planlarım` yönetim girişi yoktur.
- Dinleyicinin `Etkinlik planlarım` alanı özeldir. Profilinde yalnız ayrıca paylaştığı etkinlikler görünür.
- İlk seçim gizlidir. Başarılı seçimden sonra 8 saniyelik alt bildirim gösterilir. Uygun dinleyici hesabında `Profilinde paylaş` eylemi bulunur. Dar ekranda veya büyük yazıda eylem taşmadan alt satıra geçer. Bildirimin kapanması seçimi silmez.
- Etkinlik detayında seçili `Gidiyorum` veya `Düşünüyorum` düğmesine yeniden dokunmak yeni kayıt oluşturmaz. Düğmenin yanında küçük bir menü açılır: `Seçimimi kaldır` ve uygun dinleyicide `Profilinde paylaş` (zaten paylaşılmışsa `Paylaşımı düzenle`). Bu menüde başka seçenek veya açıklama alanı yoktur. Durum değiştirmek için diğer durum düğmesine doğrudan basılır. Müzisyen ve profilde paylaşma yetkisi bulunmayan hesaplarda yalnız kaldırma bulunur.
- Durum düğmelerinin altında tekrar eden `Seçimin: …` / `Seçimimi düzenle` satırı bulunmaz. Seçili düğmenin işareti durumu belirtir. Etkinlik sona erdiğinde veya kullanılamadığında varsa yalnız mevcut seçimin düğmesi kalır, küçük menüden kaldırılabilir. Yeni olumlu tercih veya paylaşım açılamaz.
- Profildeki plan/paylaşım yönetiminin ayrı kontrolleri korunur. Bu alanlarda durum düğmeleri sayfanın üzerinde bulunmadığı için tam yönetim paneli kullanılmaya devam eder.
- `Profilinde paylaş` kişinin kendi profilindeki `Paylaşımlar` bölümüne gider ve kaydedilmemiş bir taslak açar. Açıklama yalnız burada yazılır ve isteğe bağlıdır (en fazla 500 Unicode kod noktası). Paylaşım ancak `Paylaş` düğmesine basılınca kaydedilir. Taslaktan vazgeçmek kişisel etkinlik tercihini değiştirmez.
- `Gidiyorum` ve `Düşünüyorum` arasında geçiş mevcut profil paylaşımını ve notunu korur. `Seçimimi kaldır` ikisini de kaldırır. Sadece profil paylaşımını kaldırmak kişisel tercihi korur.
- Hayalet dinleyicinin paylaşımları başkalarına gösterilmez. Özel planlar kullanılabilir. Önceden paylaşılmış tercihin görünürlük bilgisi korunur, standart profile dönüşte yeniden görünür. Hayalet modda yeni paylaşım veya not değişikliği yapılmaz.
- Geçmiş etkinlikler `Geçmiş plan` olarak gösterilir. Yeni olumlu tercih/paylaşım yapılamaz, mevcut seçim veya paylaşım kaldırılabilir. Silinen/kullanılamayan etkinlikler listelerden çıkar.
- Sanatçı davet onayı, profesyonel profil takvimi, mekan bağlantıları ve mekan istatistiklerinin kapalı raporlama ayarı bu özellikten bağımsızdır.

## Mevcut parçaların kullanımı

Giriş yapmış dinleyici etkinlik aramasına alt bardaki `Keşfet` sekmesinden ulaşır. Müzisyen/mekan/stüdyo gibi backstage hesaplarında aynı giriş `Git → Keşfet` menüsündedir. İki yol da misafirlerdeki mevcut konum/tarih aramasını kullanır. Üye görünümünde giriş/üyelik düğmeleri yerine tek bir profil alt barı bulunur. Taşınabilir masa balonu korunur ve tekrar giriş istemeden, hesabın mevcut yetkileriyle masalar listesine açılır.

`EventAudienceRepository` tek backend kaydıyla tercih ve profil paylaşımını yönetir. `EventAudienceControls` detay ve profil akışında ortaktır. Oturum, hesap rolü ve sürüm kontrolleri eski ekran işlemlerini durdurur. Belirsiz yazma hatalarında otomatik tekrar yerine yeniden okuma istenir.

Profil taslağı bellektedir, veritabanına ön kayıt veya yerel kalıcı taslak yazılmaz. Kişinin etkinlik tercihi sunucudan yeniden okunur. Taslağın başlangıç sürümü sabit tutulur, başka ekran/cihazdan değişiklik gelirse yazılmış açıklama korunur ve güncel durum açıkça kontrol edilmeden paylaşım yapılamaz. Bu sırada tercih kaldırılmışsa eski taslak onu yeniden oluşturamaz. Oturum/hesap değişikliği taslağı geçersiz kılar ve açıklamayı temizler. Yazılmış açıklamayla sayfadan ayrılırken onay istenir. Kaydetme sürerken çift gönderim ve sayfadan ayrılma engellenir.

`ListenerEventFeedController` bellekte tek sayfa tutar. Profil önizlemesi iki kayıt, tam liste en fazla 20 kayıtlık sayfalar kullanır. Her kart için özel tercih isteği yapılmaz. `Ben de gidiyorum` kontrolleri dokunulduğunda yüklenir. Uygulamaya dönüş ve profil yenilemesi veriyi yeniden doğrular.

Dinleyici kartı mevcut konuma göre etkinlik arama kartının görsel dilini kompakt ölçülere uyarlar. Konuma göre aramanın kart dosyası ve ölçüleri değişmez. Diğer dinleyici mock paylaşımları, özellikle Overthinking, korunur.

Harici paylaşım mevcut `EventShareService`, görsel hazırlayıcı ve hedef seçim panelini kullanır. Kişisel dışa aktarımda güncel tercih hem görsel hazırlanırken hem gönderilmeden önce doğrulanır. Başkasının paylaşımını paylaşmak o kişinin tercihini kendi tercihinmiş gibi görsele eklemez. Genel etkinlik paylaşımının davranışı değişmez.

## Doğrulama

İlgili testler:

- `test/event_audience_repository_test.dart`
- `test/event_audience_controller_test.dart`
- `test/event_audience_controls_test.dart`
- `test/event_audience_share_test.dart`
- `test/event_audience_profile_draft_navigation_test.dart`
- `test/listener_event_draft_composer_test.dart`
- `test/app_snack_bar_test.dart`
- `test/listener_event_posts_test.dart`
- Mevcut etkinlik detayı, paylaşım, listener profil ve gizlilik testleri

Backend migration: `SoundConnect-Backend/scripts/db/2026-09-08-event-audience-intents.sql`. Mevcut veriyi sıfırlamaz. Uygulamadan önce yedek ve geri yükleme kontrolü gerekir. Bu belge migration'ın uygulanmış olduğuna dair kayıt değildir.

Güncel telefon kontrol sırası ve ilerleme kaydı [EventAudienceManualChecks.md](EventAudienceManualChecks.md) belgesindedir. Otomatik testlerde kapsanan rol/sürüm/zaman sınırları tek tek tekrar edilmez. Gerçek cihazdaki gezinme, klavye, açık yayınlama, kalıcılık, hesap değişimi, ağ kesintisi ve işletim sistemine görsel teslimi beş kısa grupta kontrol edilir.

### 8 Eylül 2026 doğrulama kaydı

Tam Flutter paketi `flutter test --no-pub --reporter expanded` ile **3.025 test geçti**. `dart analyze lib test` temiz. Backend'in ilgili geniş regresyon paketi 631 test, Redis/migration/onboarding ek paketi 10 kontrol geçti. Gerçek yazı tipleriyle profil kartları ve paylaşım panelleri 320 px / yüzde 200 yazı boyutunda da incelendi. Keşif kartı dosyasının SHA-256 değeri değişmedi.

Kullanıcının onayıyla backend kapalıyken yedek alındı ve ayrı bir veritabanına geri yüklenerek doğrulandı. Yeni migration doğrulama kopyasına iki kez uygulandıktan sonra uygulama veritabanına uygulandı. Önceden var olan 94 public tablonun satır sayısı ve içerik parmak izleri aynı kaldı. Backend otomatik başlatılmadı. Gerçek telefondaki uçtan uca kullanıcı kontrolü bu otomatik doğrulamalardan ayrıdır.

Üye `Keşfet` girişi eklendikten sonraki tam Flutter çalıştırması **3.047 test geçti**, statik analiz temiz. Yeni alt bar/yönlendirme ve üye keşif testleri mevcut misafir aramasıyla birlikte doğrulandı. Dinleyici ve müzisyende arama sonucundan gerçek etkinlik detayına geçiş ve kişisel tercih kontrolleri test edildi. Bu gezinme eklemesi backend veya veritabanını değiştirmez.

Alt bildirim ve profil içi taslak revizyonunda tam Flutter paketi **3.105 test geçti**. Son görsel aralık düzenlemesinden sonra profil/taslak regresyonu ve gerçek yazı tipleriyle render dahil **83 kontrol yeniden geçti**, son `dart analyze lib test` temiz. Bildirim normal ekranda yan yana ve 320 px / yüzde 200 yazıda taşmadan incelendi. Taslağın kaydırma sırasında korunması, kirli taslakla çıkış, hesap/görünürlük değişimi, eski sürüm, belirsiz yazma sonucu, çift dokunma ve gerçek profil yönlendirmesi otomatik testlerle doğrulandı. Konum aramasının etkinlik kartı dosyasının SHA-256 değeri aynı kaldı. Bu revizyon backend veya veritabanı değişikliği içermez. Bu kayıt gerçek telefon üzerinde son revizyonun manuel test edildiği anlamına gelmez.

### Çok sayfalı alt bildirim düzeltmesi

Telefonda bildirilen `_RenderSingleChildViewport was mutated in _RenderLayoutBuilder.performLayout` hatası, aynı `ScaffoldMessenger` altında önceki sayfa açık tutulurken ikinci bir Scaffold'a etkinlik detayı açılan testte birebir üretildi. Ardından `Duplicate GlobalKey detected` hatası da görüldü. Bildirim mesajındaki global anahtar, Flutter'ın aynı bildirimi birden fazla kayıtlı Scaffold'a yerleştirmesiyle çakışıyordu. Önceki tek-Scaffold testleri bu durumu kapsamıyordu.

Mesajdan global anahtar kaldırıldı. Bildirim sahipliği artık kendi `ScaffoldFeatureController` kapanış sonucuyla izlenir. Kapanış temizliği kare sonrasına ve kapanış mikro görevlerinden sonraya ertelenir, böylece eski bildirim için gelen temizlik başka bir bildirimi kapatmaz. Ortak alt bildirim tasarımı, 8 saniyelik süre, paylaşım akışı ve backend değiştirilmedi. İki sayfalı hata tekrarı kalıcı regresyon testine eklendi ve düzeltmeyle geçti.

Bu düzeltmeden sonra tam Flutter paketi **3.108 test geçti**, son statik analiz temiz. Yeni üç regresyon, önceki sayfa açıkken bildirim gösterimini, üçüncü sayfaya profil paylaşımıyla geçiş/geri dönüş animasyonlarını ve aynı karede sonradan gelen bağımsız bildirimin eski temizleme işleminden korunmasını kapsar. Son revizyonun gerçek cihaz doğrulaması kullanıcı kontrolünü bekler.

### Seçili durum için küçük menü

Etkinlik detayında aynı durum düğmesine tekrar dokunma, geniş panel yerine düğmeye bağlı iki seçenekli menüye dönüştürüldü. Native açılır menü ekran sınırlarına uyum sağlar ve profil yönlendirmesi kapanış animasyonu bittikten sonra yapılır. Menü açıkken oturum/sürüm/etkinlik değişirse eski işlem durdurulur. İlk menü karesi çizilmeden etkinlik değiştirme veya bileşeni kaldırma ve ekran daralınca dayanak düğmenin yeniden yerleşmesi de güvenli kapanış testleriyle kapsanır. Profildeki tam plan yöneticisi ve ilk seçim bildirimi değişmez.

Tam Flutter paketi **3.118 test geçti**, statik analiz temiz. 36 durum kontrolü testi, 5 gerçek etkinlik detayı testi ve gerçek yazı tipleriyle küçük/büyük metin önizlemeleri doğrulandı. Telefonda son küçük menünün kullanıcı kontrolü ayrıca yapılmalıdır.
