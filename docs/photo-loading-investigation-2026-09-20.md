# Fotoğraf gecikmesi ve ilan sahibi avatarı — 20 Eylül 2026

İlk inceleme aşamasında kullanıcının isteğiyle fotoğraf performansında değişiklik yapılmadı; aşağıdaki ölçümler o aşamanın başlangıç değerleridir. Sonraki kullanıcı onayıyla uygulanan iyileştirmeler ve tekrar ölçümleri belgenin sonundadır. Mevcut Android telefon, açık Flutter debug oturumu ve `8080` backend kullanıldı. Test ilanları ve fotoğrafları korundu.

## Ölçüm

Telefonun mevcut Dart HTTP zaman çizelgesi üzerinden gerçek istekler ölçüldü. Başlıklar, tokenlar, imzalı bağlantılar ve içerik gövdeleri rapora/export dosyalarına yazılmadı. Yalnız anonimleştirilmiş istek türleri, süreler, boyutlar ve durum kodları saklandı. Ölçüm sonunda HTTP profiling ayarı önceki değerine döndürüldü.

Telefon bu ölçüm sırasında **mobil veri (CELLULAR)** kullanıyordu. Backend trafiği mevcut telefon bağlantısı üzerinden bilgisayardaki API'ye; fotoğraf trafiği telefondan doğrudan uzak depolamaya gidiyor.

| Kontrollü örnek | Gözlenen sonuç |
| --- | --- |
| Pazar ilan API'si, ilk detay + iki dönüş/tekrar açılış | 5 istekte yaklaşık 40–102 ms |
| Aynı görselin erişim bağlantısı API'si | 5 istekte 53–73 ms |
| Aynı gitar fotoğrafının uzak depolamadan indirilmesi | 5 GET: 1015, 1052, 531, 614, 457 ms; her birinde 314.980 byte, HTTP 200 |
| Aynı fotoğraf için toplam tekrar transfer | 1.574.900 byte; liste/detail geçişleri aynı dosyayı tekrar indirdi |
| Mevcut profil fotoğrafı, ilk profil açılışı | Önbellekteki dosyanın HTTP 304 doğrulaması 712 ms; fotoğraf gövdesi tekrar indirilmedi |
| Profilin ikinci açılışı | Yeni fotoğraf HTTP isteği oluşmadı; profil fotoğrafı göründü |
| Bilgisayardan mevcut backend sağlık isteği | 3 örnek: 147, 47, 49 ms |
| Bilgisayardan aynı public profil görseli | 63.241 byte, HTTP 200; 3 örnek: 715, 383, 350 ms |

Telefon oturumundaki bütün API örnekleri (profil, takvim, Collab dahil) 20–546 ms aralığındaydı. Yukarıdaki 40–102 ms yalnız kontrollü Pazar döngüsüdür. Bu kısa debug oturumu üretim performansı veya bütün koşullar için yüzdelik istatistik değildir. HTTP süresi görüntü decode/raster süresini ayrı ölçmez; 304 doğrulama süresi de önbellekteki görselin ekranda görünmesini mutlaka geciktirdiği anlamına gelmez.

## Sonuç

**Pazar'da uygulamaya ait tekrar indirme maliyeti doğrulandı.** `MarketplacePhoto` her oluşturulduğunda erişim bağlantısı ister. `AppCachedNetworkImage(persistentCache: false)` özel görseli diske yazmaz ve kaldırıldığında ImageProvider'ı bellekten çıkarır. Liste yenilenirken kartlar kaldırılıp tekrar oluşturulur. Değişen imzalı URL de sıradan URL tabanlı cache anahtarını değiştirir. Böylece aynı dosya liste/detail geçişlerinde tekrar indirilir.

Bu örneklerde asıl süre fotoğrafın uzak depolamadan gelmesindeydi. PC'deki API isteği belirgin biçimde daha kısa sürdü. Mobil hat, bağlantı kurma ve depolama gecikmesini ayrı ayrı suçlayacak kanıt yok; "internet yavaş" veya "PC yavaş" diye tek sebep atanmamalı. Gereksiz yeniden indirme, mevcut ağ gecikmesini kullanıcıya tekrar tekrar yaşatıyor.

**Ayrı geliştirme ortamı bulgusu:** avatar derlemesinden önce mevcut Java sürecinde 5,025 saniyede 12,578 CPU saniyesi tüketildi. 16 mantıksal işlemcili makinede bu yaklaşık 2,50 çekirdek / toplam kapasitenin %15,6'sı. On DevTools File Watcher için 5,185 saniyelik yakın örnekte toplam 12,938 CPU saniyesi görüldü: yaklaşık aynı 2,50 çekirdek. Bu kısa pencerede Java CPU yükünün neredeyse tamamı geliştirme dosyası izleyicilerinden geliyordu. İzleyici yükü gerçek ve ayrı incelenmeye değer; fotoğrafın ağ indirme süresinin sebebi olduğu veya üretimde de aynı yükün bulunduğu gösterilmedi. İzleyici/performance ayarları değiştirilmedi.

