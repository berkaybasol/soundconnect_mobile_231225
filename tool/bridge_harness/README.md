# İzole native bridge harness

5 Ekim 2026: BIL-001 güvenli test zemini, BIL-003 oturum regresyonları ve
BIL-007 Overthinking gerçek kart/intent kapısı.
Ürün `tr.com.soundconnect.app` ve preview bu harness'ın hedefi değildir.
Test çifti yalnız `tr.com.soundconnect.app.warmtest` ve `.warmtest.test` olur.
Fiziksel cihaz varsayılan olarak reddedilir; Vivo açık görev kapsamı ve canlı
exact seçimle çalışır. JSON/argüman insan onayı yaratmaz. Eski emulator/cihazsız
izin fiziksele veya eski kaldırma izni yeni veri kaybına genişletilmez.

## Derleme

Mevcut SDK/JBR ve offline Gradle kullanılır; SDK/cache/ACL değiştirilmez.
`JAVA_HOME` mevcut Android Studio JBR'ını göstermelidir. Cwd frontend/android:

```powershell
$PushDefine = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('SOUNDCONNECT_PUSH_ENABLED=true'))
$HarnessArgs = @('-PsoundconnectBridgeHarness=true',
  '-Ptarget=integration_test/native_push_bridge_harness.dart',
  "-Pdart-defines=$PushDefine", '-Ptarget-platform=android-arm64',
  '--offline', '--no-daemon', '--console=plain')
./gradlew.bat -I ../tool/native-tests.gradle :app:testDebugUnitTest @HarnessArgs
./gradlew.bat :app:compileDebugKotlin :app:compileDebugAndroidTestKotlin @HarnessArgs
./gradlew.bat :app:assembleDebug :app:assembleDebugAndroidTest @HarnessArgs
```

Flag ve exact Dart hedefi birlikte, push açık, preview kapalı olmalıdır.
Release/profile ve dolaylı görevleri reddedilir. Firebase init/service/receiver,
launcher/deep-link ve dış provider authority girişleri test manifestinde kapalıdır.
Ürün MainActivity/AudioService/MethodChannel kullanılır. Flutter integration_test
`runner:1.2+` isteği hem ürün hem harness debug graph'ında mevcut `1.7.0` sürümüne
sabitlenir. Normal ürün `lib/main.dart` + harness=false ile ayrı derlenir.

Build çıktıları değişmez kanıt kopyalarına alınır: BIL-007 için yalnız
`tasks/BIL-007/evidence/01-developer-01/apks/`, BIL-003 için
`tasks/BIL-003/evidence/01-developer-01/apks/`, tarihsel BIL-001 için
`tasks/BIL-001/evidence/03-*/apks/`. Mutable `build/` yolundan kurulum reddedilir.
Kaynak/flag/ABI/build komutu/exit ve önce-sonra hash'ler manifestte bağlanır.

## APK, envanter ve Prepare

`verify_apks.ps1` gerçek aapt ile exact ordinal package/runner/target, shared UID
olmaması, debug/backup, harness marker, Firebase izolasyonu, native push kaynağı,
provider authority ve Dart kernel'i denetler. Okunan kimlik normalize edilmez;
REJECTED çıktısı beklenen kimliği gözlenmiş gibi yazmaz. ADB çağırmaz.

`run_vivo.ps1` PowerShell 7 ister. Prepare varsayılandır ve ADB çağırmaz.
Gerçek verifier'a ek olarak apksigner JAR'ını mevcut JBR ile çalıştırır; gerçek
imza doğrulaması ve app/test tek sertifika SHA256 eşliği zorunludur.

```powershell
# Cwd: frontend. Her koşu için yeni EvidenceDirectory.
./tool/bridge_harness/run_vivo.ps1 `
  -Delivery '<BIL-003 sabit kanıt>/delivery-final.json' `
  -Aapt '<SDK>/build-tools/36.0.0/aapt.exe' `
  -ApkSigner '<SDK>/build-tools/36.0.0/lib/apksigner.jar' `
  -EvidenceDirectory '<yeni Prepare kanıt dizini>'
```

