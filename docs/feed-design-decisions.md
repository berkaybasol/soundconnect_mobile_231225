# Müzisyen akışı tasarım kararları

Son güncelleme: 13 Eylül 2026. Bu belge tasarım seçimlerini ve bunların ortak Flutter akış bileşenlerine uygulanmış ilk sürümünü kaydeder.

## Onaylanan yön

- **B · Sahne** düzeni seçildi: tek yazar satırı, görsele ve müziğe öncelik ve daha az iç içe kutu. Mevcut beğeni ve yorum tasarımı ile davranışı korunacak; bu alanlarda taslak yerine mevcut uygulama esas alınacak.
- **Mevcut/orijinal alt menü korunacak.** Kullanıcının son kararı, daha önce seçilen B alt menüsünün yerine geçer; B taslağındaki alt menü uygulamaya taşınmayacak.
- B düzeni, mevcut SoundConnect renkleriyle hazırlanacak. B'nin ilk sunumdaki kömür rengi, sıcak beyaz ve pastel paleti şu an uygulanmayacak.
- **Kapaksız parçalar**, tek başlık içeren kompakt dalga biçimli oynatıcıyla gösterilecek. Öneri kullanıcı tarafından onaylandı; açık karar değildir.

## Korunacak mevcut etkileşimler

- **İlanı incele, Etkinliğe git ve benzeri içerik eylemleri**, uygulamanın ilgili mevcut detay sayfasına yönlendirecek. Kartın altında veya akışın içinde yeni bir detay alanı açılmayacak.
- **Beğeni ve yorumlar**, mevcut tasarımları, açılma biçimleri ve davranışlarıyla korunacak. Taslaktaki örnek yorum kutusu veya farklı etkileşim düzeni uygulamaya taşınmayacak.
- **Arama**, mevcut uygulamadaki açılma ve gezinme davranışını koruyacak. Arama düğmesine basıldığında akışa ikinci bir arama alanı eklenmeyecek.
- Sohbet içindeki taslağın yerinde açılan arama, yorum ve detay alanları yalnızca örnek etkileşimlerdir; ürün davranışı için referans değildir. Bu kararlar gelecekteki taslak güncellemelerinde ve Flutter uygulamasında esas alınacak.

## Kullanılacak mevcut renkler

Mevcut `AppColors` anlamsal renkleri ve marka gradyanı kullanılacak; yeni tema altyapısı oluşturulmayacak.

| Taslaktaki kullanım | Mevcut `AppColors` alanı | Renk |
| --- | --- | --- |
| Derin lacivert zemin | `navBlueDeep` | `#0B1321` |
| Alt menü zemini | `navBlue` | `#101827` |
| Yumuşak panel yüzeyi | `navBlueSoft` | `#1B2436` |
| Giriş alanı yüzeyi | `inputFill` | `#151C2C` |
| Ana metin | `textPrimary` | `#EFF2F8` |
| İkincil metin | `textMuted` | `#B7C0D0` |
| Sınır ve ayırıcı | `border` | `#2A3447` |
| Mercan vurgu | `coral` | `#F47C7C` |
| Marka vurgusu | `brandGradient` | Mevcut turuncu–pembe–mor gradyan |

## İleride değerlendirilecek alternatif tema

B'nin ilk sunumdaki paleti ileride ayrı bir tema seçeneği olarak değerlendirilmek üzere saklanır. Şu an uygulama veya tema altyapısı kapsamına alınmaz.

| Anlamsal renk | Saklanan değer |
| --- | --- |
| Zemin | `#151516` |
| Ana metin | `#F5F1E9` |
| İkincil metin | `#AAA6A7` |
| Ayırıcı | `#303032` |
| Sunumda uygulanan vurgu | `#F48F94` |
| Lila vurgu | `#BCABE3` |
| Alt menü zemini | `#191819` |
| Orta düğme zemini | `#E5D8E5` |

## İlk uygulamanın kapsamı

