# SoundConnect — Dinleyici erişim sınırları ve oturum kapanışı, 14 Eylül 2026

Sonraki stüdyo akışı uygulaması ve güncel kaynak/doğrulama durumu
`session-handoff-20260914-studio-feed.md` belgesindedir; yeni oturum önce onu okumalı.
Aşağıdaki kapanış ve APK/JAR kayıtları dinleyici sınırları oturumunun tarihsel
durumudur. Stüdyo belgesinin son dağıtım kaydı, daha sonra güncellenen normal
API ve emülatör APK'sını ayrıca açıklar; bu fiziksel telefon kapanışıyla karıştırma.

Yeni oturum önce bu belgenin tamamını okumalı. Önceki tasarım ve altyapı kararları
`session-handoff-20260913.md`, ayrıntılı kronoloji `session-handoff-20260914.md`
belgesindedir. Eski belgenin ara kayıtlarındaki APK/DB/Git durumları tarihseldir;
bu belgenin son kapanış durumu esas alınmalıdır.

## Tamamlanan işler

Önceki OTP/giriş, müzisyen, mekân ve dinleyici akışları korundu. Bu oturumda
stüdyoyu konuşmadan önce mevcut üç akışın kod kalitesi incelendi ve doğrulanan
eksikler kapatıldı:

- Akış yenilemesiyle çakışan başarılı beğeni/kaydetme, geç cevapla geri alınmaz.
- Yorum toplamı sayfada görülen öğelerden değil, yetkilendirilmiş ortak count
  endpoint'inden gelir; kök yorumlar ve yanıtlar doğru sayılır.
- Sayfalama sırasında aynı içeriğin farklı kartlarında yorum sayacı ayrışmaz.
- Geçici organik kaynak hatası kalıcı boş/son sayfa replay'ine dönüşmez; aynı
  cursor ile tekrar deneme korunur.

Ardından dinleyicinin business modüllerine erişimi denetlendi. Kullanıcı stüdyo
profili istisnasını kaldırdı; stüdyo profili ve oda rezervasyonu da dinleyiciye
kapatıldı. Stüdyo/Collab erişimi uygulama çapında tekrar tarandı ve ek açıklar
düzeltildi:

- Stüdyo profil, oda/ekipman, müsaitlik/takvim, rezervasyon, yönetim ve medyası
  dinleyiciye açılmaz. Generic medya/sahiplik yolları da listener veto eder.
- Collab keşif/detay, ilan oluşturma/düzenleme, başvurular, kaydedilenler, işler,
  aktör seçimi/yorumları ve yönetim girişleri dinleyiciye kapalıdır.
- Doğrudan route/widget, paylaşım bağlantısı, DM, masa, Overthinking, avatar,
  yorum/beğeni ve bildirim yönlendirmeleri aynı sınırdan geçer.
- Açık stüdyo ve Collab sayfa/dialog/sheet'leri hesap dinleyiciye döndüğünde eski
  veriyi kaldırır. Collab, açılış ile ilk frame arasındaki hesap değişimini de
  yakalar; aynı hesabın token yenilemesi mevcut formu/scroll'u bozmaz.
- Karma LISTENER+business/yönetici yetkisinde dinleyici vetosu önceliklidir.
  Collab'ın 23 ana, 2 aktör ve 2 moderasyon servis girişi ayrıca güncel DB rolü,
  kişisel profil eşleşmesi ve gerekli moderasyon iznini doğrular.
- Business bildirimler liste/realtime/rozet ve sunucu teslimatında süzülür.
  Eski kayıtlar depoda kalır; dinleyici liste/sayacına yansımaz. Geç cevap ve
  eski startup'ın yeni hesap bağlantısını bozması da engellendi.
- Kapanmış stüdyo Spotify penceresine dönen geç cevap veya bekleyen debounce,
  kaldırılmış widget'a işlem yapmaz.

## Onaylanan ürün davranışı

Dinleyici müzik, performans, halka açık etkinlikler ve uygun sosyal paylaşımları
görür; stüdyo, Collab ve BACKSTAGE iş birliği içeriklerini görmez. Mevcut tasarım,
Mainstage alt barı, arama, ortak yorum/beğeni ve gerçek detay yönlendirmeleri
korunur. Mevcut altyapı önce taranmalı; aynı iş yeniden yazılmamalıdır.

Sosyal bir yüzeyde stüdyo avatarı/userId bulunabilir. Dinleyici profile dokununca
profil verisi yerine **“Stüdyolar Backstage’de”** bilgi ekranı açılır.

Üst metin:
> Stüdyolar, SoundConnect’in iş birliği tarafında yer alıyor. Stüdyo profilleri ve
> SoundConnect’in sunduğu diğer iş birliği akışları dinleyici hesabına açık değil.

Alt metin:
> Sen de müzik sektörünün bir parçasıysan, sana uygun farklı bir hesap oluşturarak
> iş birliği akışlarına katılabilirsin.