Manifest teslimin exact sınıflarını ve hash'i sabit kaynaklarını taşır.
BIL-003: **24 NativePushBridgeLifecycleTest + 26 NativeBridgeFixtureTest = 50**
benzersiz test, **24 durable cleanup**. Nested fixture `Probe.body` dış suite
üyesi değildir. Mevcut kaynak biçimindeki dış seviye dört boşluk girintili
`@Test fun` bildirimleri çıkarılır; biçim değişirse çıkarım da gözden geçirilir.
Host kaynak/envanter eşliğini ve ardından runner'ın gerçek exact start/PASS,
numtests, cleanup, sıfır hata/skip ve başarılı final-suite kaydını birlikte ister.
Shell exit 0 veya sıfır test başarı değildir.

BIL-007 yalnız sabit yeni kanıt yolunda üçüncü sınıfı ekler:
**24 lifecycle + 26 fixture + 5 Overthinking = 55**, **29 durable cleanup**.
Eski teslim kendi iki sınıfıyla doğrulanır; yeni sınıf veya duplicate/boş kimlik
eski inventory'ye taşınamaz. `runner_report.ps1` aynı katı parser ve bounded
process yardımcısını Vivo ile hosted runner arasında paylaşır. CRLF içeren
Windows script token'ları POSIX shell'e LF olarak aktarılır.

## Hosted CI ve normal ürün build kapısı

`.github/workflows/quality-gate.yml` mevcut Dart analyze/test/coverage eşiklerini
korur. Ayrı işler tam JVM envanteri, normal ürün push=false/true APK ölçümü ve
warmtest instrumentation çalıştırır. `native_gate.py` kaynak metotlarını (iki
parameterized JVM suite'in invocation'ları dahil) XML ve gerçek start/PASS/final
olaylarıyla eşler; eksik/skip/duplicate/crash başarısızdır. Parser negatifleri
`test_native_gate.py`, `test_runner_report.ps1` ve gerçek APK verifier'ı üzerinden
`test_verify_apks.ps1` ile koşar.

Direct Gradle öncesi Flutter precache/pub get, SDK/local.properties ve Git'te
tutulmayan wrapper launcher/JAR hazırlanır. Wrapper Flutter'ın mevcut artifact
dizininden yalnız eksikse alınır; repo Gradle sürüm properties'i korunur.
Ubuntu JDK21, Android36/build-tools36/NDK28.2 ve android-x64 açıktır.
Normal push=true sentetik config'i yalnız `GITHUB_ACTIONS=true` altında ve
dosya yoksa üretir; gerçek yerel config üzerine yazılmaz. Aapt kaynak tablosundan
yalnız push boolean loglanır. Bu ürün APK'ları build-only'dir ve kurulmaz.

Normal ürün kapısı merged XML'deki MainActivity ile APK xmltree'nin doğrudan
`manifest/application/activity` düğümünü ve badging launch hedefini birlikte
eşler. APK'da tek exact MainActivity ve exported=true gerekir; alias/nested
düğüm, benzer metin veya `Raw` açıklaması birincil attribute yerine geçmez.
`product` çağrısında APK/manifest/aapt/push/output parametreleri zorunludur;
ret halinde nonzero exit ve PASS sonucu yoktur. Gerçek iki ürün metadata
fixture'ı ve bunların sentetik hedef mutasyonları `test_native_gate.py` içinde
aynı parser/CLI üzerinden kontrol edilir; bozuk gerçek APK/telefon testi değildir.

`run_hosted.ps1` yalnız hosted **emulator-5554 / API35 / x86_64 / user0 / qemu1**
kabul eder. Normal/retained prefix envanteri boş olmalıdır. Kaynak inventory'si
14 uyumlu suite'i seçer. `NativePushVivoRecreateAcceptanceTest` ürün kabulüdür;
`PushFeatureGateInstrumentationTest#mergedManifestIncomingRoutesMatchNativeBuildOptIn`
warmtest'te kaldırılmış Firebase bileşenlerini beklediğinden normal iki APK gate'ine
aittir. Dışlama gerekçeleri `native_gate.py` içinde yazılıdır. Sınıf keşfiyle
`connectedAndroidTest` yoktur. Timeout1200 saniye; yalnız bu koşunun kurduğu iki
paket finally içinde ayrı ayrı temizlenir, cleanup hatası başarısızlıktır.

