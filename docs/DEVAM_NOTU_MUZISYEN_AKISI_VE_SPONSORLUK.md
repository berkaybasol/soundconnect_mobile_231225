# SoundConnect — oturum devam notu

Son güncelleme: 13 Eylül 2026. Bu dosyayı bağlam kaybolduğunda veya akış/sponsorluk işine dönüldüğünde önce oku. Geçmiş kararları yeniden varsayma; mevcut kod, testler ve aşağıdaki ürün sözleşmesini birlikte kontrol et.

## Şu anda ne yapıyoruz?

Kullanıcı müzisyen akışına kısa bir ara verdi. Yeni hedef, gerçek yönetilebilir sponsorluk sistemini admin panelinden kurmaya başlamak. **Bu adımda kampanya CRUD'u, ödeme veya gerçek sponsor dağıtımı yazma yetkisi verilmedi.** İstenen:

1. Bu kalıcı devam notunu oluşturmak.
2. Eski admin panelinin bütün ekran içeriğini temizlemek.
3. Admin giriş/yetki/oturum kapatma güvenliğini koruyarak boş ana sayfa ve yalnızca **Sponsorluklar** sekmesi bırakmak.
4. Sonrasında kullanıcının yeni talimatını beklemek.

Admin temizliği, uygulamanın kullanıcılarını, ilanlarını, başvurularını, etkinliklerini veya veritabanını silmek değildir. Backend iş kuralları ve diğer profillerin kendi “Yönetim Paneli” ekranları kapsam dışıdır. Bu not oluşturulduğunda admin sadeleştirme henüz uygulanmamıştı; sonucu dosyanın sonundaki kontrol noktasına işle.

## Çalışma ortamı ve korunacak sınırlar

- Çalışma alanı: `C:/Users/user/Desktop/SoundConnect`.
- Flutter: `SoundConnect-Frontend`; Spring/Java: `SoundConnect-Backend`. Ayrı Git repoları.
- İki repoda üzerinde çalışılan branch: `feature/local-simulation`. Başka branch açma, main/master'a merge/push yapma; bunlar ayrıca istenmeli.
- Admin değişikliğinden önce frontend HEAD: `109c53a`; backend HEAD: `e6b1062`.
- Frontend `tmp/` kullanıcıya ait untracked içerik; dokunma, silme, topluca stage etme. Backend bu kontrol noktasında temizdi.
- Kullanıcı prod-ready, mümkün değilse prod-quality istiyor. Dar kapsam, gerçek test, yetki kontrolü, mevcut davranışı koruma ve geri alınabilir ayrı commitler önemli.
- Kullanıcı backend'i IntelliJ, uygulamayı Android Studio yeşil Run ile başlatmayı tercih ediyor. Kendiliğinden kalıcı süreç başlatma/kapatma. Tasarım değişikliğinde çoğunlukla backend restart gerekmez.
- `.local-simulation.json` ve backend `.env.local` sır içerir; ekrana, nota veya commit'e dökme.
- Önceki taleplerin toplu reset/silme izinleri bugünkü kapsamı genişletmez. Simülasyon reseti veya hesap/veri silme yapma.
- Kullanıcı tasarım dilini keyfi değiştirmek istemiyor. Collab, stüdyo ve etkinlik keşfi referans; üst/alt navigasyondan memnun. LinkedIn mobil örnekleri **kart/akış düzeni** içindi, renklerini kopyalamak için değil.

## Asıl ürün hedefimiz: müzisyen Backstage akışı

Tek, güçlü, sunucunun sıraladığı profesyonel-sosyal akış; Following/Discover diye ayrılmıyor. İlk prod'da yeni gönderi composer'ı yok. Amaç çevrede olup biteni, uygun müzik işbirliği/fırsatlarını ve müzik içeriklerini bir arada göstermek.

Yazarlar yalnız müzisyen değildir: müzisyen, grup, onaylı mekân, stüdyo ve normal dinleyici olabilir. Organizatör/prodüktör ilk prod kapsamı dışında; ileride olup olmayacağı belirsiz. Hayalet dinleyiciler paylaşamaz; yayıncı/sosyal aktör olarak gösterilmez.

Temel içerikler:

- Takip edilenlerin Track ve ProfileMedia yayınları.
- Açık, süresi dolmamış Collab ilanları; ayrı bir sahte profil paylaşımı katmanı yok.
- Uygun gelecek etkinlikler, sanatçı profil yayınları ve dinleyicinin etkinlik profil paylaşımları.
- **Sadece normal dinleyicinin profilinde paylaştığı** Overthinking/TableGroup içerikleri, daha düşük sıklıkta.
- Takip edilen kullanıcıların takip/beğeni/yorum aktiviteleri; aynı hedefteki bazı aktiviteler tek sosyal gerekçede toplanabilir. Yorumun ağırlığı beğeniden yüksek.
- Düşük sıklıkta keşif, profil tamamlama carousel'i ve sponsor yerleşimleri.

Kullanıcı kendi yayınlarını kendi akışında görmez. Takip edilmeyenlerin keşfi tamamen kapalı değildir ama takip edilenlere göre çok daha azdır.

Kullanıcı düzeltmeleri:

- SoundConnect profillerinde genel bir gizli profil modeli yok. Overthinking'in anonimlik/erişim kurallarını bununla karıştırma.
- Yalnız dinleyici kendi profilinde Overthinking/TableGroup paylaşabilir. Müzisyen Mainstage'de gezinebilir; bu, kendi profilinde Mainstage yayın bölümü olduğu anlamına gelmez.
- İlk konuşmadaki “Mainstage asla akışta yok” cümlesi sonraki dinleyici-profil-paylaşımı kararıyla daraltıldı. Eski genel yasağı geri getirme.
- Uygulamadaki mevcut sözleşme ham/global Mainstage yayınlarını ve yalnız Mainstage içi aktiviteleri Backstage'e taşımıyor. Yeni kapsam genişletmesini varsayma.
- **Müzisyen görünen kimliği username'dir. stageName/displayName fallback'i tekrar ekleme.** StageName geçmişte yanlış kullanılıp düzeltildi. Diğer profil türlerinin ad kurallarını topluca değiştirme.
- Etkinlik oluşturan onaylı mekândır; müzisyen etkinlik oluşturamaz. Sanatçı profiline yayın/katılım bununla aynı şey değil.

## Kişiselleştirme ve profil tamamlama

- Öncelikli sinyaller: **fırsat şehri + kanonik enstrüman ID'leri**. Müzik türü/genre ilk aşamada ertelendi.
- Fırsat şehri ikamet/adres değildir. Mevcut City kataloğuna referansla ayrı akış tercihinde tutulur; Location aggregate ve Collab core'u yeniden tasarlama.
- Şehir/enstrüman ilgiyi artıran yumuşak sıralama sinyalleridir; görünürlük/yetki/geçerli durum sert filtredir. Eksik tercihler akışı bloke etmez.
- Carousel öncelikleri: fırsat şehri, enstrümanlar, biyografi, portfolyo, profil fotoğrafı/sosyal bağlantılar. Fotoğrafı işlevsel tercihlerden öne alma.
- Tamamlama v2 `BIO` kullanır. Eski `STAGE_NAME_AND_BIO` yalnız uyumluluk için okunabilir; yeni akış stageName istemez.

## Etkileşim ve teknik sözleşme

- Track/Media beğeni-yorum hedefi kanonik medya varlığıdır.
- Native Event hedefi EVENT; dinleyici Event profil paylaşımında hedef paylaşım wrapper'ıdır.
- Overthinking/TableGroup profil paylaşımı beğeni/yorumları **paylaşımın kendisine** aittir; kaynak gönderiye yazılmaz.
- Collab kendi kaydet/başvur/şikâyet/detay eylemlerini korur; Collab'a sahte beğeni-yorum ekleme.
- Silinen/geçersiz/kapalı/süresi dolmuş/erişilemez hedefler elenir. Sponsor olmak bu kontrolleri aşmaz.
- Bounded aday sağlayıcıları + merkezi mixer; hedef/yazar/tür çeşitliliği, dedup ve cursor kararlılığı. API sıralaması client'ta keyfi karıştırılmaz.
- Yeni tip: backend provider + açık payload sözleşmesi + frontend registry/renderer/navigation. Feed view içinde büyüyen route switch veya içerik kopyaları üretme.

Ana referans: `../../SoundConnect-Backend/docs/musician-feed-v1.md` (ürün ve mimari sözleşmesi). Simülasyon: `../../SoundConnect-Backend/docs/local-simulation-v1.md`.

## Bu oturumda tamamlanan önemli işler