Ana düğme **Geri dön**: mevcut route pop edilir, geldiği DM/masa/Overthinking veya
diğer sayfaya döner. Yalnız geçmişi olmayan kök girişte mevcut oturum başlangıç
rotası kullanılır. Keşfet'e zorunlu yönlendirme, çıkış veya hesap dönüşümü yoktur.

## Kullanıcının kabul ettiği sınırlar

- Bio/yorum/mesaj gibi serbest metinlerde iş ifadeleri görünmesi kabul edildi;
  semantik içerik sınıflandırması yapılmayacak.
- Önceden bilinen PUBLIC dosya/CDN adresinin açılması kabul edildi; storage
  dönüşümü veya URL iptali kapsam dışı.
- Setlist PDF bulgusu kullanıcı kararıyla kapsam dışında kaldı ve düzeltilmedi.
  Stüdyo/Collab erişim kapanışı, bu ayrı bulgunun çözüldüğü anlamına gelmez.
- Kimliksiz gerçek guest'in public API sözleşmesi korunur. Oturumlu uygulama
  audience-aware kaynaklara JWT gönderir; geçersiz Bearer guest'e düşürülmez.
- Dinleyici güvencesi etkin oturum/sunucu kimliğinde ROLE_LISTENER bulunan hesap
  içindir; karma rol olsa da reddedilir. Her bozuk DB kaydı uygulama genelinde
  yeniden sınıflandırılmış sayılmaz.

## Otomatik doğrulama

- Son tek tam Flutter koşusu: **5.001 geçti, 0 hata, 2 isteğe bağlı PNG atlaması**.
- `flutter analyze --no-pub lib test`: **No issues found**.
- Son ilgili backend regresyonu: **83 test paketinde 711 geçti**, hata/atlama yok.
  Bu tüm backend deposu veya üretim yük testi değildir.
- Bu oturumun önceki akış düzeltmesi aşamasında 4.941 Flutter ve ilgili 698 backend
  testi geçmişti. Önceki ve sonraki paket sayıları toplanarak yeni toplam üretilmez.
- Son denetim kaynakları 73 frontend / 61 backend değişmiş kaynak-test dosyası
  SHA-256 kaydıyla doğrulandı; kaynak ve dosya kümesi farkı yok.

Kanıt dizinleri workspace `.local-verification/` altındadır:
`feed-professional-fixes-20260914/`, `listener-studio-closure-20260914/`,
`studio-listener-back-copy-20260914/`, `listener-studio-collab-audit-20260914/`.
Sonuncunun `report.md` ve `verification-manifest.json` dosyaları ayrıntılı son
denetimi içerir. İzole Testcontainers testleri gerçek uygulama hesabını kullanmaz.

## Sıradaki konu

**STÜDYO AKIŞININ ÜRÜN MANTIĞI VE İÇERİK DENGESİ.** Henüz uygulanmadı;
önce kullanıcıyla konuşulacak. Var olan stüdyo profil/oda/backline altyapısıyla
henüz tasarlanmayan stüdyo akışı birbirine karıştırılmamalı. Tamamlanan işler
baştan yapılmamalı; gerçek DB'ye mock içerik eklenmemeli.

## Güncel cihaz ve backend kapanışı

Kullanıcının “güncelle ve oturum özeti/yeni oturum promptu ver” isteğiyle normal
`lib/main.dart` debug APK yeniden üretildi ve Vivo V2206 / Android 14 telefona
kuruldu. Önizleme/mock giriş noktası kullanılmadı.

- Cihaz seri: `10GCA400GT0001N`.
- Paket: `com.berkayb.soundconnect.soundconnect_23_12_25codx`.
- `adb install -r`: **Success**, 14 Eylül 17:50. `appId=10511` ve ilk kurulum
  zamanı `2026-09-13 16:43:24` korundu. Uninstall/clear-data yapılmadı.
- APK: frontend `build/normal/soundconnect-debug.apk`.
- APK SHA-256: `da78261f8d5c61a4eec9b92229a27746f6df190fb5f5bcb649af079ee8b78203`.
- Normal backend API ve media-worker JAR paketleri başarıyla üretildi.
  Worker süreci ayrıca başlatılmadı.
- Güncel API son PID `433068`, `http://127.0.0.1:8080` readiness **UP**.
  Başlangıçta çalışan IntelliJ API PID `390100` doğrulanıp graceful kapatıldı.
  Güncel API açık bırakıldı; portu kontrol etmeden ikinci backend başlatma.
- Docker PostgreSQL/Redis/RabbitMQ aynı sağlıklı servisler olarak korundu.
  Bu tur yeni migration yok; API `ddl-auto=validate` ve seed'ler kapalı açıldı.
  DB reset/restore, mock içerik veya manuel hesap/içerik değişikliği yapılmadı.
- USB reverse 8080 bağlantısı korundu. Telefonun ekran açık tutma ayarı
  değiştirilmedi; başlangıç değeri 0.

### İlk başlatma hatası ve son başarılı dinleyici girişi

