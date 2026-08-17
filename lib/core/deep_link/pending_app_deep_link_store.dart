import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_deep_link.dart';

class PendingAppDeepLink {
  const PendingAppDeepLink({required this.target, required this.createdAt});

  final AppDeepLinkTarget target;
  final DateTime createdAt;

  String get identity =>
      '${target.listingId}|${createdAt.toUtc().toIso8601String()}';
}

abstract interface class PendingAppDeepLinkStore {
  Future<void> write(PendingAppDeepLink link);

  Future<PendingAppDeepLink?> read();

  /// Removes only [expected]. A newer link arriving while navigation is being
  /// prepared must never be erased by completion of the older one.
  Future<void> clearIfMatches(PendingAppDeepLink expected);
}

class SharedPreferencesPendingAppDeepLinkStore
    implements PendingAppDeepLinkStore {
  SharedPreferencesPendingAppDeepLinkStore({
    Future<SharedPreferences> Function()? preferencesLoader,
    DateTime Function()? clock,
    this.ttl = const Duration(hours: 24),
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _clock = clock ?? DateTime.now,
       assert(ttl > Duration.zero);

  static const String _storageKey = 'sc_pending_app_deep_link_v1';

  final Future<SharedPreferences> Function() _preferencesLoader;
  final DateTime Function() _clock;
  final Duration ttl;

  @override
  Future<void> write(PendingAppDeepLink link) async {
    final preferences = await _preferencesLoader();
    final persisted = await preferences.setString(
      _storageKey,
      jsonEncode(<String, Object>{
        'version': 1,
        'type': 'collab_listing',
        'listingId': link.target.listingId,
        'createdAt': link.createdAt.toUtc().toIso8601String(),
      }),
    );
    if (!persisted) {
      throw StateError('Pending app link could not be persisted.');
    }
  }

  @override
  Future<PendingAppDeepLink?> read() async {
    final preferences = await _preferencesLoader();
    final decoded = _decode(preferences.getString(_storageKey));
    if (decoded == null || _isExpired(decoded)) {
      await preferences.remove(_storageKey);
      return null;
    }
    return decoded;
  }

  @override
  Future<void> clearIfMatches(PendingAppDeepLink expected) async {
    final preferences = await _preferencesLoader();
    final current = _decode(preferences.getString(_storageKey));
    if (current == null || current.identity != expected.identity) return;
    final removed = await preferences.remove(_storageKey);
    if (!removed) {
      throw StateError('Pending app link could not be cleared.');
    }
  }

  bool _isExpired(PendingAppDeepLink link) {
    final age = _clock().toUtc().difference(link.createdAt.toUtc());
    return age.isNegative || age >= ttl;
  }

  PendingAppDeepLink? _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> ||
          value['version'] != 1 ||
          value['type'] != 'collab_listing') {
        return null;
      }
      final listingId = value['listingId']?.toString().trim() ?? '';
      final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
      final canonicalUri = SoundConnectLinks.listing(listingId);
      final target = AppDeepLinkParser.parse(canonicalUri);
      if (target == null || createdAt == null) return null;
      return PendingAppDeepLink(target: target, createdAt: createdAt.toUtc());
    } catch (_) {
      return null;
    }
  }
}

class MemoryPendingAppDeepLinkStore implements PendingAppDeepLinkStore {
  PendingAppDeepLink? value;

  @override
  Future<void> write(PendingAppDeepLink link) async => value = link;

  @override
  Future<PendingAppDeepLink?> read() async => value;

  @override
  Future<void> clearIfMatches(PendingAppDeepLink expected) async {
    if (value?.identity == expected.identity) value = null;
  }
}

enum AppDeepLinkClaimStatus { acquired, busy, empty }

class AppDeepLinkClaim {
  const AppDeepLinkClaim._(this.status, this.link);

  const AppDeepLinkClaim.acquired(PendingAppDeepLink link)
    : this._(AppDeepLinkClaimStatus.acquired, link);

  const AppDeepLinkClaim.busy() : this._(AppDeepLinkClaimStatus.busy, null);

  const AppDeepLinkClaim.empty() : this._(AppDeepLinkClaimStatus.empty, null);

  final AppDeepLinkClaimStatus status;
  final PendingAppDeepLink? link;
}