1. Müzisyen akışı backend/frontend kuruldu; özellik bayrakları, adaylar, sıralama, cursor, kişiselleştirme, carousel, sosyal aktiviteler ve genişletilebilir sponsor katmanı var.
2. Yerel yaşayan simülasyon dünyası eklendi: 50 hesap (24 müzisyen, 10 dinleyici, 8 mekân, 8 stüdyo), ayrıca 4 grup; 3 manuel gözlemci. Gerçek servis/iş kuralları kullanılır. Venue/Studio onayı ve e-posta akışları yalnız guarded local+simulation ortamında güvenli adaptörlerle çözülür.
3. Gerçek telefonda simülasyon ve medya erişimi desteklendi. Simülasyon ayrı bir tasarım fork'u değildir; normal uygulama aynı widget'ları kullanır.
4. Akış renkleri Collab/Backstage diline alındı, iç kart yüzeyleri biraz yükseltildi. Mesajlar ve fırsat şehri seçici de önceki taleplerde yenilendi.
5. StageName karışıklığı giderildi: müzisyen username kuralı hem backend hem frontend'de testlerle korunuyor.
6. “Takip ettiğin bir profil paylaştı” yerine ilgili yayıncı username/adı, avatar ve profile giden bağlantı eklendi.
7. Sponsor aralıkları sabit/ezberlenir olmaktan çıkarıldı; eski genel kota yaklaşımı kaldırıldı.
8. “X ve N kişi daha bunu beğendi” başlığı güncel, sayfalı beğenenler listesini açıyor. Doğru paylaşım hedefi kullanılıyor; kullanıcı satırı doğru profile gider. Backend authenticated/access-checked keyset API var.
9. Feed Collab kartlarına aranan rol/enstrüman rozeti eklendi. Paylaşılan Collab kartında opt-in olduğundan diğer ekranlar korunur.
10. Müzisyen profilinin/ses kartının premium yeniden tasarımı denendi, kullanıcı beğenmedi ve **tamamen revert edildi**. Bu denemeyi yeniden getirme.
11. Collab ilan detayındaki üst kimlik ve İlan Sahibi avatar/ismi doğru profile gider. Değerlendirme/tamamlanan iş/menü davranışı korunur; profileId ile actorId/userId karıştırılmaz.
12. Akıştaki detay kartları ortak renkli sağ `>` kullanır. Collab'a eklendi; Overthinking/TableGroup “git” yazıları kalktı, önizlemenin tamamı kaynak detayını açar. Track/Media başlığı ayrı detay bağlantısıdır; ses oynatma bundan bağımsızdır. Event/Profile/Activity okları tutarlı. Akış dışı ekranlar değiştirilmedi.
13. En son akış düzenlemesi: alt etkileşim satırındaki **“Aç” kaldırıldı**; beğeni/yorum korundu. Buton/sayaç yoksa boş footer yok. Sponsor özel CTA'sı ve tamamlama butonları kaldırılmadı.

## Sponsorlar: şu anda tam olarak ne var?

Ücretli kampanya/ödeme sisteminin feed entegrasyonu **henüz yok**. Kullanıcıya açıkça anlatıldı ve onaylı mock aşamasındayız.

Mevcut development provider tam **3** sunum üretir:

1. **Öne çıkarılan native Collab:** geçerli mevcut ilanın promotion metadata ile sunumu; `Featured` -> “Öne Çıkan”, gradient çerçeve, normal ilan eylemleri; detay ilgili ilana gider.
2. **Sponsorlu native Event:** geçerli mevcut etkinlik; `Sponsored` -> “Sponsorlu”, normal etkinlik afiş/tarih/mekân ve beğeni-yorum; detay ilgili etkinliğe gider.
3. **Bağımsız sponsorlu gönderi:** başlık, metin, opsiyonel görsel, CTA. Şimdiki 6 farklı hazır metin aynı kart tipidir; görselleri null, yazar ve engagement yok. CTA örnekleri Collab veya etkinlik keşfine gider. Frontend belirli iç rotalar ve HTTPS dış bağlantıları destekler.

Native örneklerde hedef içerik simülasyondaki mevcut ilan/etkinliktir; sponsor olarak seçilmesi/kampanyası mock'tur. Bağımsız gönderilerin metin/kampanyaları da fixture'dır. Kart ve yönlendirme kodları gerçek ortak uygulama kodudur.

**Henüz bağlı olmayanlar:** sponsorlu profil, Backline. `PLATFORM_ANNOUNCEMENT` etiket desteği var ama mevcut provider üretmiyor. Bunları dördüncü/beşinci aktif tür diye sayma. Eski genel Promotion modülündeki SPONSORSHIP/CAMPAIGN/FEATURED_CONTENT/ANNOUNCEMENT enum'ları ve VENUE_MANAGEMENT_PANEL yerleşimi gerçek bir musician-feed kampanya yönetimi değildir.

