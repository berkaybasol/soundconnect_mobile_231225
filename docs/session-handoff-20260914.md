# SoundConnect — 14 Eylül 2026 oturum devamı

Bu belge, `session-handoff-20260913.md` sonrasındaki tamamlanmış işleri anlatır.
Her iki repo `feature/local-simulation` dalında. Eşleşen backend kapanış commit'i
`1ec3fa2ad4c888e74bb73be4df4cbf7d06c2c3a5`; frontend kapanışı bu belgeyi içeren
commit'tir. `2b8d4f3` / `0bc4f70` bu çalışmanın başlangıç commit'leridir.
Yeni oturumda HEAD, uzak dal ve çalışma ağacını ayrıca doğrula.

Aşağıdaki ara aşamalardaki “DB uygulanmadı / uygulama başlatılmadı / commit yok”
ifadeleri tarihsel kayıttır. Güncel durum en sondaki **Gerçek cihaz ve yerel DB
kapanışı** bölümüdür: migrationlar uygulandı, güncel normal APK gerçek backend ile
telefonda kontrol edildi. Stüdyo akışı henüz yapılmadı; sıradaki görüşme konusudur.

## Kullanıcının son kapsamı

Müzisyen akışını inceleyip doğrulanan hataları ve algoritma sorunlarını düzeltmek
onaylandı ve tamamlandı. Ardından kullanıcı mekân akışını da onayladı: profil
tamamlama olmayacak, keşif/fırsat dengesi müzisyen/grup/performans bulmaya
yönelecek, bunun dışındaki davranışlar aynı kalacak. Tasarım, alt bar, arama, gerçek detay
yönlendirmeleri ve ortak etkileşim altyapısı korunur. Gerçek DB'ye mock içerik
eklenmez. Sonrasında dinleyicinin Mainstage akışı da tamamlandı ve onaylandı.
Kullanıcı ilk aşamada Flutter/backend'i kendisi açmak istedi; kapanışta bu isteğini
güncelleyip gerçek DB migrationı, bağlı telefonda güncel backend/Flutter kontrolü
ve ardından iki repoya commit/push yapılmasını açıkça istedi.

## Tamamlanan giriş / OTP düzeltmesi

Kayıt doğrulama ekranında uygulama kapanınca oluşan doğrulanmamış hesap artık
doğru parola ile giriş denediğinde genel yetki hatası yerine mevcut OTP akışına
devam eder. Backend `1113 EMAIL_VERIFICATION_REQUIRED` ile yalnız parola
doğrulandıktan sonra canonical e-posta döndürür; frontend bunu doğrulayıp mevcut
OTP sayfasına taşır. Hatalı OTP `1114` ile ayrıdır. Devam edilen kayıtta sahte
180 saniyelik kod süresi başlatılmaz; açık yeniden gönderim gerçek süreyi başlatır.
Parola sıfırlamak e-posta onayı yerine geçmez. Önceki auth değişiklikleri korundu.

## Tamamlanan müzisyen akışı düzeltmeleri

- Takip kartının kabul edilmiş yerel durumu sonraki başarılı sunucu yenilemesinde
  emekli edilir. Başka ekranda takipten çıkma artık eski `true` ile ezilmez;
  eşzamanlı takip işlemleri yine korunur.
- Medya/duyuru detayından dönüş, tüm ilk sayfayı yüklemek yerine mevcut hedefin
  beğeni/yorum bilgisini ortak repository üzerinden tazeler. Yüklü 40 kart,
  cursor ve akış oturumu korunur. Aynı hedefin tüm kartları birlikte güncellenir.
- Eski okuma, hesap değişimi, eşzamanlı beğeni/yorum ve geç sayfalama cevapları
  için korumalar tamamlandı. Başarısız beğeni, o sırada eklenen yorumu geri almaz.
- Backend algoritması `musician-v1.2.0`: çeşitlilik, sayfa seçimi sırasında tüm
  sınırlı aday havuzunda uygulanır; son beş organik kartın geçmişi sonraki sayfaya
  taşınır. Aynı yazara ait ilk 20 aday artık alternatif yazarı dışarıda tutmaz.
