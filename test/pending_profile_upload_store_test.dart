import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/pending_profile_upload_store.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';

const _storageKey = 'soundconnect.pending_profile_uploads.v1';
const _corruptKey = 'soundconnect.pending_profile_uploads.v1.corrupt';

void main() {
  group('PendingProfileUpload attachment serialization', () {
    test('round-trips listener avatar expectedVersion', () {
      final pending = PendingProfileUpload(
        sessionKey: 'account-1',
        assetId: 'listener-avatar',
        ownerType: 'LISTENER_PROFILE',
        ownerId: 'listener-1',
        mediaKind: 'IMAGE',
        deadline: DateTime.utc(2030),
        retryIndex: 0,
        phase: PendingProfileUploadPhase.attaching,
        attachmentIntent: const ProfileUploadAttachmentIntent.profilePicture(
          profileType: 'LISTENER_PROFILE',
          expectedVersion: 12,
        ),
        completedMediaId: 'listener-avatar',
      );

      final encoded = pending.toJson();
      final attachment = encoded['attachment'] as Map<String, dynamic>;
      final restored = PendingProfileUpload.fromJson(encoded);

      expect(attachment['expectedVersion'], 12);
      expect(restored, isNotNull);
      expect(restored!.attachmentIntent.expectedVersion, 12);
    });

    test(
      'accepts a legacy non-listener queue item without expectedVersion',
      () {
        final pending = PendingProfileUpload(
          sessionKey: 'account-1',
          assetId: 'studio-avatar',
          ownerType: 'STUDIO_PROFILE',
          ownerId: 'studio-1',
          mediaKind: 'IMAGE',
          deadline: DateTime.utc(2030),
          retryIndex: 0,
          phase: PendingProfileUploadPhase.attaching,
          attachmentIntent: const ProfileUploadAttachmentIntent.profilePicture(
            profileType: 'STUDIO_PROFILE',
          ),
          completedMediaId: 'studio-avatar',
        );
        final legacyJson = pending.toJson();
        (legacyJson['attachment'] as Map<String, dynamic>).remove(
          'expectedVersion',
        );

        final restored = PendingProfileUpload.fromJson(legacyJson);

        expect(restored, isNotNull);
        expect(restored!.attachmentIntent.expectedVersion, isNull);
        expect(restored.attachmentIntent.profileType, 'STUDIO_PROFILE');
      },
    );
  });

  group('SharedPreferencesPendingProfileUploadStore', () {
    test(
      'quarantines only corrupt payload and keeps preferences usable',
      () async {
        final preferences = _FakePendingUploadPreferences(<String, String>{
          _storageKey: '{not-json',
        });
        final store = SharedPreferencesPendingProfileUploadStore(
          preferencesLoader: () async => preferences,
        );

        expect(await store.readAll(), isEmpty);
        expect(preferences.values[_storageKey], isNull);
        expect(preferences.values[_corruptKey], '{not-json');

        await store.upsert(_pending('asset-after-corruption'));

        final persisted = jsonDecode(preferences.values[_storageKey]!);
        expect(persisted, isA<Map<String, dynamic>>());
        expect((persisted as Map<String, dynamic>)['version'], 1);
        expect(persisted['items'], hasLength(1));
      },
    );

    test('setString false is surfaced and rolls back the cache', () async {
      final preferences = _FakePendingUploadPreferences()
        ..setStringResult = false;
      final store = SharedPreferencesPendingProfileUploadStore(
        preferencesLoader: () async => preferences,
      );

      await expectLater(
        store.upsert(_pending('asset-rejected')),
        throwsA(isA<PendingUploadPersistenceException>()),
      );

      preferences.setStringResult = true;
      expect(await store.readAll(), isEmpty);
      await store.upsert(_pending('asset-accepted'));
      expect(await store.readAll(), hasLength(1));
    });

    test('setString exception is surfaced and rolls back the cache', () async {
      final preferences = _FakePendingUploadPreferences()
        ..setStringError = StateError('disk unavailable');
      final store = SharedPreferencesPendingProfileUploadStore(
        preferencesLoader: () async => preferences,
      );

      await expectLater(
        store.upsert(_pending('asset-write-error')),
        throwsA(
          isA<PendingUploadPersistenceException>().having(
            (error) => error.cause,
            'cause',
            isA<StateError>(),
          ),
        ),
      );

      preferences.setStringError = null;
      expect(await store.readAll(), isEmpty);
    });
  });
}

PendingProfileUpload _pending(String assetId) => PendingProfileUpload(
  sessionKey: 'account-1',
  assetId: assetId,
  ownerType: 'MUSICIAN_PROFILE',
  ownerId: 'musician-1',
  mediaKind: 'IMAGE',
  deadline: DateTime.utc(2030),
  retryIndex: 0,
  phase: PendingProfileUploadPhase.uploading,
  attachmentIntent: const ProfileUploadAttachmentIntent.none(),
);

class _FakePendingUploadPreferences implements PendingUploadPreferences {
  _FakePendingUploadPreferences([Map<String, String>? seed])
    : values = <String, String>{...?seed};

  final Map<String, String> values;
  bool setStringResult = true;
  bool removeResult = true;
  Object? setStringError;
  Object? removeError;

  @override
  String? getString(String key) => values[key];

  @override
  Future<bool> remove(String key) async {
    final error = removeError;
    if (error != null) throw error;
    if (removeResult) values.remove(key);
    return removeResult;
  }

  @override
  Future<bool> setString(String key, String value) async {
    final error = setStringError;
    if (error != null) throw error;
    if (setStringResult) values[key] = value;
    return setStringResult;
  }
}
