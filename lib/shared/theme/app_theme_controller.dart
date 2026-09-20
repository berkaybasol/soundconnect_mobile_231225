import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/diagnostics/app_diagnostics.dart';

enum AppThemeVariant { dark, light }

/// Owns only presentation preference; changing it never recreates app services.
class AppThemeController extends ChangeNotifier {
  AppThemeController({Future<SharedPreferences> Function()? loadPreferences})
    : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static final AppThemeController instance = AppThemeController();
  static const preferenceKey = 'app_theme_variant';

  AppThemeVariant _variant = AppThemeVariant.dark;
  Future<void>? _initialization;
  Future<bool>? _pendingWrite;
  int _selectionRevision = 0;
  final Future<SharedPreferences> Function() _loadPreferences;

  AppThemeVariant get variant => _variant;

  Future<void> initialize() => _initialization ??= _load();

  Future<void> _load() async {
    final revision = _selectionRevision;
    try {
      final preferences = await _loadPreferences();
      final saved = preferences.getString(preferenceKey);
      // A choice made while storage loads takes priority over old data.
      if (revision != _selectionRevision) return;
      final restored = saved == AppThemeVariant.light.name
          ? AppThemeVariant.light
          : AppThemeVariant.dark;
      if (_variant != restored) {
        _variant = restored;
        notifyListeners();
      }
    } catch (error, stackTrace) {
      AppDiagnostics.reportRecoverable(
        source: 'theme-preference-load',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Applies immediately, then saves in order so rapid taps cannot store an
  /// older choice. Storage failure never blocks use of the selected theme.
  Future<bool> setVariant(AppThemeVariant value) {
    _selectionRevision += 1;
    if (_variant != value) {
      _variant = value;
      notifyListeners();
    }
    final previousWrite = _pendingWrite;
    final write = previousWrite == null
        ? _save(value)
        : previousWrite.then((_) => _save(value));
    _pendingWrite = write;
    write.then((_) {
      if (identical(_pendingWrite, write)) _pendingWrite = null;
    });
    return write;
  }

  Future<bool> _save(AppThemeVariant value) async {
    try {
      final preferences = await _loadPreferences();
      return await preferences.setString(preferenceKey, value.name);
    } catch (error, stackTrace) {
      AppDiagnostics.reportRecoverable(
        source: 'theme-preference-save',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