- Uygun Collab/etkinlikler, arz varsa kalan normal seçim slotlarının yaklaşık
  %20'sine erişir (`floor(slots/5)`, en az beş slotta). Genel profil önerileri bu
  rezervasyonu doldurmaz. Küçük sayfada ana içerik keşfe kurban edilmez; seyrek
  akış mevcut keşif adaylarıyla doldurulur.
- Gerçek organik `IMPRESSION` kayıtlarının son 24 saati 240.000 puanlık yumuşak
  azaltma sağlar; önden yükleme görülme sayılmaz ve içerik kalıcı dışlanmaz.
  Sorgu oturum başlangıcında sabittir. Storage/transaction hatası halinde içerik
  korunur ve operasyon metriği artar.
- Duyurular yeni plana alınırken aynı hesap/duyuru için altı saat bekleme ve kayan
  24 saatte iki gösterim sınırı uygulanır. En fazla üç duyuru, görülmemiş en yeni
  duyurunun erken konumu ve mevcut normal kart aralıkları korunur. Önceden açılmış
  eşzamanlı planlar için kilitli küresel kota iddiası yoktur.
- Sponsorun aynı hedefteki yorumları bastırmasıyla açılan sayfa boşlukları hazır
  havuzdan doldurulur. Modül kartları bitişmez; yalnız bloke modüller kaldığında
  gereksiz boş devam sayfası sunulmaz.
- Duyuru okumalarında beş saniyelik transaction timeout, mevcut Micrometer
  üzerinden akış/provider süreleri, hata/timeout, kuyruk ve içerik dağılımı
  ölçümleri eklendi. Yeni public endpoint yoktur.

## Doğrulama ve dağıtım sınırları

Aşağıdaki 448/445 sayıları müzisyen düzeltmesi tamamlandığındaki önceki
doğrulamadır. Mekân uyarlamasını da içeren güncel sonuçlar belgenin sonundadır.

Frontend ilgili geniş paket: **448 test geçti**. Statik analiz temiz.
Backend 66 pakette son sürümleri esas alınan **445 test geçti**, hata/atlama yok:
geniş PostgreSQL/Redis regresyonu 442, ardından son mixer değişiklikleri için
ilgili paketlerin tekrar çalıştırılması ve üç ek sınır testi. Toplamlar yinelenen
test çalıştırmalarını iki kez saymaz. Önceki auth regresyonları da bu paketlerde.

Son izole yük testi de geçti: PostgreSQL'de 50.000 parça, 10.000 etkinlik,
6.400 nitelikli gösterim. Seri/8/16 kullanıcı ve aynı-cursor p95 süreleri sırasıyla
154,15 / 492,81 / 1.009,94 / 1.098,38 ms. 573/573 sağlayıcı çağrısı tamamlandı;
hata/uyarı yok, 16/16 aynı-cursor cevabı byte düzeyinde aynı. Mevcut 6 worker,
24 kuyruk, 4 saniye provider bütçesi ve 10 DB bağlantısı artırılmadı. Kapsam
TRACK/EVENT/PROFILE service/JDBC geliştirme senaryosudur; HTTP/medya veya tüm
sağlayıcıların üretim kapasitesi değildir. Rapor ve planlar aynı kanıt dizininin
`backend-load-report/` altındadır; günlük `backend-fixes-load.log`.

Kanıtlar workspace kökündeki `.local-verification/feed-audit-20260914/` altında:
`frontend-fixes-final.log`, `frontend-fixes-analyze-final.log`,
`backend-fixes-regression.log`, `backend-fixes-final-mixer.log`, XML arşivleri ve
`backend-fixes-final-summary.json`. Backend doğrulaması Windows directory
classpath sorunu nedeniyle aynı kaynaklardan oluşturulan izole main JAR ve
`fixes.gradle` üzerinden çalışır; uygulama jar'ı değiştirilmez.

Eklenen `scripts/db/2026-09-14-musician-feed-recent-views.sql` yalnız gösterim
okuma indeksi ekler; `scripts/dev.ps1` sırasındadır. Gerçek DB'ye uygulanmadı;
başka ortama geçerken autocommit ve `ON_ERROR_STOP=1` ile uygulanmalıdır.
Kullanıcı verisi veya içerik ekleyen bir migration değildir.

