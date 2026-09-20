# Profil akışları: ilk sürümde rafa kaldırma

20 Eylül 2026

Profil türüne göre kişiselleştirilen müzisyen, stüdyo, mekân ve dinleyici
akışlarının kullanıcı erişimi ilk sürüm için kapalıdır. Motor, kartlar,
sıralama, servisler ve testler gelecekteki açılış için korunur.

## Uygulamadaki davranış

- İlk aşamada boşaltılan Backstage alt barının ilk yuvası, sonraki ürün kararıyla
  Ekipman Pazarı'na ayrıldı. Müzisyen, stüdyo ve mekân hesaplarında “Pazar” açılır;
  yetkisiz veya karışık kimlikte bu yuva boş ve işlevsizdir. Dinleyici barına eklenmez.
- Bu üç profil için başlangıç ekranı Ekipman Pazarı'dır. Eski profil akışı ekranı
  ve kodu korunur; varsayılan derlemede feed Cubit'i oluşturulmaz.
- Dinleyici profil menüsündeki ve etkinlik keşfi başlığındaki “Akış” girişleri
  gösterilmez. Dinleyici feed ekranı doğrudan oluşturulsa da feed başlatmaz.
- Hesap ayarlarındaki “Akışta sessize alınanlar” girişi gizlenir.
- `/backstage-profiles-home`, `/listener-feed` ve
  `/settings/musician-feed/muted-authors` istekleri oturumun normal başlangıç
  rotasına döner. Giriş ve profil seçimi kontrolleri önceliğini korur.
- Mainstage alt barındaki “Keşfet”, **etkinlik keşif modülüdür** ve açık kalır.
  Collab, Overthinking, masalar, profiller ve profil paylaşımları da korunur.

## Daha sonra açmak

Tek istemci anahtarı:
`lib/core/policy/profile_feed_availability.dart` içindeki
`ProfileFeedAvailability.enabled`.

Normal derlemeler varsayılan olarak kapalıdır. Planlı bir açılış/test derlemesi:

```sh
flutter run --dart-define=SOUNDCONNECT_PROFILE_FEEDS_ENABLED=true
```

Bu bir derleme ayarıdır; uygulamadaki kullanıcı tercihlerinden açılamaz.
Üretim derlemelerine bu tanım eklenmemelidir; yeniden açılış kararı verilince
feed rotaları ve ekran içeriği açılır. Pazar'ın alt bar yuvası korunur;
yeniden açılışta profil akışı için ayrı bir kullanıcı girişi tasarlanmalıdır.

Sunucu ayrı yönetilir. Mevcut backend `application-prod.yml` dosyası,
`SOUNDCONNECT_MUSICIAN_FEED_ENABLED` için zaten `false` varsayar. Bu bayrak dört
profil feed'inin HTTP uçlarını birlikte yönetir. Gerçek ortamdaki override
değerleri bu çalışma kapsamında doğrulanmadı/değiştirilmedi. Yerel backend
varsayılanı açıktır. İstemci girişlerini kapatmak bir API yetki kontrolünün
yerine geçmez. Yeniden açılışta backend'in mevcut rollout koşulları da sağlanır;
cleanup ve saklanan içerikler bağımsızdır.

## Ürün ve mimari incelemesi

İnceleme frontend, backend ve Link-Landing kodu üzerinden yapıldı. Tüm
modüllerin cihaz üzerinde uçtan uca çalıştırıldığı bir kabul testi değildir.

| Alan | Kullanıcı yolculuğu |
| --- | --- |
| Mainstage | Dinleyici profili, standart/hayalet görünürlük, playlistler; etkinlik keşfi, Overthinking, Müzik Birleştirir! masaları ve mesajlar |
| Backstage | Müzisyen, mekân ve stüdyo profilleri; Collab; “Git” menüsü üzerinden etkinlik, Overthinking ve masalar |
| Collab | Profil/grup adına ilan, kayıt, başvuru, kabul, iş tamamlama ve değerlendirme; dinleyiciye kapalı |
| Etkinlik | Konum/tarih ile canlı müzik keşfi; mekânın etkinlik oluşturması, sanatçı katılımı ve profilde yayınlama için ayrı kararlar |
| Müzisyen/grup | Medya ve müzik, enstrümanlar, grup üyeliği, setlist/PDF, mekân bağlantıları, davetler ve takvim |
| Mekân | Sanatçı bağlantıları, etkinlik ve takvim yönetimi, kamusal profil |
| Stüdyo | Oda, rezervasyon/onay, manuel bloklar, müsaitlik, backline ve envanter |
| Overthinking | Müzik bağlantılı yazılar, görünürlük ve kimliği açığa çıkarma talepleri, profil paylaşımları |
| Masalar | Keşif, masa açma, katılım başvurusu, üye yönetimi, sohbet ve sohbet içi oyunlar; mekân/stüdyo için oluşturma/katılma kısıtları |
| Ortak altyapı | Takip, beğeni/yorum, medya, Spotify, DM, bildirim, rol/oturum korumaları ve paylaşım bağlantıları |

