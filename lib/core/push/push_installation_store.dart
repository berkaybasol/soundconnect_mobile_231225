import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'push_provider.dart';

class PushInstallationMutation {
  const PushInstallationMutation(this.installationId, this.clientRevision);
  final String installationId;
  final int clientRevision;
}

abstract interface class PushInstallationStore {
  Future<String> installationId();
  Future<PushInstallationMutation> nextMutation();
  Future<String?> ownerId();
  Future<void> setOwnerId(String? value);
  Future<bool> resetRequired();
  Future<void> setResetRequired(bool value);
}

/// A proof written only after native binding succeeds; includes its epoch so a
/// delayed write can never authorize another binding after a scope transition.
abstract interface class PushBindingContextStore {
  Future<String?> bindingContext();
  Future<void> setBindingContext(String value);
}

class SharedPreferencesPushInstallationStore
    implements PushInstallationStore, PushBindingContextStore {
  SharedPreferencesPushInstallationStore({SharedPreferencesAsync? preferences})
    : _providedPreferences = preferences;
  final SharedPreferencesAsync? _providedPreferences;
  late final SharedPreferencesAsync _preferences =
      _providedPreferences ?? SharedPreferencesAsync();
  static const _native = MethodChannel('com.soundconnect/push');
  bool get _usesNativeReset =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<String>? _installation;
  @override
  Future<String> installationId() {
    final cached = _installation;
    if (cached != null) return cached;
    final operation = _loadId();
    _installation = operation;
    return operation.catchError((Object error, StackTrace stack) {
      if (identical(_installation, operation)) _installation = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<String> _loadId() async {
    // Native no-backup storage prevents restoring one phone's installation ID
    // onto another phone and repeatedly stealing its device registration.
    final id = await const MethodChannel(
      'com.soundconnect/push',
    ).invokeMethod<String>('installationId');
    if (!PushTarget.isUuid(id)) {
      throw StateError('Invalid installation identity');
    }
    return id!;
  }

  @override
  Future<PushInstallationMutation> nextMutation() async {
    final value = await const MethodChannel(
      'com.soundconnect/push',
    ).invokeMapMethod<String, Object?>('nextMutation');
    final id = value?['installationId'];
    final revision = value?['clientRevision'];
    if (id is! String ||
        !PushTarget.isUuid(id) ||
        revision is! int ||
        revision < 1 ||
        revision > 9007199254740991) {
      throw StateError('Invalid installation mutation');
    }
    _installation = Future.value(id);
    return PushInstallationMutation(id, revision);
  }

  @override
  Future<String?> bindingContext() =>
      _preferences.getString('push.binding-context.v1');
  @override
  Future<void> setBindingContext(String value) =>
      _preferences.setString('push.binding-context.v1', value);

  @override
  Future<String?> ownerId() => _preferences.getString('push.owner.v1');
  @override
  Future<void> setOwnerId(String? value) => value == null
      ? _preferences.remove('push.owner.v1')
      : _preferences.setString('push.owner.v1', value);
  @override
  Future<bool> resetRequired() async {
    if (!_usesNativeReset) {
      return await _preferences.getBool('push.reset.v1') ?? false;
    }
    bool? native, preferences;
    Object? failure;
    try {
      native = await _native.invokeMethod<bool>('pushResetRequired');
      if (native == null) throw StateError('Invalid native reset state');
    } catch (error) {
      failure = error;
    }
    try {
      preferences = await _preferences.getBool('push.reset.v1') ?? false;
    } catch (error) {
      failure = error;
    }
    // Either latch is enough to require invalidation. Unknown state must never
    // be interpreted as permission to reuse a token.
    if (native == true || preferences == true) return true;
    if (failure != null) throw StateError('Push reset state unavailable');
    return false;
  }

  @override
  Future<void> setResetRequired(bool value) async {
    if (!_usesNativeReset) {
      await _preferences.setBool('push.reset.v1', value);
      return;
    }
    var nativeWritten = false;
    var preferencesWritten = false;
    try {
      await _native.invokeMethod<void>('setPushResetRequired', {
        'required': value,
      });
      nativeWritten = true;
    } catch (_) {
      // The independent preferences latch must still be attempted.
    }
    try {
      await _preferences.setBool('push.reset.v1', value);
      preferencesWritten = true;
    } catch (_) {
      // A successfully written native latch survives process death independently.
    }
    // Requiring a reset succeeds if either durable boundary accepted it; clearing
    // requires both so a partially cleared state cannot reopen native delivery.
    if (value
        ? !nativeWritten && !preferencesWritten
        : !nativeWritten || !preferencesWritten) {
      throw StateError('Push reset state could not be persisted');
    }
  }
}
