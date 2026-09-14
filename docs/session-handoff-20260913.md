# SoundConnect — 13 Eylül 2026 oturum devri

14 Eylül'deki giriş/OTP ve müzisyen akışı düzeltmeleri ile doğrulama sonuçları
[session-handoff-20260914.md](session-handoff-20260914.md) içindedir. Aşağıdaki
13 Eylül kaydı önceki commit'lerin tarihsel durumunu anlatır.

Bu belge uzun müzisyen akışı oturumunun **son kabul edilen durumunu** anlatır. Tasarım karar belgesindeki önceki denemeler ve eski yerel raporlardaki bekleyen işler tarihsel kayıttır; aşağıdaki son durum önceliklidir. Kullanıcı oturumu kapatırken her iki repoya commit/push ve yeni oturum için devam notu istedi. Sonraki özellik henüz belirtilmedi.

## Çalışma alanı ve kapsam

- Windows çalışma alanı: `C:\Users\user\Desktop\SoundConnect`.
- Frontend: `SoundConnect-Frontend`, origin `berkaybasol/soundconnect_mobile_231225`.
- Backend: `SoundConnect-Backend`, origin `berkaybasol/SoundConnect`.
- Her iki repoda çalışma dalı: `feature/local-simulation`. Adı tarihsel; normal uygulamaya örnek veri ekleyen bir simülasyon değildir.
- Bu frontend kapanışıyla eşleşen backend commit'i: `0bc4f702ff4b35c20b7961146ac1ef724d882d71` (`feat(feed): harden delivery and add managed SoundConnect announcements`). Frontend kapanışı bu belgeyi içeren commit'tir; yeni oturumda güncel HEAD ve çalışma ağacını ayrıca doğrula.
- Üst çalışma klasörü bağımsız Git reposu değildir. Kaynak, test, doküman ve gerekli önizleme varlıkları alt repolardadır. Yerel APK, ekran görüntüsü, test günlükleri ve yedekler commit kapsamına girmez.
- Üç çalışma başlığı vardı: müzisyen akışının kalite düzeltmeleri, yeni özellikler (SoundConnect duyuruları), tasarım. Aşağıdaki geliştirme kapsamı tamamlandı ve kullanıcı son görünümü kabul etti. Bu, uygulamanın tamamının üretim yayınına hazır olduğu iddiası değildir.

## Müzisyen akışı kalite çalışması

- Etkinliklerin SQL NULL nedeniyle elenmesi, kota sonrası sayfalamanın erken bitmesi, beğeni/sayfalama yarışları ve eski akışın tekrarında güncel görünürlük sorunları düzeltildi.
- Yazar sessize alma tercihi kalıcıdır; listeleme ve geri alma ekranı vardır. Geri bildirimlerdeki 5.000 kayıt sınırı kaldırıldı; eski tercihler korunur, Redis ve okuma yollarındaki iş sınırları ve indeksler düzenlendi.
- Yönetici rapor kuyruğu, gerekçeli karar/geçmiş, yalnızca müzisyen akışından kaldırma ve geri açma eklendi. Rapor silinse bile kalan kısıtlamalar yönetilebilir. Kaynak paylaşım veya hesap silinmez; Collab kendi moderasyon altyapısını korur.

## SoundConnect duyuruları

Mevcut Promotion, medya, beğeni/yorum, oynatıcı, analitik ve yönetim altyapısı genişletildi. Paralel medya veya etkileşim sistemi kurulmadı.

- Yönetici yolu: **Akış Yönetimi → SoundConnect duyuruları**. Metin, isteğe bağlı tek fotoğraf veya video; taslak/düzenleme/yayınlama/zamanlama/bitiş/arşivleme. Kalıcı silme yalnızca taslak/arşivde.
- Hedef roller MUSICIAN, LISTENER, VENUE ve STUDIO olarak seçilebilir. Otomatik yerleştirme şu an yalnızca mevcut müzisyen akışındadır; diğer rollerin akışları uygulanmadı.
- Bir akış oturumunda en fazla üç ayrı duyuru. En yeni uygun duyuru henüz görülmediyse 1–2 normal içerik sonrasında gelir. En yeni duyuru görülmüşse eski görülmemişler bu önceliği devralmaz; seçilen duyurular 4–8 normal içerik aralığını kullanır. Oturum boyunca sabit kalan imzalı plan ve daha az görülene ağırlık veren seçim kullanılır. Her dördüncü içerikte tekrarlayan sabit yerleşim yoktur.
- Duyurular arka arkaya veya sponsorla bitişik gelmez. Yeterli normal içerik yoksa üçe tamamlamak için sıkıştırılmaz.
- **Bir daha gösterme** kullanıcı + duyuru UUID'sine bağlıdır. Düzenleme tercihi sıfırlamaz; yeni UUID ile oluşturulan duyuru eski gizleme kararından etkilenmez.
- **Tüm duyurular**, hedeflenen aktif duyuruları, akışta gizlenenler dahil, listeler. Beğeni ve yorum mevcut bileşenleri kullanır.
- Yönetici istatistikleri gerçek görünürlük/oynatma, tekil erişim, detay açma, video başlatma/tamamlama ve mevcut beğeni/yorum/gizleme sayılarını kapsar. İstanbul günü, rol ve kaynak filtreleri ile yinelenen olay koruması vardır. Yönetici önizlemesi istatistik üretmez.

