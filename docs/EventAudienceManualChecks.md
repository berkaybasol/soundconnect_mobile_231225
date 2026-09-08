# İstatistik sonrası etkinlik akışı — kalite ve cihaz kontrolü

Son güncelleme: 9 Eylül 2026.

### Son cihaz bulgusu — sayfaya dönüşte beğeni kimliği

Bu düzeltme sonrası otomatik sonuç: tam Flutter **3.458 geçti**, gerçek taşıma/kalp bütünleşmesi **13/13**, backend kimlik/güvenlik paketi **58/58**. Tam kod analizi temiz. Bu sonuçlar aşağıdaki bekleyen cihaz adımını geçti saymaz.

Kullanıcı Beğen/Yanıtla sırasını onayladı. Yanıtları kapatıp açma kontrolü geçti. Etkinlikten çıkıp yeniden girince toplamlar korunurken kalplerin seçili görünmediği **gerçek hata** bildirildi. Bu nedenle sayfalar arası beğeni kalıcılığı manuel geçmiş sayılmadı.

Neden: girişli EVENT yorum okumaları misafir URL'sinden gidiyor, ağ istemcisi bu URL'ye JWT eklemiyordu. Oturum çiti tek başına sunucuya kimlik göndermek değildir. Girişli/aktif hesap okumaları mevcut kimlik doğrulamalı yorum/yanıt rotalarına alındı. Misafir okuma ve diğer yorum yüzeyleri korundu. Gerçek Dio+repository taşıma testi önce hatayı üretti, sonra düzeltmeyle geçti. Şema veya backend üretim kodu değişmedi.

Sıradaki tek cihaz kontrolü: Flutter hot restart sonrası aynı hesaptan aynı etkinliğe yeniden gir. Önceden beğendiğin ana yorumun ve açtığın yanıtın kalbi seçili gelmeli. Yalnız ana yorumun beğenisini kaldır, çıkıp dön. Ana yorum seçili olmamalı ve toplamı bir azalmış olmalı, yanıt seçili kalmalı. Bundan sonra önceki ikinci hesap/medya/katılım taslağı planına devam edilecek.

Kısa yükleme için otomatik kontrol eklendi: etkinlik başlığı/tarih/profil bağlantıları/Paylaş, beş ilk ağ cevabı beklerken çizilir; yorumlar diğer cevapları beklemeden görünebilir. 1 ve400 ana yorum aynı başlangıç istek sayısını üretir (bir50kayıtlık yorum sayfası, erken yanıt/beğeni okumaları yok). Cihazda gerçek gecikme/kare hızı ve üretim yük kapasitesi ölçülmüş sayılmaz. Bekleme göstergesi saklanmadı ve eski hesap verisiyle maskelenmedi.

## Son durak — beğeni ve ortak yorum/takvim güncellemesi

Kullanıcı kompakt, açılır/kapanır yanıt görünümünü onayladı. Yeni yorum/yanıt beğenileri, diğer gerçek yorum alanlarının aynı tasarıma taşınması ve haftalık takvim günü düzeltmesi tamamlandı. 3.425 Flutter ve 219 ilgili backend testi geçti, tam kod analizi temiz. Küçük şema geçişi kullanıcı onayıyla yedeklenip uygulandı, 95 tablonun verileri değişmedi. Backend kapalı bırakıldı.

M1 hâlâ kısmen doğrulandı. Önce backend güncel kaynakla başlatılıp uygulamaya hot restart yapılacak. Önceki başarılı davet/üyelik/konum kontrolleri baştan tekrarlanmayacak.

Kısa cihaz kontrolü (henüz yapılmadı):

