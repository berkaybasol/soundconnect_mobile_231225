# Canlı kabul otomasyonu

Bu araçlar çalışan yerel backend'e gerçek HTTP istekleri gönderir. Normal unit/widget testlerini tamamlar; mock cevap kullanmaz. Emülatör akışları ayrı scriptlerdir. Başarılı API kontrolleri bütün manuel senaryoların geçtiği anlamına gelmez.

## API paketini çalıştırma

Python 3.10+ ve çalışan yerel backend gerekir. Üç ayrı test rolü kullanılmalıdır: müzisyen, dinleyici ve mekan sahibi. Mekan hesabının erişebildiği bir mekan; müzisyenin geçici grup oluşturabilmesi için üç grupluk kotasında boş yer bulunmalıdır. Python için ek paket gerekmez.

Hesap bilgilerini çalıştıracağın terminalin ortamına tanımla:

| Değişken | İçerik |
| --- | --- |
| `SC_TEST_MUSICIAN_USERNAME` | Test müzisyeni |
| `SC_TEST_LISTENER_USERNAME` | Test dinleyicisi |
| `SC_TEST_VENUE_USERNAME` | Test mekan sahibi |
| `SC_TEST_PASSWORD` | Ortak test şifresi |

Şifreler farklıysa ortak değişken yerine `SC_TEST_MUSICIAN_PASSWORD`, `SC_TEST_LISTENER_PASSWORD`, `SC_TEST_VENUE_PASSWORD` kullanılır. Şifre/token raporlara veya kaynak dosyalara yazılmaz.

```powershell
.\tools\live_acceptance\run_api_acceptance.ps1
```

Python PATH'te değilse çalıştırılabilir dosyanın tam yolunu `-PythonCommand` ile ver. Parametre bir çalıştırılabilir dosyadır; Python komut satırı seçenekleri içermez.

```powershell
.\tools\live_acceptance\run_api_acceptance.ps1 `
  -PythonCommand 'C:\Python313\python.exe' `
  -BaseUrl 'http://127.0.0.1:8080' `
  -OutputDirectory '..\.local-verification\live-acceptance'
