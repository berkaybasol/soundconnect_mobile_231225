# Backstage alım satım modülü — kodlama öncesi inceleme

> Bu belge ilk incelemenin tarihsel kaydıdır. Sonraki kullanıcı kararıyla katalog
> Pan Music düzeni referans alınarak tamamen ayrıldı; Backline eşlemesi ve stüdyo
> envanterinden aktarma kapsam dışı bırakıldı. Güncel uygulama ve doğrulama notları:
> [Ekipman Pazarı — ilk sürüm](marketplace-first-release.md).

20 Eylül 2026. Bu belge ürün önerisi ve yerel kaynak kod incelemesidir. Uygulama/backend kodu değiştirilmedi; canlı veritabanı veya üretim ortamı incelenmedi, test çalıştırılmadı.

## 1. Sabit ürün kararları

- Modül yalnız Backstage içindir. Dinleyici liste, detay, arama, bildirim ve paylaşım bağlantılarından ilanlara erişemez. İlk satıcı/alıcı profilleri müzisyen, stüdyo ve mekândır; yönetici müdahalesi ayrı yetkidir.
- Enstrüman, ses ve sahne ekipmanı ilanları desteklenir.
- Ürün durumu yalnız **Sıfır / İkinci el** olur. Kozmetik veya çalışma durumu için ayrı alan oluşturulmaz; satıcı bunları açıklamaya yazar.
- İki ürün durumunu da kapsadığı için görünür modül adı önerisi **Alım Satım**dır.
- Ödeme, tahsilat, kargo organizasyonu, satın alma garantisi veya satış doğrulaması bu sürümde yoktur. Kullanıcı satıcıyla mevcut DM üzerinden iletişim kurar.
- Stüdyo envanteri satış ilanıyla aynı kayıt değildir. Envanterden yalnız bağımsız ilan taslağı üretilebilir.

## 2. Nihai teknik öneri

**Backline'ın mevcut ürün listesini temel alan, satış modülüne ait küçük bir kategori kataloğu; mevcut location altyapısının doğrudan yeniden kullanımı. Instrument satış kategorisi olmayacak.**

| Bileşen | Karar | Gerekçe |
| --- | --- | --- |
| Instrument | İlan kategorisine bağlanmaz | Müzisyenin çaldığı enstrüman ve uzmanlık sözlüğü; ürün dışı kayıtlar içeriyor |
| Backline kategori verisi | Başlangıç sözlüğü, ikonlar ve eşleme kaynağı olarak kullanılır | Enstrüman ve ekipman kapsamı hazır |
| Backline kategori tablosu/iş akışı | Satış ilanları buna doğrudan FK ile bağlanmaz | Ayrı kategori ayrıntısı, yayın yaşamı ve değişiklik ihtiyacı var |
| Satış kategorileri | Yeni, küçük, iki seviyeli katalog | Backline envanterini değiştirmeden satış filtrelerini geliştirmeyi sağlar |
| Location | Mevcut tablo, endpoint, repository ve seçim bileşeni kullanılır | İl/ilçe ihtiyacını karşılıyor |
| Medya ve DM | Mevcut altyapı, ilana özgü sahiplik/erişim/bağlam eklenerek kullanılır | Yeni paralel yükleme veya sohbet sistemi gerekmiyor |
| Satış ilanı | Ayrı modül ve kayıt | Fiyat, Sıfır/İkinci el, ilan yaşamı ve moderasyon envanterden farklı |

Burada yeni kategori kataloğu; sınırsız derinlik, marka/model veritabanı, kategori talep sistemi veya ayrı bir mikroservis anlamına gelmez. Kategori kimliği, sabit kod, ad, ebeveyn, sıra, ikon ve seçim aktifliği yeterlidir. İlk sürüm yönetimi kontrollü referans veri değişiklikleriyle yapılır; kullanıcı serbestçe kategori açmaz.

### Instrument neden uygun değil?

Repodaki seed'de 164 düz kayıt var. “Akustik Gitar” yanında “Aranjör”, “Besteci”, “FOH Mühendisi”, “Vokal Koçu” gibi uzmanlıklar bulunuyor. Veri modeli ürün ağacı değil; temel olarak kimlik ve ad tutuyor. Müzisyen profilleri ve Collab da bu sözlüğü kullanıyor. Satış ürünlerini buraya eklemek mevcut uzmanlık seçimlerini etkiler.

