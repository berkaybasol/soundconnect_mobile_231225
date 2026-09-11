import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../location/domain/entities/city.dart';
import '../../../location/domain/location_repository.dart';
import '../../domain/musician_feed_preferences.dart';
import '../../domain/musician_feed_preferences_repository.dart';
import '../musician_feed_visual_theme.dart';

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
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.pureBlack.withValues(alpha: 0.76),
    builder: (_) => _OpportunityCitySheetFrame(
      preferencesRepository: preferencesRepository,
      locationRepository: locationRepository,
    ),
  );
  return changed ?? false;
}

class _OpportunityCitySheetFrame extends StatelessWidget {
  const _OpportunityCitySheetFrame({
    required this.preferencesRepository,
    required this.locationRepository,
  });

  final MusicianFeedPreferencesRepository preferencesRepository;
  final LocationRepository locationRepository;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final keyboardVisible = keyboardInset > 0;
    final availableHeight = mediaQuery.size.height - keyboardInset;
    final largeText = mediaQuery.textScaler.scale(1) > 1.4;
    final compactLayout = keyboardVisible || largeText;
    final sheetHeight = keyboardVisible
        ? availableHeight
        : mediaQuery.size.height * (largeText ? .91 : .87);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: MusicianFeedThemeScope(
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: _OpportunityCitySheet(
              height: sheetHeight,
              compactLayout: compactLayout,
              preferencesRepository: preferencesRepository,
              locationRepository: locationRepository,
            ),
          ),
        ),
      ),
    );
  }
}

class _OpportunityCitySheet extends StatefulWidget {
  const _OpportunityCitySheet({
    required this.height,
    required this.compactLayout,
    required this.preferencesRepository,
    required this.locationRepository,
  });