- Gerçek etkinlik afişi kırpılmadan gösteriliyor; tarih ve diğer bilgiler görselin altında. Afişsiz etkinliklerin mevcut `EventPosterFallback` bileşeni korunuyor. Bu yerleşim kullanıcının değerlendireceği ilk uygulamadır.
- Üst barın kapsamı bu kararla genişletilmedi. Açıkça seçilen alanlar dışında mevcut ekranlar ve davranışlar korunacak.
- Dış kart çerçeveleri ve tekrarlanan yayıncı başlıkları kaldırıldı. Farklı bir profil paylaşımı, sosyal etkileşim gerekçesi ve sponsor açıklaması korunuyor. Fotoğraf/video önce, başlık/açıklama sonra geliyor; duyuruda tekrar eden SoundConnect kimliği yalnızca akışta kaldırıldı.
- Şarkı veri sözleşmesinde kapak alanı bulunmadığından mevcut ses altyapısıyla kapaksız oynatıcı kullanılıyor. Yeni medya API'si veya tema altyapısı eklenmedi; Collab kartı ve etkinlik varsayılan görseli yeniden yazılmadı.
- Akış zemini `AppColors.navBlueDeep`; mevcut yorum/beğeni, menü ve diğer bileşenlerin `BackstagePalette` renkleri korunuyor. Yukarıdaki HTML taslağı renk tablosu bu bileşenleri yeniden boyamak için uygulanmadı.
- Normal uygulamanın detay yönlendirmeleri değişmedi. İzole önizlemenin mevcut sınırlamaları devam ediyor: etkinlik/Collab/sosyal detayları katalog örneğiyle temsil ediliyor; gerçek veri isteyen bu modüllerin tamamı taklit edilmiyor. Medya, duyuru ve yorum ekranları gerçek bileşenleri kullanıyor.

## Doğrulama ve geri dönüş

- 199 regresyon testi ve değişen üretim dosyalarının statik analizi geçti.
- Son görsel kontrolde başlangıçtaki geçen süre `0:00` yapıldı; ilgili 43 test yeniden geçti ve son profile APK'nın gerçek telefon ekranında doğrulandı.
- Vivo V2206 üzerinde 62 katalog görünümü, 58 kartlık dolu akış, gerçek yorum/beğeni, gizleme/dizin ve yerel ses/video testi geçti. Sonuçlar `.local-verification/feed-sahne/device-report.json` içinde.
- Üst bar, mevcut alt bar, normal detay yönlendirme dosyası ve mevcut beğeni/yorum bileşeni tasarım öncesi sürümle karşılaştırıldı; değişmedikleri doğrulandı.
- Son internetsiz profile APK ayrı önizleme paketine kuruldu ve dolu akış açık bırakıldı. Asıl uygulamanın sürüm/güncelleme kaydı başlangıçla aynı; bu tur asıl pakete kurulum yapılmadı.
- Tasarım öncesi dosyalar ve önizleme APK'sı çalışma alanındaki `.local-backups/feed-sahne-20260913` içinde saklanıyor. Yalnızca bu turdaki değişiklikleri gösteren yama ve önce/sonra dosya karmaları `.local-verification/feed-sahne` içinde. Geri dönüşte tüm çalışma ağacını sıfırlamak yerine bu kapsam kullanılmalı; daha eski geliştirmeler korunmalı. Sonradan düzenlenen dosyalar geri yüklenmeden önce kayıtlı karma ile karşılaştırılmalı.

## Kalp ve oynatıcı düzenlemesi · 13 Eylül 2026

- Kullanıcının yeni isteğiyle akış kalpleri yorumlardaki görünümle eşleştirildi: 18 px yuvarlak kalp, her iki durumda pembe `AppColors.likeHeart`, beğenilmemiş durumda boş ve beğenilmiş durumda dolu. Mevcut yorum bileşeni, beğeni yazıları, sayılar ve davranışlar korunuyor.
- Akıştaki şarkı/ses kartı ve oradan açılan yüklenmiş ses detayında içi boş, ince marka gradyan çerçevesi kullanılıyor. Dolu pembe çal düğmesinin yerini çerçeveli, gradyan ikonlu kontrol aldı. Ses detayındaki geri/ileri kontrolleri de aynı çizgide ve en az 48 px dokunma alanına sahip.
- Mevcut `GradientOutlineButton` çizicisi ortak `GradientOutline` sarmalayıcısıyla yeniden kullanıldı. Ses altyapısı ve `WaveformStub` yeniden yazılmadı; dalga çizgilerinin dar alanda taşmasını ve geniş alanda boşluk bırakmasını önleyen ölçü düzeltmesi yapıldı.
- Bu tur akış ve yüklenmiş ses detayını kapsar. Spotify'ın kendine özgü renk/kontrol düzeni ve bağımsız profil kartlarının yerleşimi korunuyor.
- Değişen altı üretim dosyasının analizi ve 166 regresyon testi geçti; 80, 160 ve 520 px genişliklerde dalga çizim sınırları gerçek piksel çıktısıyla kontrol edildi.
- Bu turun öncesindeki dosyalar ve APK `.local-backups/feed-controls-20260913` içinde; kontrol kayıtları `.local-verification/feed-controls` içinde saklanıyor.
- Son internetsiz önizleme telefona kuruldu. Akışta kalbin boş/dolu değişimi ve sayaç artışı, gerçek ses ilerlemesi/duraklatma, ses detayındaki geri/ileri düğmeleri (yüzde 0 ve yüzde 100) doğrulandı. Önizleme yeniden başlatılarak başlangıçtaki dolu akış açık bırakıldı; asıl uygulamaya kurulum yapılmadı.