Kaynaklar: [seed](C:/Users/user/Desktop/SoundConnect/SoundConnect-Backend/src/main/resources/instrument-catalog-seed.json:9), [Instrument](C:/Users/user/Desktop/SoundConnect/SoundConnect-Backend/src/main/java/com/berkayb/soundconnect/modules/instrument/entity/Instrument.java:18).

### Backline neden doğrudan kullanılmıyor?

Seed'de **10 ana, 79 alt kategori** var. Amfi, mikrofon, ses kartı, monitör, DJ ekipmanı, kablo, stand ve taşıma çözümlerini zaten kapsıyor. İyi bir başlangıç sözlüğü.

Ancak satış filtreleri için bazı seçenekler birleşik:

| Backline'daki mevcut seçenek | Satışta önerilen ayrım |
| --- | --- |
| Akustik & Klasik Gitarlar | Akustik gitar / klasik gitar |
| Ses Kartları & Kayıt Cihazları | Ses kartı / kayıt cihazı |
| PA Hoparlörleri & Subwooferlar | PA hoparlörü / subwoofer |
| Analog & Dijital Mikserler | Analog mikser / dijital mikser |
| Kondansatör & Ribbon Mikrofonlar | Kondansatör mikrofon / ribbon mikrofon |
| Halk & Dünya Enstrümanları | Bağlama, ud, kanun vb. ayrı seçimler |
| Tahta Nefesli Enstrümanlar | Flüt, klarnet, saksafon vb. ayrı seçimler |

Backline ekipmanları kategoriye canlı FK ile bağlı. Mevcut seed aynı kodu bulunca adını, ebeveynini, sırasını ve aktifliğini güncelleyebiliyor. Kategori talepleri stüdyo sahibine bağlı; onaylanan kategori ortak Backline ağacına ekleniyor. Satışın kategori ağacını bu yoldan değiştirmek stüdyo ekranlarını da etkiler.

Ortak katalog teknik olarak mümkün, fakat ayrıştırılmış satış türleri için modüle göre seçim görünürlüğü ve eski geniş kategorilerle uyumluluk kuralları gerekir. Kullanıcının ayrıntılı satış filtreleri ve bağımsız büyüme isteği için **küçük ayrı katalog + açık envanter eşlemesi** daha uygun. Bunun karşılığı iki sözlük ve eşlemenin bakımını yapmaktır; bu maliyet bilinçli kabul edilir. Aynı kavramların etiketleri uyumlu tutulur, Backline değişiklikleri satışa kendiliğinden uygulanmaz.

## 3. Önerilen satış kategori düzeni

İki adım: **Ana kategori → Ürün türü**. Marka ve model kategori seviyesine dönüşmez; ayrı alanlardır. Ayrıca Instrument seçimi istenmez.

Aşağıdaki liste önerilen ana düzen ve alt tür örnekleridir; uygulanmış seed değildir.

| Ana grup | Alt tür örnekleri |
| --- | --- |
| Gitarlar ve Baslar | Elektro, akustik, klasik, elektro bas, akustik bas, ukulele |
| Amfiler ve Kabinler | Gitar combo/kafa/kabin, bas combo/kafa/kabin, akustik gitar ve klavye amfisi |
| Pedal ve Efektler | Tekli pedal, multi efekt, modelleyici, footswitch/kontrol pedalı |
| Tuşlular ve MIDI | Akustik piyano, dijital piyano, synthesizer, workstation, org, MIDI klavye/kontrolcü |
| Davul ve Ziller | Akustik set, elektronik set, tekil davul, trampet, zil, davul pedalı, elektronik pad/modül |
| Perküsyon | Cajon, conga, bongo, darbuka, bendir, tef, küçük el perküsyonu, mallet perküsyonu |
| Yaylı Enstrümanlar | Keman, viyola, çello, kontrbas |
| Üflemeli Enstrümanlar | Flüt, klarnet, saksafon, trompet, trombon, armonika |
| Geleneksel ve Dünya Enstrümanları | Bağlama, cura, ud, kanun, ney, cümbüş ve diğer geleneksel çalgılar |
| DJ Ekipmanları | CDJ/medya oynatıcı, turntable, DJ mikseri, DJ kontrolcüsü, sampler, drum machine |
| Mikrofon, Kayıt ve Stüdyo | Mikrofon türleri, ses kartı, kayıt cihazı, stüdyo monitörü, kulaklık, preamp, outboard işlemci |
| Canlı Ses Sistemleri | PA hoparlörü, subwoofer, analog/dijital mikser, sahne monitörü, in-ear, kablosuz sistemler, güç amfisi |
| Sahne Işık ve Efektleri | Sahne ışığı, hareketli ışık, DMX kontrolcüsü, sis/duman cihazı |
| Aksesuar ve Yedek Parçalar | Stand, kablo/adaptör, rack/case, taşıma çantası, nota sehpası, tabure, tel, pena, yedek parça |