Aday sağlayıcılarının sınırları değişmedi. Daha önce görülen adaylar havuzu
dolduruyorsa, havuz dışındaki her görülmemiş içeriğin bulunması garanti edilmez.
Ürün ağırlıkları açıklanabilir bir v1 politikasıdır; gerçek kullanım ölçümleriyle
iyileştirilebilir. Gerçek cihaz, HTTP/auth ve medya ağ kapasitesi bu oturumun
regresyon sonuçlarıyla yeniden doğrulanmış sayılmaz.

Backend ayrıntıları: `docs/musician-feed-v1.md`, `docs/musician-feed-recent-views.md`,
`docs/announcements-feed.md`, `docs/musician-feed-performance.md`.

## Tamamlanan mekân akışı uyarlaması

- Mevcut Backstage ekranı ve Cubit/repository altyapısı mekân hesabına açıldı.
  API, oturumdaki tek aktif kişisel role göre `/api/v1/feed/musician` veya
  `/api/v1/feed/venue` seçer. Ekran, alt bar, arama, beğeni/yorum, takip ve gerçek
  detay sayfaları korunur; duyurular menüsü ve sessize alınanlar yönetimi mekânda
  da aynı ekranları kullanır.
- Mekânda profil tamamlama capability, kart ve yönlendirme yoktur. Müzisyen
  tercih kaydı okunmaz/oluşturulmaz; sıralama mekânın mevcut şehrini kullanır.
- Keşif müzisyen/grup profili, parça ve performansa yöneldi. Yerel eşleşmede
  sanatçının fırsat şehri tercihi önceliklidir; boşsa hesap şehri kullanılır.
  Gruplarda aktif/doğrulanmış üyeler değerlendirilir. Özel şehir tercihleri
  payload'a eklenmez. Yerel arz yetersizse diğer şehirler tamamlar.
- Arz varsa normal slotların yaklaşık %20'si sanatçı/performans içeriklerine
  ayrılır; müzisyenin Collab/etkinlik önceliği kendi akışında aynı kalır.
  Takip edilen diğer profil türlerinin yayınları ve ortak sosyal kartlar kalır.
  Duyuru seçiminde `VENUE` audience kullanılır; sıklık ve yerleşim değişmedi.
- Mekân `venue-v1.0.0`, müzisyen `musician-v1.2.0` sürümündedir. Cursor role ve
  ana mekân kimliğine imzayla bağlıdır; rol/mekân değişiminde eski sayfa replay
  edilmez. Birden fazla uygun mekânda UUID-ilk olan kararlı şehir kaynağıdır.
  Flutter kullanıcı/token/rol değişince eski Cubit ve kaydırma durumunu ayırır.
- Yeni mekân endpoint'leri mevcut rate limit, moderasyon, feedback, telemetry ve
  teslimat servislerini kullanır. Müzisyen endpoint'lerinin rol sınırı korundu.
  Paylaşılan feature flag ve metriklerde tarihsel `musician` adı korunmuştur.

Güncel geniş regresyon: **frontend 521 test**, **backend 95 pakette 641 test**
geçti; backend hata/atlama yok. `flutter analyze --no-pub lib test` temiz.
Tüm repo analizi, eski `tmp` görsel render betiklerinde beş mevcut stil notu
bildirir; uygulama/test kaynaklarında bulgu yok. Java derleyicisinin mevcut
Lombok/MapStruct uyarıları sürer; yeni derleme hatası yok.

Kanıtlar `.local-verification/venue-feed-20260914/`: `frontend-regression.log`,
`frontend-source-analyze.log`, `backend-regression.log`,
`backend-regression-summary.json`, `backend-regression-xml/`.
Backend Windows classpath doğrulaması aynı izole main JAR yaklaşımını
`verify.gradle` ile kullanır. Üretim derleme ayarları bu workaround için değişmedi.
Mekân yük testi aynı geçici fixture üzerinde `-PfeedLoadAudience=VENUE` ile
çalışır; şehir/sahiplik kişiselleştirmesi de gerçek repository ve transaction
üzerinden okunur. Kullanıcının backend/Flutter süreci yeniden başlatılmadı.

Ayrıntılı ürün/API/oturum kuralları backend `docs/venue-feed-v1.md` belgesindedir.
Bu ek çalışma da henüz commit/push edilmedi; her iki HEAD değişmedi.

