# Bildirim açılışları — kalıcı proje politikası

Kullanıcı UX kararı: **30 Eylül 2026**. Kalıcı talimatın kaydı: **1 Ekim 2026**.

Bu belge mevcut ve ilerideki bildirim çalışmalarında uygulanacak proje talimatı ve değerlendirme standardıdır. Tek başına otomatik teknik engel veya gelecekte hiç hata olmayacağı garantisi değildir. Güncel açık kullanıcı talimatı önceliklidir; çelişki varsa kaynak ve kapsamıyla kaydet, kararı sessizce değiştirme.

## Kullanıcıya görünen akış

- **UX-1 — Gerçek hedef:** Hangi giriş yolu uygulanmışsa (native kart veya inbox), bildirime dokunma ilgili mevcut gerçek ürün sayfasını açar. Bu kural yeni native destek veya yeni bildirim türü açma yetkisi vermez.
- **UX-2 — Ek bildirim sayfası yok:** Yalnız bildirimi açıklamak için ayrı “Masa bildirimi / olay tarihi / güncel durum / geçmiş olay” raporu, snapshot/sonuç, ara onay/devam, boş loading veya tam ekran hata route'u ekleme. Aynı raporu büyük modal, bottom sheet veya görünür rapor overlay'ine taşımak çözüm değildir. Fazladan görünür route veya Back basamağı oluşturma.
- **UX-3 — Küçük açıklama:** Gereken kısa durum, ağ, hata veya retry açıklamasını yetkili mevcut ürün ya da origin sayfasının altında uygulamanın mevcut küçük mesaj biçimiyle göster. Teknik hata ayrıntısını kullanıcı akışına rapor olarak taşıma. Erişilemeyen hedef için yetkisiz detay gösterme, başarı uydurma.
- **UX-4 — Eksik ürün hedefi:** Mevcut gerçek hedef sayfası yoksa bildirime özel rapor veya yeni ürün tasarımı icat etme. Eksik gerçek ürün ihtiyacını somut kapsam kararı olarak bildir. Mevcut yetkili fallback varsa yalnız kendi hedef/read sözleşmesiyle kullan; genel fallback başarısı exact okundu kanıtı değildir.
- **UX-5 — Gerçek ürün işlevi korunur:** Gerçek sohbet, profil, içerik, masa, rezervasyon/takvim ve işlem yapılabilen başvuru/davet/karar sayfaları korunur. Gerekli gerçek profil seçimi, kısıtlı hesabın kendi başvuru/support/logout/promotion akışı ve ürünün normal loading/error/boş durumları bu yasak kapsamında değildir. Bu politika bütün uygulamaya genel modal veya hata ekranı yasağı koymaz.
- **UX-6 — Teknik koordinasyon:** Kullanıcıya ek rapor/ara ekran göstermeyen, görünür route veya Back adımı üretmeyen teknik resolver, koordinatör ve overlay kalabilir. Dosya/sınıf adındaki `Screen`, `Open` veya `Result` görünür ekran kanıtı değildir. Bu adları yasaklayan kural, yeniden adlandırma işi veya regex/CI testi çıkarma. Backend `RESULT` veri modeli ayrı kullanıcı rapor ekranını zorunlu kılmaz.

## Hedef, görünürlük ve okundu güvenliği

- **READ-1 — Güncel ve yetkili hedef:** Sade görünüm için fresh owned hedef çözümleme; recipient/yetki/captured session; source/receipt/applicationId/cycle/legacy; route/foreground kontrolleri kaldırılmaz. Eski payload veya gösterim verisi tek başına güncel hedef ya da read kanıtı değildir. Backend `RESULT`/receipt/cycle veri sözleşmesi korunur; görünür rapor ekranından ayrı değerlendirilir.
- **READ-2 — Gerçek görünürlük:** Otomatik bildirim ACK'i yalnız fresh exact içerik veya sunucudan doğrulanmış **aynı olaya ait terminal küçük mesaj**, doğru oturumda, current route üzerinde foreground'da **gerçekten görünür olduğunda** yapılır. Mesajı kuyruğa almak, genel listeyi yüklemek, generic 403/404/ağ/erişilemiyor mesajı göstermek yetmez. Aileye özgü sohbet/medya/exact satır hazır olma koşulları korunur. Kullanıcının mevcut açık “Tümünü oku” işlemi bu otomatik açılış kuralıyla yeniden tasarlanmaz.
- **READ-3 — İki ayrı retry:** Hedef sorgusu hatasının retry'si ile ACK-only retry ayrıdır; hata sonrası tekrar deneme açık kullanıcı eylemidir. ACK-only retry hedef GET'ini veya domain işlemini yinelemez. İlgisiz kardeş bildirimlerin unread/read durumları korunur; sayaç yalnız sunucunun başarılı exact ACK sonucu doğrultusunda güncellenir.
- **READ-4 — TABLE hidden→resume:** Görünmezken biten TABLE sorgusunun eski sonucuyla otomatik hedef GET/navigation/ACK yapılmaz. Aynı geçerli origin/session dönüşünde küçük açık retry ve yeniden seçilebilir inbox satırı korunur. Retry ve aynı satır seçimi tek bekleyen isteği/future'ı paylaşır. Origin/Navigator/session kaybında bekleyen future güvenle kapanır. Henüz başlamamış ilk sorgunun foreground beklemesi, hata sonrası retry ile karıştırılmaz.