**Genel fotoğraf altyapısında aynı davranış saptanmadı.** Profil/Collab/stüdyo yüzeyleri ortak public disk cache'i kullanıyor; uygun olduğunda sunucu thumbnail URL'si tercih ediliyor. Profilde ikinci açılışın ağ isteği üretmemesi cihazda doğrulandı. Collab ekranı mevcut oturumda boştu, görselli ilan için cihaz ölçümü yapılamadı. Stüdyo ekranları kod düzeyinde incelendi; gerçek cihazda görsel performansı ölçülmedi. Bütün uygulamanın yavaş veya hızlı olduğu sonucu çıkarılmadı.

`cacheWidth/cacheHeight` decode belleğini küçültür, indirilen dosyanın byte boyutunu küçültmez. Yeni public görselin thumbnail'i henüz hazır değilse mevcut resolver orijinale dönebilir; bu potansiyel soğuk açılış maliyeti bu ölçümde genel hata olarak doğrulanmadı.

## Konuşulacak iyileştirme

İlk aday, Pazar'ın erişim kontrolünü koruyarak aynı oturumda yakın zamanda görülen fotoğrafları sınırlı RAM önbelleğinden tekrar kullanmak. Her yeni erişimde sunucu yetki kontrolü, oturum değişimi/arka plan/süre bitiminde temizleme, geç gelen isteklerin reddi ve yönetici erişiminin ayrılması korunmalı. Özel fotoğrafları public kalıcı cache'e taşımak uygun değil. Küçük kartlar için yetkili thumbnail üretimi ayrı bir ikinci adım olabilir. Kullanıcıyla görüşülmeden ikisi de uygulanmadı.

## İlan sahibi fotoğrafı

İki ayrı eksiklik bulundu: backend `seller.avatarUrl` değerini sürekli `null` dolduruyordu; frontend satıcı kartı da var olan `avatarUrl` alanını kullanmayıp daima baş harf çiziyordu. Avatar düzeltmesi performans değişikliğinden bağımsızdır. Backend mevcut profil/medya altyapısıyla PUBLIC/READY güncel profil görselini toplu çözümler; frontend ortak görüntü bileşeniyle gösterir. Fotoğraf yoksa veya erişilemezse baş harf yedeği korunur. Profil bağlantısının davranışı korunur.

Frontend doğrulaması: 5 yeni avatar testi + 19 Pazar widget testi + 7 ortak görsel testi, toplam **31 test geçti**; odaklı analiz temiz. Backend'de **15 test geçti**: 14 Marketplace PostgreSQL senaryosu ve ortak medya display URL politikası için bir test. Testler geçici veritabanı/ayrı derleme klasöründe çalıştı; QA ilanlarına dokunulmadı.

Runtime doğrulaması tamamlandı: `classes` derlemesiyle mevcut DevTools context'i yenilendi; backend aynı PID `55336` ve port `8080` üzerinde kaldı, readiness tekrar `UP`. Frontend mevcut Flutter runner üzerinden hot restart ile yüklendi. Gerçek telefonda kullanıcının mevcut profil fotoğrafı ilan sahibi kartında göründü; profil bağlantısı da tekrar açıldı. [Düzelmiş ilan sahibi kartı](../tmp/marketplace-manual-qa/avatar-02-real-seller-photo.png).

## Kanıtlar

- [Pazar ilk açılış ağ ölçümü](../tmp/marketplace-manual-qa/photo-perf-marketplace-first.json)
- [Pazar tekrarlı açılış ağ ölçümü](../tmp/marketplace-manual-qa/photo-perf-marketplace-repeated.json)
- [Profil tekrar açılışı](../tmp/marketplace-manual-qa/photo-perf-profile-repeat.json)
- [Son anonimleştirilmiş HTTP ölçümü](../tmp/marketplace-manual-qa/photo-perf-final.json)

## Onay sonrası uygulanan iyileştirme ve tekrar ölçümü

Mevcut S3 ve medya işleyicisi korundu. Özel görseller için aynı immutable
kaynak dizininde 960 piksel uzun kenarlı JPEG küçük görsel üretiliyor;
erişim mevcut modül ACL'sinden sonra kısa süreli imzalanıyor. Kartlar küçük
görseli, detay galerisi orijinali seçiyor. Eski veya henüz işlenmemiş kayıtlar
orijinale düşüyor. Özel medyanın public URL alanları doldurulmuyor.

