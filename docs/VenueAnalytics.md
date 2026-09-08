# Mekan ve etkinlik istatistikleri

## Güncel yayın durumu: Yakında

Raporlama varsayılan olarak kapalıdır. Mekan Yönetimi içindeki “İstatistikler”
satırı “Yakında” etiketi gösterir; dokunmak yalnız kısa bilgilendirme gösterir,
istatistik sayfası veya API isteği açmaz. Mekan profili ve etkinlik detayındaki
“İstatistikleri gör” bağlantıları görünmez; profil bağlantısının dış boşluğu da
kaldırılır. Eski veya doğrudan bir istatistik rotası açılırsa “Yakında” sayfası
gösterilir ve özel rapor bileşeni/veri isteği oluşturulmaz.

Bu durum yalnız raporların görünürlüğünü yönetir. `AnalyticsTracker`, görünürlük
ve yaşam döngüsü ölçümleri, kuyruk, tekrar gönderim ve gözlem toplama isteği
değiştirilmedi. Rapor ekranları, grafikler, karşılaştırmalar, repository ve
testleri gelecekte açılmak üzere korunur. Sunucudaki toplama anahtarı
`SOUNDCONNECT_VENUE_ANALYTICS_ENABLED`, raporlama anahtarından bağımsızdır.

### Yeniden açma

Frontend'de tek kaynak değişmez `VenueAnalyticsReportingConfig.build` değeridir.
`SOUNDCONNECT_VENUE_ANALYTICS_REPORTING_ENABLED` derleme tanımı verilmezse `false`
olur. Gelecekte raporları açmak için Flutter derleme/çalıştırma komutuna
`--dart-define=SOUNDCONNECT_VENUE_ANALYTICS_REPORTING_ENABLED=true` eklenip uygulama
yeniden derlenmelidir. Çalışan uygulamaya yalnız ortam değişkeni eklemek yeterli
değildir. Testler açık yolu Navigator'ın üstündeki açık
`VenueAnalyticsReportingScope` ile sınar; varsayılan yayını değiştirmez.

Sunucuda eşleşen `SOUNDCONNECT_VENUE_ANALYTICS_REPORTING_ENABLED=true` ortam
ayarı ve backend yeniden başlatması da gereklidir. Bu anahtar da varsayılan
olarak kapalıdır; üç özel rapor GET uç noktası sunucuda ayrıca korunur.
Toplama ayarı, HMAC anahtarı ve veri saklama işi bağımsız kalır. İki taraf
etkinleştirildikten sonra sahip hesabıyla kapsam, dönemler, sıralama ve
başka hesabın erişememesi gerçek cihazda doğrulanmalıdır.

Raporlama kapalıyken mevcut 90 günlük saklama süresi uzatılmaz. Daha eski
gözlemler normal temizlemeyle silinir; yıllarca biriken geçmiş veya gelecekte
eksiksiz geriye dönük karşılaştırma vaat edilmez. Veri yeterli olmadığında
korunan raporlar eksik geçmiş durumunu göstermeye devam eder.

Kapalı yayın doğrulaması (8 Eylül 2026): istatistik ekran/repository/grafik,
gerçek etkinlik detayı, mekan profili ve yönetim gezinmesi paketlerinde
**304/304 test geçti**. Varsayılan kapalı ekran ve bağlantılarda sıfır özel
rapor çağrısı, “Yakında” yönetim girişi, açık kapsamın kapanması sırasında
eski dokunma/gecikmiş yanıtların bırakılması ve ölçüm toplamanın devam etmesi
doğrulandı. Raporlama açık yolun mevcut testleri yalnız açık bir test kapsamıyla
çalıştırıldı.

Son tam regresyon doğrulaması: `flutter test --no-pub --reporter compact`
ile **2.901/2.901 test geçti**. `dart analyze lib test` sonucu **No issues found**.
Bu sonuçlar otomatik test kapsamını belirtir, gerçek cihaz veya üretim yükü
doğrulaması yerine geçmez.

## Ölçüm sözleşmesi

- İstatistikler yalnız ilgili mekanın güncel, aktif sahibine açıktır. Ekran
  gizlemesi yeterli değildir, her özel API isteği sunucuda yetkilendirilir.