Başka ortama geçişte mevcut migration önkoşullarının ardından, yeni koddan önce altı `2026-09-13` SQL adımı uygulanmalıdır: `musician-feed-feedback-lookup`, `musician-feed-moderation`, `musician-feed-retention-lookup`, `feed-announcements`, `announcement-feed-plan`, `announcement-analytics`. Dosyalar backend `scripts/db` altında, uygulanma sırası `scripts/dev.ps1` içindedir. Üretimde API ve ayrı medya worker birlikte güncellenmeli; özel kaynak/çıktı IAM izinleri `docs/MediaModule/IsolatedMediaWorker.md` üzerinden sağlanmalıdır. Bu oturumda üretime dağıtım yapılmadı.

## Dolu önizleme ve onaylı tasarım

- Ayrı Android `.preview` uygulaması, ayrı UID/depolama ve RAM verisi kullanır. Kullanıcıya verilen önizleme APK'sında INTERNET izni yoktur; medyalar pakete dahildir. Gerçek backend'e örnek veri yazılmaz.
- 58 karışık kart ve 62 katalog görünümü; gerçek akış, Cubit, tema, medya ve etkileşim bileşenleri yeniden kullanılır. Etkinlik/Collab/bazı sosyal detaylar önizlemede katalog örneğidir; bu modüllerin tümü simüle edilmez. **Normal uygulama mevcut gerçek detay sayfalarına gider.**
- Onaylı düzen: **B · Sahne yerleşimi + uygulamanın mevcut lacivert SoundConnect renkleri**. B taslağının sıcak/kömür renkleri yalnızca ileride alternatif tema fikridir.
- **Eski mevcut alt bar korunur. Arama yeni ekstra alan açmaz. Mevcut yorum ve beğeni davranışı korunur.** Akış kalbi yorumlardaki 18 px yuvarlak pembe kalple eşleştirildi.
- Akış sesi ve yüklenmiş ses detayında içi boş ince marka gradyan çerçevesi; mevcut ses oynatıcı kullanılır. Dalga çiziminin ölçü taşması giderildi.
- Collab ve etkinlik kartları kabul edildi. Afişsiz etkinlik mevcut varsayılan görsel bileşenini kullanır; testteki afiş gerçek varsayılan tasarımın yerine geçmez.
- TableGroup, dinleyici profilindeki kartın ortak bileşene çıkarılıp akışa uyarlanmış halidir. Gerçek masa detayı ve paylaşım etkileşimi kimlikleri korunur.
- Profil tamamlama kartı: **A seçeneği**, iç zemin akışla aynı `#0B1321`; kenarlık/ikon/gradyan eylem korunur. Daha açık lacivert deneme reddedilip geri alındı.
- Duyurunun “SoundConnect duyurusu” başlığının solunda 18 px marka gradyanlı megafon bulunur.
- Kabul edilen tasarım normal uygulamaya da derlenip kuruldu; yalnızca önizlemede kalmadı. Kullanıcı yeniden giriş yaptı ve gerçek müzisyen akışı cihazda doğrulandı.

## Son iş: yönetim panelinde tek sayfalık Profil Tamamlama

