# Misafir etkinlik keşfi — geri alınabilir tasarım denemesi

8 Eylül 2026 (dördüncü görsel revizyon). Kullanıcının onayladığı kapsam: Bugün varsayılan, tarihli Yarın,
diğer günler için sınırlı tarih seçimi, sade konum filtresi ve SoundConnect'in
ince gradient tasarım dili. Misafir hesap olmadan arama yapabilir.

## Görünüm ve kullanım

- Bugün / Yarın (8 Eyl gibi) / Tarih seç. Üçüncü seçim alt panelde diğer beş
  günü gösterir. Aylık/yıllık takvim yok. Aralık bugün dahil yedi gündür.
- Şehir gereklidir. Şehir seçildikten sonra hemen altında `İlçe veya mahalle seç`
  satırı görünür. İsteğe bağlı alanlar başlangıçta kapalıdır ve bu satırla açılır.
  Kapatmak seçilen filtreleri silmez, satır seçilen ilçe/mahalle özetini gösterir.
  Şehir değişimi alanı yeniden kapatır. Mahalle için ilçe
  seçilmelidir. Açılan alanlar normal ekranda yan yana, dar ekranda/büyük yazıda
  alt alta yerleşirler.
- Üstte mevcut `assets/Logoyanyana.png` yatay logosu kompakt 204×42 alanda kullanılır. Başlık
  `Canlı müzik nerede?`, alt metin `Şehrindeki sahneleri keşfet.`.
  Logonun saydam kenar boşluğu hizalamada telafi edilir, başlıkla arasındaki
  boşluk azaltılarak tek bir üst alan görünümü sağlanır.
  Son küçük boyut revizyonunda genişlik 190'dan 204'e çıkarıldı, sol kenar
  telafisi orantılı güncellendi. Alanın yüksekliği ve çevre boşlukları değişmedi.
- `Seçimleri temizle` özelliği kaldırılmıştır. Şehir, gün ve isteğe bağlı
  filtreler kendi alanlarından değiştirilebilir. `Şehrini seçerek başla` ve
  `Hazırsın` yardımcı satırları kaldırılmıştır.
- Filtre kartının bölüm aralıkları sıkılaştırılmıştır. İlçe/mahalle açma
  kontrolünün en az 48 piksel dokunma alanı korunur.
- Alt `Giriş Yap` ve `Üye Ol` düğmeleri `Mekan öner` ile aynı bileşeni kullanır:
  15 piksel dış köşe yarıçapı ve en az 52 piksel iç yükseklik. Girişin sade
  çerçevesi ve üyeliğin gradient çerçevesi korunur. Eski ekranın alt alanı değişmez.
- `Üye Ol` etkinlik detayındaki misafir alanıyla ortak üyelik seçeneklerini
  açar. `Google ile devam et` / `Yakında` pasiftir. `E-posta ile devam et`
  mevcut kayıt ekranını açar. Giriş doğrudan mevcut giriş ekranına gider.
  Seçenekleri kapatmak kayıt başlatmaz, hızlı çift dokunma ekranları çoğaltmaz.
- Etkin ikonlarda stüdyo profilindeki çapraz turuncu/pembe/mor görünüm
  `BrandGradientIcon.social` ile kullanılır. Ortak ikonun varsayılanı değişmez.
- Filtre ve beta kartlarında `navBlue`, seçim alanları ve düğme içlerinde
  `inputFill` kullanılır. Stüdyo profilindeki gibi iç kontroller yüzeyden bir
  ton açık kalır. Seçili gün koyulaşmak yerine ince gradient çerçeveyle ayrılır.
  Genel tema, logo hizası, masa balonu ve düğme geometrisi değiştirilmez.
- `Etkinlikleri göster` düğmesi kaldırılmıştır. Şehir seçilince arama otomatik
  başlar. Gün, ilçe veya mahalle değişiminde de yeni seçimlerle arama yapılır.
  Henüz şehir seçilmediyse istek gönderilmez, boş sonuç kartı gösterilmez.
- Seçimler 300 ms beklenerek birleştirilir. Aynı seçime yeniden dokunmak istek
  göndermez. Değişiklik anında eski sonuçlar geçersizleşir, bekleme sırasında
  yalnız sonuç alanı yüklenir. Seçim kontrolleri kullanılabilir kalır.
