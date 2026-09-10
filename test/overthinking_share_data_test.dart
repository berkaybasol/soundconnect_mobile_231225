import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_data.dart';

void main() {
  test('public export carries the source text, author and music', () {
    final data = OverthinkingShareData.fromPost(_source());
    expect(data.postId, 'post');
    expect(data.title, 'Bir şarkının içinde');
    expect(data.content, 'Belki bir başkası da tam böyle hissediyordur.');
    expect(data.authorLabel, contains('berna'));
    expect(data.authorAvatarUrl, 'https://example.com/avatar.png');
    expect(data.trackName, 'BRLN');
    expect(data.artistName, 'Şair');
    expect(data.albumImageUrl, 'https://i.scdn.co/image/album');
    expect(data.anonymous, isFalse);
    expect(data.hasMusic, isTrue);
    expect(data.accessibilityDescription, contains(data.title));
    expect(data.accessibilityDescription, isNot(contains('author-secret-id')));
    expect(data.accessibilityDescription, isNot(contains('spotify-secret-id')));
  });

  for (final entry in <String, OverthinkingPost>{
    'anonymous source with accepted reveal': _source().copyWith(
      anonymous: true,
    ),
    'legacy anonymous visibility with visible author': _source().copyWith(
      visibilityType: 'ANONYMOUS',
    ),
    'hidden author even on a visible source': _source().copyWith(
      canViewAuthor: false,
    ),
    'missing authoritative author id': _source().copyWith(authorId: null),
    'blank authoritative author id': _source().copyWith(authorId: '  '),
  }.entries) {
    test('${entry.key} never exposes identity outside the app', () {
      final data = OverthinkingShareData.fromPost(entry.value);
      expect(data.anonymous, isTrue);
      expect(data.authorLabel, 'Anonim yazar');
      expect(data.authorAvatarUrl, isNull);
      expect(data.accessibilityDescription, isNot(contains('berna')));
      expect(
        data.accessibilityDescription,
        isNot(contains('author-secret-id')),
      );
    });
  }

  test('anonymous external data ignores viewer-specific reveal identity', () {
    final initial = _source().copyWith(anonymous: true);
    final revealed = initial.copyWith(
      authorUsername: 'accepted-identity',
      authorAvatarUrl: 'https://example.com/private-avatar.png',
      authorId: 'revealed-user-id',
      revealRequestPending: true,
    );
    expect(
      OverthinkingShareData.fromPost(
        initial,
      ).matches(OverthinkingShareData.fromPost(revealed)),
      isTrue,
    );
  });

  test(
    'counter and viewer reaction changes do not invalidate prepared art',
    () {
      final source = _source();
      expect(
        OverthinkingShareData.fromPost(source).matches(
          OverthinkingShareData.fromPost(
            source.copyWith(
              likeCount: 920,
              commentCount: 18,
              likedByMe: true,
              revealRequestPending: true,
            ),
          ),
        ),
        isTrue,
      );
    },
  );

  for (final entry in <String, OverthinkingPost>{
    'source id': _source().copyWith(id: 'another-post'),
    'title': _source().copyWith(title: 'Yeni başlık'),
    'content': _source().copyWith(content: 'Yeni içerik'),
    'public author': _source().copyWith(authorUsername: 'different'),
    'public avatar': _source().copyWith(authorAvatarUrl: null),
    'anonymity': _source().copyWith(anonymous: true),
    'music title': _source().copyWith(spotifyTrackName: 'Başka şarkı'),
    'music artist': _source().copyWith(spotifyArtistName: 'Başka sanatçı'),
    'album art': _source().copyWith(spotifyAlbumImageUrl: null),
  }.entries) {
    test('a changed ${entry.key} invalidates the prepared art', () {
      expect(
        OverthinkingShareData.fromPost(
          _source(),
        ).matches(OverthinkingShareData.fromPost(entry.value)),
        isFalse,
      );
    });
  }

  test('a post without music exports without a fabricated music label', () {
    final data = OverthinkingShareData.fromPost(
      _source().copyWith(
        spotifyTrackName: null,
        spotifyArtistName: null,
        spotifyAlbumImageUrl: null,
        spotifyTrackUrl: null,
      ),
    );
    expect(data.hasMusic, isFalse);
    expect(data.albumImageUrl, isNull);
    expect(data.accessibilityDescription, isNot(contains('BRLN')));
  });
}

OverthinkingPost _source() => OverthinkingPostModel.fromJson({
  'id': 'post',
  'title': 'Bir şarkının içinde',
  'content': 'Belki bir başkası da tam böyle hissediyordur.',
  'authorId': 'author-secret-id',
  'authorUsername': 'berna',
  'authorAvatarUrl': 'https://example.com/avatar.png',
  'anonymous': false,
  'canViewAuthor': true,
  'visibilityType': 'VISIBLE',
  'spotifyTrackName': 'BRLN',
  'spotifyArtistName': 'Şair',
  'spotifyArtistId': 'spotify-secret-id',
  'spotifyTrackUrl': 'https://open.spotify.com/track/track-id',
  'spotifyAlbumImageUrl': 'https://i.scdn.co/image/album',
  'likeCount': 8,
  'commentCount': 3,
});