Son yük kontrolleri **her iki rol için geçti**. Mekân seri/8/16 kullanıcı ve
aynı-cursor p95: 177,71 / 470,76 / 941,65 / 1.135,68 ms. Müzisyen:
153,59 / 484,55 / 719,70 / 1.098,62 ms. Her rolde 573/573 sağlayıcı tamamlandı,
16/16 aynı-cursor cevabı birebir aynıydı; hizmet hatası/uyarısı yoktu.
Kanıtlar güncel dizinin `venue-load-report/`, `musician-load-report/`,
`venue-load-xml/`, `musician-load-xml/` ve `backend-*-load.log` dosyalarında.
Service/JDBC kapsamı ve üretim/HTTP/medya sınırları önceki bölümdeki gibi geçerlidir.

## Mekân akışı görsel önizlemesi

Kullanıcı geçici sahte içeriklerle birkaç ekran görüntüsü istedi. Mevcut preview
kataloğu/RAM repository'leri, VENUE oturumu ve gerçek
`BackstageProfilesHomeScreen` / Cubit / kartlarla 12 örnekli yerel render alındı.
Sıra görsel inceleme için elle düzenlenmiştir; backend sıralama kanıtı değildir.
Normal uygulama/backend/DB açılmadı, hesaba veri yazılmadı, APK kurulmadı.
Test işlemi kapandı; göreve ait geçici resim önbelleği de temizlendi. Eski ayrı
Android önizleme uygulaması ve örnek kaynak kataloğu değiştirilmedi.

PNG'ler ve rapor workspace `.local-verification/venue-feed-preview-20260914/`
altında: `01-akis-ve-duyuru.png`, `02-muzisyen-ve-grup.png`,
`03-performans-ve-kayit.png`. Yeniden üretilebilir geçici harness:
`tmp/venue_feed_20260914/render_test.dart`. Bu dosya normal girişe import edilmez.

Görsel incelemede CITY_MATCH metni mekânda “Mekânınla aynı şehirde” olarak
düzeltildi; müzisyen metni aynı kaldı. İki rol için iki widget testi eklendi.
İlgili kart/venue paketi ve render toplam 39 test geçti; son render ayrıca
tekrar geçti. Değişen uygulama/test dosyalarının statik analizi temiz.

## Dinleyici / Mainstage akışı

Kullanıcı dinleyicilerin uygulamanın iş tarafını görmemesini istedi: stüdyolar,
Collab ve bunlarla ilgili kaynak/paylaşımlar dışlanacak; takip edilen
dinleyicilerin uygun sosyal paylaşımları korunacak. Aynı tasarım, kartlar,
etkileşimler ve gerçek detaylar kullanılacak. Bu uyarlama mevcut ortak akış
motoru üstünde yapıldı; algoritma `listener-v1.0.0`, API `/api/v1/feed/listener`.

- Yeni `/listener-feed` ekranına dinleyici profil menüsünden ve mevcut Keşfet
  ekranının başlığındaki Akış girişinden ulaşılır. Mevcut Keşfet / Overthinking /
  Müzik Birleştirir! / Mesajlar / Profil alt barı ve Keşfet filtreleri korunur.
- Takip edilen dinleyici, müzisyen, mekân ve grupların uygun müzik, performans,
  etkinlik ve sosyal paylaşım kaynakları ortak sağlayıcılardan gelir. Profil
  tamamlama, Collab ve genel sponsor kartları yoktur. Duyurular LISTENER hedef
  kitlesini kullanır. Konum mevcut dinleyici hesap şehrinden okunur; müzisyen
  tercih kaydı oluşturulmaz. Müzik keşfi ulusaldır, etkinliklerde şehir sinyali
  kullanılır. Arz varsa yaklaşık %20 müzik/etkinlik keşif payı ve mevcut
  tekrar azaltma/çeşitlilik kuralları uygulanır.
- Stüdyo/Collab kaynakları aday sorgularında limitten önce elenir. Gömülü
  paylaşımlar, sosyal aktiviteler ve saklanmış sayfa tekrarları da güncel kaynak
  uygunluğundan geçer. Özel planlar ve hayalet kimliklerin mevcut gizliliği sürer.
  Rol/profil değişiminde eski cursor, teslimat ve Flutter oturum sonuçları
  dinleyici akışında kullanılamaz.