Sahne ışığı/DMX mevcut Backline seed'inde yoktur; yukarıdaki grup “sahne ekipmanı” kapsamına önerilen eklemedir.

Seçici ana grupları ve ürün türlerini arayabilmeli. Örneğin “klasik gitar” yazıldığında doğrudan ilgili alt tür ve ana grubu görünmeli. İlan yalnız son kategoriye bağlanır; ana grup oradan türetilir. Aynı ürün türü birden fazla gruba çoğaltılmaz; arama eş anlamlıları kullanılır.

Kategori kodu değişmez. İsim düzeltmek başka bir ürüne dönüştürmek değildir. Pasifleştirilen tür yeni ilanda seçilemez fakat eski ilanı silmez; kategori değişimi ve yeniden yayınlama kontrollü ele alınır. İlk sürümde kategoriye özel onlarca teknik alan, marka/model kataloğu veya üçüncü seviye yoktur.

## 4. Location: mevcut yapı yeterli

Mevcut yapı `City → District → Neighborhood`. İl ve ilçe API'leri, Flutter repository'si, Türkçe sıralama ve aramalı seçim bileşeni hazır. Repo seed'i 81 il, 973 ilçe ve 32.254 mahalle içeriyor; bu sayı canlı veritabanının doğrulaması değildir. Prod otomatik seed'i kapalıdır.

- İlanda il ve ilçe zorunlu; ürünün bulunduğu konumu gösterir.
- Mahalle, sokak, açık adres, GPS veya koordinat bu sürümde gerekli değil.
- Stüdyo/mekân konumu taslağı ön doldurabilir; satıcı değiştirebilir.
- Müzisyen kullanıcı kaydında il var, ilçe yok; ilçeyi satıcı seçer.
- İlan kendi `districtId` referansını tutar, il bu ilişkinin üzerinden türetilir. Profil taşındığında ilan konumu kendiliğinden değişmez.
- Aramada il filtresi, onun altında isteğe bağlı ilçe filtresi olur.
- API hem il hem ilçe alırsa ilçenin seçilen ile ait olduğu doğrulanır; sadece iki kaydın varlığını kontrol etmek yetmez.

Hazır LocationCubit'in ilçe yüklemesinde geç gelen eski isteği ayıran koruma yok. Yeni ilan formunda il değişince ilçe sıfırlanmalı; eski isteğin cevabı yeni seçimi ezmemeli. Repository ve seçim sheet'i yeniden kullanılır; ilan formunun durum yönetimi bu dar kapsamlı korumayı ekler. Yeni location modülü veya paralel şehir tablosu yazılmaz.

## 5. Stüdyo envanterinden taslak

Stüdyo sahibi “Envanterimden seç” ile kendi aktif ekipmanını seçer. Sunucu sahipliği yeniden denetler. İlk aşamada otomatik yayınlama yapılmaz.

| Envanter alanı | İlan taslağı |
| --- | --- |
| Kategori kodu | Açık eşleme üzerinden satış alt türü |
| Ad, marka, model | Düzenlenebilir alanlar |
| Açıklama ve özellikler | Düzenlenebilir açıklama |
| Sıralı fotoğraflar | İlanın kendi korumalı medya kopyaları |
| Stüdyo konumu | Değiştirilebilir il/ilçe başlangıcı |
| Adet, bakım, meşguliyet, müsaitlik | Aktarılmaz; satış stok yönetimi değildir |
| Fiyat ve Sıfır/İkinci el | Satıcı doldurur; envanterde bulunmuyor |