Sponsor ürün kuralları:

- İlk iki pozisyonda yok, arka arkaya yok, iki organikte bir yok.
- **6–10 organik arası değişken aralık, ortalama 8**. Her 8. gönderi gibi ezberlenebilir kalıp yok.
- Pagination/retry yerleşimi yeniden zar atarak değiştirmez; anchor/session/placement sırasıyla tutarlıdır.
- Genel günlük sponsor kotası yok. Farklı sponsorları sırf toplam sınıra ulaşıldı diye kesme.
- Aynı hedefin/aynı içeriğin tekrarı ve organik+sponsor çift görünümü aynı akış oturumunda engellenir.
- Sponsor bulunmazsa organik devam eder; sonra telafi için reklam yığılmaz.
- Görünürlük, yetki, onay, süre ve ilgililik filtreleri sponsor için de geçerli.

Son kullanıcıya gösterilen görseller:

- `../../artifacts/musician-feed-sponsors-2026-09-13/01-one-cikarilan-collab.png`
- `../../artifacts/musician-feed-sponsors-2026-09-13/02-sponsorlu-etkinlik.png`
- `../../artifacts/musician-feed-sponsors-2026-09-13/03-bagimsiz-sponsorlu-gonderi.png`

Bunlar telefondan ekran yakalama değil; mevcut Flutter registry/widget'larının örnek veriyle alınmış doğrulanmış çıktılarıdır. Yeni mockup çizilmedi, kaynak tasarım değiştirilmedi. Yeniden üretme yardımcı testi ignored `build/musician_feed_sponsor_review_20260913_test.dart` içinde; build çıktısı kalıcı kaynak değildir.

**Bir sonraki sponsorluk tasarımında netleştirilecekler:** yönetilebilir kampanya veri modeli ve iş akışı, native hedef seçimi, başlangıç/bitiş ve durumlar, hedefleme, gerçek ücretli/organik/editoryal ayrımı, ölçüm/raporlama, görsel/CTA kuralları, gelecekteki Backline/Profile ekleme sözleşmesi. Bugün bunları kullanıcı adına kararlaştırıp uygulama.

Özellikle mevcut mock Collab `Featured` gösteriyor; ürün dokümanı Featured'ı editoryal, Sponsored'ı ücretli olarak ayırıyor. Kullanıcının ücretli öne çıkarılan Collab hedefiyle gerçek yönetimde bu ayrımı netleştir; mock etiketi kalıcı ücretli ürün sözleşmesi sanma.

## Kod haritası

Frontend:

- `lib/modules/musician_feed/domain/musician_feed_models.dart`
- `lib/modules/musician_feed/presentation/widgets/musician_feed_card_registry.dart`
- `lib/modules/musician_feed/presentation/widgets/musician_feed_content_cards.dart`
- `lib/modules/musician_feed/presentation/widgets/musician_feed_system_cards.dart`
- `lib/modules/musician_feed/presentation/widgets/musician_feed_card_chrome.dart`
- `lib/modules/musician_feed/presentation/widgets/musician_feed_detail_link.dart`
- `lib/modules/musician_feed/presentation/navigation/musician_feed_navigation_coordinator.dart`
- `lib/modules/musician_feed/presentation/musician_feed_visual_theme.dart`
- `lib/shared/theme/backstage_palette.dart` (Collab/Backstage renk kaynağı)
- `lib/modules/collab/presentation/widgets/collab_discovery_widgets.dart` (`showWantedBadge` ve `titleTrailing` opt-in)
- `lib/modules/collab/presentation/screens/collab_listing_detail_screen.dart`
- `lib/modules/admin/presentation/screens/admin_dashboard_screen.dart`
- `lib/app/router/app_route_guard.dart`, `lib/app/router/app_router.dart`, `lib/core/di/service_locator.dart`

Backend:

- `src/main/java/com/berkayb/soundconnect/modules/feed/musician/`
- `.../sponsor/DevelopmentMusicianFeedSponsorshipProvider.java` (3 mock sunum)
- `.../sponsor/MusicianFeedSponsorshipProvider.java` (genişletme arayüzü)
- `.../mixer/MusicianFeedMixer.java` (sponsor yerleşimi dahil)
- `src/main/java/com/berkayb/soundconnect/modules/promotion/` (eski genel modül; feed entegrasyonu değil)
- `src/main/resources/application-simulation.yml` mock sponsor açık; production'da mock kapalı/güvenlik kontrolü var.