- Müzisyen yönetim panelinden yalnızca **Biyografi menü girişi** kaldırıldı. Biyografi verisi, profil düzenleyicisi ve akışın doğrudan BIO tamamlama bağlantısı korunur.
- **Profil Tamamlama**, şehir/akış tercihi ve enstrümanların birlikte düzenlendiği tek tam sayfadır; tek **Değişiklikleri kaydet** düğmesi vardır. Önceki iki seçenekli alt menü son tasarım değildir.
- Şehir için seçili şehri gösteren **tek alan** vardır. Dokununca tüm şehirlerin aramalı listesi açılır; seçili işareti, Türkçe arama, iptal ve klavye uyumu bulunur. Sayfaya yayılan şehir kutuları reddedildi. Etkinliğin mevcut konum seçicisi ortak `location_picker_sheet.dart` bileşenine çıkarıldı; etkinlik de bunu kullanır.
- Mevcut şehir/enstrüman işlemleri ortak controller'larla yeniden kullanılır; yeni backend endpoint'i yoktur. Yalnızca değişen alanlar, önce şehir sonra enstrümanlar kaydedilir. Kısmi başarı korunur; yeniden deneme yalnızca başarısız alanı gönderir.
- Kaydedilmemiş taslak için çıkış onayı, tekrar gönderme ve kayıt sırasında geri çıkış engeli, oturum değişimi kontrolleri vardır. Kayıt sonrası sayfa açık kalır; değişiklikle çıkıldığında mevcut profil yenilemesi çalışır.
- Son normal APK telefona aynı paket/imza ile kuruldu; form açık bırakıldı. Gerçek hesap tercihlerine test amacıyla kayıt yapılmadı. Kayıt ve hata/yeniden deneme davranışı otomatik testlerde doğrulandı.

## Doğrulama ve sınırlar

Oturum boyunca hedefli testler, gerçek PostgreSQL/Redis ve FFmpeg kontrolleri, Vivo V2206 üzerinde kaydırma/medya/kart ve son form kontrolleri yapıldı. Farklı turlardaki test sayıları örtüşür; toplanmamalıdır. Kapanışın nihai toplu test sonucu bu bölüme kaydedilir.

- Kapanış statik analizi: tüm `lib`, `test`, `integration_test`, `test_driver` için temiz.
- Kapanış tam Flutter paketi: **4.756 başarılı, 0 başarısız, 2 isteğe bağlı görsel çıktı testi atlandı**. Atlanan iki test çıktı klasörü ortam değişkeniyle çalışan eski görsel dışa aktarma düzenekleridir. İlk taramadaki iki eski golden referansı, yalnızca onaylı dalga çizimi alanındaki fark piksel karşılaştırmasıyla doğrulandıktan sonra güncellendi. Sekiz ekran golden'ı ve üç dalga sınır testi, ardından tüm paket yeniden geçti; üretim kodunu değiştirmek gerekmedi.
- Kapanış tam backend paketi: **4.094 başarılı, 0 başarısız/hata, 1 önceden devre dışı bırakılmış test** (`SoundConnectApplicationTests.contextLoads`). 583 rapor paketinde toplam 4.095 test; çalışma süresi 34 dakika 43 saniye. Gerçek PostgreSQL/Redis entegrasyonları ve üç gerçek FFmpeg testi çalıştı ve geçti; Docker/FFmpeg yokluğu nedeniyle geçilmiş sayılmadı.
- Kapanış ayrı PostgreSQL akış yük testi de geçti (1 test, atlama yok). TRACK/EVENT/PROFILE service/JDBC geliştirme senaryosunda p95: seri **112,81 ms**, 8 kullanıcı **285,31 ms**, 16 kullanıcı **589,22 ms**, aynı cursor tekrarları **660,21 ms**. 573 sağlayıcı çağrısı uyarı/hata olmadan tamamlandı; 16/16 tekrar byte düzeyinde aynıydı. Bu senaryo duyuruya özel yükü, HTTP/auth, Redis veya medya trafiğini ölçmez; üretim kapasitesi iddiası değildir.
- Kapanış API ve ayrı medya worker paketlemesi (`bootJar`, `mediaWorkerBootJar`) başarılı. Bu kapanışta Docker imajı başlatılmadı, çalışan API yeniden başlatılmadı ve üretime dağıtım yapılmadı.
- Mevcut API'nin süreç kimliği/başlangıcı korundu; kapanışta readiness `UP`. Mevcut MapStruct/deprecation derleyici uyarıları engelleyici hata değildi.
- Son normal cihaz APK SHA-256: `418c6379ac25a2340189ee0ca36ffcad7df30dd4aad29136968832e6061283ae`. Normal paket UID 10511, önizleme UID 10519. Normal pakette önizleme etkinliği/örnek medya yok; aynı imza doğrulandı.
- Gerçek Android H.264/AAC ve gerçek FFmpeg/ffprobe kullanıldı. RAM duyuru testleri gerçek kimlik doğrulamalı CDN uçtan uca testi değildir.
- Üretim öncesi hedef ortam HTTP/auth/Redis yükü, uzun süreli yük, CDN/IAM/HTTPS özel medya, mobil ağlar, ek cihazlar/iOS ve operasyonel yayın kontrolleri ayrı işlerdir. Geliştirme yük testi bunların yerine geçmez.