## İzinli ve yasak örnekler

Bu tablo belge anlamını açıklar; yeni ürün testi veya fiziksel kabul sonucu değildir.

| Örnek | Değerlendirme | Dayanak |
| --- | --- | --- |
| Ayrı “Masa bildirimi / olay tarihi / güncel durum” raporu | Eklenmez; gerçek yetkili masa ürünü veya mevcut yetkili fallback ve gerekirse küçük mesaj kullanılır. | UX-1–4 |
| Aynı raporun büyük modal/bottom sheet içinde sunulması | Eklenmez; raporu başka bir yüzeye taşımak kararı karşılamaz. | UX-2 |
| Gerçek davetin kabul/red yapılabilen ürün sayfası | Korunur; kullanıcının işlem yaptığı gerçek hedeftir. | UX-5 |
| Görünmeyen teknik `TableNotificationOpenScreen` veya resolver | Görünür ek rapor/route/Back üretmiyorsa korunur; adı yasak nedeni değildir. | UX-6 |
| Generic 404 veya genel listenin yüklenmesi | Otomatik ACK yapılmaz. | READ-1–2 |
| Fresh exact terminal küçük mesaj sunucudan doğrulanmış ama yalnız kuyruğa alınmış | ACK yapılmaz; gerçekten görünür olması beklenir. | READ-2 |
| Aynı terminal mesaj doğru session/current route/foreground'da gerçekten görünür | İlgili aile sözleşmesi de karşılanıyorsa yalnız exact ACK yapılabilir. | READ-1–3 |
| ACK hatasında kullanıcının “Tekrar dene” seçimi | Yalnız ACK tekrar edilir; hedef GET/domain işlemi yinelenmez. | READ-3 |
| TABLE sorgusu görünmezken biter, geçerli origin/session'a dönülür | Otomatik GET/navigation/ACK yok; küçük açık retry, serbest satır ve tek bekleyen istek korunur. | READ-4 |

## Manuel kabul

- **KABUL-1 — Etkiye göre kabul:** Her uygulama promptunda ayrı **Manuel kabul** bölümü bulunur. Mobil ekran, Android kartı veya dokunma/hedef/okundu davranışı etkilenirse ilgili gerçek kullanıcı yolu **fiziksel Vivo'da** doğrulanır. Yalnız backend işinde **gerçek çalışan API/HTTP ve gerekli kalıcılık** kontrolleri yapılır; telefonun kapsam dışında olma gerekçesi yazılır. Her durumda adım, beklenen/gözlenen sonuç, ortam/paket ve kanıt belirtilir. Yapılmayan kontrol tamamlandı sayılmaz.
- **KABUL-2 — Dört ayrı sonuç:** Otomatik ürün testleri, gerçek API/HTTP ve kalıcılık, fiziksel cihaz kabulü, kullanıcı görsel/akış onayı ayrı raporlanır. Belge/dosya/bağlantı kontrolü ürün testi değildir. HTTP 200 veya FCM ACCEPTED tek başına telefonda görünme/okunma kanıtı değildir; HTTP testi telefon/FCM kabulünün yerine geçmez. Ajanın incelemesi kullanıcı onayı değildir.
- **KABUL-3 — Dar kapsam:** Testler etkilenen aile, giriş yolu ve senaryoya göre seçilir. İlgisiz kapalı matrisler yeniden başlatılmaz; tarihsel kabuller yeni pakette yeniden yapılmış gibi sunulmaz. Bu politika bütün varyantların her görevde yeniden çalıştırılmasını veya açık işlerin otomatik başlamasını gerektirmez.

Kalıcı ürün kararları [proje karar kaydında](../../hafiza/kararlar.md) tutulur.
[Analytics bütün bildirim işlerinden, iOS genel geliştirmeden sonra gelir](google-analytics-plan.md).
