import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_screen_support.dart';

void main() {
  group('profile screen support', () {
    test('validates network image urls', () {
      expect(isValidNetworkImageUrl('https://example.com/a.png'), isTrue);
      expect(isValidNetworkImageUrl('http://example.com/a.png'), isTrue);
      expect(isValidNetworkImageUrl('file:///tmp/a.png'), isFalse);
      expect(isValidNetworkImageUrl('example.com/a.png'), isFalse);
      expect(isValidNetworkImageUrl(null), isFalse);
    });

    test('infers image mime types', () {
      expect(inferImageMimeType('cover.png'), 'image/png');
      expect(inferImageMimeType('cover.webp'), 'image/webp');
      expect(inferImageMimeType('cover.jpg'), 'image/jpeg');
      expect(inferImageMimeType('cover.jpeg'), 'image/jpeg');
    });

    test('extracts file name from path with fallback', () {
      expect(
        fileNameFromPath(r'C:\music\cover.png', fallback: 'fallback.png'),
        'cover.png',
      );
      expect(fileNameFromPath('', fallback: 'fallback.png'), 'fallback.png');
    });
  });
}