- Medya hedef kitlesi `contentAudience=MAINSTAGE|BACKSTAGE` olarak eklendi;
  depolama görünürlüğü PUBLIC/PRIVATE/UNLISTED'den bağımsızdır. Müzisyen, mekân ve
  grup yükleme/yönetiminde “Dinleyiciler dahil herkes” / “Yalnız sektör içi”
  seçer. Dinleyici MAINSTAGE, stüdyo BACKSTAGE olarak sabitlenir. Eski medyanın
  hedef kitlesi sahibi tarafından değiştirilebilir.
- Mevcut müzik kaybolmasın diye eski medya MAINSTAGE varsayılır. Serbest metin
  otomatik iş ilanı sınıflandırmasına tabi değildir; eski sektör içi medyalar
  sahipleri tarafından işaretlenmelidir. Stüdyo ve Collab yapısal olarak elenir.
  PUBLIC dosyaların önceden bilinen CDN adresleri özel depolamaya dönüştürülmez.
- Aynı sınır profil medyası/parçalar, arama, stüdyo detayları, Overthinking kaynak
  ve etkileşimlerinde uygulanır. Anonim Overthinking kaynağının gerçek stüdyo
  yazarı ve iliştirilmiş parçanın güncel hedef kitlesi de sunucuda kontrol edilir.
- Dinleyiciye göre süzülen misafire açık kaynak GET'leri artık dinleyici JWT'sini
  taşır. Bu kaynaklara sunulan geçersiz Bearer oturumu sunucuda 401 olur; misafir
  içeriğine düşmez. İstemcide istek boyunca guest/hesap/rol değişimi ve A→B→A
  geçişleri eski yanıtı iptal eder. Profil medyasının birleşik/fallback zinciri
  aynı bağlamı korur. Diğer public konum/etkinlik istekleri mevcut davranıştadır.

Yeni `scripts/db/2026-09-14-mainstage-content-audience.sql` migration'ı backend
sürümünden önce uygulanmalıdır; mevcut `scripts/dev.ps1` sırasına eklendi.
Gerçek veritabanına uygulanmadı, mock içerik eklenmedi. Kullanıcının normal
Flutter/backend süreci başlatılmadı veya yeniden başlatılmadı. Commit/push yok;
önceki auth, müzisyen ve mekân değişiklikleriyle birlikte çalışma ağacındadır.

Ayrıntılar backend `docs/listener-feed-v1.md` ve
`docs/mainstage-content-boundaries.md`; bu çalışmanın doğrulama kanıtları
workspace `.local-verification/listener-feed-20260914/` dizinindedir.

### Dinleyici doğrulama sonuçları

Frontend tüm test paketi ve son ilgili dosya tekrarları birlikte **4.881 geçen
test** içerir. İki isteğe bağlı PNG render testi, çıktı dizini verilmediği için
varsayılan olarak atlanır. İlk geniş koşudaki dört eski rol beklentisi (dinleyici
akış yetkisi ve stüdyo müşteri takvimi) yeni sözleşmeye göre düzeltildi; 39 testlik
son yönlendirme/sessize alınanlar koşusu geçti. M→LISTENER geçişinde eski satır ve
DELETE sonucunun iptali korunur, dinleyicinin yeni listesi kendi API'sinden gelir.
Toplam son test sürümlerini bir kez sayar; tekrar koşuları toplama eklenmez.
Son medya/repository paketi 100 testle tekrar geçti. `flutter analyze --no-pub
lib test` temizdir; yeni uyarı veya ignore/suppress eklenmedi. Yaşam döngüsü
kontrollerinde kullanılan context/State doğrudan denetlenir, mevcut oturum ve
kart değişimi korumaları sürer.

Backend 306 pakette **2.042 test geçti**, hata yok. Varsayılan kapalı iki native
FFmpeg test bildirimi atlandı; bunlar ayrıca etkinleştirilmedi (parametrik bildirim
etkinleştirilince iki örnek üretir). Yeni dinleyici PostgreSQL, migration ve kaynak
gizliliği testleri atlanmadan geçti. Akış, kaynak modülleri ve son auth güvenlik
koşularının XML'leri üst üste birleştirildi; yinelenen paketler iki kez sayılmaz.