1. Aynı etkinlikte bir yorumu ve bir yanıtı beğen. Yanıtları kapat/aç, sayfadan çıkıp geri gir. Kalbin durumu/sayısı korunsun. Birini kaldır. Aynı sırada fotoğraf ve normal dokunma hissini gözlemle.
2. Zaten planlanan ikinci hesap geçişinde aynı yoruma bak. Toplam görünürken ilk hesabın kişisel kalbi diğer hesaba taşınmamalı. Eşzamanlı/400 kayıt testleri elle tekrarlanmayacak.
3. Mevcut gerçek bir medya yorumunu aç, klavyeyle kısa yanıt gönder ve geri hareketiyle kapat. Video varsa oynatma katmanı takılmamalı. Uygun gerçek içerik yoksa geçti sayılmayacak.
4. Geçmiş tarihli test etkinliğinin ilgili mekan/sanatçı haftalık takviminde görünmediğine bir kez bak. Geçmiş etkinlik yönetim kaydı korunmalı. Gece yarısını bekleme/cihaz tarihini değiştirme gerekmiyor, sınırlar otomatik testlerde var.

Ardından M1'deki Gidiyorum ve profil taslağına geçişten devam edilecek. Yeni beğeni kontrolleri henüz manuel geçilmiş sayılmadı.

## Kapsam ve sonuç

Bu denetim Gidiyorum / Düşünüyorum tercihlerini, dinleyici profilinde açıkça paylaşmayı, açıklamalı profil taslağını, profil kartlarını, üye Keşfet girişini, alt bildirim/küçük menü davranışını ve dış uygulamaya görsel paylaşımını kapsar. Backend yetki, gizlilik, sürüm ve eşzamanlılık kontrolleri birlikte incelendi. Sanatçı katılım davetleriyle dinleyicinin kişisel etkinlik tercihi ayrı akışlardır.

Bulunan ve regresyon testiyle düzeltilen sorunlar:

- Hayalet moda geçişle aynı zamana gelen istek, istek önbelleğindeki eski standart profil bilgisini kullanabiliyordu. Yeni paylaşım ve herkese açık liste okumasında güncel, kilitle korunan görünürlük bilgisi kullanılır.
- Farklı kişilerin aynı etkinlikteki tercihleri gereksiz yere tek bir özel kilidi bekliyordu. Etkinliği değiştirmeyen işlemler ortak okuma kilidi kullanır. Etkinlik değiştirme/silme ve kullanıcıya ait sürüm korumaları korunur.
- Geciken menü ve profil kartı işlemleri yeni sayfaya, yenilenmiş karta veya başka oturuma taşınabiliyordu. İşlemler oluşturuldukları oturum, kart, veri kaynağı ve sayfayla sınırlandı.
- Hesap değişiminde paylaşım önizlemesi boş bir pencere olarak kalabiliyordu. Yalnız o önizleme kapanır, üstüne açılmış başka sayfa kapanmaz.
- Görsel dosyası hazırlanırken hesap veya kişisel tercih değişirse eski kişisel görsel dış uygulamaya verilebiliyordu. İşletim sistemine teslim edilmeden önce de geçerlilik kontrol edilir.
- Sonucu belirsiz bir kayıttan sonra tutulmuş eski paylaş düğmesi tekrar yazma yapabiliyordu. Taslak belirsizlik koruması düğmenin görünümünden bağımsız uygulanır.
- Taslaktan çıkış penceresinin eski cevabı yeni açılan sayfayı kapatabiliyordu. Pencere sahipliği, tek cevap ve oturum geçerliliği korunur. Oturum değişince bekleyen çıkış penceresi de temizlenir.

### Otomatik doğrulama

Bu kayıttaki sayılar aynı testlerin farklı çalıştırmalarını toplayarak büyütülmemiştir.

| Çalıştırma | Sonuç |
| --- | --- |
| Frontend `flutter test --no-pub --reporter expanded` | 3.152 test geçti, yaklaşık 1 dk 56 sn |
| Frontend `dart analyze lib test` | Sorun yok |
| Backend son kapsamlı ilgili regresyon paketi | 17 pakette 215 test geçti, başarısız/hatalı/atlanmış test yok |
| İki depoda `git diff --check` | Boşluk hatası yok |

