# Yorum akışı kalite kontrolü

İlk denetim 8 Eylül 2026, son etkinlik görünümü revizyonu 9 Eylül 2026. Etkinlik, fotoğraf/ses/video ve gerçek Overthinking yorum akışları incelendi. Dinleyici profilindeki örnek Overthinking içerikleri ve mekan istatistiklerinin kapalı ayarı değiştirilmedi.

## Düzeltilenler

- Backend, profil fotoğrafını müzisyen, dinleyici, stüdyo, mekan, organizatör ve prodüktör profillerinin güncel medya kaydından toplu olarak çözer. Her yorum için ayrı profil sorguları yapılmaz. Hazır ve herkese açık olmayan medya için eski fotoğrafa dönülmez. Aynı kullanıcının birden fazla mekanı varsa mevcut hesap kimliği sözleşmesi korunur, bir mekan adına yorum yapma seçicisi eklenmez.
- Anonim yorumda tutarsız bir payload gelse bile gerçek ad/kimlik/fotoğraf kullanılmaz. Silinmiş yorumlarda içerik yerine yer tutucu gösterilir. Fotoğraflar sabit yuvarlak alanda kırpılır, hata ve boş fotoğraf durumunda güvenli yer tutucu kullanılır. Harf yer tutucusu emojiyi veya birleşik karakteri yarıda bölmez.
- Fotoğraf ve kullanıcı adı profil bağlantıları mevcut kullanıcı-profili çözümleyicisini kullanır. Kendi kimliği kendi yönetilebilir profiline, başka kişi gerçek profil kimliğine gider. Anonim/silinmiş yazar için profil açılmaz. Başka hesaba veya yenilenmiş eski karta ait gecikmiş tıklama engellenir. Henüz desteklenmeyen/ulaşılamayan profil türü için yanlış hedef üretilmez.
- Yalnız ilk 50 yorumu gösterme sorunu giderildi. Ana yorumlar 50, yanıtlar 20 kayıtlık açık sayfa yüklemeleri kullanır. Sunucu zaten sayfalı yanıt veriyordu, yeni endpoint gerekmemiştir. Yanıtlar kendiliğinden her yorum için istenmez. Sayfa hatası, tekrar deneme ve daha fazla yükleme görünürdür.
- Etkinlik yorumları, sanatçı/mekan bilgisi yüklemesini beklemeden yüklenir. Ana yorumlar kaydırma sırasında tembel oluşturulur. Yanıt sayfalarının eski sonuçları yeni oturum, yenilenmiş ana yorum veya gönderim sonrası gelen yeni sayfanın üzerine yazamaz.
- Etkinlik yanıt editörü yalnız sunucunun başarılı yazma cevabından sonra kapanır. Başarısız yazmada açıklama ve hata görünür kalır. Çift gönderme, eski ekran callback'i ve hesap/etkinlik değişimi korunur. Başarılı kayıt ile sonrasındaki liste yenileme hatası birbirinden ayrılır.
- Ortak medya/video/Overthinking yorum bileşeni aynı kimlik, yanıt, sayfalama, silme ve hata davranışını kullanır. Gerçek yorum yerine placeholder liste gösteren kısımlar giderildi. Video/medya beğenileri yorum beğenisi sayılmaz ve bu çalışmada değiştirilmedi.
- Kullanıcı kendi yorum/yanıtını açık onayla silebilir. Başka kullanıcının silme eylemi görünmez. Silme penceresinin eski cevabı yeni sayfayı kapatamaz, oturum yenilenince eski işlem çalışmaz. Sunucuda yanıt ekleme ve ana yorumu silme aynı kilidi kullanır.
- Genel yorum okuma/yazma yollarının gizli, kullanılamayan veya silinmiş içeriğe erişim yolu olarak kullanılabilmesi giderildi. Mevcut etkinlik ve profil gizlilik kuralları korunur.
- Türkçe yanıt/zaman/hata metinleri ve yorumların isim/tarih/fotoğraf yerleşimi toparlandı. Etkinlik detayının afiş, başlık, sanatçı/mekan bilgisi ve paylaşım tasarımı korunur.
- Sonraki kullanıcı onayıyla aynı içeriğe hızlı gönderim koruması eklendi. Sunucunun `9356` yanıtı o içerik için kalan bekleme süresini gösterir. `9357`, kayıt öncesinde gönderimin durdurulduğunu belirten ayrı mesaj verir. Her iki durumda yorum/yanıt taslağı korunur, liste yenilenmez ve kendiliğinden POST tekrarı yapılmaz. Hesap değişince önceki hesaba ait taslak/yeniden deneme taşınmaz. Genel sunucu `9999` hatası ise kesin ret sayılmaz, mevcut belirsiz gönderim uyarısını korur.

