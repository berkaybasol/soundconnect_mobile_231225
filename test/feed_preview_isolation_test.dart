import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/preview/runtime/preview_http.dart';
import 'package:soundconnect_23_12_25codx/preview/runtime/preview_isolation.dart';
import 'package:soundconnect_23_12_25codx/preview/runtime/preview_media.dart';
import 'package:soundconnect_23_12_25codx/preview/runtime/preview_session.dart';
import 'package:soundconnect_23_12_25codx/preview/domain/preview_feed_scenario.dart';

void main() {
  Map<Object?, Object?> status({bool qa = false}) => {
    'packageName': previewPackageName,
    'internetPermissionGranted': qa,
    'previewQa': qa,
    'registeredPluginNames': [
      ...previewNativePlugins,
      if (qa) 'integration_test',
    ],
  };
  test(
    'boot requires separate package, matching native QA state and no release',
    () {
      for (final qa in [false, true]) {
        validatePreviewIsolation(
          status(qa: qa),
          compiledForPreview: true,
          releaseMode: false,
          qa: qa,
        );
      }
      final invalid = [
        {
          ...status(),
          'packageName': previewPackageName.replaceAll('.preview', ''),
        },
        {...status(), 'internetPermissionGranted': true},
        {...status(), 'previewQa': true},
        {
          ...status(),
          'registeredPluginNames': [...previewNativePlugins, 'audio_service'],
        },
        {
          ...status(),
          'registeredPluginNames': ['just_audio'],
        },
        <Object?, Object?>{},
      ];
      for (final value in invalid) {
        expect(
          () => validatePreviewIsolation(
            value,
            compiledForPreview: true,
            releaseMode: false,
            qa: false,
          ),
          throwsStateError,
        );
      }
      expect(
        () => validatePreviewIsolation(
          status(),
          compiledForPreview: false,
          releaseMode: false,
          qa: false,
        ),
        throwsStateError,
      );
      expect(
        () => validatePreviewIsolation(
          status(),
          compiledForPreview: true,
          releaseMode: true,
          qa: false,
        ),
        throwsStateError,
      );
      expect(
        () => validatePreviewIsolation(
          status(qa: true),
          compiledForPreview: true,
          releaseMode: false,
          qa: false,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'media rejects real hosts, loopback, credentials, ports and traversal',
    () {
      for (final url in [
        'https://example.com/fixtures/photo.png',
        'http://preview.soundconnect.invalid/fixtures/photo.png',
        'http://127.0.0.1:8080/api/v1/feed',
        'https://preview.soundconnect.invalid:8080/fixtures/photo.png',
        'https://user@preview.soundconnect.invalid/fixtures/photo.png',
        'https://preview.soundconnect.invalid/fixtures/../photo.png',
        'https://preview.soundconnect.invalid/fixtures/photo.png?url=https://example.com',
        'https://preview.soundconnect.invalid/fixtures/photo.png#fragment',
      ]) {
        expect(
          () => previewFixtureName(Uri.parse(url)),
          throwsStateError,
          reason: url,
        );
      }
      expect(
        previewFixtureName(
          Uri.parse('https://preview.soundconnect.invalid/fixtures/photo.png'),
        ),
        'photo.png',
      );
    },
  );

  test(
    'image client serves bytes only and never delegates unknown requests',
    () async {
      final overrides = PreviewHttpOverrides({
        'photo.png': Uint8List.fromList([1, 2, 3]),
      });
      final client = overrides.createHttpClient(null);
      addTearDown(client.close);
      final request = await client.openUrl(
        'GET',
        Uri.parse('https://preview.soundconnect.invalid/fixtures/photo.png'),
      );
      request.headers.set('Accept', 'image/png');
      await request.addStream(const Stream.empty());
      final response = await request.close();
      expect(response.statusCode, 200);
      expect(response.contentLength, 3);
      expect(response.headers.contentType?.mimeType, 'image/png');
      expect(await response.expand((value) => value).toList(), [1, 2, 3]);
      expect(overrides.servedImages, 1);
      for (final target in [
        'https://example.com/image.png',
        'http://127.0.0.1:8080',
        'https://preview.soundconnect.invalid/fixtures/unknown.png',
      ]) {
        await expectLater(client.getUrl(Uri.parse(target)), throwsStateError);
      }
      await expectLater(
        client.openUrl(
          'POST',
          Uri.parse('https://preview.soundconnect.invalid/fixtures/photo.png'),
        ),
        throwsStateError,
      );
      expect(overrides.rejectedRequests, 4);
      final missing = await (await client.getUrl(
        Uri.parse('https://preview.soundconnect.invalid/fixtures/missing.png'),
      )).close();
      expect(missing.statusCode, 404);
      expect(await missing.toList(), [isEmpty]);
    },
  );

  test(
    'preview authentication is independent memory and resets on a new run',
    () async {
      final first = await createPreviewSession();
      final second = await createPreviewSession();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      expect(first.session.userId, previewViewerUserId);
      expect(first.session.username, previewViewerUsername);
      expect(first.session.token, endsWith('.preview-local-only'));
      await first.logout();
      expect(first.session.isAuthenticated, false);
      expect(second.session.isAuthenticated, true);
    },
  );
}