## TableGroup kartı · 13 Eylül 2026

- Kullanıcı Collab ve etkinlik kartlarını kabul etti; TableGroup için dinleyici profilindeki masa kartının akışa uyarlanmasını istedi.
- Dinleyici kartının açıklama, konum, mekân/buluşma bilgisi ve katılımcı bölümü ortak `TableGroupSharePreview` bileşenine çıkarıldı. Profildeki varsayılan görünüm aynı; akışta başlık 23 px ve en fazla dört satır. Akışın mevcut yayıncı, paylaşım notu ve beğeni/yorum satırları kullanılıyor.
- Profildeki mevcut kaynak doğrulaması ortak parser olarak kullanılıyor. Yeni backend alanı veya paralel TableGroup altyapısı eklenmedi. Eksik eski kaynaklarda kişi sayısı/durum uydurulmadan sade detay bağlantısı gösteriliyor.
- Açık masa mevcut TableGroup detay yolunu açıyor. Süresi dolmuş/iptal edilmiş kaynak profil kartındaki durum gösterimini kullanıyor; paylaşımın beğeni/yorumları kullanılabilir kalıyor. Ekranda beklerken sona erme, yerel gün değişimi ve uygulamaya dönüşte bilgi yenileniyor; dokunmada süre yeniden kontrol ediliyor.
- Dört izole önizleme kaydı normal, dolu, süresi dolmuş ve mekânı belirtilmemiş masa örnekleri içeriyor. Masa detay kimliği kaynak kimliği, etkileşim kimliği ise backend sözleşmesindeki paylaşım kimliği. Sunucuya örnek veri yazılmadı.
- Bu turun dosya/APK yedeği `.local-backups/feed-tablegroup-20260913`, doğrulama kayıtları ve sınırlı değişiklik yaması `.local-verification/feed-tablegroup` içinde.
- Altı değişen üretim/önizleme dosyasının analizi ve 137 test geçti. Vivo V2206 üzerinde dört masa durumu, beğeni sayısının 42→43 artışı ve mevcut yorum ekranı doğrulandı. Son APK ayrı önizleme kimliğiyle ve INTERNET izni olmadan doğrulanarak kuruldu. Normal uygulamanın sürüm/güncelleme kaydı aynı; üst bar, alt bar, gerçek detay yönlendirmesi ve yorum kalbi dosyalarının karmaları değişmedi.
- RAM verisi yeniden başlatılarak sıfırlandı; telefonda `tablegroup` filtresiyle dört kartlık katalog açık bırakıldı.

## Profil tamamlama zemin denemesi geri alındı · 13 Eylül 2026

- Kullanıcı daha açık lacivert zemin denemesini reddetti ve hemen geri alınmasını istedi. Son renk değişikliği, öncesindeki dosyanın karması doğrulanarak geri alındı; önceki onaylı önizleme APK'sı yeniden kuruldu.
- TableGroup, kalp/oynatıcı ve önceki kabul edilen tasarımlar korunuyor. Profil tamamlama için sonraki karar aşağıdaki A seçeneğidir.
- Reddedilen denemenin doğrulama kayıtları `.local-verification/feed-completion-tone`, geri dönüş yedeği `.local-backups/feed-completion-tone-20260913` içinde.

## Profil tamamlama · A seçeneği onaylandı · 13 Eylül 2026

- Kullanıcı karşılaştırmadaki A seçeneğini onayladı: görev kartının ve tamamlandı durumunun iç zemini akış zeminiyle aynı `AppColors.navBlueDeep` (`#0B1321`) yapıldı.
- Mevcut kenarlık, ikon ve gradyan eylem düğmesi korundu; kaynak dosyada yalnızca iki zemin rengi değişti.
- Statik analiz ve mevcut iki profil tamamlama yerleşim/eylem testi geçti. Son internetsiz APK ayrı önizleme paketine kuruldu; gerçek telefon görüntüsünde kart içi ve akış zemini piksel değerleri aynı `#0B1321` olarak doğrulandı. Normal uygulamanın sürüm/güncelleme kaydı aynı; profil tamamlama kataloğu açık bırakıldı.
- Önceki belge, kaynak dosya ve APK `.local-backups/feed-completion-a-20260913` içinde; doğrulama ve sınırlı değişiklik yaması `.local-verification/feed-completion-a` içinde saklanıyor.