## Cihaz kontrolünde bulunan saat hatası ve kompakt görünüm

Kullanıcının `Cuma Falan` ekranında yeni yazdığı `a` yorumunun `3 sa önce` görünmesi gerçek bir hataydı. Backend'in UTC auditing zamanı saat dilimsiz JSON olarak geliyordu. `DateTime.tryParse` bunu cihazın yerel saati sanıyordu. Önceki testler bu farkı yakalamamıştı. Türkiye saat diliminin gerçekten UTC+03 olduğu doğrulanan yeni testte eski kodun 10 saniyelik kök yorumu ve yanıtı 3 saat 10 saniye eski gösterdiği üretildi.

- Backend artık yorum ve yanıt `createdAt` değerini UTC `Instant` olarak `Z` son ekiyle gönderir. Uygulamadaki yorum ayrıştırıcısı da eski saat dilimsiz UTC cevapları doğru yorumlar, açık `Z` veya saat farkını değiştirmez. Sabit üç saat eklenmedi. Etkinliklerin başlangıç/bitiş saatleri, global saat ayarları ve veritabanındaki tarih değerleri değiştirilmedi.
- Tarih modeli ve sayfa doğrulaması aynı ayrıştırıcıyı kullanır. Genel EVENT/MEDIA/OVERTHINKING kök yorum/yanıt okuma-yazmaları ve herkese açık etkinlik yorumları kapsanır. Yeni ortak `formatCommentAge` metni `Az önce`, `N dk önce`, `N saat önce`, `N gün önce` olarak üretir.
- İlk görünüm revizyonunda etkinlikteki büyük çerçeveli yorum kartları kaldırıldı. Ortak `CommentEntry` görünümünde fotoğraf solda, isim/metin sağda, zaman ve sade Yanıtla/Sil işlemleri alttadır. Kullanıcının sonraki referansıyla yalnız etkinlik görünümü aşağıdaki tasarıma geçti. Gerçek medya/video/Overthinking yorumlarında ortak kompakt görünüm kaldı. Silme onayı, kimlik/izin kontrolleri, taslak koruması, sayfalama ve kısa süreli gönderim koruması korunur.
- Tek harflik yorumun gereksiz yüksekliği için yerleşim regresyonu eklendi. Kompaktlık dokunma alanını küçülterek sağlanmadı, işlemler en az 44 piksel yüksekliktedir. Yanıtlar ince bir bağlantı çizgisiyle ayrılır. 320 piksel genişlik ve iki kat yazıda bulunan hayalet profil rozeti taşması sınırlandırıldı, tam rozet metninin erişilebilir açıklaması korunur.

Türkiye saat dilimini zorunlu doğrulayan test seçeneği: `--dart-define=COMMENT_TEST_REQUIRE_ISTANBUL=true`. Böylece bu özel doğrulama yanlışlıkla yalnız UTC ortamında çalışıp geçmiş sayılmaz. Normal taşınabilir testler ayrıca açık `+03`, `-07`, `+05:30`, UTC ve gece yarısı tarih sınırlarını karşılaştırır.

## Kullanıcı referansı — etkinlik detayının alt bölümü

9 Eylül 2026. Kullanıcının `ChatGPT Image 8 Eyl 2026 23_48_35.png` görselindeki bitiş kartından aşağısı Flutter bileşenleriyle uyarlandı. Üst afiş, başlık, sanatçı/mekan satırı ve paylaşım tasarımı değiştirilmedi.

