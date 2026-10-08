import '../../modules/musician_feed/domain/musician_feed_models.dart';
import '../domain/preview_feed_scenario.dart';

/// Hand-authored visual scenarios. This is deliberately not backend ranking.
List<PreviewFeedScenario> buildPreviewFeedCatalogue({DateTime? now}) {
  final b = _Catalogue((now ?? DateTime.now()).toUtc());
  for (final variant in [
    'normal',
    'no-bpm',
    'long-title',
    'zero-count',
    'popular',
  ]) {
    b.add(
      'track-$variant',
      switch (variant) {
        'no-bpm' => 'BPM bilgisi olmayan kayıt',
        'long-title' => 'Uzun parça adı',
        'zero-count' => 'Henüz etkileşim almamış kayıt',
        'popular' => 'Yoğun etkileşim',
        _ => 'Parça · ses oynatıcı',
      },
      'Parçalar',
      MusicianFeedItemType.track,
      (id) => {
        'trackId': id,
        'mediaAssetId': previewUuid('$id-media'),
        'title': variant == 'long-title'
            ? 'Geceye Kalan Son Akor · Kadıköy Provasından Akustik Bir Kayıt'
            : 'Geceye Kalan',
        'playbackUrl': '$previewMediaBaseUrl/audio.wav',
        'durationSeconds': 8,
        'bpm': variant == 'no-bpm' ? null : 112,
      },
      targetType: 'MEDIA',
      targetId: (id) => previewUuid('$id-media'),
      likes: variant == 'zero-count'
          ? 0
          : variant == 'popular'
          ? 12480
          : 42,
      comments: variant == 'zero-count'
          ? 0
          : variant == 'popular'
          ? 208
          : 3,
      liked: variant == 'popular',
      reason: variant == 'popular' ? 'DISCOVERY' : 'FOLLOWING_PUBLICATION',
    );
  }
  for (final variant in [
    'landscape',
    'portrait',
    'square',
    'no-caption',
    'long-caption',
    'video',
    'portrait-video',
    'audio',
    'missing-image',
    'loading-image',
  ]) {
    final audio = variant == 'audio';
    final video = variant.contains('video');
    final portrait = variant.contains('portrait');
    final imageName = variant == 'missing-image'
        ? 'missing.png'
        : variant == 'loading-image'
        ? 'loading.png'
        : 'photo-$variant.png';
    b.add(
      'media-$variant',
      switch (variant) {
        'landscape' => 'Yatay fotoğraf',
        'portrait' => 'Dikey fotoğraf',
        'square' => 'Kare fotoğraf',
        'no-caption' => 'Başlıksız ve açıklamasız fotoğraf',
        'long-caption' => 'Uzun açıklamalı fotoğraf',
        'video' => 'Yatay video',
        'portrait-video' => 'Dikey video',
        'audio' => 'Profilde ses paylaşımı',
        'missing-image' => 'Görsel yükleme hatası',
        _ => 'Görsel yükleniyor',
      },
      'Profil medyası',
      MusicianFeedItemType.profileMedia,
      (id) => {
        'mediaAssetId': previewUuid('$id-media'),
        'kind': audio
            ? 'AUDIO'
            : video
            ? 'VIDEO'
            : 'IMAGE',
        'displayUrl': audio ? null : '$previewMediaBaseUrl/$imageName',
        'thumbnailUrl': audio ? null : '$previewMediaBaseUrl/$imageName',
        'playbackUrl': audio
            ? '$previewMediaBaseUrl/audio.wav'
            : video
            ? '$previewMediaBaseUrl/video.mp4'
            : null,
        'title': variant == 'no-caption'
            ? null
            : audio
            ? 'İlk demo · tek kayıt'
            : 'Prova odasından',
        'description': variant == 'no-caption'
            ? null
            : variant == 'long-caption'
            ? 'Bir şarkının son halini bulması bazen tek bir prova, bazen aylar sürüyor. Bugün herkesin başka bir fikirle geldiği ve aynı melodide buluştuğu günlerden biriydi. Yeni düzenlemeyi, sahnede nasıl duyulduğunu ve bütün o küçük detayları birlikte konuşmak istiyoruz.'
            : 'Akşam provasından küçük bir an. Birlikte çalmak iyi geliyor.',
        'durationSeconds': audio || video ? 8 : null,
        'width': audio
            ? null
            : portrait
            ? 720
            : variant == 'square'
            ? 1000
            : 1280,
        'height': audio
            ? null
            : portrait
            ? 1280
            : variant == 'square'
            ? 1000
            : 720,
      },
      targetType: 'MEDIA',
      targetId: (id) => previewUuid('$id-media'),
      includeInMixedFeed:
          variant != 'missing-image' && variant != 'loading-image',
      note: variant.endsWith('image')
          ? 'Medya hata/yükleme durumu yalnızca kart kataloğunda.'
          : null,
    );
  }
  for (final variant in [
    'regular',
    'paid-extra',
    'extra-unspecified',
    'band',
    'studio',
    'saved',
    'featured',
    'long-title',
  ]) {
    final extra = variant.contains('extra');
    final wanted = variant == 'band'
        ? 'BAND'
        : variant == 'studio'
        ? 'STUDIO'
        : 'MUSICIAN';
    b.add(
      'collab-$variant',
      switch (variant) {
        'regular' => 'Düzenli müzisyen arayışı',
        'paid-extra' => 'Ücreti belirtilmiş ekstra iş',
        'extra-unspecified' => 'Ücreti görüşülecek ekstra iş',
        'band' => 'Grup arayan mekân',
        'studio' => 'Stüdyo arayışı',
        'saved' => 'Kaydedilmiş Collab',
        'featured' => 'Öne çıkarılmış Collab',
        _ => 'Uzun ilan ve tür listesi',
      },
      'Collab',
      MusicianFeedItemType.collab,
      (id) => {
        'listing': {
          'id': id,
          'version': 1,
          'status': 'OPEN',
          'cadence': extra ? 'EXTRA' : 'REGULAR',
          'wantedType': wanted,
          'instrument': wanted == 'MUSICIAN'
              ? {'id': previewUuid('instrument-bass'), 'name': 'Bas Gitar'}
              : null,
          'title': variant == 'long-title'
              ? 'Hafta sonu sahneleri ve yeni kayıt projesi için birlikte üretebileceğimiz bas gitarist arıyoruz'
              : wanted == 'BAND'
              ? 'Cuma geceleri için akustik grup aranıyor'
              : wanted == 'STUDIO'
              ? 'Canlı kayıt için stüdyo arıyoruz'
              : 'Yeni projemize bas gitarist arıyoruz',
          'description':
              'Alternatif rock repertuvarı, düzenli prova ve birlikte üretim. Tanışıp bir prova yapalım.',
          'city': {'id': previewUuid('city-istanbul'), 'name': 'İstanbul'},
          'genres': variant == 'long-title'
              ? ['Alternatif rock', 'Anadolu psikedelik rock', 'Funk ve soul']
              : ['Alternatif', 'Rock'],
          'scheduledAt': extra
              ? b.now.add(const Duration(days: 7)).toIso8601String()
              : null,
          'expiresAt': b.now.add(const Duration(days: 30)).toIso8601String(),
          'feeStatus': variant == 'paid-extra'
              ? 'SPECIFIED'
              : extra
              ? 'UNSPECIFIED'
              : 'NOT_APPLICABLE',
          'feeAmountMinor': variant == 'paid-extra' ? 350000 : null,
          'currency': variant == 'paid-extra' ? 'TRY' : null,
          'publishedAt': b.now
              .subtract(const Duration(hours: 3))
              .toIso8601String(),
          'createdAt': b.now
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'publisher': b.collabPublisher(wanted == 'STUDIO' ? 0 : 3),
          'ownedByMe': false,
          'appliedByMe': false,
          'savedByMe': variant == 'saved',
          'applicationCount': 6,
        },
      },
      targetType: 'COLLAB',
      engagement: false,
      actor: wanted == 'STUDIO' ? 0 : 3,
      reason: extra ? 'CITY_MATCH' : 'CITY_AND_INSTRUMENT_MATCH',
      featured: variant == 'featured',
    );
  }
  for (final variant in [
    'poster',
    'fallback-solo',
    'fallback-band',
    'long-title',
    'venue-publisher',
    'featured',
    'share-note',
    'share-no-note',
  ]) {
    final share = variant.startsWith('share');
    final band = variant == 'fallback-band';
    b.add(
      'event-$variant',
      switch (variant) {
        'poster' => 'Özel afişli etkinlik',
        'fallback-solo' => 'Afişsiz solo etkinlik',
        'fallback-band' => 'Afişsiz grup etkinliği',
        'long-title' => 'Uzun etkinlik ve mekân adı',
        'venue-publisher' => 'Takip edilen mekânın etkinliği',
        'featured' => 'Öne çıkarılmış etkinlik',
        'share-note' => 'Notla paylaşılan etkinlik',
        _ => 'Notsuz etkinlik paylaşımı',
      },
      'Etkinlikler',
      share
          ? MusicianFeedItemType.eventProfileShare
          : MusicianFeedItemType.event,
      (id) => {
        'event': b.event(
          share ? previewUuid('$id-event') : id,
          band: band,
          poster: !variant.startsWith('fallback'),
          longTitle: variant == 'long-title',
        ),
        'note': variant == 'share-note'
            ? 'Bu akşam buradayım! Birlikte dinlemek isteyenlerle kapıda buluşalım.'
            : null,
        'publicationId': share ? id : null,
      },
      targetType: share ? 'EVENT_POST' : 'EVENT',
      actor: share
          ? 4
          : band
          ? 2
          : 0,
      reasonActor: variant == 'venue-publisher' ? 3 : null,
      featured: variant == 'featured',
    );
  }
  for (final module in ['overthinking', 'tablegroup']) {
    for (final variant in ['note', 'no-note', 'long', 'minimal']) {
      final over = module == 'overthinking';
      b.add(
        '$module-$variant',
        '${over ? 'Overthinking' : 'TableGroup'} · ${switch (variant) {
          'note' => 'paylaşım notu',
          'no-note' => over ? 'notsuz' : 'dolu masa · notsuz',
          'long' => over ? 'uzun içerik' : 'süresi dolmuş · uzun içerik',
          _ => over ? 'başlıksız kaynak' : 'mekân belirtilmemiş',
        }}',
        'Modül paylaşımları',
        over
            ? MusicianFeedItemType.overthinkingProfileShare
            : MusicianFeedItemType.tableGroupProfileShare,
        (id) => {
          'shareId': id,
          'publishedAt': b.now.toIso8601String(),
          'note': variant == 'no-note' || variant == 'minimal'
              ? null
              : over
              ? 'Bu konuşma bana iyi geldi; sizin de fikrinizi merak ediyorum.'
              : variant == 'long'
              ? 'Çok güzel bir akşamdı. Bir sonraki masada görüşürüz!'
              : 'Konser öncesi burada buluşuyoruz. Gelmek isteyen var mı?',
          'source': {
            'id': previewUuid('$id-source'),
            if (!over) 'tableGroupId': previewUuid('$id-source'),
            if (over)
              'title': variant == 'minimal'
                  ? null
                  : over
                  ? 'Sahneye çıkmadan önce aklından neler geçiyor?'
                  : 'Yeni sahneler, yeni şarkılar',
            'content': over
                ? (variant == 'long'
                      ? 'Bazen sahneden önceki sessizlik, şarkının kendisinden daha yüksek geliyor. Hata yapma ihtimalini, ilk alkışı ve dinleyicilerin yüzlerini düşünüyorum. Sonra ilk akor duyuluyor ve bütün bu düşünceler yerini müziğe bırakıyor. Bu duyguyu siz nasıl yaşıyorsunuz?'
                      : 'İlk akoru çalana kadar heyecan hiç geçmiyor. Sizde de böyle mi?')
                : null,
            'description': over
                ? null
                : variant == 'long'
                ? 'Bağımsız müzisyenlerin kayıt süreçlerini, küçük sahnelerde çalmanın zorluklarını, prova düzenini ve birbirimize nasıl destek olabileceğimizi konuştuğumuz bir masa. Deneyimlerini paylaşmak isteyen herkes katılabilir.'
                : variant == 'minimal'
                ? 'Yeni şarkılar keşfetmek için bir araya geliyoruz.'
                : 'Konserden önce tanışalım, müzik konuşalım.',
            if (!over) ...{
              'venueName': variant == 'minimal' ? null : 'Arka Oda',
              'cityName': 'İstanbul',
              'districtName': variant == 'minimal' ? null : 'Kadıköy',
              'meetingAt': b.now
                  .add(Duration(hours: variant == 'long' ? -3 : 3))
                  .toIso8601String(),
              'expiresAt': b.now
                  .add(Duration(hours: variant == 'long' ? -3 : 3))
                  .toIso8601String(),
              'status': variant == 'long' ? 'INACTIVE' : 'ACTIVE',
              'maxPersonCount': variant == 'minimal' ? 4 : 6,
              'acceptedCount': switch (variant) {
                'no-note' || 'long' => 6,
                'minimal' => 1,
                _ => 3,
              },
            },
          },
        },
        targetType: over ? 'OVERTHINKING_PROFILE_SHARE' : 'TABLE_GROUP_POST',
        actor: over ? 0 : 4,
        reason: over ? 'DISCOVERY' : 'FOLLOWING_PUBLICATION',
      );
    }
  }
  for (final profile in ['MUSICIAN', 'BAND', 'VENUE', 'STUDIO', 'LISTENER']) {
    b.add(
      'profile-${profile.toLowerCase()}',
      '${_profileLabel(profile)} profil önerisi',
      'Profiller',
      MusicianFeedItemType.profile,
      (id) => b.profile(id, profile),
      targetType: 'PROFILE',
      engagement: false,
      reason: 'DISCOVERY',
    );
  }
  b.add(
    'profile-followed',
    'Takip edilen profil',
    'Profiller',
    MusicianFeedItemType.profile,
    (id) => {...b.profile(id, 'MUSICIAN'), 'followedByViewer': true},
    targetType: 'PROFILE',
    engagement: false,
    reason: 'FOLLOWED_USER_FOLLOWED',
  );
  b.add(
    'profile-minimal',
    'Avatarsız ve biyografisiz profil',
    'Profiller',
    MusicianFeedItemType.profile,
    (id) => {
      ...b.profile(id, 'MUSICIAN'),
      'avatarUrl': null,
      'bio': null,
      'location': null,
    },
    targetType: 'PROFILE',
    engagement: false,
    reason: 'INSTRUMENT_MATCH',
  );
  for (final variant in [
    'follow',
    'like-track',
    'like-media',
    'like-event',
    'comment-track',
    'comment-share',
    'multiple',
  ]) {
    final follow = variant == 'follow';
    final comment = variant.startsWith('comment');
    final type = follow
        ? MusicianFeedItemType.activityFollow
        : comment
        ? MusicianFeedItemType.activityComment
        : MusicianFeedItemType.activityLike;
    final targetItemType = follow
        ? 'PROFILE'
        : variant.contains('event')
        ? 'EVENT'
        : variant.contains('media')
        ? 'PROFILE_MEDIA'
        : variant.contains('share')
        ? 'OVERTHINKING_PROFILE_SHARE'
        : 'TRACK';
    b.add(
      'activity-$variant',
      switch (variant) {
        'follow' => 'Takip aktivitesi',
        'like-track' => 'Parça beğenisi',
        'like-media' => 'Fotoğraf beğenisi',
        'like-event' => 'Etkinlik beğenisi',
        'comment-track' => 'Parçaya yorum aktivitesi',
        'comment-share' => 'Paylaşıma yorum aktivitesi',
        _ => 'Birden fazla kişinin sosyal kanıtı',
      },
      'Sosyal aktiviteler',
      type,
      (id) => {
        'action': follow
            ? 'FOLLOW'
            : comment
            ? 'COMMENT'
            : 'LIKE',
        'actor': b.actor(1),
        'targetItemType': targetItemType,
        'targetPayload': switch (targetItemType) {
          'PROFILE' => b.profile(id, 'MUSICIAN'),
          'EVENT' => {
            'event': b.event(id),
            'note': null,
            'publicationId': null,
          },
          'PROFILE_MEDIA' => {
            'mediaAssetId': id,
            'kind': 'IMAGE',
            'displayUrl': '$previewMediaBaseUrl/photo-social.png',
            'thumbnailUrl': '$previewMediaBaseUrl/photo-social.png',
            'playbackUrl': null,
            'title': 'Stüdyodan bir kare',
            'description': 'Yeni parçanın kayıtları başladı.',
            'durationSeconds': null,
            'width': 1000,
            'height': 1000,
          },
          'OVERTHINKING_PROFILE_SHARE' => {
            'shareId': id,
            'publishedAt': b.now.toIso8601String(),
            'note': null,
            'source': {
              'id': previewUuid('$id-source'),
              'title': 'Birlikte üretmek',
              'content':
                  'Bir fikrin şarkıya dönüşmesi bazen bir mesajla başlıyor.',
            },
          },
          _ => {
            'trackId': previewUuid('$id-track'),
            'mediaAssetId': id,
            'title': 'Sabahın İlk Işığı',
            'playbackUrl': '$previewMediaBaseUrl/audio.wav',
            'durationSeconds': 8,
            'bpm': 96,
          },
        },
      },
      targetType: follow
          ? 'PROFILE'
          : targetItemType == 'EVENT'
          ? 'EVENT'
          : targetItemType == 'OVERTHINKING_PROFILE_SHARE'
          ? 'OVERTHINKING_PROFILE_SHARE'
          : 'MEDIA',
      engagement: !follow,
      actor: 1,
      reasonActor: 1,
      others: variant == 'multiple' ? 4 : 0,
      reason: follow
          ? 'FOLLOWED_USER_FOLLOWED'
          : comment
          ? 'FOLLOWED_USER_COMMENTED'
          : 'FOLLOWED_USER_LIKED',
    );
  }
  for (final variant in ['many', 'one', 'done']) {
    b.add(
      'completion-$variant',
      switch (variant) {
        'many' => 'Profil tamamlama · görevler',
        'one' => 'Profil tamamlama · son görev',
        _ => 'Profil tamamlandı',
      },
      'Profil tamamlama',
      MusicianFeedItemType.profileCompletion,
      (_) => {
        'completed': variant == 'done'
            ? 4
            : variant == 'one'
            ? 3
            : 1,
        'total': 4,
        'tasks': [
          for (final task in [
            (
              'OPPORTUNITY_CITY',
              'Şehrini seç',
              'Yakınındaki sahne ve müzisyenleri keşfet.',
              'Şehir seç',
              '/backstage/feed/preferences',
            ),
            (
              'INSTRUMENTS',
              'Enstrümanını ekle',
              'Sana uygun müzisyen arayışlarını gör.',
              'Enstrüman ekle',
              '/profile/musician/edit',
            ),
            (
              'BIO',
              'Kendinden bahset',
              'Müzikal yolculuğunu birkaç cümleyle anlat.',
              'Profili düzenle',
              '/profile/musician/edit',
            ),
          ].indexed)
            {
              'code': task.$2.$1,
              'title': task.$2.$2,
              'description': task.$2.$3,
              'ctaLabel': task.$2.$4,
              'route': task.$2.$5,
              'priority': task.$1,
              'complete': variant == 'done' || variant == 'one' && task.$1 != 2,
            },
        ],
      },
      targetType: 'PROFILE',
      targetId: (_) => previewViewerProfileId,
      engagement: false,
      author: false,
      reason: 'PROFILE_INCOMPLETE',
      includeInMixedFeed: variant == 'many',
      note: variant == 'done'
          ? 'Tamamlanmış durum katalogda incelenir; gerçek akış bu kartı artık üretmez.'
          : null,
    );
  }
  for (final variant in ['image', 'text', 'long']) {
    b.add(
      'sponsor-$variant',
      variant == 'image'
          ? 'Görselli sponsorlu içerik'
          : variant == 'text'
          ? 'Metin sponsorlu içerik'
          : 'Uzun sponsor metni',
      'Sponsorlar',
      MusicianFeedItemType.sponsored,
      (id) => {
        'campaignId': id,
        'title': variant == 'long'
            ? 'Bir sonraki kaydında aradığın sesi birlikte bulalım'
            : 'Kayıt gününe hazır mısın?',
        'body': variant == 'long'
            ? 'Bağımsız müzisyenlere özel canlı kayıt, miks ve mastering çalışmaları. Projeyi birlikte dinliyor, ihtiyaçlarını belirliyor ve sana uygun bir kayıt planı hazırlıyoruz.'
            : 'Müzisyenlere özel prova ve canlı kayıt buluşmaları.',
        'mediaUrl': variant == 'text'
            ? null
            : '$previewMediaBaseUrl/sponsor.png',
        'ctaLabel': 'Ayrıntıları incele',
        'ctaUrl': 'https://preview.soundconnect.invalid/local/sponsor/$id',
      },
      targetType: 'STANDALONE',
      engagement: false,
      author: false,
      sponsored: true,
      reason: 'SPONSORED',
    );
  }
  for (final variant in ['text', 'image', 'video']) {
    b.add(
      'announcement-$variant',
      switch (variant) {
        'text' => 'SoundConnect · metin duyurusu',
        'image' => 'SoundConnect · fotoğraflı duyuru',
        _ => 'SoundConnect · videolu duyuru',
      },
      'Duyurular',
      MusicianFeedItemType.announcement,
      (id) => {
        'id': id,
        'version': 1,
        'title': variant == 'video'
            ? 'Yeni akışınla tanış'
            : 'Müzik burada bir araya geliyor',
        'body': variant == 'text'
            ? 'Takip ettiğin müzisyenler, yeni çalışmalar ve sana uygun fırsatlar aynı yerde. SoundConnect topluluğundaki yenilikleri artık akışından takip edebilirsin.'
            : 'Sahneni paylaş, yeni seslerle tanış. Birlikte ürettiğimiz her şey burada daha çok kişiye ulaşıyor.',
        'targetProfiles': ['MUSICIAN', 'LISTENER', 'VENUE', 'STUDIO'],
        'status': 'PUBLISHED',
        'startsAt': b.now.subtract(const Duration(hours: 4)).toIso8601String(),
        'endsAt': null,
        'firstPublishedAt': b.now
            .subtract(const Duration(hours: 4))
            .toIso8601String(),
        'createdAt': b.now.subtract(const Duration(days: 1)).toIso8601String(),
        'updatedAt': b.now.toIso8601String(),
        'media': variant == 'text'
            ? null
            : {
                'assetId': previewUuid('$id-media'),
                'kind': variant == 'video' ? 'VIDEO' : 'IMAGE',
                'status': 'READY',
                'streamingProtocol': 'PROGRESSIVE',
                'width': 1280,
                'height': 720,
                'durationSeconds': variant == 'video' ? 8 : null,
              },
        'engagement': {'likeCount': 128, 'commentCount': 3, 'likedByMe': false},
        'feedHidden': false,
      },
      targetType: 'ANNOUNCEMENT',
      author: false,
      reason: 'PLATFORM_ANNOUNCEMENT',
      likes: 128,
    );
  }
  return List.unmodifiable(b.items);
}