Frontend Flutter + BLoC/Cubit, repository katmanları, `get_it` ve Dio kullanır.
Backend Java 21/Spring Boot modüler monolittir; PostgreSQL, Redis, RabbitMQ,
REST/STOMP ve ayrı medya worker'ı bulunur. Link-Landing yalnız Collab ilan
paylaşım bağlantısını çözer; profil feed bağlantısı yoktur.

Kişiselleştirilmiş feed, bu ürünlerin içeriğini bir araya getiren ek bir
yüzeydir. Kaynak modüller ve MAINSTAGE/BACKSTAGE içerik görünürlüğü ayrı
kurallarla çalışır.

### Sonraki ürün konuşması için notlar

1. Backstage'de sosyal modüller “Git” altında, mesleki işlemler profil yönetim
   panellerinde kalır. İlk aşamada boşaltılan giriş sonrasında Ekipman Pazarı'na
   ayrıldı; güncel kapsam `marketplace-first-release.md` belgesindedir.
2. Müzisyen profil tamamlama ekranında enstrümanlarla birlikte “Akış Tercihleri”
   şehir ayarı var. Feed'e giriş sağlamıyor; bu değişiklikte profil düzenlemesi
   korunuyor. İlk sürüm metni/yerleşimi sonraki ürün kararında ele alınabilir.
3. Yönetim panellerinde “Yakında” alanları var. Modüllerin anlaşılır sıralaması
   konuşulurken hazır işlevlerle bu alanların nasıl sunulacağı değerlendirilebilir.
4. Backend release-readiness belgesi şema, gerçek ortam ve operasyon kontrolleri
   içeriyor. Bu inceleme o üretim geçiş koşullarının tamamlandığı anlamına gelmez.

## Kod referansları

- `lib/core/policy/{access_policy,stage_mode,profile_feed_availability}.dart`
- `lib/app/router/app_route_guard.dart`, `lib/app/app.dart`
- `lib/modules/profile/presentation/screens/profile_public_bottom_bar.dart`
- `lib/modules/profile/presentation/screens/backstage_profiles_home_screen.dart`
- `lib/modules/musician_feed/presentation/screens/listener_feed_screen.dart`
- `lib/modules/event/presentation/screens/event_discovery_screen.dart`
- `lib/modules/profile/presentation/screens/listener_profile_screen.dart`
- `lib/modules/auth/presentation/screens/account_settings_screen.dart`
- `../SoundConnect-Backend/src/main/resources/application-prod.yml`
- `../SoundConnect-Backend/docs/{ReleaseReadiness,mainstage-content-boundaries}.md`

## Doğrulama sonucu

- Varsayılan kapalı derleme: rota/oturum, alt bar, hesap ayarları, etkinlik
  keşfi ve profil feed sözleşmelerinde 145 test geçti.
- Dinleyici profil menüsü ve çıkış davranışı: kapalı derlemede ek 8 test geçti.
- `SOUNDCONNECT_PROFILE_FEEDS_ENABLED=true` ile aynı erişim yüzeyleri ve
  saklanan feed ekranlarının davranışı: 135 test geçti.
- `flutter analyze --no-pub lib`: sorun yok.
- Değişen dosyalarda `git diff --check`: whitespace hatası yok.

Repo kökünün sınırsız analizi `tmp/` altındaki eski ekran kopyalarını da
taradığı için bu geçici dosyalardan hata üretti. Yukarıdaki temiz analiz gerçek
uygulama kaynakları olan `lib/` kapsamındadır. Cihazda veya canlı sunucuda
doğrulama/deploy yapılmadı.