- Sona erme bilgisi ince gradyan çerçeveli, saat simgeli ve sabit dalga çizgili karta taşındı. Görsel dosyası indirme, animasyon veya yeni sunucu isteği yok. Kart yüksekliği metin ölçeğine göre büyür.
- Yorum başlığına kısa marka çizgisi ve sayaç eklendi. Sayaç sunucunun ana yorum toplamını kullanır, yüklenen sayfadaki kayıt sayısını veya yanıtları toplamaz. İlk yükleme/hata durumunda bilinmeyen sayı sıfır gösterilmez. Büyük sayılar Türkçe kısaltılır, erişilebilir açıklama tam ana yorum sayısını belirtir. Mevcut kilitli `intl 0.20.2` doğrudan bağımlılık olarak kaydedildi, paket sürümü yükseltilmedi.
- Etkinlik yorum kartında 44 piksel avatar, ad/zaman başlığı, sağ üstte yalnız sahibine görünen silme düğmesi ve çizgiyle ayrılmış Yanıtla alanı var. Kısa kart 130–150 piksel aralığındadır. Uzun metin, anonim/silinmiş kimlik ve büyük yazı kontrolleri korunur. Ortak kimlik/fotoğraf ve zaman bileşenleri yeniden yazılmadı.
- Alt yorum alanı referansın yuvarlatılmış yüzeyi ve ince gradyan çerçevesini kullanır. Kullanıcının isteğiyle mevcut 46×46 lacivert gönderme düğmesi, tıklama/işlemde göstergesi ve misafir giriş kapısı korunur.
- Gidiyorum/Düşünüyorum kuralı değiştirilmedi. Sunucu sona erdi diyorsa yeni tercih yapılamaz. Önceden seçim yoksa iki düğme de gizlidir. Önceden seçim varsa yalnız seçili düğme kalır ve kaldırma menüsüne erişilebilir. Kullanılamayan etkinlik sona ermiş gibi gösterilmez. Bu durum sunucu cevabına dayanır, cihazda canlı bitiş sayacı eklenmedi.
- UTC yorum saati düzeltmesi korundu. Referanstaki örnek `3 sa önce` yazısı sabitlenmedi, yeni yorum gerçek yaşına göre `Az önce` gösterir.

## Kompakt ve açılır/kapanır yanıtlar — 9 Eylül 2026

Kullanıcı ana yorum kartını onayladı. Yalnız yanıtların fazla yüksek olduğunu belirtti ve yanıtları isteğe bağlı açıp kapatmayı istedi.

- Ana yorum kartı, bitiş kartı ve mevcut gönderme düğmesi korundu. Yanıtlar 28 piksel avatar, hemen yanında ad/zaman ve altında metin kullanır. Kısa yanıt 44–64 piksel aralığındadır. Zaman, yer varsa isimle aynı satırdadır. Uzun adlar, hayalet rozeti ve iki kat yazı gerektiğinde satır değiştirir. Yalnız sabit küçük avatarın dekoratif harfi ölçekle sınırlanır, yazar/metin kullanıcının yazı ölçeğini korur. Çerçevesiz silme simgesinin dokunma alanı en az 44 pikseldir.
- Başlıklar başlangıçta kapalıdır. `Yanıtları göster (N)` ilk sayfayı açık istekle getirir, `Yanıtları gizle` alt içerikleri widget ağacından kaldırır. Her başlık bağımsızdır. Kapatıp tekrar açmak aynı sayfayı yeniden istemez. Yükleme sırasında kapatılan başlık geç gelen cevapla kendiliğinden açılmaz.
- İlk yanıt sayfası ve sonraki sayfalar 20 kayıttır. `Daha fazla yanıt` ve hata sonrası tekrar deneme ayrıdır. Başarısız sayfa ilerletilmez, aynı sayfa tekrar istenir. Kapatıp açmak önceden yüklenmiş sayfaları kaybettirmez. Yeni oturum, etkinlik değişimi veya ana yorum yenilemesi eski görünüm/önbelleği geçersiz kılar.
- Kapalı başlığa yanıt yazmak o başlığı otomatik açmaz veya gereksiz yanıt GET'i oluşturmaz. Önceden açık başlığa başarılı yazma sonrasında güncel yanıtlar tekrar alınır. Önceki okumanın gecikmiş cevabı yeni yazma sonucunu ezemez.
- Sayfa sınırında yinelenen yorumun daha güncel DTO'su artık eski içerik/kimliği değiştirir, sıra ve benzersiz kimlikler korunur. Yanıtların devamı benzersiz önbellek uzunluğuna değil tüketilmiş sayfa aralığına göre belirlenir. Toplamla çelişen boş sunucu sayfası sessizce bitiş sayılmaz, mevcut liste korunarak tekrar denenebilir.

