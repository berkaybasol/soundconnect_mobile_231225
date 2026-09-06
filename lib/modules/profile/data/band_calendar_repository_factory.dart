import 'dart:async';

import '../../../core/network/api_client.dart';
import '../domain/musician_calendar_repository.dart';
import 'musician_calendar_repository_impl.dart';

/// Keeps one band-scoped repository only while a profile or its settings are
/// mounted. No visited-band cache, polling, or preference data is retained.
class BandCalendarRepositoryFactory {
  BandCalendarRepositoryFactory(
    this._api, {
    required String? Function() sessionKeyProvider,
    required Stream<void> refreshes,
    void Function()? onSettingsConfirmed,
  }) : _sessionKeyProvider = sessionKeyProvider,
       _onSettingsConfirmed = onSettingsConfirmed {
    _refreshSubscription = refreshes.listen((_) {
      for (final entry in _entries.values) {
        entry.repository.invalidate();
      }
    });
  }

  final ApiClient _api;
  final String? Function() _sessionKeyProvider;
  final void Function()? _onSettingsConfirmed;
  final Map<String, _BandCalendarEntry> _entries = {};
  late final StreamSubscription<void> _refreshSubscription;
  bool _disposed = false;

  MusicianCalendarRepository acquire(String bandId) {
    if (_disposed) throw StateError('Calendar repository factory is disposed.');
    final id = bandId.trim();
    if (id.isEmpty) throw ArgumentError.value(bandId, 'bandId');
    final entry = _entries.putIfAbsent(
      id,
      () => _BandCalendarEntry(
        MusicianCalendarRepositoryImpl(
          _api,
          sessionKeyProvider: _sessionKeyProvider,
          targetBandId: id,
          onSettingsConfirmed: _onSettingsConfirmed,
        ),
      ),
    );
    entry.references++;
    return entry.repository;
  }

  Future<void> release(String bandId) async {
    final id = bandId.trim();
    final entry = _entries[id];
    if (entry == null) return;
    entry.references--;
    if (entry.references == 0) {
      _entries.remove(id);
      await entry.repository.dispose();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _refreshSubscription.cancel();
    final repositories = _entries.values
        .map((entry) => entry.repository)
        .toList(growable: false);
    _entries.clear();
    await Future.wait(repositories.map((repository) => repository.dispose()));
  }
}

class _BandCalendarEntry {
  _BandCalendarEntry(this.repository);

  final MusicianCalendarRepository repository;
  int references = 0;
}