- Varsayılan dönem bugün dahil son 30 gündür. 7 ve 90 gün de seçilebilir.
  Gün sınırları Europe/Istanbul'a göredir. Sayılar seçilen dönemdeki tekil
  ziyaretçileri ifade eder, günlük tekillerin toplamı değildir.
- Tekil erişim (`impressions`): izleyicinin ekranında etkinlik kartının en az yarısının, uygulama
  ön planda ve ilgili sayfa açıkken kesintisiz bir saniye görünmesi.
- Detay ziyaretçisi (`detailViews`): kimliği sunucudan doğrulanmış etkinlik detayının gerçekten
  görüntülenmesi. Afiş çözümleme, paylaşım ve ön yükleme istekleri sayılmaz.
- Profil ziyaretçisi (`profileVisits`): doğru mekanın herkese açık profilinin gerçekten açılması.
  Etkinlik detayından gelen kaynak bilgisi profil yönlendirmesinde korunur,
  sunucu etkinlik-mekan eşleşmesini ve yakın tarihli detay ziyaretini doğrular.
  Geçersiz ilişkilendirme genel profil ziyaretini başka etkinliğe yazmaz.
- Mekan profilindeki toplam tüm kaynaklardan gelen ziyaretlerdir. Etkinlik
  detayındaki profil ziyareti yalnız o etkinlikten gelen ziyaretlerdir.
- Kimliği bilinen mekan sahibinin kendi ziyaretleri ve yönetim/önizleme
  listelerindeki kartlar ölçüme katılmaz. Gidiyorum henüz bir özellik değildir,
  sayı yerine Yakında gösterilir.
- Kullanıcının kararı: silinen etkinliğin geçmiş sayısal verisi dönem mekan
  toplamlarında kalır. Silinen etkinlik listelenmez, başlık arşivi tutulmaz.

## Gizlilik ve sınırlar

Üyeler hesap, misafirler ilk taraf rastgele kurulum kimliği üzerinden
tekilleştirilir. Yeniden kurulum, başka cihaz ve misafirden üyeliğe geçiş
aynı kişiyi birden fazla ziyaretçi yapabilir. Bunlar doğrulanmış insan sayıları
veya reklam faturalama verisi değildir. Ham IP, cihaz parmak izi, reklam kimliği,
kişi isimleri veya ziyaretçi listesi mekan sahibine gösterilmez.

Ölçüm toplama etkinleştirilmeden önceki görüntülenmeler geriye dönük üretilmez.
Toplamın sıfır olması ile sunucunun geçici olarak yanıt verememesi ayrıdır.

## İstemci altyapısı

Mevcut PostgreSQL/Redis altyapısı kullanılır, yeni bir dış analiz hizmetine
ziyaretçi verisi aktarılmaz. Flutter'da mevcut geçişli bağımlılık
visibility_detector 0.4.0+2 doğrudan tanımlanmıştır. Geometri ölçümü tek başına
yeterli olmadığından sayfa ve uygulama yaşam döngüsü de izlenir.

İstemci kuyruğu en fazla 128 kayıt, gönderim en fazla 20 kayıt içerir. Tekrar
gönderimler aynı gözlem kimliği ve zamanı kullanır. Misafir/üye oturum sınırı
ağ katmanında korunur, hesap değişince eski gözlemler yeni hesaba yazılmaz.
Yorum, arama, gezinme ve profil yüklemeleri analiz isteğinin sonucunu beklemez.
Normal gönderimler üç saniyelik gruplar halinde yapılır. Ağ hatalarında artan
bekleme, sunucunun Retry-After süresi ve seyrek yeniden deneme uygulanır.
Kısa aralıkta aynı ekrana dönmek ağ isteğini de şişirmez. Kalıcı depolama
yazımları tek çalışan yazma ve en güncel bekleyen görüntüyle sınırlıdır.

Analiz isteği sonuçlanmadan hesap değiştirilirse o hesaba ait henüz teslim
edilmemiş kayıtlar bilerek bırakılır. Yanlış hesaba yazmamak tam sayım
iddiasından önce gelir. Çevrimdışı kayıtların süresi 24 saatle sınırlıdır.

## Raporlama yeniden açıldığında yerleşim

- Mekan Yönetimi → İstatistikler: dönem seçimi, üç metrik, Yakında alanı,
  günlük grafik, dönem karşılaştırması ve sıralanabilir sayfalı etkinlik listesi.
