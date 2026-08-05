import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_audio_file_support.dart';

void main() {
  group('ProfileUploadSource and cancellation', () {
    test('byte source reports exact size and can be reopened', () async {
      final source = ProfileUploadSource.bytes(<int>[1, 2, 3, 4]);

      expect(source.sizeBytes, 4);
      expect(await source.openRead().expand((chunk) => chunk).toList(), <int>[
        1,
        2,
        3,
        4,
      ]);
      expect(await source.openRead().expand((chunk) => chunk).toList(), <int>[
        1,
        2,
        3,
        4,
      ]);
    });

    test('cancellation is idempotent and notifies a late listener once', () {
      final cancellation = ProfileUploadCancellation();
      cancellation.cancel('user-request');
      cancellation.cancel('ignored');
      final reasons = <Object?>[];

      cancellation.attach(reasons.add);

      expect(cancellation.isCancelled, isTrue);
      expect(cancellation.reason, 'user-request');
      expect(reasons, <Object?>['user-request']);
    });

    test('detach removes the active listener before cancellation', () {
      final cancellation = ProfileUploadCancellation();
      final reasons = <Object?>[];

      cancellation.attach(reasons.add);
      cancellation.detach();
      cancellation.cancel('user-request');

      expect(cancellation.isCancelled, isTrue);
      expect(cancellation.reason, 'user-request');
      expect(reasons, isEmpty);
    });
  });

  group('Profile audio validation', () {
    test('reports supported formats with user-facing Turkish characters', () {
      expect(
        profileAudioUploadValidationError(fileName: 'kayıt.exe'),
        'Sadece ses dosyası seçilebilir: mp3, m4a, aac, wav, waw, ogg, flac',
      );
    });

    test('rejects image bytes disguised with an audio extension', () {
      expect(
        profileAudioUploadValidationError(
          fileName: 'kapak.mp3',
          bytes: Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0]),
        ),
        'Seçilen dosya bir görsel gibi görünüyor. Lütfen ses dosyası seç.',
      );
    });

    test('maps content mismatch detail to an actionable audio message', () {
      final message = profileAudioUploadFailureMessage(
        Exception(
          'Yüklenen dosyanın boyutu veya içerik türü başlatılan yükleme ile uyuşmuyor',
        ),
      );

      expect(
        message,
        'Bu dosya geçerli bir ses dosyası değil veya desteklenmiyor. '
        'Lütfen başka bir MP3, WAV, M4A, AAC, OGG ya da FLAC dosyası seç.',
      );
      expect(message, isNot(contains('Exception')));
    });

    test('does not expose unexpected technical upload failures', () {
      final message = profileAudioUploadFailureMessage(
        StateError('internal init-upload implementation detail'),
      );

      expect(message, 'Ses dosyası yüklenemedi. Lütfen tekrar dene.');
      expect(message, isNot(contains('init-upload')));
    });
  });
}
