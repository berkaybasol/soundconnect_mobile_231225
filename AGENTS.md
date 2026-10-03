# SoundConnect Frontend — kalıcı proje kararları

## Bildirim açılışları

30 Eylül 2026 kullanıcı UX kararı; 1 Ekim 2026 kalıcı talimat uygulaması:
uygulanmış native kart/inbox girişinden ilgili mevcut gerçek ürün sayfasını aç;
gereken kısa açıklamayı yetkili ürün/origin altında mevcut küçük mesajla ver.
Bildirime özel rapor/sonuç, ara onay/devam, boş loading/tam ekran hata route'u,
büyük rapor modalı/bottom sheet veya ekstra Back basamağı ekleme. Gerçek işlem
sayfaları ve görünmeyen teknik koordinasyon korunur. Fresh exact hedef,
yetki/session/görünürlük/read güvenliği ve iki ayrı açık retry korunur;
ACK-only retry hedef GET/domain işlemini yinelemez.
[Esas politika ve örnekler](docs/notification-navigation-policy.md)
bu repo içindedir; frontend tek başına açıldığında da uygulanır. Her uygulama
promptunda ayrı **Manuel kabul** ve otomatik/API/fiziksel/kullanıcı sonuçları bulunur;
mobil davranış etkilenirse ilgili gerçek yol fiziksel Vivo'da doğrulanır.
Bu talimat yeni native destek veya yeni kullanıcı görsel onayı değildir.

## İkinci beyin bağlantısı

Durum/karar/öncelik görevlerinde ve çok adımlı proje çalışmalarında, üst SoundConnect
çalışma alanı mevcutsa [hafıza dizinini](../hafiza/README.md) oku. İlgili karar/iş
değiştiğinde asıl konu kaydını ve kısa hafıza özetini tarih/kaynakla güncelle;
fikirleri onaylı iş sayma. Repo tek başına açılmış ve
hafıza klasörü yoksa bu sınırı belirt; varmış gibi davranma.

Firebase, push bildirimleri, kullanım ölçümü veya canlıya hazırlık çalışmalarında
[Google Analytics kararını](docs/google-analytics-plan.md) ve
[bildirim açılışı politikasını](docs/notification-navigation-policy.md) koru.

Android'in kullanıcı tarafından 2026-09-23 tarihinde onaylanan kalıcı applicationId
değeri `tr.com.soundconnect.app`, preview kimliği `tr.com.soundconnect.app.preview`.
Kotlin namespace ve Dart paket adı ayrı kavramlardır; eski teknik isimlerin kodda
bulunması applicationId'nin eski olduğu anlamına gelmez. Ayrıntılar:
[Android kimliği geçiş kaydı](docs/android-identity-20260923.md).

Kullanıcı Google Analytics'i kullanmak istediğini açıkça belirtti. Bu kararı
koru; Firebase konsolundaki seçim ile uygulamada çalışan ve doğrulanmış ölçümü
ayrı değerlendir. Güncel kullanıcı talimatları bu notlardan önceliklidir.

23 Eylül 2026 güncel sıra kararı: Analytics bütün bildirim çalışmaları bitene
kadar ertelendi. DM kabulü tüm profil türleri dahil tamamlanmadan yeni bildirim
modülüne geçilmez; kanıtlanmamış koşullar açık kaydedilir.

23 Eylül görünüm kararı: Kullanıcıya görünen uygulama adı `Soundconnect`
(yalnız ilk harf büyük). DM sistem bildiriminde görünür gönderen kimliği/avatarı,
`Sana bir mesaj gönderdi.` açıklaması ve küçük Soundconnect amblemi kullanılır;
küçük simgede yazılı tam logo kullanılmaz. Teknik paket/proje kimliklerini bu
görünüm tercihi nedeniyle değiştirme.

Kullanıcı hesap kurulumunu ekran görüntüleriyle, her seçeneğin işlevini ve önerinin
nedenini öğrenerek ilerletmek istiyor. Adımları sade Türkçeyle açıkla.

## Korunan bildirim görünümü kararları

23 Eylül 2026: 03 beyaz daireli rozetin **B seçeneği** onaylıdır:
72dp daire içinde 54dp görünür yükseklik, 1,5dp sola optik hizalama. B korunur.
01/02 ortak küçük amblem için kullanıcının istediği %4,5 büyütme ve optik hizalama
korunur. `ic_notification.xml`: 356 viewport, %4,494 büyüme, 24dp boyutta
0,654dp sola kayma. Özgün yollar ve #F58477 mercan rengi korunur; ortak kaynak
durum çubuğunu da etkiler.

24 Eylül 2026: Uygulama içindeki zil/DM sayaçları ve okunmamış noktaları
`AppColors.brandGradient` kullanır; alt sayaç kapsül biçimindedir.

24 Eylül son kullanıcı kararı: “Diğer ölçüleri koru, başlık şimdilik böyle
kalsın.” Ortak ikonu %14 küçültme seçeneği reddedildi. Özgün ortak
`ic_notification`, beyaz summary ve mercan çocuk kartları korunur; başlıktaki
büyük/koyu amblem ve sınırlı iç boşluk kabul edilen sınırlamadır. 01/02, avatar
altı ve durum çubuğu ölçeği/optik hizalama korunur. Ayrı summary ikonu ve
beyaz çocuk amblemi veren level-list denemeleri onaylı tasarım değildir.
Bu kararı yeni istek olmadan tekrar açma. Standart Android/OEM sunumunda
özgün gradyanın veya saf beyazın her temada korunacağını vaat etme.

Bu ürün kararları otomatik test, fiziksel cihaz kabulü veya tam üretim kabulü
yerine geçmez. Kalıcı kararlar [proje karar kaydında](../hafiza/kararlar.md) tutulur.