class _Catalogue {
  _Catalogue(this.now);
  final DateTime now;
  final items = <PreviewFeedScenario>[];
  void add(
    String slug,
    String label,
    String category,
    MusicianFeedItemType type,
    Map<String, dynamic> Function(String) payload, {
    required String targetType,
    String Function(String)? targetId,
    bool engagement = true,
    bool author = true,
    int actor = 0,
    int? reasonActor,
    int others = 0,
    String reason = 'FOLLOWING_PUBLICATION',
    int likes = 42,
    int comments = 3,
    bool liked = false,
    bool featured = false,
    bool sponsored = false,
    bool includeInMixedFeed = true,
    String? note,
  }) {
    final id = previewUuid(slug);
    final target = targetId?.call(id) ?? id;
    final capabilities = type == MusicianFeedItemType.announcement
        ? ['HIDE']
        : type == MusicianFeedItemType.profileCompletion
        ? ['HIDE']
        : ['HIDE', 'SHOW_LESS', 'REPORT'];
    final rawPayload = payload(id);
    final rawAuthor = type == MusicianFeedItemType.profile
        ? rawPayload
        : this.actor(actor);
    final item = MusicianFeedItem.fromJson({
      'id': '${type.apiValue}:$id',
      'type': type.apiValue,
      'payloadVersion': 1,
      'occurredAt': now
          .subtract(Duration(minutes: items.length * 3 + 1))
          .toIso8601String(),
      'position': items.length,
      'impressionToken': 'preview-only-$id',
      'reason': {
        'code': reason,
        'actors': [if (reasonActor != null) this.actor(reasonActor)],
        'secondaryActorCount': others,
      },
      'author': author ? rawAuthor : null,
      'target': {'type': targetType, 'id': target},
      'engagement': engagement
          ? {
              'targetType': targetType,
              'targetId': target,
              'likeCount': likes,
              'commentCount': comments,
              'likedByMe': liked,
              'likable': true,
              'commentable': true,
            }
          : null,
      'promotion': featured || sponsored
          ? {
              'campaignId': sponsored ? id : previewUuid('$slug-campaign'),
              'disclosure': featured ? 'FEATURED' : 'SPONSORED',
              'ctaLabel': sponsored ? 'Ayrıntıları incele' : null,
              'ctaUrl': sponsored
                  ? 'https://preview.soundconnect.invalid/local/sponsor/$id'
                  : null,
            }
          : null,
      'feedbackCapabilities': capabilities,
      'payload': rawPayload,
    });
    items.add(
      PreviewFeedScenario(
        id: slug,
        label: label,
        category: category,
        item: item,
        note: note,
        includeInMixedFeed: includeInMixedFeed,
      ),
    );
  }