Backend komutu, gerçek PostgreSQL/Redis izolasyonu ve hata tekrarlarının kanıtı `SoundConnect-Backend/docs/EventAudienceIntents.md` içindeki son denetim bölümündedir. Frontend yerel kayıtları `build/audience-audit-full-tests.log`, `build/audience-audit-full-analyze.log` ve `build/audience-audit-final-draft.log` dosyalarıdır. `build` geçicidir, sürüm kontrolüne eklenmez.

Konuma göre aramadaki mevcut etkinlik kartı değiştirilmedi. Dosyanın SHA-256 değeri: `87130539DE206F32C99DCF28D36E878CEA695F2273ACF1BF4734F28C2AE372C8`.

Otomatik kontrollerde bilinen açık bir engelleyici bulgu kalmadı. Bu sonuç gerçek telefon kontrolünün veya üretim kapasitesi ölçümünün yapıldığı anlamına gelmez.

## Korunan kararlar ve sınırlar

- İlk Gidiyorum / Düşünüyorum tercihi özel kalır. Profilde paylaşmak ayrı ve açık bir işlemdir.
- Dinleyici her iki tercihini de profilinde paylaşabilir. Müzisyen tercih yapabilir, bunu kendi profilinde paylaşamaz. Müzisyen için yeni plan yönetim menüsü eklenmez.
- Profil taslağı bellektedir. Uygulamayı kısa süre arka plana almakla korunması beklenir. İşletim sistemi uygulamayı öldürürse veya uygulama zorla kapatılırsa kaydedilmemiş taslağın kalıcı olması vaat edilmez. Yayınlanmış paylaşım ve kaydedilmiş tercih sunucuda kalır.
- Hayalet görünürlük, sona ermiş/silinmiş etkinlik ve mevcut isteğe bağlı not saklama kuralları değişmedi. Bu özellik yeni bir hesap engelleme sistemi içermez.
- Mekan istatistikleri Yakında olarak kalır. Analiz altyapısını açma, yük testi ve bütün uygulamanın izleme planı bu işin kapsamı değildir.
- Mağaza bağlantılarının yer tutucu metinleri kullanıcı kararıyla korunur. Yayından önce gerçek bağlantılar eklenecek.
- Bu denetimde gerçek veritabanı, uygulanmış migration, çalışan backend ve ortam ayarları değiştirilmedi. Yeni bir migration gerekmez. Kaynak düzeltmeleri mevcut çalışan backend'e kendiliğinden geçmez.

## Manuel planın amacı

Rol/izin matrisi, 500 karakter sınırı, sayfalama sınırları, çift tıklama, gecikmiş cevaplar, sürüm çakışmaları, hayalet mod eşzamanlılığı ve bitiş saati sınırları otomatik testlerde kapsandı. Bunları tek tek yeniden yaptırmayacağız.

Beş kısa kontrol grubunda gerçek telefonun klavyesi, geri hareketi, uygulama yaşam döngüsü, gerçek API bağlantısı ve başka uygulamaların görseli alması doğrulanacak. Her seferinde yalnız sıradaki adım kullanıcıya verilecek. Bir hata çıkarsa o adım durdurulacak, düzeltilip yalnız etkilenen akış tekrarlanacak.

### Hazırlık — DEVAM EDİYOR

1. Kullanıcı backend'i güncel kaynak kodla yeniden başlatır ve telefondaki uygulamaya hot restart yapar. Veritabanı sıfırlanmaz.
2. Standart görünürlükte bir dinleyici hesabı seçilir. İkinci hesap olarak mevcut bir müzisyen hesabı yeterlidir. Şifre paylaşılması gerekmez.
3. Keşfet'te bulunabilen, henüz sona ermemiş ve bu dinleyicinin henüz tercih yapmadığı bir test etkinliği seçilir. Uygun mevcut etkinlik varsa yenisi oluşturulmaz. Eski sanatçı daveti testlerini baştan kurmaya gerek yoktur.