## SoundConnect duyurusu başlık ikonu · 13 Eylül 2026

- Kullanıcının isteğiyle akıştaki “SoundConnect duyurusu” etiketinin solunda mevcut `BrandGradientIcon` ve `Icons.campaign_rounded` kullanıldı (18 px).
- Aynı görünüm hem `PLATFORM_ANNOUNCEMENT` akış gerekçesinde hem de öncelikli promosyon açıklamasında uygulanıyor. Diğer başlıklar ve beğeni ikonları korundu.
- Statik analiz ve mevcut 28 başlık/duyuru testi geçti. İnternetsiz ayrı önizleme paketi telefona kuruldu ve megafon gerçek ekranda doğrulandı; duyuru kataloğu açık bırakıldı. Normal uygulamanın sürüm/güncelleme kaydı aynı.
- Önceki belge, kaynak dosya ve APK `.local-backups/feed-announcement-icon-20260913` içinde; doğrulama kayıtları `.local-verification/feed-announcement-icon` içinde saklanıyor.

## Tasarım turu sonrası normal uygulama · 13 Eylül 2026

- Kullanıcı tasarım düzenlemelerini tamamladığını belirtti. Onaylanan ortak bileşenlerle normal `lib/main.dart` girişli debug APK, mevcut USB/8080 geliştirme bağlantısı için derlendi ve normal pakete `adb install -r` ile kuruldu. Yeni tasarım değişikliği yapılmadı.
- Tüm `lib` analizi ve 160 akış/ortak bileşen/yönlendirme/önizleme ayrımı testi geçti. APK'nın asıl paket kimliği, `MainActivity`, gerçek ses servisi ve mevcut kurulumla aynı imza sertifikası doğrulandı; önizleme etkinliği ve paket içi örnek medya bulunmuyor. Android uygulama UID'si 10511 kaldı.
- Port kontrolünün ilk salt okunur sonucu eksikti. Projenin mevcut `dev.cmd up` başlatıcısı şema senkronizasyonu ve Docker derlemesini tamamladı; Docker API başlatması, zaten çalışan yerel Java API'nin kullandığı 8080 portuyla çakıştı. Mevcut Java API (PID 173100) durdurulmadı; `/actuator/health/readiness` yanıtı `UP`. Docker API/worker çalışmıyor; mevcut API ile devam ediliyor. Veri hacimleri sıfırlanmadı ve örnek akış verisi eklenmedi.
- İlk kurulumda giriş ekranı açıldı. Kullanıcı giriş yaptıktan sonra sonraki yönetim paneli düzenlemesinin cihaz kontrolünde gerçek müzisyen akışının açıldığı ve onaylanan tasarımın kullanıldığı doğrulandı; kayıt `.local-verification/profile-completion-menu/03-normal-home.png` içinde.
- Önceki kurulu normal APK ve karar belgesi `.local-backups/feed-normal-final-20260913` içinde; güncel paket `build/normal/soundconnect-debug.apk`, doğrulamalar `.local-verification/feed-normal-final` içinde. Ayrı internetsiz önizleme uygulaması da telefonda duruyor.

## Yönetim panelinde profil tamamlama · 13 Eylül 2026

- Kullanıcının isteğiyle müzisyen yönetim panelindeki Biyografi girişi kaldırıldı. Akış Tercihleri ve Enstrümanlarım, yeni Profil Tamamlama menüsünde toplandı.
- Mevcut `ProfileManagementSheet` ve iki mevcut düzenleyici kullanılıyor. Yeni backend/modül veya veri silme işlemi yok; profil üzerindeki biyografi düzenlemesi ve akışın BIO tamamlama bağlantısı korunuyor.
- Alt menü seçimleri açıldığı oturuma ve profile bağlı. Enstrüman kaydı mevcut profil yenileme akışına dönüyor; profilin hızlı menüsünden girildiğinde eksik kalan yenileme çağrısı da tamamlandı.
- Tüm `lib` analizi ve 51 ilgili test geçti. Normal debug APK aynı paket/imza ile `install -r` kullanılarak güncellendi; normal UID 10511 ve önizleme UID 10519 korundu.
- Gerçek telefonda yeni hiyerarşi, şehir listesinin yüklenmesi, kayıtlı iki enstrümanın seçili gelmesi ve iki düzenleyiciden iptal ederek yönetim paneline dönüş doğrulandı. Gerçek hesap tercihleri değiştirilmedi; kaydetme davranışı testlerde doğrulandı. Profil Tamamlama menüsü açık bırakıldı.
- Bu turun kaynak/test/belge ve normal APK yedeği `.local-backups/profile-completion-menu-20260913`, sınırlı değişiklik yaması ve cihaz kayıtları `.local-verification/profile-completion-menu` içinde.