  Map<String, dynamic> actor(int index) {
    final actors = [
      ('MUSICIAN', 'ada_gitar', 'Ada Yılmaz'),
      ('MUSICIAN', 'selin_vokal', 'Selin Aksoy'),
      ('BAND', 'kiyi_kolektif', 'Kıyı Kolektif'),
      ('VENUE', 'kiyi_sahne', 'Kıyı Sahne'),
      ('LISTENER', 'ece_dinliyor', 'Ece'),
      ('STUDIO', 'oda_studyo', 'Oda Stüdyo'),
    ];
    final value = actors[index % actors.length];
    return {
      'userId': previewUuid('user-$index'),
      'profileId': previewUuid('profile-$index'),
      'profileType': value.$1,
      'username': value.$2,
      'displayName': value.$3,
      'avatarUrl': '$previewMediaBaseUrl/avatar-$index.png',
      'followedByViewer': true,
    };
  }

  Map<String, dynamic> collabPublisher(int index) {
    final value = actor(index);
    return {
      'actorId': previewUuid('collab-actor-$index'),
      'profileType': value['profileType'],
      'sourceProfileId': value['profileId'],
      'contactUserId': value['userId'],
      'contactUsername': value['username'],
      'displayName': value['displayName'],
      'avatarUrl': value['avatarUrl'],
      'rating': 4.8,
      'reviewCount': 12,
      'completedJobCount': 31,
    };
  }