400 ana yorumun 50'şer kayıtla 8 istek, tek başlıktaki 400 yanıtın 20'şer kayıtla 20 açık istek üzerinden erişilebilirliği test edildi. Ana yorumlar kaydırma sırasında tembel oluşturulur, kapalı yanıtlar oluşturulmaz veya yüklenmez. Kullanıcı açık başlıkta daha fazla sayfa istedikçe yüklenen yanıtlar birikir. Bunlar işlev/istek sınırı kontrolleridir, üretim kapasitesi ya da gerçek cihaz kare hızı ölçümü değildir.

Paylaşılan repository/Cubit denetiminde 137 test geçti. Buna 400 ana yorumun EVENT/MEDIA/OVERTHINKING akışları, sayfa 3 hatasının aynı sayfadan tekrarı, eşzamanlı tıklamanın tek istek oluşu ve başa eklenen 50 yorumun yol açtığı tamamen örtüşen sayfadan sonra devam edebilme dahildir. Yeni yorumlar sayfa başına eklenirse yenilemeyle görülür. Başarılı yorum oluşturma/silme sonrası mevcut ilk sayfaya yenileme davranışı değiştirilmedi. Sayfalama, farklı istekler arasında tek anlık görüntü garantisi vermez.

Backend aynı turda izole PostgreSQL üzerinde 400 ana yorum, 400 yanıt ve 400 farklı yazarla doğrulandı. 20/37/50 sayfa boyutları, son/boş sayfalar, sabit tarih+kimlik sırası, silinmiş yer tutucular ve hedef izolasyonu geçti. 5 pakette 75 test başarılı, hata/başarısız/atlanmış test yok. Backend üretim kodu veya şema değişmedi. Ayrıntılar backend `docs/CommentAudit.md` içindedir.

Görünüm kontrolleri `weekly_event_detail_reply_design_cases.dart`, uçtan uca ekran sayfalaması `weekly_event_detail_reply_pagination_cases.dart` içindedir. Gerçek fontlu açık/kapalı 390 piksel ve 320 piksel/iki kat yazı önizlemeleri `build/event-reply-review/` altında incelendi. Gerçek fotoğraf ağı ve telefon klavyesi için manuel plan korunur.

Son birleşik doğrulama: `flutter test --no-pub --dart-define=COMMENT_TEST_REQUIRE_ISTANBUL=true --reporter expanded` ile **3.337 test geçti**, yaklaşık 2 dk 6 sn. `dart analyze lib test` temiz, iki depoda `git diff --check` boşluk hatası göstermedi. Hedefli paketlerin sayıları bu tam sonuca yeniden eklenmez. Son günlükler `build/comment-replies-full-tests.log` ve `build/comment-replies-full-analyze.log`. Backend 75 testin XML toplamları ayrıca kontrol edildi. Bu tur yalnız Flutter hot restart gerekir, backend üretim kodu ve şema değişmedi.

## Önceki referans görünümünün doğrulaması

| Kontrol | Sonuç |
| --- | --- |
| Tam Flutter paketi, Türkiye saat dilimi kontrolü açık | 3.310 test geçti, yaklaşık 2 dk 17 sn |
| `dart analyze lib test` | Sorun yok |
| Etkinlik detayına ait tam hedefli paket | 195 test geçti, tam Flutter sayısına yeniden eklenmez |
| Son kaynakla gerçek fontlu referans render testi | 1 test geçti, 390 piksel ve 320 piksel/iki kat yazılı iki PNG incelendi |