Dinleyici: ekrandaki yorum kimliği `@berna`. Müzisyen: henüz seçilmedi. Açılan etkinlik: `Cuma Falan`. Kullanıcının ekranında bu etkinlik sona ermiş görünüyor. Gidiyorum/Düşünüyorum kontrolleri için henüz sona ermemiş bir etkinlik seçilmeli.

### M1 — Keşfet ve ilk tercih — KISMEN DOĞRULANDI, DURAKLADI

- Dinleyicide Keşfet'e gir. Gerçek klavyeyle konumu seç, gerekiyorsa tarihi değiştir ve etkinliği aç.
- Telefonun geri hareketiyle sonuçlara dön. Seçili konum/tarih korunmalı, tek alt menü bulunmalı. Masa balonunu açıp geri dönmek yanlış sayfaya veya giriş ekranına atmamalı.
- Etkinliğe tekrar girip Gidiyorum seç. Alt bildirim kesilmeden okunmalı, Profilinde paylaş eylemi erişilebilir olmalı. Klavye/geri hareketi ve bildirim geçişinde kırmızı hata veya donma olmamalı.
- Yorum denetimi sonrası eklenen kısa kontrol: Aynı etkinliğe dinleyiciyle bir yorum gönder. Fotoğraf varsa kendi profilindekiyle eşleşmeli, yoksa yer tutucu düzgün olmalı. İsim/fotoğrafına dokununca kendi profilin açılmalı. Geri dönüp aynı etkinlikte devam et.
- Bildirim kapanırsa seçili Gidiyorum düğmesine tekrar dokunup küçük menüden Profilinde paylaş'a geç. Ek bir seçim özeti satırı veya eski geniş seçim paneli aranmamalı.

Bu grubun amacı cihazdaki doğal gezinme ve gerçek kayıt isteğidir. Tüm konum/tarih filtre kombinasyonları tekrar edilmeyecek.

### M2 — Profil taslağı ve gerçek kalıcılık — BEKLİYOR

- Kendi profilindeki taslak doğru etkinliği göstermeli. Gerçek klavyeyle kısa, Türkçe ve emojili bir açıklama yaz. Alan ve Paylaş düğmesi klavyenin altında erişilemez kalmamalı.
- Uygulamayı zorla kapatmadan kısa süre arka plana alıp geri dön. Yazı korunmalı. Yazı varken sayfadan geri çıkmayı dene ve düzenlemeye devam et. Pencere kapanmalı, sayfa kullanılabilir kalmalı.
- Açıkça Paylaş'a bas. Kendi profilinde tek bir gerçek etkinlik paylaşımı görünmeli. Şimdi uygulamayı kapatıp yeniden aç ve paylaşımın sunucudan geri geldiğini kontrol et.
- Aynı etkinlikte Düşünüyorum'a geçip profile dön. Aynı paylaşım güncellenmeli, ikinci kart oluşmamalı ve açıklama korunmalı.

Burada iki durum için aynı taslak süreci baştan tekrarlanmaz. İlk kayıt, açık yayınlama, durum güncelleme ve yeniden açma tek zincirde kontrol edilir.

### M3 — Başka hesap ve müzisyen geçişi — BEKLİYOR