- Sonuçlarda afiş ve mevcut SoundConnect varsayılan afişi kullanılır.
- Sonuç başlığı tarihi ve seçilen şehir/ilçe/mahalleyi gösterir. Seçilmemiş
  alt konumlar eklenmez. Uzun başlıklar dar ekranda alt satıra geçer.
- Kartın detay işareti mekan satırında değil etkinlik adı ve sanatçı alanının
  yanında, kompakt bir çerçeve içindedir. Kartın tamamı aynı etkinlik detayını
  açar, bu işaret ayrı bir küçük dokunma hedefi değildir.
- Sanatçı/grup adının solunda küçük bir gradient müzik notası bulunur. Bu
  simge katılım onayı rozeti değildir, yalnız satırın neyi anlattığını belirtir.
  Uzun adlar mevcut iki satır ve taşma sınırını korur.
- Kullanıcının sevdiği yuvarlak, sürüklenebilir masa butonu ve yardım balonu
  geri getirildi. Alt giriş/üyelik alanının üzerine taşınamaz. Giriş/üyelik
  erişimleri korunmuştur.
- Veriler 20'şer yüklenir. Devam sayfası hatası mevcut sonuçları silmez.
- Eski arama/konum yanıtları güncel seçime uygulanmaz. İstanbul gece yarısı
  ve uygulamaya dönüşte gün sınırı, açık tarih paneli dahil yenilenir.
- Bu koruma gönderilmiş HTTP isteğini fiziksel olarak iptal etmez. Mevcut ağ
  katmanının zaman aşımı ve sonuç geçerlilik kontrolü kullanılır, yeni teknoloji
  eklenmez. Ekran kapanınca bekleyen arama zamanlayıcısı iptal edilir.
- Bu arama takvim gününe göredir. Bugün daha önce biten etkinlik de bugünün
  programına aittir, profillerin gün bazlı haftalık gösterimiyle aynıdır.

## Güvenli geri dönüş

Eski ekran ve eski servis kullanımı `guest_event_home_screen.dart` içindeki
`_LegacyGuestEventHomeScreen` olarak korunmuştur. Eski görünümün içerikleri
ve işlemleri değiştirilmemiştir. Uygulama yönlendirmesi değiştirilmemiştir.

`GUEST_DISCOVERY_V2` derleme ayarı varsayılan olarak `true`.

```sh
flutter run --dart-define=GUEST_DISCOVERY_V2=false
```

Bu ayar eski ekrana ve eski arama akışına döner. Çalıştırma ayarını değiştirmek
istemiyorsanız yalnız aynı sabitin `defaultValue` değerini `false` yapmak da
yeterlidir. Ardından hot restart yapılır. Onay alınana kadar eski ekranı silmeyin.

Yeni UI iki part dosyasında izoledir:

- `guest_event_home_screen_discovery.dart`
- `guest_event_home_screen_discovery_widgets.dart`

Yeni veri katmanı ve `/api/v1/events/discovery` servisi eklemedir. Backend'in
eski servisleri değiştirilmez. Geri dönüş için yeni backend servisini kaldırmak
gerekmez. Salt okunur keşif araması için veritabanı geçişi veya veri sıfırlama yok.
Aşağıdaki mekan önerisi özelliğinin ayrı, eklemeli tablo hazırlığı vardır.
İlişkisiz değişikliklere
`git reset`, tüm dosyayı HEAD'den alma veya toplu checkout uygulanmamalıdır.

## Uygulamada görüntüleme

Yeni tasarım için Flutter hot restart yeterlidir. Tarihli gerçek arama için
yeni backend kodu çalışmalıdır, kendi backend sürecinizi yeniden başlatın.
Uygulamanın veri tabanı veya hesapları sıfırlanmaz. Tasarım testlerinde kullanılan
örnek etkinlikler yalnız test fikstürüdür ve canlı veritabanına yazılmaz.

## Beta bilgilendirmesi ve mekan önerisi

Beta bilgilendirmesi ve `Mekan öner` eylemi sayfa ilk açıldığında, şehir
seçilmesini beklemeden gösterilir. Ankara dahil tüm şehirlerde ve aramadan
sonra da kalır. Aramayı engellemez. Henüz şehir seçilmeden de öneri formu
açılabilir, gerekli il ve ilçe formun içinde seçilir.

Metinler:

- `Beta sürecinde olduğumuz için etkinlikler ağırlıklı olarak Ankara’da. Diğer şehirler için çalışmaya devam ediyoruz. 🌱`
- `SoundConnect’te bulamadığın bir mekanı önererek mekanla iletişime geçmemize yardımcı olabilirsin.`

Form yalnız mekan adı, il, ilçe ve canlı müzik sorusunu içerir. Canlı müzik
yanıtları Evet / Hayır / Bilmiyorum'dur. Instagram, harita, e-posta veya telefon
istenmez. Mevcut il/ilçe forma taşınır, formun kendi seçimleri keşif aramasını
değiştirmez. Gönderim için hesap gerekmez.

Öneri `POST /api/v1/venue-suggestions` servisine gönderilir. Başarı mesajı
`Önerin bize ulaştı. Teşekkür ederiz!` yalnız sunucu öneriyi kabul ettikten sonra
gösterilir. Bu cevap e-postanın gelen kutusuna ulaştığı iddiası değildir.
Alıcılar istemciden gönderilmez. Backend, mekan başvurularının mevcut yönetici
e-posta ayarını kullanır. Bu çalışma ortamındaki mevcut iki alıcı
`backstage@soundconnect.com.tr` ve `berkay@soundconnect.com.tr` adresleridir.

Öneri servisi için backend'in ayrı şema hazırlığı ve mail kuyruğu gereklidir.
Keşif tasarımını geri almak bu kayıtları silmez. Gerçek kullanıcı verisiyle
veya gerçek e-posta alıcılarıyla otomatik test yapılmaz.

8 Eylül yerel hazırlığı: kullanıcı backend'i durdurup yedek ve geçişe onay verdi.
Tam PostgreSQL yedeği `.local-backups/venue-suggestions-20260908-013717/` altında
alındı ve arşiv doğrulandı. Backend'in `2026-09-08-venue-suggestions.sql` dosyası
testlerden sonra yerel veritabanına uygulandı. Mevcut kullanıcı/etkinlik/grup ve
bağlantı isteği sayıları korundu. Dört yeni öneri tablosu boş bırakıldı, gerçek
e-posta gönderilmedi. Kullanıcının backend'i yeniden başlatması gerekir.

## Doğrulama

Frontend testleri: `event_discovery_date_policy_test.dart`,
`event_discovery_search_repository_test.dart`,
`guest_event_discovery_screen_test.dart`, `widget_test.dart`.
Backend kapsamı: `docs/GuestEventDiscoveryPreview.md` ve `*EventDiscovery*` testleri.

İlk tasarımda doğrulanan sonuç: 61 tarih/veri katmanı testi, 21 ekran davranış testi ve
3 uygulama açılış testi geçti. Aynı 3 açılış testi `GUEST_DISCOVERY_V2=false`
ile de geçti. Yeni backend için 37 test ve mevcut davranışlar için 15
regresyon testi geçti. Yeni Dart kodunun statik analizi temiz.

390×844 önizlemeler gerçek Flutter bileşenlerinden, yalnız test içinde yerel
örnek veriler kullanılarak üretildi. Android'deki Roboto/Material ikonları
yüklendi. Çıktılar çalışma alanında `.local-verification/guest-discovery/`.

İkinci revizyon: 24 ekran davranış testi ve görsel üretim testi geçti.
3 uygulama açılış testi ve 23 ortak ikon/etkinlik bilgi penceresi testi de
geçti. Statik analiz temiz. 320 piksel ve yüzde 200 yazıyla tarih paneli
kapanışında yakalanan erişilebilirlik hatası, sabit formun tek sliver içinde
kararlı yerleşimiyle düzeltildi. Masa butonu 320×500 / yüzde 200 yazıda da
sürüklenebiliyor ve alt giriş/üyelik alanının dışına taşmıyor.
Yeni görseller `.local-verification/guest-discovery-revision-2/` altındadır.
Bu revizyonda backend veya veritabanı değişikliği yoktur.

Üçüncü revizyon: 25 ekran davranış testi ve görsel üretim testi geçti.
Kompakt logo sınırı, isteğe bağlı alanların açılıp kapanması, seçim ve sorgunun
korunması, kapalı alanın seçim özeti ve şehir değişiminde sıfırlama doğrulandı.
Mevcut tarih, sayfalama, erişilebilirlik ve dar ekran kontrolleri de geçti.
Değişen ekran ve ortak ikonun statik analizi temiz. Dört görsel
`.local-verification/guest-discovery-revision-3/` altındadır. Bu revizyon yalnız
görseldir, backend yeniden başlatma veya veritabanı değişikliği gerektirmez.