Son yerel günlükler `build/comment-reference-full-tests.log`, `build/comment-reference-full-analyze.log` ve `build/event-reference-complete-tests.log`. Son hedefli koşumda mevcut dar ekran testi 1.234.567 sunucu ana yorumu / bir yüklenmiş kayıt ile güçlendirildi. Tam sayının erişilebilir olması, kısaltılmış rozetin 320 piksel/iki kat yazıda sığması ve ek sayfa isteği oluşmaması doğrulandı. Bu son 195 testlik koşumun bitiş çıktısı `build/event-reference-review/weekly-detail-final-result.log` içindedir. Son görseller `build/event-reference-review/event-reference-1x.png` ve `event-reference-2x.png`. Görsellerdeki harf avatarı test verisidir, gerçek cihazın ağdan profil fotoğrafı yüklemesini doğrulamaz. Bu yalnız frontend görünümü revizyonudur. Backend yeniden değiştirilmedi veya testleri bu revizyonda tekrar çalıştırılmadı. Önceki backend doğrulaması aşağıdadır.

## Önceki saat/kompakt görünüm revizyonunun doğrulaması

| Kontrol | Sonuç |
| --- | --- |
| Tam Flutter paketi, son kompakt görünüm ve UTC düzeltmesi, Türkiye saat dilimi kontrolü açık | 3.299 test geçti, yaklaşık 2 dk 15 sn |
| `dart analyze lib test` | Sorun yok |
| Backend yorum + UTC auditing + ilgili güvenlik/medya paketi | 21 pakette 153 test geçti, hata/başarısız/atlanmış test yok |
| Gerçek fontlarla etkinlik yorum/yanıt önizlemesi | 1 görsel test, beş PNG. Kısa `a`/`deney` yorumları ve yanıt görünümü incelendi |
| Gerçek fontlarla ortak yorum önizlemeleri | 2 görsel test, normal/320 piksel-iki kat yazılı hayalet profil/medya görünümünde üç PNG incelendi |
| İki depoda `git diff --check` | Boşluk hatası yok |

Hedefli test sayıları tam Flutter sonucuna yeniden eklenmez. Başlıca regresyonlar `comment_thread_cubit_test.dart`, `comment_repository_quality_test.dart`, `non_event_comment_presentation_test.dart` ve `weekly_event_detail_comment_quality_cases.dart` içindedir. Sonuncusu mevcut etkinlik tasarım testinin bir parçasıdır.

Hızlı gönderim korumasında `comment_write_guard_test.dart` içindeki 22 test, gerçek Dio hata cevabını ortak repository ve Cubit üzerinden geçirir veya hata/süre sınırlarını kontrol eder. Üç içerik türünün kök yorum/yanıtlarında uygulama hata kodu ve `Retry-After` başlığı birlikte kontrol edilir. Kesin engelleme ile genel 500/503, `9999` ve ağ belirsizliği ayrılır. Ortak ve etkinlik yorum ekranlarına eklenen 11 arayüz regresyonu taslak/yanıt hedefinin korunmasını, ilk üç gönderimde istemci beklemesi olmamasını, otomatik tekrar yapılmamasını ve hesap değişiminde eski eylemin çalışmamasını kapsar. Bunlar son tam paketteki 3.299 teste dahildir.

Tam test komutu: `flutter test --no-pub --dart-define=COMMENT_TEST_REQUIRE_ISTANBUL=true --reporter expanded`. Önceki kompakt revizyonun günlükleri: `build/comment-compact-full-tests.log`, `build/comment-compact-full-analyze.log`, `build/comment-compact-event-tests.log`, `build/comment-compact-render.log`. O revizyonun görselleri: `build/comment-compact-review/`. Önceki denetimlerin `comment-burst-*` ve `comment-audit-*` günlükleri ayrı revizyon kayıtlarıdır. Bunlar geçici doğrulama çıktılarıdır, sürüm kontrolüne eklenmez.

Backend komutu, izolasyon, ölçülen sorgu sayısı ve API sınırları `SoundConnect-Backend/docs/CommentAudit.md` belgesindedir. Testler gerçek uygulama veritabanını değil izole PostgreSQL kullanır.

## Açık sınırlar ve ürün kararı