Frontend'de 24 MiB/64 kayıt sınırında, oturuma bağlı RAM bayt deposu eklendi.
Her gösterim yine yeni sunucu yetkisi gerektiriyor; indirme tekrarları birleşiyor.
Arka plan, oturum değişimi ve yetki süresi bitişinde veriler temizleniyor.
HTTP yanıtı/signed URL/özel fotoğraf diske cache edilmiyor. Decode belleği de
ayrıca sınırlandırılıyor ve widget kaldırılınca temizleniyor. Kartlarda
`cover` nedeniyle ikinci bir küçültme/netlik kaybı oluşturan decode tercihi
gerçek yatay/dikey görsel testleriyle düzeltildi.

Aynı Vivo telefon, aynı mobil veri bağlantısı ve mevcut debug oturumunda,
önce normal arka plan/geri dönüş ile RAM temizlenerek aşağıdaki tur yapıldı:
liste → detay → liste → detay → liste. Önceki kayıtta da aynı gitar görseli
beş gösterimde beş kez orijinal olarak indirilmişti.

| Ölçü | Önce | Sonra |
| --- | --- | --- |
| Gitar görseli için 5 gösterimde storage GET | 5 | 2 (1 thumbnail + 1 original) |
| Bu turda toplam görsel transferi | 1.574.900 byte | 356.668 byte (%77,35 azalma) |
| Liste kartında ilk transfer | 314.980 byte | 41.688 byte (%86,76 azalma) |
| Yeni sunucu yetkisi kontrolü | 5 | 5 |
| İlk liste + ilk detay sonrası 3 gösterimde ek storage GET | 3 | 0 |

Son turda erişim API'si 76,9–135,6 ms; ilk thumbnail indirmesi 863,6 ms,
ilk orijinal indirmesi 1.264,2 ms sürdü. **Veri ve tekrar istek azalması
doğrulandı; ilk uzak indirme gecikmesinin tamamen giderildiği iddia edilmiyor.**
Bu örnek ağ/konum koşullarına bağlıdır; üretim yük testi veya kullanıcı
kapasitesi kanıtı değildir. Ekran ilk piksel/raster gecikmesi ayrı ölçülmedi.

Ek manuel turda ikinci pedal fotoğrafı açıldı, satıcı avatarı görüntülendi,
satıcının profiline gidilip geri dönüldü. Son olarak uygulama arka plana
alınıp geri getirildiğinde küçük fotoğraf yeniden yetkilendirilip indirildi;
foreground dışındaki belleğin tutulmadığı gerçek ağ kaydıyla da doğrulandı.
Toplam 32 HTTP örneğinde 4xx/5xx/transport hatası görülmedi. HTTP profiling
ayarı test sonunda önceki değerine getirildi.

Otomatik doğrulama: frontend 19 fotoğraf + 11 özel RAM deposu + 19 mevcut
Pazar widget testi, toplam **49 test geçti**; odaklı analiz temiz. Backend
geniş 185 test ve ek 24 odaklı kontrol geçti (örtüşmeler çıkarılınca 188 farklı
test). Ek migration/grant, erişim, backfill/CAS ve silme güvenliği senaryoları
doğrulandı. Bu sayılar uygulamanın tüm testlerinin çalıştırıldığı anlamına gelmez.

Additive migration mevcut yerel veritabanına uygulandı; aynı PID `55336` /
`8080` DevTools ile güncellendi ve health/readiness `UP` doğrulandı. Normal
backfill 3/3 QA thumbnail'ını üretti. İlk ilan `PUBLISHED v8`, ikinci ilan
`SOLD v3`; fotoğraf sayıları ve publication zamanları aynı kaldı. Orijinaller
silinmedi, test ilanları temizlenmedi.

- [Tekrarlı gösterim ölçümü](../tmp/marketplace-manual-qa/photo-perf-private-cache-repeated.json)
- [Galeri/profil/arka plan dahil ölçüm](../tmp/marketplace-manual-qa/photo-perf-private-cache-resume.json)
- [Güncel liste](../tmp/marketplace-manual-qa/private-cache-list-cold.png)
- [Güncel detay](../tmp/marketplace-manual-qa/private-cache-detail-cold.png)
- [İkinci galeri fotoğrafı](../tmp/marketplace-manual-qa/private-cache-pedal-gallery.png)
- [Satıcı avatarı](../tmp/marketplace-manual-qa/private-cache-seller-avatar.png)
- [S3/CloudFront bulguları, güvenlik sınırları ve production rollout](private-media-delivery-2026-09-20.md)
