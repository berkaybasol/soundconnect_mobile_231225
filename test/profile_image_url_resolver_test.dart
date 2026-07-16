import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/media_asset.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_image_url_resolver.dart';

void main() {
  const asset = MediaAsset(
    id: 'media-1',
    kind: 'IMAGE',
    sourceUrl: 'https://cdn.example.test/source.jpg',
    playbackUrl: 'https://cdn.example.test/playback.jpg',
    thumbnailUrl: 'https://cdn.example.test/thumb.jpg',
    title: null,
    durationSeconds: null,
  );

  test('compact media surfaces prefer the generated thumbnail', () {
    expect(
      resolveMediaPreviewImageUrl(asset),
      'https://cdn.example.test/thumb.jpg',
    );
  });

  test('detail media surfaces prefer the original source', () {
    expect(
      resolveMediaDetailImageUrl(asset),
      'https://cdn.example.test/source.jpg',
    );
  });

  test('resolver skips blank and unsafe values while retaining fallbacks', () {
    expect(
      resolveFirstRemoteImageUrl(const [
        ' ',
        'file:///tmp/private.jpg',
        'javascript:alert(1)',
        'https://cdn.example.test/fallback.jpg',
      ]),
      'https://cdn.example.test/fallback.jpg',
    );
  });
}