  final double height;
  final bool compactLayout;
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
    final colors = Theme.of(context).colorScheme;
    final selectedCity = _cityForId(_selectedId);
    final compactLayout = widget.compactLayout;
    if (compactLayout) {
      return SizedBox(
        key: const Key('musician-feed-opportunity-city-sheet'),
        height: widget.height,
        child: _compactLayout(colors),
      );
    }
    return SizedBox(
      key: const Key('musician-feed-opportunity-city-sheet'),
      height: widget.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _OpportunityCityHeaderIcon(size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AKIŞ TERCİHİ',
                        style: TextStyle(
                          color: AppColors.socialPink,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Fırsat şehrin',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Collab ve etkinlikleri yaşadığın adrese göre değil, fırsat görmek istediğin şehre göre sıralarız.',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.42,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (selectedCity != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _SelectedCitySummary(city: selectedCity),
            ),
          _searchField(compact: false),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _body(),
            ),
          ),
          _saveArea(compact: false, includeError: true),
        ],
      ),
    );
  }

  Widget _compactLayout(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 9, 20, 0),
                  child: Row(
                    children: [
                      const BrandGradientIcon.social(
                        Icons.location_on_rounded,
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Fırsat şehrin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _searchField(compact: true)),
              if (_error != null && !_loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: _OpportunityCityError(message: _error!),
                  ),
                ),
              _compactBody(),
            ],
          ),
        ),
        _saveArea(compact: true, includeError: false),
      ],
    );
  }

  Widget _searchField({required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 7 : 12, 20, compact ? 6 : 10),
      child: TextField(
        key: const Key('musician-feed-city-search'),
        controller: _search,
        enabled: !_loading && !_saving,
        onChanged: (_) => setState(() {}),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        textInputAction: TextInputAction.search,
        cursorColor: AppColors.coralLight,
        decoration: InputDecoration(
          hintText: 'Şehir ara',
          prefixIcon: const BrandGradientIcon.social(
            Icons.search_rounded,
            size: 21,
          ),
          suffixIcon: _search.text.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: 'Aramayı temizle',
                  onPressed: _saving
                      ? null
                      : () {
                          _search.clear();
                          setState(() {});
                        },
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
          filled: true,
          fillColor: colors.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide(color: colors.outline),
          ),
        ),
      ),
    );
  }

  Widget _saveArea({required bool compact, required bool includeError}) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(20, compact ? 6 : 11, 20, compact ? 8 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (includeError && _error != null && !_loading) ...[
            _OpportunityCityError(message: _error!),
            const SizedBox(height: 10),
          ],
          _OpportunityCitySaveButton(
            label: 'Şehri kaydet',
            loading: _saving,
            onPressed: _loading || _preferences == null ? null : _save,
          ),
        ],
      ),
    );
  }

  City? _cityForId(String? id) {
    if (id == null) return null;
    for (final city in _cities) {
      if (city.id == id) return city;
    }
    return null;
  }

  Widget _compactBody() {
    if (_loading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_preferences == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar dene'),
          ),
        ),
      );
    }
    final visible = filterMusicianFeedOpportunityCities(_cities, _search.text);
    if (visible.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _emptySearchResult(),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      sliver: SliverList.separated(
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) => _cityTile(visible[index]),
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
      return _emptySearchResult();
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _cityTile(visible[index]),
    );
  }

  Widget _emptySearchResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandGradientIcon.social(Icons.search_off_rounded, size: 32),
            const SizedBox(height: 10),
            Text(
              'Aramana uygun şehir bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cityTile(City city) {
    final colors = Theme.of(context).colorScheme;
    final selected = city.id == _selectedId;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _saving ? null : () => setState(() => _selectedId = city.id),
          child: AnimatedContainer(
            key: Key('musician-feed-city-${city.id}'),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.socialPink.withValues(alpha: 0.10)
                  : colors.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppColors.socialPink.withValues(alpha: 0.72)
                    : colors.outline,
                width: selected ? 1.2 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.socialPink.withValues(alpha: 0.13)
                        : colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.coralLight.withValues(alpha: 0.42)
                          : colors.outlineVariant,
                    ),
                  ),
                  child: BrandGradientIcon.social(
                    selected ? Icons.check_rounded : Icons.location_on_outlined,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    city.name,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.socialPink.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.socialPink.withValues(alpha: 0.34),
                      ),
                    ),
                    child: Text(
                      'Seçili',
                      style: TextStyle(
                        color: AppColors.coralLight,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpportunityCityHeaderIcon extends StatelessWidget {
  const _OpportunityCityHeaderIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .33),
        gradient: LinearGradient(colors: AppColors.brandGradient),
        boxShadow: [
          BoxShadow(
            color: AppColors.socialPurple.withValues(alpha: 0.18),
            blurRadius: 20,
            spreadRadius: -6,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular((size * .33) - 1.2),
        ),
        child: Center(
          child: BrandGradientIcon.social(
            Icons.location_on_rounded,
            size: size * .46,
          ),
        ),
      ),
    );
  }
}

class _SelectedCitySummary extends StatelessWidget {
  const _SelectedCitySummary({required this.city});

  final City city;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('musician-feed-selected-city-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          const BrandGradientIcon.social(Icons.near_me_rounded, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Seçili şehir · ${city.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpportunityCityError extends StatelessWidget {
  const _OpportunityCityError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.error, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpportunityCitySaveButton extends StatelessWidget {
  const _OpportunityCitySaveButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !loading;
    final highlighted = onPressed != null || loading;
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: highlighted ? 1 : 0.58,
        child: Container(
          key: const Key('musician-feed-city-save'),
          height: 52,
          decoration: BoxDecoration(
            color: highlighted ? null : colors.surfaceContainerHigh,
            gradient: highlighted
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: AppColors.socialGradient,
                  )
                : null,
            borderRadius: BorderRadius.circular(17),
            border: highlighted ? null : Border.all(color: colors.outline),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: AppColors.socialPink.withValues(alpha: 0.22),
                      blurRadius: 18,
                      spreadRadius: -6,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  else
                    Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: highlighted
                          ? AppColors.white
                          : colors.onSurfaceVariant,
                    ),
                  const SizedBox(width: 9),
                  Text(
                    label,
                    style: TextStyle(
                      color: highlighted
                          ? AppColors.white
                          : colors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
