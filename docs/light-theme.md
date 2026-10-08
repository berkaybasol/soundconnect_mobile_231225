# Açık tema — uygulama ve doğrulama notu

15 Eylül 2026

Mevcut giriş ve profil menülerindeki **Açık** seçeneği çalışır. **Koyu** seçeneği
korunur; ilk kullanımda varsayılan Koyu'dur. **Siyah (yakında)** pasif kalır.
Seçim `app_theme_variant` tercihiyle cihazda saklanır. Tercih kaydedilemezse
seçilen tema kullanılmaya devam eder ve kullanıcıya kayıt hatası bildirilir.

## Korunan davranış

Tema geçişi navigator, oturum servisleri veya cubit sahiplerini yeniden kurmaz.
Giriş alanları, bekleyen uygulama bağlantıları, form taslakları ve açık pencere
durumunun korunması otomatik testlerle doğrulanır. Backend, veri modelleri,
rezervasyon ve yükleme iş mantığı değiştirilmemiştir.

Fotoğraf/video üzerindeki okunabilirlik katmanları ve dışa aktarılan paylaşım
tasarımları kendi orijinal renklerini korur. Yerel kırpma aracının mevcut
görünümü korunur.

## İncelemede bulunup düzeltilen sorunlar

- Uygulamanın açılışta tema tercihini silmesi.
- Mesaj, akış, Collab ve dinleyici içeriklerinin zorunlu koyu tema kapsamları.
- Açık yüzeylerde beyaz kalan yönetim simgeleri, düğmeler ve yükleme göstergeleri.
- Etkinlik fotoğrafı üzerinde beyaz yazının altındaki karartmanın açılması.
- Rezervasyon seçimlerindeki düşük kontrastlı pembe yazılar.
- Özel çizilen altı çerçevenin tema değişimini yeniden çizme nedeni saymaması.

## Doğrulama

- `lib`, `test`, `integration_test`, `test_driver`, `tool`, `tools` kaynak
  analizinde hata veya uyarı yok.
- Tam paket ve son düzeltmelerden sonraki hedefli tekrarlarla 5.000'in üzerinde
  otomatik senaryo doğrulandı. İki test paketin mevcut koşullarıyla atlandı.
  Eski "açık tema altında da içerik koyu kalır" beklentileri yeni davranışa
  göre güncellendi; Koyu için orijinal renk kontrolleri korundu.
- Son profil, stüdyo, etkinlik ve tema taramasında 292 test geçti. Özel çizim
  kontrolünün test bulucusu düzeltildikten sonra, onu da içeren 21 testlik
  profil/görsel paketi tamamen geçti. Çözülmemiş test hatası kalmadı.
- Mevcut sekiz Koyu görüntü referansı değiştirilmeden karşılaştırılır:
  giriş, şifre kurtarma, dinleyici, hayalet profil, Collab, ortak kontroller,
  yönetim penceresi ve takvim. Açık sürümleri de çizilip görsel olarak incelendi.
- Tercihin kalıcılığı, hızlı seçimlerin sırası, kayıt hatasından toparlanma,
  yeni temadaki temel metin/düğme kontrastları ve durum korunması kapsanır.

İnceleme sonunda bilinen açık bir işlevsel regresyon saptanmadı.

## Yeni ekranlar için renk kullanımı

Yeni bileşenlerde `Theme.of(context).colorScheme` kullanılır. Mevcut
`AppColors` uyumluluk getter'ları seçili paleti döndürür; bunları kullanan
widget'ın `build` aşamasında `Theme.of(context)` bağımlılığı bulunmalıdır.
Tema değişiminde ekranı farklı bir anahtarla yeniden kurmak gerekmez.

`AppTheme.navy` ve `AppTheme.light` sabit, bağımsız paletlerle üretilir.
`AppColors.legacy` yalnızca eski nötr arayüz renklerini taşımak içindir;
fotoğraf/video karartmaları, gölgeler ve anlam taşıyan vurgu renkleri için
kullanılmaz. Kenarlıklarda `legacyBorder`, sabit sanat tasarımlarında
`AppColors.originalDark` veya tasarımın kendi sabit paleti kullanılır.

## Açık tema avatar ve ikon iyileştirmesi

Fotoğrafsız profil görselleri ve başharf avatarları, açık temada ortak gri-mavi
zemin ve okunaklı koyu slate simge/yazı kullanır. Renkli avatar gölgeleri daha
hafif nötr gölgelere dönüştürüldü. Profil türleri, DM, akış, yorumlar,
bildirimler, Collab, masa grupları ve yönetim listeleri aynı kurala uyar.

Dekoratif ikon, ikon zemini ve çerçeveler için `decorativeGradient`,
`decorativeSocialGradient` ve `decorativeNeonPurpleGradient` kullanılır.
Açık temadaki marka tonları mevcut SoundConnect gradientinden türetilir.
Dolgulu ikonların açık temadaki işaret rengi `decorativeForeground`
olur. Bu getter'lar Koyu seçiliyken önceki renkleri aynen döndürür.
Nötr avatar yazısı/zemini kontrastı 4.7'nin üzerindedir.