## Yeni oturumun çalışma kuralları

1. Önce bu belgeyi ve aşağıdaki ilgili belgeleri oku; `git status` ile mevcut durumu doğrula. Kullanıcının sıradaki isteğini bekle/uygula; yeni özellik icat etme, biten işleri baştan yapma.
2. Mevcut altyapıyı tara ve yeniden kullan; yetmiyorsa genişlet. Yeni modül gerçekten gerekirse gerekçesini kullanıcıya belirt. Onaylı tasarım ve yönlendirmeleri kendiliğinden değiştirme.
3. Gerçek uygulama/veri korunur. Örnek akış için `.preview` kullan; gerçek veritabanına mock içerik yazma. Kullanıcı kontrol yapmıyor varsayımıyla gerekli kod ve cihaz kontrollerini kendin yap, ancak gerçek hesap verisini gereksizce değiştirme.
4. Çalışma ağacını topluca sıfırlama. Geri dönüş istenirse yalnızca ilgili değişikliği, sonraki çalışmaları koruyarak geri al.
5. Haftanın içerikleri moderasyon yükü nedeniyle rafa kaldırıldı. İkinci özellik henüz anlatılmadı. Dinleyici/mekân/stüdyo akış tasarımları kararlaştırılmadı.

## Yerel ortamı yeniden başlatmadan önce

- Son durumda API, yerel Java süreciyle 8080'de çalışıyordu. `dev.cmd up` komutunu körlemesine çalıştırma; önce portu ve readiness'i doğrula. Önceki yanlış boş port okuması yüzünden Docker API başlatması 8080 çakışması yaşamıştı; çalışan Java API ve veri hacimleri korunmuştu. Docker API/worker'ın Created durumunda olması tek başına mevcut API'nin kapalı olduğunu göstermez. PID gibi değerleri yeniden doğrula.
- Telefon bağlantısını `adb devices` ile yeniden denetle. Mevcut fiziksel cihaz `10GCA400GT0001N`; geliştirme bağlantısı `adb -s 10GCA400GT0001N reverse tcp:8080 tcp:8080`. Normal kontrollerde scrcpy'yi gereksizce kapatma; performans ölçümünde belgelenmiş koşulları uygula ve sonunda geri aç. Uygulamayı uninstall/clear-data yapma, şifre isteme.
- Normal paket `com.berkayb.soundconnect.soundconnect_23_12_25codx`, önizleme bunun `.preview` uzantılı ayrı paketidir. Normal geliştirme APK'sı `build/normal/soundconnect-debug.apk`.
- Flutter wrapper'ı bu makinede başlangıç kilidinde takılabiliyor. Gerekirse `C:\Users\user\development\flutter\bin\cache\dart-sdk\bin\dart.exe` ile `C:\Users\user\development\flutter\bin\cache\flutter_tools.snapshot` çalıştır. Flutter komutlarını eşzamanlı çalıştırma. SDK yazımı ve bazı Windows port/Docker okumaları sandbox dışı araç izni gerektirebilir.
- `.env`/token/anahtar içeriğini çıktı verme veya commit etme. Yerel kanıtlar üst klasörde `.local-verification`, yedekler `.local-backups` altındadır; Git'te bulunmaları beklenmez.

## İlgili kalıcı belgeler

- Frontend: [Tasarım kararları](feed-design-decisions.md), [İzole önizleme](design-preview.md), [Duyuru uygulaması](announcement-implementation.md), [Cihaz performans düzeneği](../integration_test/README.md).
- Backend: `docs/musician-feed-v1.md`, `docs/musician-feed-performance.md`, `docs/announcements-feed.md`, `docs/announcement-analytics.md`, `docs/MediaModule/IsolatedMediaWorker.md`.
- Son cihaz kanıtı yerelde `.local-verification/profile-city-picker/validation.json`; kapanış günlükleri `.local-verification/session-close-20260913/`.
