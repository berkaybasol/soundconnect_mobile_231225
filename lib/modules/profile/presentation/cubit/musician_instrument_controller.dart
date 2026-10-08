import 'package:flutter/foundation.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/result.dart';
import '../../../instrument/domain/entities/instrument.dart';
import '../../../instrument/domain/instrument_repository.dart';
import '../../../musician_feed/domain/musician_feed_preferences.dart';
import '../../../musician_feed/domain/musician_feed_preferences_repository.dart';
import '../../data/models/musician_profile_save_request.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/musician_profile_repository.dart';

/// Shared instrument draft for the standalone editor and completion page.
class MusicianInstrumentController extends ChangeNotifier {
  MusicianInstrumentController({
    required this.profile,
    required this.instrumentsRepository,
    required this.preferencesRepository,
    required this.profileRepository,
    required this.sessions,
  }) : _userId = sessions.session.userId?.trim() ?? '',
       _token = sessions.session.token?.trim() ?? '';

  final MusicianProfile profile;
  final InstrumentRepository instrumentsRepository;
  final MusicianFeedPreferencesRepository preferencesRepository;
  final MusicianProfileRepository profileRepository;
  final AuthSessionManager sessions;
  final String _userId;
  final String _token;
  bool _disposed = false;
  int _generation = 0;
  bool loading = true;
  bool saving = false;
  String? error;
  List<Instrument> instruments = const [];
  Set<String> selectedIds = const {};
  Set<String> _savedIds = const {};

  bool get hasChanges => !setEquals(selectedIds, _savedIds);

  bool get isCurrent {
    final session = sessions.session;
    return !_disposed &&
        session.isAuthenticated &&
        session.isActive &&
        session.userId?.trim() == _userId &&
        session.token?.trim() == _token &&
        profile.userId.trim() == _userId;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed || saving) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    if (!isCurrent) {
      loading = false;
      error = 'Oturum değişti. Lütfen yeniden dene.';
      _notify();
      return;
    }
    late Result<List<Instrument>> catalogue;
    late Result<MusicianFeedPreferences> preferences;
    await Future.wait<void>(
      [
        () async => catalogue = await instrumentsRepository.getAll(),
        () async => preferences = await preferencesRepository.get(),
      ].map((request) => request()),
    );
    if (_disposed || generation != _generation) return;
    loading = false;
    if (!isCurrent) {
      error = 'Oturum değişti. Lütfen yeniden dene.';
    } else if (!catalogue.isSuccess || catalogue.data == null) {
      error = catalogue.error?.message ?? 'Enstrümanlar yüklenemedi.';
    } else {
      instruments = List.unmodifiable(catalogue.data!);
      final validIds = instruments.map((item) => item.id).toSet();
      final canonical = preferences.isSuccess
          ? preferences.data?.instruments
                .map((item) => item.id)
                .where(validIds.contains)
                .toSet()
          : null;
      final fallback = profile.instruments.map(_searchKey).toSet();
      selectedIds = Set.unmodifiable(
        canonical ??
            instruments
                .where((item) => fallback.contains(_searchKey(item.name)))
                .map((item) => item.id),
      );
      _savedIds = selectedIds;
      error = preferences.isSuccess
          ? null
          : 'Mevcut seçim doğrulanamadı; profildeki bilgiler gösteriliyor.';
    }
    _notify();
  }

  void toggle(String id) {
    if (loading ||
        saving ||
        !isCurrent ||
        !instruments.any((item) => item.id == id)) {
      return;
    }
    final next = Set<String>.of(selectedIds);
    if (!next.remove(id)) {
      if (next.length >= 50) {
        error = 'En fazla 50 enstrüman seçebilirsin.';
        _notify();
        return;
      }
      next.add(id);
    }
    selectedIds = Set.unmodifiable(next);
    error = null;
    _notify();
  }

  Future<bool> save() async {
    if (_disposed || loading || saving) return false;
    if (!isCurrent) {
      error = 'Oturum değişti. Lütfen yeniden dene.';
      _notify();
      return false;
    }
    final requested = Set<String>.unmodifiable(selectedIds);
    saving = true;
    error = null;
    _notify();
    final result = await profileRepository.updateMyProfile(
      MusicianProfileSaveRequest(
        instrumentIds: requested.toList(growable: false)..sort(),
      ),
      expectedSessionKey: _userId,
    );
    if (_disposed) return false;
    saving = false;
    final updated = result.data;
    if (!isCurrent) {
      error = 'Oturum değişti. Değişiklik sonucu gösterilmedi.';
    } else if (!result.isSuccess || updated == null) {
      error = result.error?.message ?? 'Enstrümanlar kaydedilemedi.';
    } else if (updated.id.trim().isEmpty ||
        updated.id.trim() != profile.id.trim() ||
        updated.userId.trim().isEmpty ||
        updated.userId.trim() != profile.userId.trim()) {
      error = 'Profil kimliği doğrulanamadı. Lütfen yeniden dene.';
    } else {
      _savedIds = requested;
      _notify();
      return true;
    }
    _notify();
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

String _searchKey(String value) => value
    .trim()
    .replaceAll('İ', 'i')
    .replaceAll('I', 'i')
    .replaceAll('ı', 'i')
    .toLowerCase();