- Mekanın kendi profili: yalnız sahibine görünen küçük “İstatistikleri gör”
  bağlantısı. Genel istatistik ekranını açar, profil içinde sayı/kart göstermez.
- Mekanın kendi etkinlik detayı: aynı küçük bağlantı yalnız o etkinliğin
  istatistik ekranını açar. Üç metrik ve Yakında alanı bu ayrı ekrandadır.
- Bağlantılar dokunulana kadar istatistik API isteği başlatmaz. Tekrarlanan
  dokunuşlar tek sayfa açar. Sahip doğrulaması ekran açılırken ve her API
  isteğinde korunur. Ölçüm toplama kuralları bu tasarım değişikliğiyle değişmez.

### Günlük görünürlük ve dönem karşılaştırması

Grafik erişim, detay ve profil ziyaretçisi arasında istemci içinde geçiş yapar;
metrik değiştirmek yeni API isteği oluşturmaz. Grafiğe dokunmak veya yatay
sürüklemek gün ve tam değeri gösterir. Önceki/sonraki gün düğmeleri ve ekran
okuyucu artırma/azaltma eylemleri aynı seçimi yapabilir. Sıfır gerçek bir
değerdir; ölçülmemiş günler `null` ve ekranda `—` olarak kalır, çizgide boşluk
oluşturur. Bugün her zaman kısmi gündür. Ölçümün gün ortasında başladığı tarih
ve gecikmiş ilk paketten başlangıcın öncesine yazılan gerçek günlük ölçümler
de kısmi gösterilir. Günlük tekiller dönem toplamı için toplanmaz.

Üstteki ana kartlar seçilen 7/30/90 gün boyunca, bugün dahil tekil sayıları
gösterir. Ayrı “Dönem karşılaştırması” kartı ise dün biten son N tamamlanmış
İstanbul gününü önceki N tamamlanmış günle karşılaştırır. İki aralığın başlangıç
ve bitiş tarihleri açıkça yazılır; karşılaştırma sayıları ana kartların
sayılarıyla aynı olmak zorunda değildir. Önceki dönem sıfırsa artış yüzdesi
üretilmez. Her iki dönem sıfırsa “Değişim yok” gösterilir.

Karşılaştırma yalnız sunucunun `AVAILABLE` durumu ve iki gerçek metrik kümesiyle
gösterilir. `NOT_STARTED`, `INSUFFICIENT_HISTORY` ve `RETENTION_LIMIT` durumları
ayrı açıklamalarla gösterilir; eksik geçmişten sayı veya yüzde uydurulmaz.
90 günlük saklama iki 90 günlük geçmiş döneme yetmediği için 90 gün karşılaştırması
kullanılamaz. Genel `trackingStartedAt`, ilk toplama başlangıcıdır; belirli
mekanın bütün tarihlerde kesintisiz ölçüldüğü garantisi değildir.

Sunucu yanıtında yeni `daily`/`comparison` alanları hiç yoksa eski sürüm
uyumluluğu korunur ve ilgili raporun henüz kullanılamadığı yazılır. Alanlar
varsa tarih sürekliliği, gün sayısı, İstanbul günü, kısmi/boş değer kuralları,
karşılaştırma durum/tarih/değer tutarlılığı sıkı biçimde doğrulanır. Bozuk rapor
başarılı veya sıfır değerli rapora dönüştürülmez.

### Etkinlik karşılaştırması

“En yeni”, “Tekil erişim”, “Detay ziyaretçisi” ve “Profil ziyaretçisi” seçenekleri
API'ye `DATE`, `REACH`, `DETAIL_VIEWS`, `PROFILE_VISITS` olarak gönderilir.
Sıralama bütün uygun etkinlikler üzerinde sunucuda yapılır; yalnız yüklenmiş
sayfayı sıralayan yanıltıcı bir liste oluşturulmaz. Sıralama değişince sayfa
sıfırlanır, geciken eski sayfa yanıtları bırakılır; özet yeniden istenmez.
Yanıtın sıralama bilgisi istekle eşleşmek zorundadır. Önceki API sürümü sıralama
alanını vermiyorsa yalnız varsayılan tarih sırası kabul edilir.