Çoğu kategori birebir eşlenebilir. `Akustik & Klasik Gitarlar` gibi kaynaklar için kullanıcı son seçimi yapar. Kaynağın adından gizlice kategori/durum tahmini yapılmaz. Eşlenmemiş yeni Backline kategorisi taslağı engellemez; yayınlamadan önce kategori seçimi ister.

İlan bir ürün veya açıkça belirtilmiş tek bir seti temsil eder. Envanterde 8 mikrofon yazması sekizinin otomatik satışa çıkması değildir. Kaynak ekipman kimliği iz için tutulabilir; taslaktan sonra canlı senkronizasyon kurulmaz. Satıldı işlemi envanter adedi veya rezervasyonlara müdahale etmez.

**Fotoğraf aktarımı hazır bir kopyala-yapıştır işlemi değildir.** Mevcut ekipman görselleri `STUDIO_PROFILE` sahipliği ve PUBLIC medya kullanıyor. Envanter arşivlenince fotoğraf bağları temizleniyor; yalnız URL kopyalamak ilanı bağımsız yapmaz. Satış medyasının ayrı sahipliği, silme referansları ve Backstage erişimi olmalı. Öneri, aktarımda ilan için korumalı medya kopyası oluşturmaktır; eski stüdyo görselinin mevcut görünürlüğü değişmez. Kullanıcı yeni çektiği fotoğraflarla bunları değiştirebilir.

Bu kolaylık temel ilan akışından sonra eklenmeli. Kapsam azaltmak gerekirse ertelenecek bölüm envanterden otomatik aktarım olur; kullanıcı normal ilan formuyla ürününü yine yayınlayabilir. Rezervasyon/stok senkronizasyonu eklenmez.

## 6. İlk sürüm ilan sözleşmesi

Zorunlu alanlar: ürün alt türü, başlık, **Sıfır / İkinci el**, pozitif TL fiyatı, açıklama, il/ilçe ve en az bir fotoğraf. Fotoğraf üst sınırı önerisi 8. Marka/model opsiyonel metin alanıdır; marka seçimi için ayrı katalog gerekmiyor. Pazarlığa açık ve teslim tercihi küçük ek seçenekler olabilir.

Kozmetik puanı, arıza checkbox'ı veya çalışma durumu enum'u yoktur. Açıklama yardımı satıcıya kusur, tamir ve kutu içeriğini belirtmesini hatırlatır.

Ürün durumu ile ilan durumu ayrıdır. İlan durumu: taslak, yayında, satıldı, satıcı tarafından kaldırıldı, moderasyonla kaldırıldı. “Satıldı” satıcının beyanıdır; doğrulanmış işlem veya satış puanı üretmez.

Liste varsayılan olarak yeni yayın tarihine göre sıralanır. Arama başlık/marka/model üzerinden; filtreler kategori, Sıfır/İkinci el, il/ilçe ve fiyat üzerinden çalışır. Düzenlemek yayın tarihini otomatik yenilemez. “Satıcıya yaz” mevcut kullanıcı çifti DM'sini açar ve ilana ait bağlam sağlar; tıklama kendi başına mesaj göndermez.

İlan şikâyeti, yönetici kaldırması, yayınlama limitleri ve kullanıcı engelleme planın parçasıdır. Mevcut Collab/feed moderasyonu tasarım örneğidir; hazır genel marketplace moderasyonu veya genel DM engellemesi bulunduğu varsayılmaz.

## 7. Uygulama sırası ve doğrulama

1. Satış kategori seed'i ve Backline→satış eşlemeleri kesinleştirilir; mevcut Backline/Instrument verileri değişmez.
2. İlan modeli, sahiplik/Backstage erişimi, kategori ve konum doğrulaması kurulur.
3. İlan medyası mevcut yükleme altyapısına eklenir; korumalı sunum, görsel sırası, silme ve taslak temizliği tamamlanır.
4. Liste, detay, ilan oluşturma/düzenleme ve ilanlarım ekranları bağlanır.
5. DM ilan bağlamı, şikâyet/engelleme ve admin müdahalesi doğrulanır.
6. Stüdyo envanterinden taslak aktarımı eklenir; bağımsızlık ve fotoğraf yaşamı test edilir.