Yerel PC'de emulator açılmaz. Workflow tanımının varlığı hosted başarı değildir;
yerel 55-test Vivo sonucu izole native kabulüdür, ürün FCM/read/görsel onay değildir.

Hosted HTTP transport fixture'ı yalnız `127.0.0.1` üzerinde çalışır. Harness debug
manifesti kendi `bridgeHarness/res` ağ politikasını kullanarak yalnız bu adrese
cleartext izni verir; genel ve dış host trafiği kapalı kalır. Yedi mevcut HTTP
testinin setup'ı bu sınırı Android `NetworkSecurityPolicy` üzerinden doğrular.
Normal ürünün manifesti ve kaynak setleri bu harness kaynağını almaz.

## Vivo, boş kurulum ve veri koruyan güncelleme

Run için Prepare parametrelerine `-Mode Run -Adb ... -Serial ... -AndroidUser 0
-RunId ... -DeviceIdentity ... -AuthorizationRecord ...` eklenir. Cihaz identity
kaydı manufacturer/model/fingerprint/android/abi alanlarını taşır. Host her
komutta exact `-s` kullanır; get-serialno/get-state/current-user ve bütün kimlikleri
canlı eşler. İlk cihazı seçme veya emülatöre fallback yoktur. RunId 1–80 ASCII
harf/rakam/nokta/alt çizgi/tiredir; ilk karakter harf/rakamdır.

Yetki kaydı approved/readyNow boolean'ları, gerçek userMessage/source/recordedAt,
serial/androidUser/runId, son aday appSha256/testSha256 ve beş identity alanını
bağlar. Görevin doğrudan uygulanması yetki kaynağı olabilir; yeni hash'ler teknik
aday eşlemesidir ve eski kullanıcı cevabında varmış gibi gösterilmez.

Owner user0 normal paket listesi ve `pm list packages --user 0 -U
--show-versioncode -u tr.com.soundconnect.app` uzlaştırılır. `-u` retained veriyi,
`-U` UID'yi gösterir. Retained/partial/foreign, okunamayan/duplicate/çelişkili
UID/sürüm, bilinmeyen format ve sorgu hataları mutasyondan önce reddedilir.
Benzer prefix/suffix/harf farkı exact test çifti sayılmaz. App/test ve ürün/preview
UID'leri ayrı olmalıdır. Preexisting process/Activity/kart, recipient/reset veya
atomic kalıntı reddedilir. EmptyState yalnız ölçtüğü native dosyaları kanıtlar;
bütün uygulama verisinin byte eşliği değildir.

İki exact paket iki görünümde de yoksa yalnız `install --user 0 -t` yapılır.
Mevcut çift yeni adaylarla byte/hash eşse yeniden kurulum yapılmaz.
Bilinen önceki çiftin güncellemesi için açık
`-UpgradeFromDelivery '<önceki sabit delivery.json>'` gerekir. Eski manifestin
başarılı harness build kaydı, önce/sonra kaynak hash'leri, eski/yeni APK'ların
hash/manifest/runner ve **eski/yeni signer sertifikası** eşliği zorunludur.
Yetki kaydında dataPreservingUpgrade=true ve previousDeliverySha256 bulunur.
Önceki teslimin provenance okuması iki açık biçimi destekler:

- Legacy BIL-001: `buildCommand` içinde sayısal `exitCode=0`; teslim kökündeki
  `build-sources-before.json` ve `build-sources-after.json`, düz `path/hash` dizisi.
- BIL-003: `buildCommand`, ayrı `buildExit` sonucu ve açık `before`/`after`
  yolları; snapshot içinde `inputs` dizisinin `path/sha256` girdileri. Üç açık
  alan birlikte bulunmalıdır. Command ayrıca exitCode taşıyorsa o da başarılı
  olmalıdır; eksik/bozuk/string/null sonuç başarı sayılmaz.

