import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../location/domain/entities/city.dart';
import '../../../location/domain/location_repository.dart';
import '../../domain/musician_feed_preferences.dart';
import '../../domain/musician_feed_preferences_repository.dart';

String musicianFeedCitySearchKey(String value) => value
    .trim()
    .replaceAll(RegExp('[İIı]'), 'i')
    .replaceAll(RegExp('[Şş]'), 's')
    .replaceAll(RegExp('[Ğğ]'), 'g')
    .replaceAll(RegExp('[Üü]'), 'u')
    .replaceAll(RegExp('[Öö]'), 'o')
    .replaceAll(RegExp('[Çç]'), 'c')
    .toLowerCase();

List<City> filterMusicianFeedOpportunityCities(
  Iterable<City> cities,
  String query,
) {
  final normalizedQuery = musicianFeedCitySearchKey(query);
  return List<City>.unmodifiable(
    cities.where(
      (city) =>
          normalizedQuery.isEmpty ||
          musicianFeedCitySearchKey(city.name).contains(normalizedQuery),
    ),
  );
}

Future<bool> showMusicianFeedOpportunityCitySheet(
  BuildContext context, {
  required MusicianFeedPreferencesRepository preferencesRepository,
  required LocationRepository locationRepository,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.navBlueDeep,
    builder: (_) => _OpportunityCitySheet(
      preferencesRepository: preferencesRepository,
      locationRepository: locationRepository,
    ),
  );
  return changed ?? false;
}

class _OpportunityCitySheet extends StatefulWidget {
  const _OpportunityCitySheet({
    required this.preferencesRepository,
    required this.locationRepository,
  });

  final MusicianFeedPreferencesRepository preferencesRepository;
  final LocationRepository locationRepository;

  @override
  State<_OpportunityCitySheet> createState() => _OpportunityCitySheetState();
}

class _OpportunityCitySheetState extends State<_OpportunityCitySheet> {
  static const _preferenceVersionConflictCode = '1317';

  final _search = TextEditingController();
  MusicianFeedPreferences? _preferences;
  List<City> _cities = const [];
  String? _selectedId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      widget.preferencesRepository.get(),
      widget.locationRepository.getCities(),
    ]);
    if (!mounted) return;
    final preferencesResult = results[0];
    final citiesResult = results[1];
    final preferences = preferencesResult.data as MusicianFeedPreferences?;
    final cities = citiesResult.data as List<City>?;
    if (!preferencesResult.isSuccess ||
        !citiesResult.isSuccess ||
        preferences == null ||
        cities == null) {
      setState(() {
        _loading = false;
        _error =
            preferencesResult.error?.message ??
            citiesResult.error?.message ??
            'Şehirler yüklenemedi.';
      });
      return;
    }
    setState(() {
      _preferences = preferences;
      _cities = List.unmodifiable(cities);
      _selectedId = preferences.opportunityCity?.id;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final preferences = _preferences;
    if (_saving || preferences == null) return;
    final requestedCityId = _selectedId;
    setState(() {
      _saving = true;
      _error = null;
    });

    var expectedVersion = preferences.version;
    var refreshedAfterConflict = false;
    while (mounted) {
      final result = await widget.preferencesRepository.updateOpportunityCity(
        cityId: requestedCityId,
        expectedVersion: expectedVersion,
      );
      if (!mounted) return;
      if (result.isSuccess && result.data != null) {
        Navigator.of(context).pop(true);
        return;
      }

      final error = result.error;
      if (!refreshedAfterConflict &&
          error?.code == _preferenceVersionConflictCode) {
        refreshedAfterConflict = true;
        final latestResult = await widget.preferencesRepository.get();
        if (!mounted) return;
        final latest = latestResult.data;
        if (!latestResult.isSuccess || latest == null) {
          setState(() {
            _saving = false;
            _selectedId = requestedCityId;
            _error =
                latestResult.error?.message ??
                'Güncel akış tercihlerin yüklenemedi. Seçimini koruduk; lütfen tekrar dene.';
          });
          return;
        }
        expectedVersion = latest.version;
        setState(() {
          _preferences = latest;
          _selectedId = requestedCityId;
        });
        continue;
      }

      setState(() {
        _saving = false;
        _selectedId = requestedCityId;
        _error = error?.code == _preferenceVersionConflictCode
            ? 'Akış tercihlerin yeniden değişti. Seçimini koruduk; lütfen tekrar dene.'
            : error?.message ?? 'Şehir tercihi kaydedilemedi.';
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .84,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          2,
          18,
          14 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Fırsat şehrin',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              'Collab ve etkinlikleri yaşadığın adrese göre değil, fırsat görmek istediğin şehre göre sıralarız.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              enabled: !_loading && !_saving,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Şehir ara',
                prefixIcon: const BrandGradientIcon.social(
                  Icons.search_rounded,
                ),
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: _body()),
            if (_error != null && !_loading) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: GradientOutlineButton(
                label: 'Şehri kaydet',
                loading: _saving,
                onPressed: _loading || _preferences == null ? null : _save,
                backgroundColor: AppColors.navBlue,
                leading: const Icon(Icons.check_rounded, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_preferences == null) {
      return Center(
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tekrar dene'),
        ),
      );
    }
    final visible = filterMusicianFeedOpportunityCities(_cities, _search.text);
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandGradientIcon.social(
                Icons.search_off_rounded,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                'Aramana uygun şehir bulunamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final city = visible[index];
        final selected = city.id == _selectedId;
        return ListTile(
          minTileHeight: 50,
          enabled: !_saving,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? AppColors.coral : AppColors.textMuted,
          ),
          title: Text(
            city.name,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          onTap: () => setState(() => _selectedId = city.id),
        );
      },
    );
  }
}