## Profil tamamlama tek sayfaya dönüştürüldü · 13 Eylül 2026

- Kullanıcı alt menü yerine her iki alanı aynı sayfada düzenlemek istedi. Yönetim panelindeki Profil Tamamlama artık doğrudan tam sayfa form açıyor: şehir araması/seçimi, seçili enstrümanlar, enstrüman araması ve tek Değişiklikleri kaydet düğmesi.
- Mevcut şehir ve enstrüman düzenleyicilerinin yükleme/kayıt işlemleri ortak controller'lara çıkarıldı; hem eski bağımsız düzenleyiciler hem bu sayfa aynı işlemleri kullanıyor. Mevcut backend yeterliydi; yeni endpoint, veri modeli veya veri silme işlemi eklenmedi.
- Yalnızca değiştirilen alanlar mevcut endpoint'lerine kaydediliyor. Şehir kaydı başarısızsa enstrüman yazımı başlamıyor. Şehir kaydedilip enstrüman kaydı başarısızsa şehir korunuyor ve tekrar denemede yalnızca enstrümanlar gönderiliyor. Kaydetme sonrası sayfa açık kalıyor; değişiklik varsa geri dönüşte profil yenileniyor.
- Kaydedilmemiş seçimler geri çıkışta korunuyor veya kullanıcının sayfa içi kararıyla bırakılıyor. Kayıt sırasında tekrar gönderme/geri çıkış engelleniyor; oturum değişiminde sonraki yazım başlamıyor. Şehir tercihi için mevcut sürüm çakışması ve bir kez yeniden deneme davranışı korunuyor.
- Tüm `lib` ve değişen test dosyası analizi temiz. İlk 58 regresyon, son değişiklikler ve mevcut şehir çakışması davranışı için 29 hedefli kontrol geçti (bu sayılar tekrar koşulan testler içerir). Son alt alan/renk düzenlemesi için 2 ilgili test ve sayfa analizi yeniden geçti.
- Normal APK aynı paket/imza ve UID 10511 ile güncellendi. Gerçek telefonda iki arama alanı, seçili iki enstrüman, klavye açıkken kayıt düğmesi, sayfa kaydırma ve kaydetmeden çıkış doğrulandı. Deneme seçimleri bırakıldı; gerçek hesap tercihlerine yazım yapılmadı. Son APK'da sayfa başlangıcı ve alt kayıt alanının kapalı zemini kontrol edildi; yeni form açık bırakıldı.
- Önceki sürüm `.local-backups/profile-completion-page-20260913`, kaynak kapsamı/kanıtlar `.local-verification/profile-completion-page` içinde. Önceki alt menü tasarımı bu sayfayla değiştirildi.

## Profil tamamlama şehir seçimi · 13 Eylül 2026

- Kullanıcı sayfaya yayılan şehir kutularını reddetti. Yerine mevcut şehri gösteren tek alan kondu; dokununca tüm şehirlerin yer aldığı aramalı seçim listesi açılıyor. Seçim aynı forma dönüyor, temizleme alanın yanındaki düğmeden yapılıyor. Kayıt formun mevcut tek düğmesiyle devam ediyor.
- Etkinlikteki mevcut konum seçicisi ortak `location_picker_sheet.dart` bileşenine çıkarıldı; etkinlik de aynı bileşeni kullanıyor. Şehir listesinin yüklenmesi ve kayıt controller'ları değiştirilmedi. Ortak seçici Türkçe arama, seçili işareti, iptal, klavye yüksekliği ve tekrarlı seçim korumasını içeriyor.
- Tüm `lib` ve değişen test dosyasının analizi temiz; 39 profil tamamlama/şehir seçimi/etkinlik regresyon testi geçti. Tam liste, alt sıralara kaydırma, Türkçe arama, iptal ve yalnızca taslak seçimin değişmesi doğrulandı.
- Normal APK aynı imza/paket ve UID 10511 ile güncellendi. Telefonda alan, tam liste, klavyeli arama ve seçimin forma dönmesi kontrol edildi; deneme seçimi temizlendi, gerçek hesap tercihi kaydedilmedi. Yeni form açık bırakıldı. Ayrı önizleme UID 10519 korundu.
- Önceki dosya/APK yedekleri `.local-backups/profile-city-picker-20260913`, kapsam ve cihaz kayıtları `.local-verification/profile-city-picker` içinde.