  Map<String, dynamic> profile(String id, String type) => {
    'profileId': id,
    'profileType': type,
    'userId': previewUuid('$id-user'),
    'username': 'deniz_akustik',
    'displayName': switch (type) {
      'BAND' => 'Kıyı Kolektif',
      'VENUE' => 'Kıyı Sahne',
      'STUDIO' => 'Oda Stüdyo',
      'LISTENER' => 'Ece',
      _ => 'Deniz Kaya',
    },
    'avatarUrl':
        '$previewMediaBaseUrl/avatar-${switch (type) {
          'BAND' => 2,
          'VENUE' => 3,
          'LISTENER' => 4,
          'STUDIO' => 5,
          _ => 0,
        }}.png',
    'bio': type == 'MUSICIAN'
        ? 'Alternatif rock, caz ve akustik projelerde gitar çalıyorum. Yeni seslere ve ortak üretime açığım.'
        : 'Müziğin etrafında buluşuyoruz.',
    'location': 'Kadıköy, İstanbul',
    'followedByViewer': false,
  };
  Map<String, dynamic> event(
    String id, {
    bool band = false,
    bool poster = true,
    bool longTitle = false,
  }) => {
    'id': id,
    'title': longTitle
        ? 'Yazdan Kalan Şarkılar · Akustik Buluşmalar ve Yeni Seslerle Uzun Bir Gece'
        : 'Kıyıda Akustik Gece',
    'performerName': band ? 'Kıyı Kolektif' : 'ada_gitar',
    'performerType': band ? 'BAND' : 'MUSICIAN',
    'musicianProfileId': band ? null : previewUuid('profile-0'),
    'bandId': band ? previewUuid('profile-2') : null,
    'performerImageUrl': '$previewMediaBaseUrl/avatar-${band ? 2 : 0}.png',
    'bandMembers': band ? ['Ada', 'Selin', 'Emre'] : <String>[],
    'venueId': previewUuid('profile-3'),
    'venueName': longTitle
        ? 'Kıyı Sahne · Moda Kültür ve Canlı Performans Alanı'
        : 'Kıyı Sahne',
    'venueCity': 'İstanbul',
    'venueDistrict': 'Kadıköy',
    'venueNeighborhood': 'Moda',
    'eventDate': now
        .add(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10),
    'startTime': '20:30',
    'endTime': '23:00',
    'posterImageUrl': poster ? '$previewMediaBaseUrl/poster.png' : null,
    'description':
        'Bağımsız müzisyenlerle akustik bir akşam. Kapılar 20.00’de açılıyor.',
  };
}

String _profileLabel(String type) => switch (type) {
  'MUSICIAN' => 'Müzisyen',
  'BAND' => 'Grup',
  'VENUE' => 'Mekân',
  'STUDIO' => 'Stüdyo',
  _ => 'Dinleyici',
};