- Müzisyen hesabıyla dinleyicinin profilini aç. Paylaşım doğru etkinlik/durum/açıklamayla gelmeli. Önceki hesabın özel planları veya açık taslağı görünmemeli.
- Paylaşımdaki Ben de gidiyorum yoluyla aynı etkinlik için müzisyen tercihini kaydet. Etkinlik detayına geçince aynı kişisel tercih görünmeli. Müzisyende profilinde paylaş eylemi bulunmamalı.
- Git → Keşfet ve geri dönüşü bir kez kullan. Dinleyici alt menüsüne veya başka kişinin yönetim profiline düşmemeli.
- Aynı etkinliğin yorumlarında dinleyicinin doğru kimliğini gör. Müzisyenle yanıt gönderip kendi profil fotoğrafını kontrol et, ardından yalnız kendi yanıtını sil. Mevcut bir ses/video içeriğinde yorum alanını ve klavyeyi bir kez açıp geri kapat. Uygun içerik yoksa son kontrol yapılmadı diye kaydet.

Bu adımlar bütün yetki testlerini tekrarlamaz. Gerçek hesap değişimi, uygulama yönlendirmesi ve sunucudaki iki farklı kişinin kaydının ayrılığı birlikte görülür.

### M4 — Gerçek bağlantı kesintisi ve toparlanma — BEKLİYOR

- Dinleyiciye dönüp kendi paylaşımını düzenleme taslağını aç. Kısa bir açıklama değişikliği yap.
- Yalnız test telefonunun internetini kesip Paylaş'a bas. Sonsuz yükleme veya sahte başarı olmamalı. Sonucun doğrulanamadığı anlaşılmalı, yazdığın açıklama korunmalı.
- Bağlantıyı geri aç. Sunucudaki güncel durumu kontrol etme yönlendirmesini kullan. Gerekiyorsa bir kez açıkça Paylaş'a bas. Profili yeniden açınca tek paylaşım ve doğrulanmış son açıklama görünmeli.

Yanıt kaybı/zaman aşımı kombinasyonları otomatik testlerde vardır. Cihazda tek gerçek kesinti yeterlidir. Testte gelen bildirim metni ve ekranda kalan yazı kayda alınır.

### M5 — WhatsApp / Instagram teslimi ve geri dönüş — BEKLİYOR

- Etkinliğin paylaşım önizlemesini aç. WhatsApp'ta kendi test sohbetine veya gönderim önizlemesine geç. Görsel açılmalı, bozuk/boş dosya olmamalı, logo ve etkinlik bilgisi kırpılmamalı. Yayın öncesi mağaza yer tutucusu bilinçli olarak kalır.
- Instagram kuruluysa hikaye düzenleyicisini aç. Gerçekten paylaşmak zorunlu değil. Görsel okunur olmalı. İptal edip SoundConnect'e dönünce sayfa donmamalı, boş perde kalmamalı, tercih değişmemeli.
- Hedef uygulama kurulu değilse bu hedefin cihaz kontrolü YAPILAMADI olarak not edilir, geçmiş sayılmaz. Mevcut sistem paylaşım seçicisiyle geri dönüş ayrıca gözlenebilir.

iOS test cihazı yoksa iOS paylaşımı doğrulandı denmez. iOS işletim sistemi teslimi yayın öncesi gerçek cihazda ayrı kontrol edilmelidir.

## İlerleme kaydı

Kullanıcı son manuel akışa başladı. Keşfet'te konum/tarih seçimi, etkinliği açıp telefonun geri hareketiyle sonuçlara dönme ve seçili konum/tarihin korunması kullanıcı tarafından doğrulandı. Masa balonu, Gidiyorum/Düşünüyorum, profil paylaşımı ve sonraki kontroller henüz yapılmadı.

`Cuma Falan` yorum ekranında tasarım ve yeni yorumun üç saat eski görünmesi sorunu görüldüğü için akış burada durakladı. Ekranda `Bu etkinlik sona erdi.` yazıyor. Sonraki katılım kontrolünde bu bitmiş etkinlik kullanılmayacak. Yorum görünümü kompakt ortak bileşene taşındı ve UTC saat hatası düzeltildi. Türkiye saat dilimi kontrolü açık son pakette 3.299 Flutter testi ve 153 ilgili backend testi geçti. Şimdi kaynak güncellemesi sonrasında aynı sayfadaki yeni görünüm ve bir yeni yorumun `Az önce` zamanı cihazda doğrulanacak. Bu bulgu, otomatik kontrolün gerçek cihaz kontrolünün yerine geçmediğini gösterdi.

