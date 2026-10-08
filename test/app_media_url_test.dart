import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/network/app_media_url.dart';

void main() {
  group('resolveMediaUrl', () {
    String? resolve(String? value, {Uri? baseUri}) {
      return resolveMediaUrl(
        value,
        baseUri: baseUri ?? Uri.parse('https://api.soundconnect.test'),
      );
    }

    test(
      'resolves backend relative paths against the configured HTTPS base',
      () {
        expect(
          resolve('/media/track.mp3'),
          'https://api.soundconnect.test/media/track.mp3',
        );
        expect(
          resolve(
            'media/track.mp3?version=2',
            baseUri: Uri.parse('https://api.soundconnect.test/v1'),
          ),
          'https://api.soundconnect.test/v1/media/track.mp3?version=2',
        );
        expect(
          resolve(
            'media/track.mp3',
            baseUri: Uri.parse('https://api.soundconnect.test/v1/'),
          ),
          'https://api.soundconnect.test/v1/media/track.mp3',
        );
      },
    );

    test('allows absolute HTTPS media without rewriting its origin', () {
      const url = 'https://cdn.soundconnect.test/media/photo.webp?version=2';
      expect(resolve(url), url);
      expect(resolve(url, baseUri: Uri.parse('http://127.0.0.1:8080')), url);
      expect(resolveMediaUrl(url, baseUri: null), url);
      expect(resolve('  $url  '), url);
    });

    test('rejects every plain HTTP media origin including local aliases', () {
      for (final host in [
        '127.0.0.1',
        'localhost',
        '[::1]',
        '10.0.2.2',
        '192.168.1.40',
        'media.example.com',
      ]) {
        final origin = 'http://$host:8080';
        expect(
          resolve('$origin/media/track.mp3', baseUri: Uri.parse(origin)),
          isNull,
          reason: 'HTTP media stays disabled for $host',
        );
        expect(
          resolve('/media/track.mp3', baseUri: Uri.parse(origin)),
          isNull,
          reason: 'relative media must not bypass HTTPS for $host',
        );
      }
    });

    test('rejects relative paths when no backend origin is available', () {
      expect(resolveMediaUrl('/media/track.mp3', baseUri: null), isNull);
      expect(resolveMediaUrl('media/track.mp3', baseUri: null), isNull);
    });

    test('rejects ambiguous or unsafe references', () {
      for (final value in [
        '//evil.example/media.png',
        'file:///tmp/media.png',
        'javascript:alert(1)',
        'https://user:secret@example.com/media.png',
        'https://example.com/media.png#fragment',
        r'..\media.png',
        'https://example.com/media\u0000.png',
        '',
        '  ',
        null,
      ]) {
        expect(resolve(value), isNull, reason: '$value');
      }
    });
  });

  group('isSafeMediaReference', () {
    test('allows relative and HTTP(S) references for runtime validation', () {
      expect(isSafeMediaReference('/media/image.png'), isTrue);
      expect(isSafeMediaReference('media/audio.mp3'), isTrue);
      expect(
        isSafeMediaReference('https://cdn.example.test/image.png'),
        isTrue,
      );
      const httpUrl = 'http://localhost:8080/image.png';
      expect(isSafeMediaReference(httpUrl), isTrue);
      expect(
        resolveMediaUrl(httpUrl, baseUri: Uri.parse('http://localhost:8080')),
        isNull,
        reason: 'syntax acceptance must not bypass runtime HTTPS policy',
      );
    });

    test('rejects unsafe media references before runtime resolution', () {
      for (final value in [
        '//example.test/image.png',
        'file:///tmp/media.png',
        'javascript:alert(1)',
        'https://user:secret@example.com/image.png',
        'https://example.com/image.png#fragment',
        r'..\media.png',
        '',
      ]) {
        expect(isSafeMediaReference(value), isFalse, reason: value);
      }
    });
  });
}