- Yeni yorum POST'u sunucuda kalıcı bir komut kimliği kullanmaz. Cevap kaybolduğunda yazma gerçekleşmiş olabilir. Otomatik tekrar yapılmaz, belirsiz sonuçta yazı korunur ve yeniden göndermeden mevcut yorumları kontrol etme uyarısı verilir. Sunucu tarafı tam bir-kez gönderim garantisi bu çalışmada eklenmedi.
- Kullanıcı kararıyla genel 10/dakika kotası yerine aynı içeriğe hızlı gönderim koruması seçildi. Aynı kullanıcının aynı içerikteki ilk üç yorum/yanıtı 30 saniyelik kayan aralıkta gönderilebilir. Dördüncü için en eski gönderimin bu aralıktan çıkması beklenir. Her gönderimden sonra bekleme, hesap cezası veya kalıcı kötü niyet etiketi yoktur. Yanıtlar aynı içerik hesabına dahildir. Ayrıntılar backend `docs/CommentBurstProtection.md` belgesindedir.
- Metin sınırı mevcut backend sözleşmesindeki 500 UTF-16 birimidir. Bazı emojiler birden fazla birim tüketir. Karakter sınırı yeni bir ürün kararıyla değiştirilmedi.
- Sayfalama sırası tarih + kimlik ile kararlıdır. Ayrı sayfa istekleri arasındaki yeni yorumlar/silmeler bütün listenin tek anlık görüntüsü garantisini vermez. Kimlik üzerinden tekrarlar ayıklanır. Yük/kapasite testi yapılmış sayılmaz.
- Yeni yorum düzenleme, moderatör yetkisi, engelleme, yorum beğenisi veya silinen metnin saklama politikası eklenmedi. Sunucunun mevcut soft-delete saklama kuralı değişmedi.
- Gerçek telefonun CDN/fotoğraf erişimi, klavyesi ve video katmanı henüz manuel doğrulanmadı. Otomatik görselde kullanılan harfler bilerek fotoğrafsız test verisidir, gerçek fotoğrafın telefonda yüklendiğine kanıt değildir.

Gerçek veritabanı, migration, çalışan backend veya cihazdaki uygulama değiştirilmedi. Önceki UTC kaynak düzeltmesi backend'in güncel kodla başlatılmasını gerektirir. Son referans görünümü yalnız Flutter hot restart gerektirir. Şema geçişi gerekmez.

## Manuel akışa eklenen kısa kontrol

[Mevcut test planındaki](EventAudienceManualChecks.md) hesap geçişleri kullanılır. Aynı izin/sınır/yarış testleri elle tekrarlanmaz:

1. Dinleyiciyle test etkinliğinde kısa yorum gönder. Fotoğrafı varsa kendi profilindeki fotoğrafla eşleşsin, yoksa düzgün yer tutucu görünsün. Kendi isim/fotoğrafına dokununca kendi profili açılsın.
2. Zaten planlanan müzisyen hesabına geçişte aynı etkinliğe gel. Yorumdaki dinleyici kimliğini kontrol et, yanıt yaz. Müzisyenin gerçek fotoğrafı doğru gelsin. Kendi yanıtını sil ve yanlış yorumun silinmediğini gözlemle.
3. Mevcut bir ses/video içeriğinde yorum alanını bir kez aç/kapat. Klavye, geri hareketi ve video katmanı birbirini engellemesin. Uygun gerçek içerik yoksa bu kontrol geçildi sayılmaz, sonraya kaydedilir.

Son durum: Cihazda Keşfet'ten etkinliğe girip geri dönme ve seçili konum/tarihin korunması kullanıcı tarafından doğrulandı. Kullanıcı ana referans yorum tasarımını ve kompakt/açılır-kapanır yanıt görünümünü onayladı. Son paylaştığı 9 Eylül tarihli ekranda Gidiyorum/Düşünüyorum, fotoğraflı `@berna` ana yorum/yanıtı ve `Az önce` metni görünüyordu. M1 aşağıdaki beğeni ve takvim ek kontrolü için durakladı. Katılım tercihi, kendi profiline dokunma ve diğer manuel adımlar geçti sayılmadı.

## Yorum beğenileri, ortak görünüm ve takvim günü — 9 Eylül 2026

Bu son bölüm önceki turdaki “şema geçişi gerekmez” durumunu günceller. Kullanıcı backend'i durdurduğunu teyit etti. Yedekli COMMENT beğenisi geçişi bu tur uygulandı, backend asistan tarafından başlatılmadı.