Kurulum öncesinde eski belgedeki berna dinleyici hesabı değil, **qwe owner
profili / Backstage oturumu** açıktı. APK aynı veri alanına kuruldu; fakat ilk
backend JAR başlatmasında yerel ayarların process environment'a aktarılması
eksik bırakıldı. Shell'den gelen JWT secret, `.env.local` değerini bastırdı.
17:54:51'de altı `Invalid JWT token` / SignatureException kaydı oluştu; uygulama
401 cevabıyla kayıtlı oturumu temizleyip giriş ekranına döndü.

Bu, güncelleme sırasında yapılan bir operasyon hatasıdır; kullanıcıya açıkça
bildirildi. Eski IDE sürecinin exact secret değeri/kaynağı ayrıca kanıtlanmadı.
APK/veri silme veya hesap silme işlemi değildir, fakat **yeniden giriş gerekti**.
Token üretme, kimlik doğrulamayı atlama veya şifreye erişme yapılmadı.

Backend yeniden, `scripts/dev.ps1` içindeki `Import-DotEnv` ile aynı davranışla
`.env.local` yüklenerek açıldı. Çalışan JVM'nin environment ve Spring resolved JWT
ayarlarının yerel dosyayla eşitliği yalnız boolean sonuçla doğrulandı; secret
değerleri çıktıya yazılmadı. Son PID `433068` bu düzeltilmiş süreçtir.
Gelecek çalışmalarda yalnız Spring config import'una güvenip inherited process
environment'ı atlama; mevcut geliştirme başlatma sözleşmesini koru.

Kullanıcı daha sonra kendisi **mmelikeunal dinleyici hesabıyla** giriş yaptı.
Doğru backend ayarıyla **6 temel gerçek cihaz kontrolü geçti**:

1. Mevcut dinleyici profili yüklendi; hesap adı ve dinleyici türü doğrulandı.
2. Beşli Mainstage alt barı ve profil menüsü korundu; business girişleri yoktu.
3. Profil menüsünden gerçek akış açıldı; müzisyen ve mekân önerileri geldi.
4. Desteklenen `soundconnect://is-birligi/ilan/{uuid}` bağlantısı mevcut profil
   sayfasını koruyup “Bu ilanı müzisyen, mekan veya stüdyo hesabıyla
   görüntüleyebilirsin.” uyarısıyla reddedildi. Sadece geçerli biçimde bir test
   UUID'si kullanıldı; gerçek ilan veya başvuru oluşturulmadı.
5. Arama yüzeyi dinleyiciye uygun müzisyen/dinleyici/grup/mekân kapsamıyla açıldı.
6. Tam kapatma ve yeniden açmadan sonra aynı mmelikeunal dinleyici profili ve
   oturumu geri geldi; tekrar giriş gerekmedi.

Son API readiness UP; düzeltilmiş API günlüğünde JWT uyarısı ve ERROR satırı 0.
Telefon yeni APK üzerinde mmelikeunal profilinde, backend açık bırakıldı.
İlk qwe oturumunun kurulum boyunca korunduğu iddia edilmez; **kullanıcının yeni
dinleyici girişi son soğuk açılışta korundu**. Eski “berna / 16 kontrol” kaydı
önceki sabah kapanışına aittir.

Bu cihaz turunda stüdyo profil bilgi ekranı için doğal bir giriş kullanılmadı;
stüdyo dış deep-link formatı zaten yoktur. Stüdyo kapısı, geri dönüş/ölçek ve
diğer Collab/API/karma-rol senaryolarının kapsamlı doğrulaması otomatik testlerdir.
Aramada gerçek sonuç sorgusu, çok sayfalı akış, medya oynatma, mesaj, rezervasyon,
beğeni/yorum yazma bu turda test edilmedi. Normal akış okuması doğal gösterim
telemetrisi oluşturabilir; gerçek DB'ye mock içerik eklenmedi.

Kanıtlar workspace
`.local-verification/session-close-listener-boundaries-20260914/` altında:
APK build/install/hash ve paket bilgileri; kurulum öncesi qwe ve sonraki giriş
ekranı PNG/XML'leri; backend paket/launch/readiness/state ve runtime-config
doğrulaması; `tested-source-and-git-state.json`. Kaynak kodu dağıtım sırasında
değişmedi; 73 frontend / 61 backend test edilen dosya hash'i hâlâ eşleşir.
Yeni giriş ve başarılı kontroller `04`–`10` numaralı cihaz kanıtlarında,
`device-validation.json` ve `final-runtime-state.json` dosyalarında kayıtlıdır.

## Git'te bırakılan durum

Her iki repo **feature/local-simulation** dalında:

- Frontend HEAD: `47d3079`.
- Backend HEAD: `1ec3fa2`.

Bu oturumun akış/erişim düzeltmeleri ve belgeleri çalışma ağaçlarındadır;
**henüz commit/push edilmedi, çalışma ağaçları temiz değildir**. Güncel kurulan
APK/JAR bu değişiklikleri içerir. Önceki kullanıcı değişiklikleri korundu.
Yeni oturum gerçek Git durumunu kontrol etmeli, mevcut işleri silmemeli veya
tamamlanmamış sanıp yeniden uygulamamalıdır. Yerel APK/log/ekran görüntüsü ve
geçici doğrulama dosyaları Git'e alınmamalıdır.