/// Process-wide inbox backed by durable storage. The volatile copy keeps link
/// navigation working even if platform preferences are temporarily unavailable.
class AppDeepLinkInbox {
  AppDeepLinkInbox({
    required PendingAppDeepLinkStore store,
    DateTime Function()? clock,
    this.duplicateWindow = const Duration(seconds: 2),
  }) : _store = store,
       _clock = clock ?? DateTime.now,
       assert(!duplicateWindow.isNegative);

  final PendingAppDeepLinkStore _store;
  final DateTime Function() _clock;
  final Duration duplicateWindow;
  PendingAppDeepLink? _volatile;
  String? _lastRecordedListingId;
  DateTime? _lastRecordedAt;
  Future<void> _storageTail = Future<void>.value();
  Future<void> _claimTail = Future<void>.value();
  String? _claimedIdentity;
  int _claimRevision = 0;
  Completer<void> _claimChanged = Completer<void>();

  int get claimRevision => _claimRevision;

  /// Waits for claim ownership to change without missing a release that races
  /// with subscription. The timeout bounds each wait so callers can re-check
  /// their own lifecycle even if a claim owner stalls.
  Future<void> waitForClaimChange({
    required int afterRevision,
    Duration timeout = const Duration(seconds: 2),
  }) {
    if (afterRevision != _claimRevision) return Future<void>.value();
    return _claimChanged.future.timeout(timeout, onTimeout: () {});
  }

  Future<PendingAppDeepLink?> record(AppDeepLinkTarget target) async {
    final now = _clock().toUtc();
    final lastRecordedAt = _lastRecordedAt;
    final sinceLastRecord = lastRecordedAt == null
        ? null
        : now.difference(lastRecordedAt);
    if (_lastRecordedListingId == target.listingId &&
        sinceLastRecord != null &&
        !sinceLastRecord.isNegative &&
        sinceLastRecord < duplicateWindow) {
      return null;
    }
    _lastRecordedListingId = target.listingId;
    _lastRecordedAt = now;
    final link = PendingAppDeepLink(target: target, createdAt: now);
    _volatile = link;
    await _enqueueStorage(() => _store.write(link));
    return link;
  }

  Future<PendingAppDeepLink?> pending() async {
    PendingAppDeepLink? stored;
    try {
      stored = await _store.read();
    } catch (_) {
      // Fall back to the process copy.
    }
    final volatile = _volatile;
    if (stored == null) return volatile;
    if (volatile == null || stored.createdAt.isAfter(volatile.createdAt)) {
      _volatile = stored;
      return stored;
    }
    return volatile;
  }

  /// Atomically reserves the current link for one navigation coordinator.
  /// Other coordinators receive [AppDeepLinkClaimStatus.busy] and must not
  /// perform fallback navigation while the owner is deciding the route.
  Future<AppDeepLinkClaim> claim() => _coordinateClaim(() async {
    if (_claimedIdentity != null) return const AppDeepLinkClaim.busy();
    final candidate = await pending();
    if (candidate == null) return const AppDeepLinkClaim.empty();
    _claimedIdentity = candidate.identity;
    _notifyClaimChanged();
    return AppDeepLinkClaim.acquired(candidate);
  });

  Future<void> complete(PendingAppDeepLink expected) =>
      _coordinateClaim(() async {
        if (_volatile?.identity == expected.identity) _volatile = null;
        await _enqueueStorage(() => _store.clearIfMatches(expected));
        if (_claimedIdentity == expected.identity) {
          _claimedIdentity = null;
          _notifyClaimChanged();
        }
      });

  /// Gives an unconsumed claim back to the inbox after a navigation failure or
  /// widget disposal. The durable target remains available for a later retry.
  Future<void> release(PendingAppDeepLink expected) =>
      _coordinateClaim(() async {
        if (_claimedIdentity == expected.identity) {
          _claimedIdentity = null;
          _notifyClaimChanged();
        }
      });

  void _notifyClaimChanged() {
    _claimRevision += 1;
    final changed = _claimChanged;
    _claimChanged = Completer<void>();
    if (!changed.isCompleted) changed.complete();
  }

  Future<T> _coordinateClaim<T>(Future<T> Function() operation) {
    final result = _claimTail.then<T>((_) => operation());
    _claimTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _enqueueStorage(Future<void> Function() operation) {
    final queued = _storageTail.then((_) async {
      try {
        await operation();
      } catch (_) {
        // The process copy keeps navigation working. A stale preference is
        // bounded by the store TTL and must not become a user-facing failure.
      }
    });
    _storageTail = queued;
    return queued;
  }
}