Bu iyileştirmede 59 ortak tema/navigasyon testi, 80 profil testi ve 24 modül
testi geçti. Sekiz mevcut Koyu görüntü referansı değiştirilmeden eşleşti.
Güncel modül galerisi 38 görüntü üretim testiyle yeniden oluşturuldu; Git
geçiş menüsü dahil 61 ekran içerir. `lib` kod analizi temizdir.

## Açık temanın bütününde SoundConnect gradienti

19 Eylül 2026: kullanıcı adları, işlem düğmeleri, ikonlar ve çerçeveler
uygulamanın mevcut beş duraklı SoundConnect gradientini kullanır.
Açık palet `originalDark.brandGradient` renklerinin her birine aynı beyaz
karışımı uygulanarak üretilir: %65 marka rengi, %35 beyaz. Turuncu/mercan,
pembe ve mor sıralaması korunur; ayrı gülkurusu-lila renk dizileri yoktur.

Kullanıcı adlarında `brandTextGradient`, geniş eylem yüzeylerinde
`actionGradient` / `actionSocialGradient` ve koyu `onAccent` yazısı kullanılır.
Bu gradientler, dekoratif/sosyal gradientler ve `brandGradient` açık temada
aynı beş renk listesini paylaşır. Odaklanmış metin alanı, kayıt ve şifre
kurtarma adım ikonları da geçişin tamamını kullanır.
İlan Ver, Başvuruyu Gönder, stüdyo işlemleri, masa grupları, profil işlemleri,
DM gönderme ve diğer ortak eylemler aynı açık renk düzenine uyar.
Küçük metinlerde `accentText` okunaklı kalır; hata ve servis renkleri kendi
anlamlarını korur. Koyu temada bu getter'lar önceki değerleri döndürür.

Bu ikinci renk düzenlemesinde 50 ortak tema/profil/navigasyon testi, 118
profil testi, 133 modül testi ve 3 dalga sınır testi geçti. DM/akış denetiminde
15 test ve ekran çizimi senaryosu geçti. Sekiz mevcut Koyu görüntü referansı
değiştirilmeden eşleşti. Son kaynaklarla `lib` ve tema testi analizi temizdir.
Son etiket düzeltmelerinde 31 etkinlik/takvim testi, sosyal bağlantı ve stüdyo
rozetlerinin son düzenlemesinde 24 mevcut test daha geçti. Kaynaklar
tamamlandıktan sonra sekiz Koyu referansı yeniden eşleşti; aynı paketin
sekiz Açık çizim kontrolü de geçti.
38 görüntü üretim testi geçti; güncel galeri, başvuru gönderme bölümünün
kaydırılmış görünümüyle birlikte 62 ekran içerir. Tüm test paketinin
5.000 üzerindeki ilk çalıştırması bu son renk düzenlemesinden öncedir.

Tek SoundConnect gradientine geçişten sonra 19 Eylül'de 53 hedefli test ve
38 galeri çizim testi yeniden geçti. Sekiz Koyu görüntü referansı yine
değiştirilmeden eşleşti; `lib` ve tema testi kaynak analizi temizdir.

## Açık temada çerçeveli kontroller

Marka rengiyle dolgulu buton ve ikon daireleri açık temada ince SoundConnect
gradient çerçevesi ve renksiz/nötr iç yüzey kullanır. Git geçiş menüsü,
İlan Ver ve Başvuruyu Gönder dahil Collab eylemleri, masa oluşturma dairesi,
cinsiyet seçimleri ve bildirim ikonları bu kurala uyar. Aynı dolgulu tasarımı
kullanan profil düzenleme rozetleri, sosyal bağlantı ekleme daireleri, stüdyo
işlemleri, DM gönderme ve diğer ortak eylemler de uyumlu hale getirildi.
Yüklenemeyen bildirim fotoğrafının yerine çıkan simge de dolguyu geri getirmez.

İsim gradientleri, dalgalar ve mevcut gradient çizgileri korunur. Yeni çerçeve
yalnızca Açık seçiliyken çizilir; Koyu'nun önceki dolgu ve gölgeleri korunur.
Buton ölçüleri, tıklama eylemleri, yükleniyor/pasif durumları değiştirilmez.

Bu düzenlemede 70 ortak/DM/ayar/akış, 50 Collab/bildirim, 100 profil/stüdyo
ve 168 masa testi geçti. Bildirim fotoğrafı hata görünümünün son düzeltmesi
sonrasında 9 bildirim testi tekrar geçti. Sekiz Koyu görüntü referansı
değiştirilmeden eşleşti; kaynak analizi temizdir.
38 galeri çizim testiyle 62 ekran yenilendi; istenen altı görünüm ayrıca
`artifacts/light-theme-refinement/cerceveli-acik-tema.png` içinde toplandı.

20 Eylül: misafir ve üye etkinlik keşfinin ortak `_GuestTableAccessFab`
bileşeninde kalan dolgu da yalnızca açık temada kaldırıldı. Bu düzeltme
eski misafir görünümünü de kapsar; sürükleme, animasyon ve giriş yönlendirmesi
korunur. 68 keşif/navigasyon/çizim testi geçti. Aynı misafir ekranının Koyu
öncesi/sonrası PNG dosyaları birebir eşleşti. Misafir ekranı galeriye ayrıca
eklendi; güncel galeri 63 ekran içerir.