Her satır üç sayıyı birlikte gösterir ve etkinliğin istatistiklerini seçili
dönemi koruyarak açar. Eski satırın elde tutulmuş dokunma işlevi hesap, dönem
veya liste değiştikten sonra yeni sayfa açamaz. Satırlar görünür oldukça
oluşturulur. Sunucu sayfaları ayrı okumalardır; aradaki yeni ölçümler sıralamayı
değiştirebilir, liste tekrarları istemcide tekilleştirilir. Ekranda etkinliklerin
görünür kaldıkları sürelerin farklı olabileceği kısa notu bulunur. Bu rapor
CTR, kullanıcı hunisi, gerçek katılım veya otomatik “en iyi etkinlik” sonucu üretmez.

## Kaynaklar

- [VisibilityDetector belgeleri](https://pub.dev/packages/visibility_detector)
- [Flutter uygulama yaşam döngüsü](https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html)
- [PostgreSQL atomik INSERT/ON CONFLICT](https://www.postgresql.org/docs/current/sql-insert.html)

## Doğrulama / etkinleştirme

Yerel veritabanı geçişi backend durdurulup yedek alındıktan ve kullanıcı
onayından sonra uygulanır. Yeni toplama altyapısı varsayılan olarak kapalıdır.
Sunucuya ait ayrı HMAC anahtarı mobil uygulamaya veya Git'e konulmaz.
Etkinleştirme, saklama süreleri ve sunucu doğrulamaları için backend'in
analiz dokümantasyonu esas alınır.

8 Eylül 2026 ilk kurulum doğrulaması (raporlama geliştirmesinden önce):

- Tüm Flutter test paketi: 2.829 test geçti, hata yok.
- `dart analyze lib test`: sorun yok.
- Gerçek etkinlik detayı entegrasyonundaki sahip/ziyaretçi ve çıkış sonrası
  özel sayıların gizlenmesi kontrolleri ayrıca 7/7 geçti.
- Backend analiz ve ilgili güvenlik/etkinlik regresyon paketi: 262/262 geçti,
  atlanan test yok. Buna bağımsız PostgreSQL/Redis kontrolleri de dahildir.
- Yeni ekranların görsel önizlemeleri yerel doğrulama klasöründe incelendi.
- Gerçek telefonda etkinleştirilmiş sunucuyla uçtan uca test henüz yapılmadı.
- Kullanıcı onayıyla yerel veritabanı geçişi uygulandı. Yedek ayrı kopyaya
  geri yüklendi, geçiş iki kez denendi ve mevcut 89 tablonun içeriği korundu.
  Git'in dışladığı yerel anahtar ve etkinleştirme ayarı eklendi.
- Backend yeniden başlatılması ve gerçek cihaz kabul testi bekleniyor.

Bu testler gerçek üretim yükü altında performans garantisi veya sıfır hata
iddiası değildir. Mevcut kayıtlar korunarak eklemeli geçiş tamamlandı.

Küçük bağlantı tasarımına geçiş doğrulaması: ilgili 292 Flutter testi geçti.
Bu pakette bağlantıların dokunmadan istek göndermemesi, etkinliğe doğru
yönlendirme, sahip/oturum kontrolleri, 320 piksel ve yüzde 200 yazı boyutu ile
mevcut etkinlik/profil/keşif akışları kontrol edildi. Statik analiz temiz.
Bu revizyon backend, ölçüm toplama veya veritabanı ayarlarını değiştirmez.

### Kısa cihaz kabul testi

1. Mekan hesabında yeni bir etkinlik oluştur. Detaydaki “İstatistikleri gör”
   bağlantısından açılan ekranda üç sayının sıfır, Katılacaklar alanının
   yalnız Yakında olduğunu doğrula. Detayın kendisinde sayaç bulunmamalı.
2. Farklı aktif bir hesapla keşif sayfasında o etkinliğin kartını en az bir
   saniye görünür tut. Detayı aç, ardından mekan bağlantısından profili aç.
   Hesap değiştirmeden en az beş saniye bekle (normal ağ bağlantısında).
3. Mekan hesabında İstatistikler'i yenile. Yeni etkinlik için bir tekil erişim,
   bir detay ziyaretçisi ve etkinlikten bir profil ziyaretçisi beklenir.
   Mekanın genel profil sayısı önceden başka ziyaretler almış olabilir.
4. Aynı ziyaretçi hesabıyla adımları tekrarla. Seçilen dönemde aynı kişiye
   ait tekrarlar sayıyı artırmamalı. Farklı gerçek test hesabı artırmalı.
5. Mekan sahibi olarak kendi etkinliğini ve profilini açmak artırmamalı.
   Misafir ziyaretleri de ölçülür, ancak sahibin çıkış yapmış halini sistem
   güvenilir biçimde tanıyamaz.
6. Etkinliği sil. İstatistik listesinden kalkmalı, dönem toplamındaki geçmiş
   tekil ziyaretçiler korunmalı. Üç dönem seçeneği ve yenileme çalışmalı.

Bu cihaz adımları otomatik test sonuçları değildir. Gerçek telefonda ve
etkinleştirilmiş yerel sunucuda ayrıca uygulanmalıdır. Dönem mekan toplamları
etkinliklerin sayılarını toplayarak değil, ziyaretçileri tekilleştirerek hesaplanır.

### Raporlama geliştirmesi doğrulaması

8 Eylül 2026: raporlama repository, istatistik ekranı ve yeni grafik/karşılaştırma
testleri toplam **117/117** geçti. Bu kapsam tarih ve durum çözümleme, eski API
uyumu, eksik/sıfır/kısmi günler, dokunma ve ekran okuyucu gün seçimi, sıfır
paydalı değişim, sıralama/oturum yarışları, seçilen dönemle tek etkinlik açılışı
ve 320 pikselde yüzde 200 metin ölçeğini kapsar. İlgili modül ve üç test dosyası
statik analizinde sorun yok. Görsel render seçimi ayrıca 11/11 geçti.

Yerel, sentetik örnek verilerle üretilen PNG önizlemeleri Git'in dışladığı
`build/venue-analytics-premium-previews/` klasöründedir. Bunlar gerçek mekan
ölçümleri veya gerçek cihaz kabul testi değildir. Bu geliştirme toplama,
görünürlük ölçümü, ortam ayarları ve mevcut küçük giriş bağlantılarını değiştirmez.

Son bütünleşik doğrulama: tüm Flutter paketi **2.890/2.890** geçti
(`flutter test --reporter compact`, 1 dakika 48 saniye). `dart analyze lib test`
tamamlandı ve sorun bulunmadı. Backend'in ilgili güvenlik ve raporlama paketi
**288/288** geçti. Ayrıca ayrı PostgreSQL konteynerinde 10.001 etkinlik,
120.000 günlük kayıt ve sekiz eşzamanlı çalışanla 2.800 karma işlem doğrulandı.
Bu kısa veritabanı kontrolü üretim HTTP kapasitesi veya gerçek telefon testi
yerine geçmez. Ayrıntılar backend `docs/VenueAnalyticsLoadTesting.md` dosyasında.

### Yeni raporların cihaz kontrolü

1. Backend'i yeni kodla yeniden başlat, uygulamada hot restart yap.
   Bu raporlama revizyonu için yeni şema geçişi veya veritabanı sıfırlama yok.
2. Mekan Yönetimi → İstatistikler bölümünde 7/30/90 gün seçeneklerini dene.
   Günlük grafikte erişim, detay ve profil seçeneklerini değiştir. Bir güne
   dokununca tarih ve değer değişmeli. Bugün kısmi gün olarak belirtilmeli.
3. Yeni ölçüm geçmişiyle dönem karşılaştırmasının yetersiz geçmiş göstermesi
   beklenir. Gerçek kullanıcı verisini eskiymiş gibi doldurmayın. 90 gün
   seçiminde iki ayrı 90 günlük dönem için yeterli saklama olmadığı belirtilir.
4. Etkinlik karşılaştırmasında dört sıralamayı değiştir. Yeni seçimde önceki
   sıralamanın geç gelen yanıtı gösterilmemeli. Bir etkinliğe dokununca yalnız
   onun istatistikleri aynı seçili dönemle açılmalı.
5. İstatistik ekranı açıkken hesaptan çıkıldığında özel sayılar kaybolmalı.

Genel ürün davranış analizi, uygulama çapında çevrimiçi kullanıcı paneli ve
yayın ortamı monitoring kurulumu bu çalışmaya dahil değildir.
