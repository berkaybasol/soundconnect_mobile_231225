import 'package:flutter/foundation.dart';

import '../../../../core/error/result.dart';
import '../../../location/domain/entities/city.dart';
import '../../../location/domain/location_repository.dart';
import '../../domain/musician_feed_preferences.dart';
import '../../domain/musician_feed_preferences_repository.dart';

/// Owns the opportunity-city draft and the existing version-conflict retry.
/// Both the standalone sheet and profile-completion form use this state.
class MusicianFeedOpportunityCityController extends ChangeNotifier {
  MusicianFeedOpportunityCityController({
    required MusicianFeedPreferencesRepository preferencesRepository,
    required LocationRepository locationRepository,
    bool Function()? isCurrent,
  }) : _preferencesRepository = preferencesRepository,
       _locationRepository = locationRepository,
       _isCurrent = isCurrent;

  static const _preferenceVersionConflictCode = '1317';

  final MusicianFeedPreferencesRepository _preferencesRepository;
  final LocationRepository _locationRepository;
  final bool Function()? _isCurrent;
  MusicianFeedPreferences? _preferences;
  List<City> _cities = const [];
  String? _selectedId;
  bool _loading = true;
  bool _loadingRequest = false;
  bool _saving = false;
  bool _disposed = false;
  String? _error;

  MusicianFeedPreferences? get preferences => _preferences;
  List<City> get cities => _cities;
  String? get selectedId => _selectedId;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;
  bool get hasChanges =>
      _preferences != null && _selectedId != _preferences!.opportunityCity?.id;

  bool _checkCurrent() {
    if (_disposed) return false;
    if (_isCurrent?.call() ?? true) return true;
    _loading = false;
    _loadingRequest = false;
    _saving = false;
    _error = 'Oturum değişti. Lütfen yeniden dene.';
    notifyListeners();
    return false;
  }

  Future<void> load() async {
    if (_disposed || _loadingRequest || _saving || !_checkCurrent()) return;
    _loadingRequest = true;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      late Result<MusicianFeedPreferences> preferencesResult;
      late Result<List<City>> citiesResult;
      await Future.wait<void>([
        () async {
          preferencesResult = await _preferencesRepository.get();
        }(),
        () async {
          citiesResult = await _locationRepository.getCities();
        }(),
      ]);
      if (!_checkCurrent()) return;
      final preferences = preferencesResult.data;
      final cities = citiesResult.data;
      if (!preferencesResult.isSuccess ||
          !citiesResult.isSuccess ||
          preferences == null ||
          cities == null) {
        _error =
            preferencesResult.error?.message ??
            citiesResult.error?.message ??
            'Şehirler yüklenemedi.';
      } else {
        _preferences = preferences;
        _cities = List.unmodifiable(cities);
        _selectedId = preferences.opportunityCity?.id;
      }
      _loading = false;
      _loadingRequest = false;
      notifyListeners();
    } catch (_) {
      if (!_checkCurrent()) return;
      _loading = false;
      _loadingRequest = false;
      _error = 'Şehirler yüklenemedi. Lütfen tekrar dene.';
      notifyListeners();
    }
  }

  void selectCity(String? cityId) {
    if (_disposed || _loading || _saving || !_checkCurrent()) return;
    if (cityId != null && !_cities.any((city) => city.id == cityId)) return;
    _selectedId = cityId;
    _error = null;
    notifyListeners();
  }

  Future<bool> save() async {
    final preferences = _preferences;
    if (_disposed ||
        _saving ||
        _loading ||
        preferences == null ||
        !_checkCurrent()) {
      return false;
    }
    final requestedCityId = _selectedId;
    _saving = true;
    _error = null;
    notifyListeners();

    var expectedVersion = preferences.version;
    var refreshedAfterConflict = false;
    try {
      while (_checkCurrent()) {
        final result = await _preferencesRepository.updateOpportunityCity(
          cityId: requestedCityId,
          expectedVersion: expectedVersion,
        );
        if (!_checkCurrent()) return false;
        if (result.isSuccess && result.data != null) {
          _preferences = result.data;
          _selectedId = result.data!.opportunityCity?.id;
          _saving = false;
          notifyListeners();
          return true;
        }

        final error = result.error;
        if (!refreshedAfterConflict &&
            error?.code == _preferenceVersionConflictCode) {
          refreshedAfterConflict = true;
          final latestResult = await _preferencesRepository.get();
          if (!_checkCurrent()) return false;
          final latest = latestResult.data;
          if (!latestResult.isSuccess || latest == null) {
            _saving = false;
            _error =
                latestResult.error?.message ??
                'Güncel akış tercihlerin yüklenemedi. Seçimini koruduk; lütfen tekrar dene.';
            notifyListeners();
            return false;
          }
          expectedVersion = latest.version;
          _preferences = latest;
          notifyListeners();
          continue;
        }

        _saving = false;
        _error = error?.code == _preferenceVersionConflictCode
            ? 'Akış tercihlerin yeniden değişti. Seçimini koruduk; lütfen tekrar dene.'
            : error?.message ?? 'Şehir tercihi kaydedilemedi.';
        notifyListeners();
        return false;
      }
    } catch (_) {
      if (!_checkCurrent()) return false;
      _saving = false;
      _error = 'Şehir tercihi kaydedilemedi. Lütfen tekrar dene.';
      notifyListeners();
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