Kodlama sonrası kabul senaryoları: dinleyicinin doğrudan URL/API ile erişememesi; başka hesabın ilanı düzenleyememesi; pasif/ana kategoriyle yayınlanamaması; yanlış il–ilçe çiftinin reddi; hızlı şehir değişiminin eski veriyi göstermemesi; yarım fotoğraf yüklemesiyle yayınlanamaması; silinen envanterin ilan fotoğraflarını bozmaması; satıldı işleminin envanter rezervasyonlarını değiştirmemesi; ilan değişse/kapanmış olsa da DM bağlamının doğru davranması.

## 8. Kaynaklar

Dosya adları yerel çalışma alanındaki mevcut kodu gösterir; bu rapordaki kategori önerilerinin uygulanmış olduğunu ifade etmez.

- `SoundConnect-Backend/src/main/resources/backline-category-seed.json`: mevcut 10/79 kategori.
- `SoundConnect-Backend/src/main/resources/instrument-catalog-seed.json`: 164 enstrüman/uzmanlık kaydı.
- `SoundConnect-Backend/src/main/java/com/berkayb/soundconnect/modules/backline/catalog/entity/BacklineCategory.java`: UUID/kod, iki seviye, aktiflik.
- `SoundConnect-Backend/src/main/java/com/berkayb/soundconnect/modules/backline/catalog/service/BacklineCatalogService.java`: ortak ağaç ve stüdyoya bağlı kategori talepleri.
- `SoundConnect-Backend/src/main/java/com/berkayb/soundconnect/modules/backline/catalog/seed/BacklineCatalogSeeder.java`: mevcut kayıtları eşitleme davranışı.
- `SoundConnect-Backend/src/main/java/com/berkayb/soundconnect/modules/studio/equipment/entity/StudioEquipment.java`: envanter alanları ve fotoğraf bağlarının temizlenmesi.
- `SoundConnect-Backend/src/main/java/com/berkayb/soundconnect/modules/studio/equipment/service/StudioEquipmentService.java`: sahiplik, aktif kategori ve medya doğrulaması.
- `SoundConnect-Backend/src/main/java/com/berkayb/soundconnect/modules/media/service/MediaAssetServiceImpl.java`: PUBLIC/korumalı medya erişimi.
- `SoundConnect-Backend/src/main/java/com/berkayb/soundconnect/modules/media/service/MediaAssetReferenceGuard.java`: referanslı medya silme koruması.
- `SoundConnect-Backend/src/main/java/com/berkayb/soundconnect/modules/location/entity/District.java`: ilçenin il ilişkisi.
- `SoundConnect-Backend/src/main/java/com/berkayb/soundconnect/modules/location/support/LocationEntityFinder.java`: varlık kontrolü.
- `SoundConnect-Backend/docs/location-seed.md`: konum veri kapsamı ve üretim aktarımı.
- `SoundConnect-Frontend/lib/modules/location/data/location_repository_impl.dart`: mevcut şehir/ilçe sorguları.
- `SoundConnect-Frontend/lib/modules/location/presentation/widgets/location_picker_sheet.dart`: ortak seçim bileşeni.
- `SoundConnect-Frontend/lib/modules/location/presentation/cubit/location_cubit.dart`: mevcut istek yönetimi.
- `SoundConnect-Frontend/lib/modules/profile/presentation/screens/studio_profile_backline_taxonomy.dart`: stüdyo ekranına bağlı kategori sunumu.
- `SoundConnect-Frontend/lib/modules/profile/presentation/screens/studio_owner_backline_inventory_editor.dart`: envanter formu ve fotoğraf akışı.

Kategori/lokasyon sayıları repodaki başlangıç dosyalarına aittir. Canlı ortam verisi ayrıca doğrulanmalıdır. Bu çalışma yalnız inceleme ve rapor hazırlamadır.
