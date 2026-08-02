import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/pending_draft_media_cleanup_store.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/pending_profile_upload_store.dart';

const _storageKey = 'soundconnect.pending_draft_media_cleanup.v1';
const _corruptKey = 'soundconnect.pending_draft_media_cleanup.v1.corrupt';

void main() {
  group('SharedPreferencesPendingDraftMediaCleanupStore', () {
    test('persists and restores the owner-scoped cleanup intent', () async {
      final preferences = _FakePreferences();
      final first = SharedPreferencesPendingDraftMediaCleanupStore(
        preferencesLoader: () async => preferences,
      );

      await first.upsert(_pending('asset-1'));
      final restarted = SharedPreferencesPendingDraftMediaCleanupStore(
        preferencesLoader: () async => preferences,
      );

      final restored = (await restarted.readAll()).single;
      expect(restored.sessionKey, 'account-1');
      expect(restored.assetId, 'asset-1');
      expect(restored.ownerType, 'STUDIO_PROFILE');
      expect(restored.ownerId, 'studio-1');
    });

    test(
      'quarantines corrupt state without sweeping arbitrary media',
      () async {
        final preferences = _FakePreferences(<String, String>{
          _storageKey: '{not-json',
        });
        final store = SharedPreferencesPendingDraftMediaCleanupStore(
          preferencesLoader: () async => preferences,
        );

        expect(await store.readAll(), isEmpty);
        expect(preferences.values[_storageKey], isNull);
        expect(preferences.values[_corruptKey], '{not-json');

        await store.upsert(_pending('asset-after-corruption'));
        final payload = jsonDecode(preferences.values[_storageKey]!);
        expect(payload, isA<Map<String, dynamic>>());
        expect((payload as Map<String, dynamic>)['version'], 1);
        expect(payload['items'], hasLength(1));
      },
    );

    test('failed persistence rolls back the in-memory queue', () async {
      final preferences = _FakePreferences()..setStringResult = false;
      final store = SharedPreferencesPendingDraftMediaCleanupStore(
        preferencesLoader: () async => preferences,
      );

      await expectLater(
        store.upsert(_pending('asset-rejected')),
        throwsA(isA<PendingUploadPersistenceException>()),
      );

      preferences.setStringResult = true;
      expect(await store.readAll(), isEmpty);
    });
  });
}

PendingDraftMediaCleanup _pending(String assetId) => PendingDraftMediaCleanup(
  sessionKey: 'account-1',
  assetId: assetId,
  ownerType: 'STUDIO_PROFILE',
  ownerId: 'studio-1',
  createdAt: DateTime.utc(2026, 7, 21),
);

class _FakePreferences implements PendingUploadPreferences {
  _FakePreferences([Map<String, String>? seed])
    : values = <String, String>{...?seed};

  final Map<String, String> values;
  bool setStringResult = true;
  bool removeResult = true;

  @override
  String? getString(String key) => values[key];

  @override
  Future<bool> remove(String key) async {
    if (removeResult) values.remove(key);
    return removeResult;
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (setStringResult) values[key] = value;
    return setStringResult;
  }
}