Kanıt dosyası yolları ait oldukları delivery köküne göre çözülür; o kök içinde
mutlak yol da desteklenir, kök dışına referans reddedilir. Eski kanıtlar veya
tarihsel kaynaklar güncel dosyalarla değiştirilmez. Her önceki manifest kaynağı
iki snapshot'ta da tek path ile aynı SHA256'yı taşımalıdır. Snapshot veya manifest
duplicate path, geçersiz hash, eksik/değişmiş/ambiguous eşleşme ve çelişkili build
argümanı reddedilir. Prepare da aynı önceki-teslim kapısını sıfır ADB çağrısıyla
çalıştırır; `-UpgradeFromDelivery` Prepare örneğine de eklenebilir.

Canlı kurulu çiftin eski hash'leri, ayrı UID ve boş/quiescent state'i doğrulanır.
Yalnız bu iki APK `install --user 0 -r -t` ile güncellenir. Her iki install sonrası
aynı UID'ler, yeni APK hash'leri, runner/target ve boş state doğrulanmadan test
başlamaz. Ürün/preview kimlikleri koşu öncesi/sonrası karşılaştırılır.

İki install atomik değildir: ilk/ikinci hata instrumentation'ı engeller;
tamamlanan adımlar kanıta yazılır. Otomatik retry/repair yoktur; old/new karışık
çift sonraki çağrıda da reddedilir. Genel partial/foreign istisnası açılmaz.
Host uninstall/clear/force-stop veya notification izni değişikliği yapmaz.

Yalnız exact iki sınıf instrumentation ile seçilir; connectedAndroidTest veya
paket keşfi yoktur. Android fixture yalnız edindiği engine/cache/Activity/state'i
temizler; rejected setup unrelated kaynaklara dokunmaz. Emulator-only eski aile
suite'lerinin Vivo kapıları korunur. Emülatör ayrıca yetkiliyse qemu/model ve
exact emulator serial doğrulanır; fiziksele alternatif olarak seçilmez.

ADB okuma 30sn, install 180sn, instrumentation 900sn ile sınırlıdır. Timeout
host sürecini bitirir; cihazın da durduğu varsayılmaz. Hata/cleanup/crash sonrası
otomatik yeniden koşu veya temizleme yapılmaz; sınırlı test-package diagnostic
ve kanıt korunur.

## Regresyon ve kabul ayrımı

```powershell
./tool/bridge_harness/test_verify_apks.ps1 -EvidenceDirectory '<yeni verifier dizini>'
./tool/bridge_harness/test_run_vivo.ps1 -EvidenceDirectory '<yeni host dizini>'
```

Sentetik APK metinleri gerçek verifier'dan, sahte executor vakaları gerçek host
fonksiyonlarından geçer. Başarı kontrolü yanında retained, provenance/signer/UID,
mutasyon öncesi dirty state, ilk/ikinci install hatası, mixed-pair reddi, eksik
start/PASS/cleanup/final ve timeout denetlenir. Cihaz kabulünün yerine geçmez.
`test_run_vivo.ps1 -HostScript <korunmuş eski host>` aynı testleri bir önceki
host kopyasında RED/GREEN karşılaştırmak içindir; ürün host'una bypass eklemez.
Yeni/legacy predecessor Prepare pozitifleri ve build result/snapshot bozulması
vakaları aynı gerçek host fonksiyonlarını çağırır. `upgrade-authorization-manifest-mismatch`
yalnız yetki kaydındaki önceki manifest hash'ini sınar; kaynak provenance testleri
ayrı `provenance-*` vakalarıdır.

45 destekli OPEN_PUSH türünün current/stale/missing/blank/malformed epoch matrisi,
aynı alıcıya rebind sonrası eski intent'in ilk kabulü, cold/warm ve lifecycle,
shortcut tekrar/kimlik mahremiyeti ve pending oturum sınırları ölçülür.
İzole paketin notification izni korunur: kardeş reservation/ledger ve OS snapshot
testi görünür kart üretildiğini iddia etmez. Görünür kart ve kardeş korunumu
normal ürün kabulünde ayrıca doğrulanır. Fixture rebind gerçek auth logout/login
değildir. BIL-003 ürün girişini değiştirdiği için gerçek API/kalıcılık, FCM/kart/tap,
fiziksel ürün ve kullanıcı görsel kabulü ayrı gerekir; BIL-001'in test-only
UYGULANAMAZ gerekçesi bu işe taşınmaz. Fiilî sonuçlar ilgili handoff'tadır.