- Mevcut beğeni altyapısı COMMENT hedefine genişletildi. Ana yorum ve yanıt DTO'ları `likeCount` / `likedByMe` taşır. Sayfa başına toplu sorgu kullanılır, her kalp için GET yapılmaz. Ziyaretçi sayıyı görür, beğeni yazamaz. Silinmiş yorum kalp göstermez. Anonim/hayalet yazar gizliliği ve kendi profilini açma kuralları değişmedi.
- Ortak `CommentLikeButton` açık hedef durumunu POST/DELETE ile yazar. Tek işlem kilidi, oturum/kaynak geçerliliği ve sunucu sonucu doğrulaması var. Belirsiz yazma bir kez salt okunur doğrulanır, otomatik POST tekrarı yapılmaz. Durum hâlâ bilinmiyorsa sonraki dokunuş yalnız yeniler. Başarı bildirimiyle ekran doldurulmaz.
- Ekrana ait `CommentLikeMemory` tam yorum DTO'suna zayıf anahtarla bağlıdır. Kaydırıp geri gelmek, yanıt kapatıp açmak ve işlem sırasında yeniden oluşturulmak onaylı/beğenilen veya bekleyen durumu korur. Yeni hesap/DTO/ekran eski sonucu devralmaz. Yorum DTO'su sadece beğeni için değiştirilmediğinden açık yanıtlar ve sayfalar sıfırlanmaz. Genel, sınırsız oturumlar arası önbellek yoktur.
- Etkinlik dışındaki tüm gerçek yorum alanları tarandı: fotoğraf/ses/video detayı, video akışı yorum paneli, Overthinking akış/detay/alt paneli ortak `CommentThreadView` kullanıyor. İnce gradyan kart, fotoğraf/ad/zaman, sahip silme işlemi, Yanıtla/Beğen, kök yorum sayacı ve katlanır yanıt dili buralara taşındı. Profillerdeki örnek Overthinking içerikleri değiştirilmedi. Yanıta yanıt verme mevcut köke bağlı çalışır.
- Küçük yanıt satırında kalp ve silme en az 44 piksel dokunma alanını korur. Yer yoksa ad/zaman satır değiştirir. Geniş test fontunda kısa yanıt en fazla 80 piksel, gerçek 390 piksel/font görünümü kompakt kalır. 320 piksel/iki kat yazı görüntüleri de incelendi. Etkinliğin gönderme düğmesi değiştirilmedi.
- Mekan, müzisyen ve grup haftalık takvimleri İstanbul gününü kullanır. Bugün bitmiş etkinlik bugün kalır, ertesi gün takvimden çıkar. Açık ekran gece yarısında ve uygulamaya dönüşte kontrol edilir. Mekanın boş haftalık listesini tüm geçmiş etkinliklerle dolduran hatalı geri dönüş kaldırıldı. Müzisyen/grup haftası tarih değişiminde yeniden alınır. Mekanda yeni haftalık pencereye giren ileri tarihli etkinlikler mevcut profil yenilemesiyle gelir. Geçmiş etkinlik kayıtları ve dinleyici paylaşımları silinmez.

### Son doğrulama

- Tam Flutter: **3.425 test geçti**, 2 dk 14 sn. `build/comment-likes-full-tests.log`.
- Tam `dart analyze lib test`: sorun yok. `build/comment-likes-full-analyze.log`.
- Son beğeni sözleşme/etkileşim kontrolü: **70/70**. Tam sayı üzerine eklenmez. `build/comment-likes-final-contract-tests.log`.
- Backend ilgili birleşik paket: **219 test / 28 paket**, hata/başarısız/atlanmış yok. 42 takvim testi dahil. Gerçek PostgreSQL üzerinde 400 ana yorum ve 400 yanıt beğeni verisiyle sayfalama ve sorgu sınırları doğrulandı.
- Gerçek font görüntüleri: `build/comment-likes-reference/` ve `build/shared-reference-review/`. Telefon ağı, gerçek fotoğraf yüklemesi ve klavye/geri hareketi henüz bu tur cihazda doğrulanmadı.

Bu sayılar üretim yük/kullanıcı kapasitesi garantisi değildir. Yedek, geri yükleme ve 95 tablonun değişmediği geçiş kaydı backend `docs/CommentLikesLocalMigration20260909.md` dosyasındadır.

## Cihazda bulunan geri giriş beğenisi hatası — 9 Eylül 2026