```

Paket yalnız loopback HTTP adresi kabul eder. Birden fazla mekan varsa `-VenueId` ile seç. Ayrık alan eşzamanlılık kontrolünü 1–20 kez tekrarlamak için `-ConcurrencyRepetitions` kullanabilirsin; varsayılan 1'dir.

Aşamalar sırayla çalışır:

1. Üç hesabın giriş/rol ve profil cevapları; müzisyen/mekan açıklama ve bağlantılarının geçici güncellenmesi, doğrulama, eşzamanlılık ve geri yükleme.
2. Yeni geçici etkinlik; gerçek beğeni/yorum/yanıt ve rol kontrolleri; etkinliğin ve etkileşimlerin temizlenmesi. Paket `--keep-event` kullanmaz.
3. Yeni benzersiz `AUTOQA-Band-...` grubu; oluşturma, tekrar isteği, alan koruma/boşaltma, link normalizasyonu, yalnız harf büyüklüğüyle yeniden adlandırma, girdi reddi, yetkisiz değişiklik reddi ve silme.

Profil adımı mevcut test profilinin yalnız ilgili açıklama/link alanlarını geçici değiştirir ve `finally` içinde geri yükler. Başlangıçta `null` olan boş alanlar API sözleşmesi nedeniyle boş metin olarak geri yüklenebilir; bu fark raporda belirtilir. Listener mock verileri değiştirilmez. Grup adımı mevcut grupları düzenlemez. Aynı hesapları değiştiren UI testi veya ikinci API paketiyle eşzamanlı çalıştırma.

## Kanıt ve hata sonucu

Varsayılan çıktı frontend reposunun dışındaki `../.local-verification/live-acceptance/<çalıştırma-id>/` dizinine yazılır. Alternatif çıktı konumunu `-OutputDirectory` belirler. Her aşamanın JSON raporu ve logu ayrıdır; `suite-results.json` bunları birleştirir. Tokenlar saklanmaz; profil geri yükleme dosyaları test profilinin önceki alanlarını içerir ve kaynak kontrolüne eklenmemelidir.

Bir aşama hata verse de diğer aşamaların sonucu kaydedilir. Eksik/bozuk rapor, başarısız temizleme, atlanan kontrol veya sıfırdan farklı süreç çıkışı paket için başarılı sayılmaz; PowerShell çıkış kodu 1 olur. Rapordaki kontrol sayısı assertion sayısıdır; tekrarlanan giriş/ön koşullar bulunabilir ve benzersiz manuel senaryo sayısı değildir.

Tam paket sekiz giriş isteği gönderir. Arka arkaya çalıştırmalar veya aynı adresi kullanan başka testler auth hız sınırına ulaşabilir. HTTP 429 oluşursa bu çalıştırma başarısız/eksik kaydedilir; ilgili hız sınırı penceresi dolduktan sonra yeniden çalıştır. Hız sınırını kapatmak veya yükseltmek bu paketin parçası değildir.

Geri yükleme yarım kalırsa ilgili aşamanın `*-restore.json` dosyasıyla `live_api_acceptance.py --restore-snapshot <dosya> --output-dir <ayrı-kanıt-dizini>` kullanılabilir. Saklanan geçici etkinliğin temizliği `--cleanup-event <event-fixture.json>` ile yapılır. Bu komutlarda aynı backend, hesaplar ve gerekiyorsa `--venue-id` seçilmelidir. Temizleme sonucunu doğrulamadan kaydı geçti sayma.

## Emülatör/UI kontrolleri ayrı çalışır

### Bağımsız etkinlik paylaşımı yorumları

Güncel backend ve etkinlik `postId` veritabanı geçişi hazırken `python .\tools\live_acceptance\live_event_post_acceptance.py --output-dir ..\.local-verification\event-post-live` çalıştırılabilir. Yalnız mekan/dinleyici ortam değişkenlerini kullanır. Yeni ve benzersiz bir etkinlik oluşturur; etkinlik ve profil paylaşımının ayrı yorum kimliklerini/sayılarını, yetkisiz silme reddini, paylaşım silindikten sonra özel `GOING` planının korunmasını, eski yorumlara erişimin kapanmasını ve yeniden paylaşımda yeni kimlik/boş yorum akışını doğrular. Mevcut etkinlik/paylaşımları değiştirmez; genel API paketi bu scripti kendiliğinden başlatmaz.

Her koşu ayrı sonuç ve `*-event-post-fixture.json` kaydı üretir. `finally` içinde önce kendi yorumlarını, sonra paylaşımı ve özel planı, son olarak geçici etkinliği temizler. Temizlik başarısızsa koşu başarısızdır; aynı hesaplarla `live_event_post_acceptance.py --cleanup-snapshot <fixture-dosyası> --output-dir <ayrı-kanıt-dizini>` yalnız o koşunun temizliğini tekrarlar. Araç yalnız loopback HTTP adreslerini kabul eder ve HTTP yönlendirmelerini izlemez. Önceki sürüm backend üzerinde çalıştırılmamalıdır; UI görünümü ayrıca doğrulanır.

Paket ayrıca paylaşım oluşturmadan `NONE → GOING → NONE` katılım geçişini ve yayımlanmış paylaşımda `GOING ↔ THINKING`, Unicode açıklama kaydı/temizleme işlemlerini doğrular. Düzenleme sonrası sürümün ilerlemesi, aynı `postId` ile yorumların ve iki hesabın beğenilerinin korunması gerçek HTTP okumalarıyla kontrol edilir.

`android_ui.py`, `ui_profile_acceptance.py` ve `ui_navigation_acceptance.py` gerçek Android ekranlarına dokunur ve ekran/XML kanıtı toplar. API paketi bunları otomatik başlatmaz veya hesap değiştirmez.

- Android SDK `adb` erişilebilir, emülatör açık ve güncel uygulama kurulu olmalıdır.
- Profil scripti için uygulamada test müzisyeni açık olmalıdır; HTTP giriş yapmak uygulamanın oturumunu değiştirmez.
- Gezinme scripti için test dinleyicisi açık, seçilen sanatçılı etkinlik keşfedilebilir, kendisine verilen geçici etkinlik kaydı hâlâ mevcut olmalıdır. Güncel seçenekler scriptin `--help` çıktısındadır.
- UI adımlarıyla aynı hesapları düzenleyen API adımları sırayla yürütülmelidir; otomasyon sırasında ekrana elle dokunulmamalıdır.

API kanıtı form çizimini, klavyeyi, onay diyaloğunu, geri tuşu/route yarışını, native galeri/paylaşımı veya gerçek telefonun ses çıkışını doğrulamaz. Bunlar ilgili UI/cihaz kanıtıyla kapanır; bu araçlar 27 manuel senaryonun tamamını kapattığını iddia etmez.

### Profil UI komutu

Windows sürücüsü `%LOCALAPPDATA%/Android/Sdk/platform-tools/adb.exe` kullanır ve fiziksel cihaz seri numarasını reddeder. Varsayılan hedef `emulator-5554`; profil testinde `SC_EMULATOR_SERIAL`, gezinmede `--serial` ile başka emülatör seçilebilir. Doğrulanan ekran 1280×2856'dır; özellikle kaydırma farklı ekran düzenlerinde uyarlanabilir. Metin girişi ASCII kabul işaretleriyle çalışır; Unicode klavye kabulü sayılmaz.

```powershell
$env:SC_ACCEPTANCE_OUTPUT = [IO.Path]::GetFullPath('..\.local-verification\live-ui')
$env:SC_UI_USERNAME = $env:SC_TEST_MUSICIAN_USERNAME
# Ortak SC_TEST_PASSWORD tanımlı, uygulamada aynı müzisyen açık olmalı.
python .\tools\live_acceptance\ui_profile_acceptance.py
```

Uygulama giriş ekranındaysa önce `python .\tools\live_acceptance\android_ui.py login` gerçek iki alanı doldurup giriş düğmesine dokunur. Başka hesap açıksa uygulamadan çıkış yapıp bu komutu kullan. Scriptler başka açık hesabı otomatik değiştirmez. Profil koşusu açıklamayı UI'dan kaydeder, Android uygulama sürecini tamamen kapatıp açar, sonra başlangıç açıklamasını UI'dan geri yükler; API geri okumasıyla doğrular. Kurtarma gerektiğinde yalnız bu koşunun işaretini geri alır; farklı bir sonraki değişikliği ezmez.

### Dinleyici gezinme komutu

Önce dinleyiciyle giriş yapılır (`SC_UI_USERNAME` dinleyici olmalıdır). Ardından aynı mekânda bugün veya yarın görünen, müzisyene bağlı mevcut bir etkinlik kimliği seçilir. `live_api_acceptance.py --accounts venue listener --disposable-event --keep-event --output-dir <kanıt-dizini>` ayrı bir sanatçısız etkinlik, silinmiş ana yorum ve korunan yanıt oluşturur. Komutun ürettiği `*-event-fixture.json` dosyası kullanılır:

```powershell
python .\tools\live_acceptance\ui_navigation_acceptance.py `
  --artist-event-id <mevcut-sanatcili-etkinlik-uuid> `
  --fixture <etkinlik-fixture-json-dosyasi>
```

Gerçek keşif → etkinlik → müzisyen → mekan → mekan takvimi → sanatçısız etkinlik → yanıt → kendi profilim yolu izlenir. Beş dinleyici sekmesi, doğru profil kimlikleri ve silinen yorumun altındaki yanıt kontrol edilir. Bittiğinde, UI sonucu başarısız olsa da, `live_api_acceptance.py --accounts venue listener --cleanup-event <etkinlik-fixture-json-dosyasi> --output-dir <ayri-temizlik-dizini>` çalıştırılır. Silinmiş fixture tekrar kullanılamaz.

Hızlı peş peşe paketleri çalıştırmak gerçek giriş hız sınırına takılabilir; HTTP 429 başarısız/eksik koşu olarak raporlanır. Sınırı değiştirmeden pencerenin dolmasını bekleyip yeni koşu başlat. JSON sonuçları benzersiz koşu kimliği taşır; eski PASS yeni bir başarısız koşunun yerine kullanılmaz.