## Geri alınabilir kontrol noktaları

Frontend:

- `1483ca1` müzisyen akışı
- `dda65b9` simülasyon launcher; `fc06d81` fiziksel cihaz medya
- `1d31cc3` Backstage renkleri; `c60cbda` iç önizlemeler
- `3023876` mesaj tasarımı
- `0545db1` username düzeltmesi
- `efac5e4` fırsat şehri sheet
- `1db280f` tıklanabilir yayıncı başlığı
- `ec7207a` beğenenler listesi
- `fb13798` Collab aranan rozetleri
- `9b3bf2d` REDDEDİLEN profil/audio tasarımı; **`190a16f` bunu geri aldı**
- `acb06f5` Collab detay avatar/isim navigasyonu
- `a92415b` ortak akış okları
- `109c53a` tekrarlanan Aç kaldırıldı — admin öncesi güvenli akış noktası

Backend:

- `f374283` müzisyen akışı
- `3e7faf5` simülasyon dünyası
- `416b7da` username kimliği
- `d49d1ac` değişken sponsor aralığı/observer izolasyonu
- `e6b1062` access-checked, sayfalı beğenen kimlikleri

Revert gerekirse kapsamı bilinen commit üzerinden geri al; `reset --hard`, kullanıcının değişikliklerini ezme veya geçmişte reddedilen tasarımı geri getirme yok.

## Doğrulama ve cihaz

Son akış kodu `109c53a`: **144** hedefli test başarılı, değişen dosyalarda Dart analiz temiz, debug APK fiziksel cihaza `install -r` ile başarıyla yüklendi. Önceki ortak-ok çalışmasında Collab regresyonlarıyla toplam 183 test geçmişti; sayıların farklı test kümelerine ait olduğunu unutma.

Önemli frontend testleri:

- `test/musician_feed_contract_test.dart`
- `test/musician_feed_widget_quality_test.dart`
- `test/musician_feed_detail_affordance_test.dart`
- `test/musician_feed_publication_header_test.dart`
- `test/musician_feed_like_users_header_test.dart`
- `test/musician_feed_visual_theme_test.dart`
- `test/collab_listing_owner_profile_navigation_test.dart`
- `test/collab_listing_detail_screen_test.dart`
- `test/collab_discovery_screen_test.dart`

Flutter SDK: `C:/Users/user/development/flutter`. Android SDK: `C:/Users/user/AppData/Local/Android/Sdk`. Son bağlı fiziksel telefon ADB seri: `10GCA400GT0001N` (V2206); her seferinde `adb devices` ile doğrula.

Android Studio Flutter kilidi varken kullanılan mevcut yürütme yöntemi:

```powershell
$env:FLUTTER_ALREADY_LOCKED='true'
& 'C:\Users\user\development\flutter\bin\cache\dart-sdk\bin\dart.exe' --packages='C:\Users\user\development\flutter\packages\flutter_tools\.dart_tool\package_config.json' 'C:\Users\user\development\flutter\bin\cache\flutter_tools.snapshot' test --no-pub --reporter expanded test/musician_feed_detail_affordance_test.dart
```

Aynı Flutter snapshot ile `build apk --debug --no-pub --dart-define-from-file=.local-simulation.json` kullanıldı. Derleme sonrası `adb -s <doğrulanmış seri> install -r build/app/outputs/flutter-apk/app-debug.apk` verileri korur; uygulamayı veya backend'i kendiliğinden çalıştırma. Sır içeren define dosyasını okumak/yazdırmak gerekmez. Araç izin gerektirirse normal onay mekanizmasını kullan.

## Son kontrol noktası — admin sadeleştirme

- Durum: devam notu tamamlandı; eski admin içeriğinin güvenli sökümü sıradaki iş.
- Eski admin açılışı `AdminPanelCubit.initialize()` ile özet/başvuru istekleri yapıyor. Boş panel bu istekleri yapmamalı.
- `/admin` route'u ve admin role guard korunacak. Backend admin endpoint'leri, venue/studio onay kuralları ve simülasyon admin hesabı silinmeyecek.
- Tamamlandığında kaldırılan frontend yüzeylerini, testleri ve kurulumu buraya ekle; gerçek sponsorluk uygulamasına kullanıcı yeni talimat vermeden başlama.