İzole dinleyici yük testi de geçti. 50.000 parça / 10.000 etkinlik / 6.400 nitelikli
gösterim üzerinde seri, 8/16 kullanıcı ve aynı-cursor p95 süreleri
**152,07 / 542,38 / 931,22 / 1.103,22 ms**. 573/573 sağlayıcı tamamlandı; hata/uyarı
yok, 16/16 replay cevabı birebir aynı. Worker/kuyruk/DB sınırları artırılmadı.
Bu, gerçek HTTP/telefon/medya ağı veya üretim kapasitesi ölçümü değildir.

Kanıtlar aynı dizinde: `frontend-full-tests.log`, `frontend-final-role-tests.log`,
`frontend-final-media-tests.log`, `backend-final-summary.json`,
`backend-final-xml/`, `backend-listener-load.log`, `listener-load-report/`,
`listener-load-xml/`, `load-host.json` ve `source-hashes.json`.
Son analiz günlüğü `frontend-source-analyze-clean.log`, sonuç manifesti
`verification-manifest.json` dosyasıdır.

### Dinleyici akışı örnek ekran görüntüleri

Kullanıcının isteğiyle gerçek `ListenerFeedScreen`, ortak Cubit/kartlar ve mevcut
yerel önizleme kataloğu kullanılarak dört PNG alındı. Müzik/duyuru, konser, takip
edilen dinleyicinin Overthinking paylaşımı ve konser öncesi buluşma gösteriliyor.
12 örnek yalnız süreç belleğinde tutuldu; sıralama görsel örnek için elle seçildi.
Her ekrandaki içerik dinleyici uygunluk kontrolünden geçti. Gerçek API/DB veya
normal uygulama başlatılmadı; ağ çıkışı sıfır, yerel reset doğrulandı, göreve ait
resim önbelleği kaldırıldı. Normal uygulama kaynakları/tasarımı değiştirilmedi.

Workspace `.local-verification/listener-feed-preview-20260914/` altında:
`01-muzik-ve-duyuru.png`, `02-konser-ve-paylasim.png`,
`03-dinleyicilerin-paylasimlari.png`, `04-birlikte-dinleme.png` ve `report.json`.
Görseller 390×844 mantıksal ekranın 1170×2532 PNG çıktısıdır. Her biri ayrı Flutter
test sürecinde üretildi ve görsel olarak kontrol edildi. Geçici tekrar üretim
betiği `tmp/listener_feed_20260914/render_test.dart`; `LISTENER_PREVIEW_SECTION`
dart-define değerleri sırasıyla 0, 2, 4, 5'tir. Dört son render koşusu geçti.

## Gerçek cihaz ve yerel DB kapanışı

14 Eylül sabahı kullanıcı stüdyo akışından önce mevcut işleri kapatmayı istedi.
Bu kapanışta yeni stüdyo akışı veya yeni ürün özelliği uygulanmadı. Önceki
testlerden sonra davranış değiştiren kaynak düzenlemesi gerekmedi. Git'in yeni
dosyalar için yaptığı staged denetimde beş Java dosyasının yalnız sonundaki fazla
boş satır temizlendi; test edilen içerikle eşitlik ayrıca kaydedildi.

### Veritabanı ve güncel backend

- Hedef, Docker'daki `localhost:5433/soundconnectdb` yerel uygulama DB'sidir.
  5432'deki ayrı PostgreSQL'e dokunulmadı. Önce `pg_dump -Fc` yedeği alındı ve
  `pg_restore --list` ile arşivin okunabildiği doğrulandı; restore provası yapılmadı.
- Yedek workspace `.local-backups/session-close-20260914/soundconnect-pre-migration.dump`;
  SHA-256 `1f4b0092891adaa1de0beb0a509c8819c9548d39603182f060906e0f73c5b835`.
- Eski SoundConnect IDE Java süreci kapatıldı. Mevcut `dev.cmd boot` akışıyla
  migrationlar doğru sırada uygulandı ve güncel kaynaklardan backend açıldı.
  Yeni `2026-09-14-musician-feed-recent-views` ve
  `2026-09-14-mainstage-content-audience` kayıtları DB'de doğrulandı.
- Recent-views indeksi `indisvalid=true`, `indisready=true`; audience constraint'i
  `convalidated=true`; geçersiz veya stüdyo için yanlış audience satırı sayısı 0.
  Migration öncesinde de stüdyo backfill gerektiren satır yoktu. Mock içerik eklenmedi.