Son doğrulama: tam Flutter paketi **3.458 test geçti** (2 dk 14 sn), tam `dart analyze lib test` temiz. Son kaynak üzerinde gerçek taşıma + kalp bileşeni paketi ayrıca **13/13 geçti**. Backend kimlik/güvenlik paketi **58/58 geçti**. Hedefli paket sayıları tam toplama eklenmez. Günlükler: `build/comment-personal-read-full-tests.log`, `build/comment-personal-read-full-analyze.log`, `build/comment-personal-read-final-transport-tests.log`. Düzeltilmiş gerçek telefon akışı henüz kullanıcı tarafından tekrar doğrulanmadı.

Yukarıdaki testlerin geçmiş olması gerçek akışın tamamının doğrulandığı anlamına gelmedi. Kullanıcı sayfaya yeniden girince toplam doğru, kalp seçimi yanlış kaldığını bildirdi. Önceki testlerde repository'nin taşıma sınırı taklit ediliyor, backend HTTP testlerinde principal doğrudan veriliyordu. Bu iki ayrı doğru parça gerçek ağ istemcisindeki kimlik kaybını yakalamamıştı.

`DioApiClient` public etkinlik URL'lerinde `expectedSessionKey` çitini kontrol etmesine rağmen JWT eklemiyor. EVENT root/reply okumaları da her oturum için bu URL'yi kullandığından sunucu misafir görünümü (`likedByMe=false`) döndürüyordu. Beğeni yazması özel URL'de kimlikle çalıştığı için veri kaybolmuyor, yeniden okumanın kişisel bilgisi kayboluyordu.

Dar düzeltme: aktif, girişli, kullanıcı kimliği bulunan ve profil seçimi tamamlanmış hesaplarda mevcut `/api/v1/comments/EVENT/{eventId}` ve `/api/v1/comments/replies/{rootId}` kullanılır. Diğer EVENT okumaları public adapter'da kalır. Tüm public isteklere genel JWT ekleme, yeni API, her kalp için ek sorgu veya yeniden girişte eski ekran önbelleğinden seçim uydurma yapılmadı. Kimlikli rota reddedilirse bu istek misafir rotasından sessizce tekrar edilmez. Mevcut kök/etkinlik/oturum bağlılığı ve sayfa yanıtının ebeveyn kontrolü korunur.

Yeni `comment_like_transport_integration_test.dart` gerçek `AuthSessionManager`, token deposu, `DioApiClient` ve repository'yi birlikte kullanır. Sunucu tarafı bearer'a göre kişiselleşen test adapter'ıdır. Başlangıçta dört kimlikli ana yorum/yanıt testi gerçek rapordaki gibi başarısız, misafir testi başarılıydı. Aynı testler düzeltmeden sonra geçti. Bunlar canlı backend/telefon testi değildir. Backend'e ayrıca gerçek imzalı JWT, filter, güvenlik zinciri ve controller üzerinden15 test eklendi. 58 testlik ilgili paket geçti,0 hata/başarısız/atlanmış.

Yükleme iddiası ayrı incelendi. İlk açılışta yorum sayfası, etkinlik detayı, varsa sanatçı/grup ve mekan önizlemesi, uygun hesapta kişisel katılım tercihi eşzamanlı alınır (en fazla5 JSON okuma, görseller ayrı). Tüm sayfa bu cevapları beklemez. Yeni dört ekran testi bütün cevapları bekleterek başlık/tarih/bağlantılar/Paylaş'ın hemen çizildiğini ve yorumun diğer dört cevabı beklemediğini doğrular. 1 veya400 yorumda aynı başlangıç bütçesi geçer: tek50kayıtlık sayfa, kapalı yanıtlar ve beğeni sayacı için ek istek yok. Önceki400satırlık PostgreSQL testleri sorgu sınırlarını denetler. Bunların hiçbiri gerçek ağ gecikmesi, kare hızı veya üretim yük kapasitesi ölçümü değildir. Kısa tazeleme göstergesi kaldırılmadı. Tam profil önizleme DTO'larını daha küçük hale getirmek ayrı bir performans iyileştirmesi olabilir, bu hata düzeltmesinde API kapsamı büyütülmedi.