Dördüncü revizyon: 28 ekran davranış testi, görsel üretim testi ve 3 uygulama
açılış testi geçti. Giriş/üyelik yönlendirmeleri, ortak düğme geometrisi,
temizleme işleminin kaldırılması ve şehir değişiminde eski arama yanıtının
yok sayılması doğrulandı. Dar ekran ve büyük yazı kontrolleri de geçti.
Ekranın ve test dosyasının statik analizi temiz. Beş görsel
`.local-verification/guest-discovery-revision-4/` altındadır. Backend veya
veritabanı değişmedi.

Eski etkinlik akışının kullanıcı tarafından ertelenen geçmişe geçiş/silme
manuel kontrolleri bu değişiklikle geçmiş sayılmaz.

Mekan önerisi frontend doğrulaması: 34 keşif ekranı davranış testi, 33 bağımsız
form/repository testi ve 3 uygulama açılış testi geçti. Aynı 3 açılış testi eski
tasarıma dönüş bayrağıyla da geçti. Statik analiz temiz. Yedi Flutter önizlemesi
`.local-verification/guest-venue-suggestion/` altında, son ikisi beta kartı ve
öneri formudur. Önizleme üretim testi de geçti.

Beta kartı ve renk revizyonu: 36 keşif ekranı davranış testi, 33 form/repository
testi ve 3 uygulama açılış testi geçti. Önizleme üretimi ayrıca geçti. Şehir
seçilmeden öneri formunu açıp kapatma, Ankara'da da beta kartının görünmesi,
eski yardımcı metinlerin kaldırılması ve kontrol dolguları doğrulandı.
320 piksel ve yüzde 200 yazı kontrolleri temiz. Statik analiz temiz.
Sekiz önizleme `.local-verification/guest-venue-suggestion-refinement/` altında.
Bu revizyon yalnız frontend görünüm ve metinlerini değiştirir, backend veya
veritabanı değişikliği gerektirmez.

Otomatik arama revizyonu: 44 keşif ekranı davranış testi, 54 arama repository
testi, 11 tarih testi, 33 öneri form/repository testi ve 3 uygulama açılış testi
geçti (145 işlevsel test). Önizleme üretimi ayrıca geçti. 299/300 ms sınırı,
hızlı seçimlerin birleştirilmesi, aynı seçimin tekrar sorgu üretmemesi, eski
ilk/devam sayfası yanıtları, hata sonrası aynı sayfadan tekrar deneme ve ekran
kapanışı doğrulandı. 10.000 toplam sonucu olan ilk/orta/son sayfa sözleşmesi
ve 20'lik UI yüklemesi kontrol edildi. Ağ hataları API adresi veya teknik
tanılama metni yerine kullanıcı odaklı bir mesaj gösterir.
Sekiz önizleme `.local-verification/guest-discovery-auto-search/` altında.
Bu testler eşzamanlı kullanıcı yükü veya canlı ortam kapasite ölçümü değildir.
Bu revizyonda keşif API'sinin kullanılmayan grup üyesi sorgusu da kaldırıldı.
`bandMembers` alanı boş liste döner, kart ve detay gezinmesinde kullanılan
sanatçı/grup kimlikleri korunur. Eski etkinlik endpoint'leri değişmez.
Sunucu kodunun devreye girmesi için backend yeniden başlatılır. Şema geçişi,
veri sıfırlama veya yeni teknoloji kurulumu gerekmez.

Konum başlığı ve kart işareti revizyonu: 47 keşif ekranı davranış testi ve 3
uygulama açılış testi geçti. Önizleme üretimi ayrıca geçti, statik analiz temiz.
İlçe/mahalle seçme, Tümü ile sıfırlama ve şehir değişimi başlıkta doğrulandı.
320 piksel ve yüzde 200 yazıda uzun konum/etkinlik metinleri taşmıyor. Hem
kart başlığı hem detay işareti aynı etkinlik kimliğiyle mevcut detay sayfasına
yönlendiriyor. Dokuz önizleme `.local-verification/guest-discovery-context-refinement/`
altında. Bu revizyonda backend ve sorgu davranışı değişmedi.