9 Eylül görünüm revizyonu: Kullanıcı kompakt etkinlik yorum görünümünü beğenmedi ve yeni referans verdi. Yalnız etkinlik detayında sona erme kartı, yorum başlığı/sayacı, yorum kartı ve giriş alanı referansa uyarlandı. Gönderme düğmesi ve UTC düzeltmesi korundu. Son tam Flutter paketi 3.310 test geçti, statik analiz temiz. Bu tur backend değişmedi. Cihazda tasarım henüz kullanıcı tarafından onaylanmadı, M1 aynı yerde duruyor. Önceden tercih yapılmamış sona ermiş etkinlikte Gidiyorum/Düşünüyorum düğmelerinin gizlenmesi mevcut doğru davranıştır. Tasarım onayından sonra yeni katılım kontrolü henüz bitmemiş etkinlikle sürdürülecek.

Sonraki kullanıcı kontrolü: Ana referans tasarımı onaylandı. Kullanıcının 9 Eylül tarihli ekranında Gidiyorum/Düşünüyorum düğmeleri, `@berna` fotoğraflı ana yorum ve yanıt görünüyordu. Yalnız yanıtlar kompakt ve açılır/kapanır hale getirildi. M1 bu küçük görünüm kontrolünde duruyor. Sıradaki kısa cihaz kontrolü aynı yorumda Yanıtları göster/gizle hareketidir. 400 kayıtlık sayfalama, tekrar eden kayıt, hata/sayfa tekrarı ve geciken cevap senaryoları otomatik doğrulandığından yüzlerce hesap veya elle yüzlerce yorum oluşturulmayacak. Katılım tercihi ve profil taslağı henüz manuel geçti sayılmadı.

Son yanıt revizyonu: 3.337 Flutter testi, 75 ilgili backend testi geçti. Tam Flutter statik analizi temiz. Ayrıntılar ve bu sonuçların yük/kapasite testi anlamına gelmediği sınırı [CommentAudit.md](CommentAudit.md) içinde kayıtlıdır.

Yorum denetiminde kısa cihaz kontrolleri M1/M3'e eklendi. Ayrıntılar [CommentAudit.md](CommentAudit.md) belgesinde. Kullanıcı, her yorumdan sonra bekleme yerine aynı içeriğe hızlı gönderim korumasını onayladı ve uygulama tamamlandı. Kota sınırı, süre ve eşzamanlılık otomatik testte kontrol edildi, aynı spam senaryosunu elle yeniden yaptırmayacağız. Hızlı gönderim koruması revizyonunda 3.256 Flutter testi ve 143 ilgili backend testi geçti, tam statik analiz temizdi. Bunlar o revizyonun sonuçlarıdır, önceki/sonraki çalıştırmalarla toplanmaz. Yeni yorum saat/görünüm düzeltmesinin doğrulaması yorum denetimi belgesine ayrıca kaydedilir.

| Adım | Sonuç | Kullanıcı gözlemi |
| --- | --- | --- |
| Hazırlık | DEVAM EDİYOR | Keşfet açıldı. Katılım testi için sona ermemiş etkinlik seçimi gerekiyor |
| M1 | KISMEN DOĞRULANDI | Konum/tarih korunarak etkinlikten sonuçlara dönüş geçti. Yorum saat/görünüm düzeltmesinde durakladı |
| M2 | BEKLİYOR | — |
| M3 | BEKLİYOR | — |
| M4 | BEKLİYOR | — |
| M5 | BEKLİYOR | — |

Yalnız kullanıcının gerçekten doğruladığı adım GEÇTİ yapılır. Varsayım veya otomatik test sonucu manuel geçiş sayılmaz.
