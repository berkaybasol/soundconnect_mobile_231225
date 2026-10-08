import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_installation_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.soundconnect/push');
  late _Preferences preferences;
  late SharedPreferencesPushInstallationStore store;
  var native = false;
  var failNativeWrite = false;
  var failNativeRead = false;
  setUp(() {
    preferences = _Preferences();
    store = SharedPreferencesPushInstallationStore(preferences: preferences);
    native = false;
    failNativeWrite = false;
    failNativeRead = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'pushResetRequired') {
            if (failNativeRead) throw PlatformException(code: 'storage');
            return native;
          }
          if (call.method == 'setPushResetRequired') {
            if (failNativeWrite) throw PlatformException(code: 'storage');
            native = (call.arguments as Map)['required'] as bool;
            return null;
          }
          throw StateError('Unexpected method');
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'native reset survives a primary write failure and a fresh store',
    () async {
      preferences.failWrite = true;
      await store.setResetRequired(true);
      expect(native, isTrue);
      expect(preferences.required, isFalse);
      final restarted = SharedPreferencesPushInstallationStore(
        preferences: preferences,
      );
      expect(await restarted.resetRequired(), isTrue);
    },
  );

  test(
    'preferences reset survives an independent native write failure',
    () async {
      failNativeWrite = true;
      await store.setResetRequired(true);
      expect(native, isFalse);
      expect(preferences.required, isTrue);
      expect(await store.resetRequired(), isTrue);
    },
  );

  test('both failing reset writes report failure', () async {
    failNativeWrite = true;
    preferences.failWrite = true;
    await expectLater(store.setResetRequired(true), throwsStateError);
  });

  test(
    'partially clearing native latch does not clear primary reset',
    () async {
      await store.setResetRequired(true);
      preferences.failWrite = true;
      await expectLater(store.setResetRequired(false), throwsStateError);
      expect(native, isFalse);
      expect(await store.resetRequired(), isTrue);
    },
  );

  test(
    'partially clearing primary latch does not clear native reset',
    () async {
      await store.setResetRequired(true);
      failNativeWrite = true;
      await expectLater(store.setResetRequired(false), throwsStateError);
      expect(preferences.required, isFalse);
      expect(await store.resetRequired(), isTrue);
    },
  );

  test('unknown native state cannot approve reuse', () async {
    failNativeRead = true;
    await expectLater(store.resetRequired(), throwsStateError);
  });

  test('unknown primary state cannot approve reuse', () async {
    preferences.failRead = true;
    await expectLater(store.resetRequired(), throwsStateError);
  });

  test(
    'known reset remains required even when other store is unreadable',
    () async {
      await store.setResetRequired(true);
      failNativeRead = true;
      expect(await store.resetRequired(), isTrue);
      failNativeRead = false;
      preferences.failRead = true;
      expect(await store.resetRequired(), isTrue);
    },
  );

  test('successful reset clears both latches', () async {
    await store.setResetRequired(true);
    await store.setResetRequired(false);
    expect(native, isFalse);
    expect(preferences.required, isFalse);
    expect(await store.resetRequired(), isFalse);
  });
}

// Fault-injection fake intentionally exposes mutable state for storage failures.
// ignore: must_be_immutable
class _Preferences extends Fake implements SharedPreferencesAsync {
  bool required = false;
  bool failRead = false, failWrite = false;
  @override
  Future<bool?> getBool(String key) async {
    if (failRead) throw StateError('storage');
    return required;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    if (failWrite) throw StateError('storage');
    required = value;
  }
}