- Başlangıç ve cihaz kontrolü sonrasında readiness `UP`. `bootJar` ve
  `mediaWorkerBootJar` başarılı; API ve worker paketleri güncel kaynaklardan üretildi.
  Bu turda ayrı native worker süreci veya yeni medya yükleme/oynatma testi açılmadı.

### Fiziksel telefon kontrolü

- Vivo V2206 / Android 14, seri `10GCA400GT0001N`; normal `lib/main.dart` debug APK,
  USB reverse üzerinden gerçek `http://127.0.0.1:8080`. Önizleme giriş noktası yok.
- APK aynı paket üzerine `adb install -r` ile kuruldu. Paket
  `com.berkayb.soundconnect.soundconnect_23_12_25codx`, appId 10511;
  `berna` dinleyici oturumu korundu. Uninstall, clear-data, çıkış, parola değişimi
  veya yeni kimlik bilgisi isteme yapılmadı.
- Güncel normal APK `build/normal/soundconnect-debug.apk`;
  SHA-256 `7e391961d87f03113645c20e124bf2edc5718cf60235810797b8b74a7d860804`.
- 16 kayıtlı kontrol geçti: profil menüsünden ve Keşfet'ten Akış'a giriş, gerçek
  müzisyen/mekân önerileri, mekân detayına geçiş ve geri dönüş, yenileme ve kısa
  listenin kaydırılması, mevcut arama/sonuçtan gerçek profile yönlendirme, duyuru
  ve sessize alınanlar boş durumları, Overthinking okuması, beşli dinleyici alt
  barı, uygulamayı tamamen kapatıp açınca aynı hesabın ve akışın geri gelmesi.
- 04:33–04:36 gözlem aralığında 2 oturum / 4 teslimin tamamı `listener-v1.0.0`:
  her oturumda 1 MUSICIAN + 1 VENUE önerisi. 4 gösterim ve 1 açma doğru kullanıcı
  ve teslimlere bağlı; yasaklı kart/stüdyo yazarı ve eşleşme hatası 0. Sunucuda
  akış hatası/uyarısı yok. Mevcut Spring PageImpl serialization uyarısı gözlendi.
- İlk APK açılışı backend readiness'den önceydi; doğal bağlantı hatasından sonra
  sunucu hazırken yeniden deneme geçti. Sonraki soğuk açılış temizdi. Uygulama
  günlüklerinde Flutter exception, taşma veya native fatal crash bulunmadı.

Cihaz turu yalnız mevcut dinleyici hesabıyla yapıldı. Müzisyen/mekân oturumlarına
geçilmedi; bu rollerin doğrulaması yukarıdaki otomatik regresyonlar ve önceki
izole cihaz/önizleme kanıtlarıdır. Gerçek akışta iki profil önerisi vardı: çok
sayfalı akış, medya oynatma, beğeni/yorum yazma ve yeni OTP/parola sıfırlama bu
gerçek hesap üzerinde yeniden çalıştırılmış sayılmaz. Hesap tercihleri ve
paylaşımlar test için değiştirilmedi; doğal gösterim/açma telemetrisi oluştu.

### Kanıtlar ve bırakılan durum

Workspace `.local-verification/session-close-20260914/` altında
`device-validation.json`, numaralı gerçek telefon PNG/XML'leri,
`migration-validation.log`, `final-readiness.json`, `frontend-build.log`,
`backend-boot.log`, `backend-package.log` ve `cleanup.json` vardır.
`tested-source-comparison.json` önceki doğrulamadan gelen 3.149 kaynak hash'inin
tamamını eşleştirir; sonraki beş salt EOF temizliği `eof-whitespace-cleanup.json`
ile ayrıca izlenir. Bu değişiklikler uygulama davranışını değiştirmez.

Kontrol için geçici açılan normal telefon uygulaması ve backend kapatıldı; güncel
APK kurulu, hesap verisi yerinde. Mevcut Docker PostgreSQL/Redis/RabbitMQ altyapısı
korundu. Telefonun USB'de ekranı açık tutma ayarı 0 → 2 → 0 olarak geri alındı;
kilit/parola ayarı değiştirilmedi. Kullanıcı normal uygulama ve backend'i kendisi
yeniden açabilir. Yerel log, yedek, APK, ekran görüntüsü ve geçici betikler Git'e
alınmaz. Sıradaki iş stüdyo akışının ürün mantığını konuşmaktır.
