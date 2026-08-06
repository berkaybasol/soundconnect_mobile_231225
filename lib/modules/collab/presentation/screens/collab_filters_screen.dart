import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../data/collab_discovery_mock_data.dart';
import '../../data/collab_mock_controller.dart';
import '../../domain/collab_discovery_models.dart';
import '../theme/collab_visual_theme.dart';
import '../widgets/collab_discovery_widgets.dart';
import 'collab_listing_detail_screen.dart';

enum _CollabResultSort { newest, soonest, feeHigh }

extension on _CollabResultSort {
  String get label => switch (this) {
    _CollabResultSort.newest => 'En yeni',
    _CollabResultSort.soonest => 'En yakın tarih',
    _CollabResultSort.feeHigh => 'Ücret yüksek',
  };
}

class CollabFiltersScreen extends StatefulWidget {
  const CollabFiltersScreen({
    required this.cadence,
    required this.direction,
    required this.initialFilter,
    this.searchQuery = '',
    this.sourceListings,
    this.controller,
    super.key,
  });

  final CollabCadence cadence;
  final CollabDirection? direction;
  final CollabDiscoveryFilter initialFilter;
  final String searchQuery;
  final List<CollabDiscoveryListing>? sourceListings;
  final CollabMockController? controller;

  @override
  State<CollabFiltersScreen> createState() => _CollabFiltersScreenState();
}

class _CollabFiltersScreenState extends State<CollabFiltersScreen> {
  late CollabDiscoveryFilter _draft;
  _CollabResultSort _sort = _CollabResultSort.newest;
  CollabMockController get _controller =>
      widget.controller ?? collabMockController;

  List<CollabDiscoveryListing> get _sourceListings =>
      widget.sourceListings ?? collabDiscoveryMockListings;

  List<String> get _cities =>
      _uniqueSorted(_sourceListings.map((listing) => listing.city));

  List<String> get _roles =>
      _uniqueSorted(_baseListings.map((listing) => listing.role));

  List<String> get _genres =>
      _uniqueSorted(_baseListings.expand((listing) => listing.genres));

  List<CollabDiscoveryListing> get _baseListings => _sourceListings
      .where((listing) => listing.cadence == widget.cadence)
      .where(
        (listing) =>
            widget.direction == null || listing.direction == widget.direction,
      )
      .where((listing) => listing.matches(widget.searchQuery))
      .toList(growable: false);

  List<CollabDiscoveryListing> get _results {
    final filtered = _baseListings.where(_draft.matches).toList();
    switch (_sort) {
      case _CollabResultSort.newest:
        return filtered;
      case _CollabResultSort.soonest:
        filtered.sort((a, b) {
          final left = a.occurrenceDate;
          final right = b.occurrenceDate;
          if (left == null && right == null) return 0;
          if (left == null) return 1;
          if (right == null) return -1;
          return left.compareTo(right);
        });
        return filtered;
      case _CollabResultSort.feeHigh:
        filtered.sort(
          (a, b) => (b.feeAmount ?? -1).compareTo(a.feeAmount ?? -1),
        );
        return filtered;
    }
  }

  @override
  void initState() {
    super.initState();
    _draft = widget.cadence == CollabCadence.regular
        ? widget.initialFilter.copyWith(clearDateRange: true)
        : widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientText(
              text: 'Collab',
              gradient: LinearGradient(colors: AppColors.brandGradient),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            Text(
              '${widget.cadence.label} ilanlarını filtrele',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _clearFilters,
            child: Text(
              'Temizle',
              style: TextStyle(
                color: AppColors.coralLight,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            sliver: SliverToBoxAdapter(
              child: CollabGradientFrame(
                radius: 20,
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ScopeSummary(
                      cadence: widget.cadence,
                      direction: widget.direction,
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useColumns = constraints.maxWidth >= 300;
                        return _FilterFields(
                          filter: _draft,
                          showDate: widget.cadence == CollabCadence.extra,
                          cities: _cities,
                          roles: _roles,
                          genres: _genres,
                          useColumns: useColumns,
                          onCityTap: _pickCity,
                          onProfileKindsTap: _pickProfileKinds,
                          onRoleTap: _pickRole,
                          onGenresTap: _pickGenres,
                          onDateTap: _pickDateRange,
                          onTimesTap: _pickTimeWindows,
                          onFeeChanged: (fee) {
                            setState(() => _draft = _draft.copyWith(fee: fee));
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 17),
                    _ApplyFiltersButton(
                      resultCount: results.length,
                      onPressed: () => Navigator.of(context).pop(_draft),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!_draft.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: _ActiveFilters(
                  filter: _draft,
                  onChanged: (filter) => setState(() => _draft = filter),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${results.length}',
                            style: TextStyle(
                              color: AppColors.coralLight,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const TextSpan(text: ' ilan bulundu'),
                        ],
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<_CollabResultSort>(
                      value: _sort,
                      borderRadius: BorderRadius.circular(14),
                      items: _CollabResultSort.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) setState(() => _sort = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (results.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _NoFilterResults(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
              sliver: SliverList.separated(
                itemCount: results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final listing = results[index];
                  return CollabListingCard(
                    listing: listing,
                    saved: _controller.isListingSaved(listing.id),
                    onSave: () => _toggleSaved(listing.id),
                    onTap: () => _openListing(listing),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  List<String> _uniqueSorted(Iterable<String> values) {
    final result = values.toSet().toList()..sort();
    return result;
  }

  void _clearFilters() {
    setState(() => _draft = const CollabDiscoveryFilter());
  }

  Future<void> _pickCity() async {
    final selected = await _showSingleSelect<String>(
      title: 'Şehir seç',
      options: _cities,
      selected: _draft.city,
      labelFor: (value) => value,
      allowAll: true,
    );
    if (!mounted || !selected.didChoose) return;
    setState(() {
      _draft = selected.value == null
          ? _draft.copyWith(clearCity: true)
          : _draft.copyWith(city: selected.value);
    });
  }

  Future<void> _pickRole() async {
    final selected = await _showSingleSelect<String>(
      title: 'Rol veya enstrüman seç',
      options: _roles,
      selected: _draft.role,
      labelFor: (value) => value,
      allowAll: true,
    );
    if (!mounted || !selected.didChoose) return;
    setState(() {
      _draft = selected.value == null
          ? _draft.copyWith(clearRole: true)
          : _draft.copyWith(role: selected.value);
    });
  }

  Future<void> _pickProfileKinds() async {
    final selected = await _showMultiSelect<CollabProfileKind>(
      title: 'Profil türleri',
      options: CollabProfileKind.values,
      selected: _draft.profileKinds,
      labelFor: (value) => value.label,
    );
    if (!mounted || selected == null) return;
    setState(() => _draft = _draft.copyWith(profileKinds: selected));
  }

  Future<void> _pickGenres() async {
    final selected = await _showMultiSelect<String>(
      title: 'Tarzlar',
      options: _genres,
      selected: _draft.genres,
      labelFor: (value) => value,
    );
    if (!mounted || selected == null) return;
    setState(() => _draft = _draft.copyWith(genres: selected));
  }

  Future<void> _pickTimeWindows() async {
    final selected = await _showMultiSelect<CollabTimeWindow>(
      title: 'Zaman tercihleri',
      options: CollabTimeWindow.values,
      selected: _draft.timeWindows,
      labelFor: (value) => value.label,
    );
    if (!mounted || selected == null) return;
    setState(() => _draft = _draft.copyWith(timeWindows: selected));
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final current = _draft.dateRange;
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: current == null
          ? null
          : DateTimeRange(start: current.start, end: current.end),
      helpText: 'İlan tarih aralığı',
      cancelText: 'Vazgeç',
      confirmText: 'Seç',
      saveText: 'Seç',
    );
    if (!mounted || selected == null) return;
    setState(() {
      _draft = _draft.copyWith(
        dateRange: CollabDateRange(start: selected.start, end: selected.end),
      );
    });
  }

  Future<_SingleSelection<T>> _showSingleSelect<T>({
    required String title,
    required List<T> options,
    required T? selected,
    required String Function(T value) labelFor,
    required bool allowAll,
  }) async {
    final result = await showModalBottomSheet<_SingleSelection<T>>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _SingleSelectSheet<T>(
        title: title,
        options: options,
        selected: selected,
        labelFor: labelFor,
        allowAll: allowAll,
      ),
    );
    return result ?? const _SingleSelection.cancelled();
  }

  Future<Set<T>?> _showMultiSelect<T>({
    required String title,
    required List<T> options,
    required Set<T> selected,
    required String Function(T value) labelFor,
  }) {
    return showModalBottomSheet<Set<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _MultiSelectSheet<T>(
        title: title,
        options: options,
        selected: selected,
        labelFor: labelFor,
      ),
    );
  }

  void _toggleSaved(String id) {
    _controller.toggleListingSaved(id);
    setState(() {});
  }

  void _openListing(CollabDiscoveryListing listing) {
    Navigator.of(context).push<void>(
      collabPageRoute(
        builder: (_) => CollabListingDetailScreen(
          listing: listing,
          controller: _controller,
          initiallySaved: _controller.isListingSaved(listing.id),
          showBottomNavigation: false,
          onSavedChanged: (saved) {
            if (!mounted) return;
            _controller.setListingSaved(listing.id, saved: saved);
            setState(() {});
          },
        ),
      ),
    );
  }
}

class _ScopeSummary extends StatelessWidget {
  const _ScopeSummary({required this.cadence, required this.direction});

  final CollabCadence cadence;
  final CollabDirection? direction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.filter_alt_outlined, color: AppColors.coralLight, size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '${cadence.label} · ${direction?.label ?? 'Tüm ilan yönleri'}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          'Akış seçimi',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _FilterFields extends StatelessWidget {
  const _FilterFields({
    required this.filter,
    required this.showDate,
    required this.cities,
    required this.roles,
    required this.genres,
    required this.useColumns,
    required this.onCityTap,
    required this.onProfileKindsTap,
    required this.onRoleTap,
    required this.onGenresTap,
    required this.onDateTap,
    required this.onTimesTap,
    required this.onFeeChanged,
  });

  final CollabDiscoveryFilter filter;
  final bool showDate;
  final List<String> cities;
  final List<String> roles;
  final List<String> genres;
  final bool useColumns;
  final VoidCallback onCityTap;
  final VoidCallback onProfileKindsTap;
  final VoidCallback onRoleTap;
  final VoidCallback onGenresTap;
  final VoidCallback onDateTap;
  final VoidCallback onTimesTap;
  final ValueChanged<CollabFeeFilter> onFeeChanged;

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      _FilterSelectionField(
        key: const ValueKey<String>('collab-filter-city'),
        label: 'Şehir',
        value: filter.city ?? 'Tümü',
        icon: Icons.location_on_outlined,
        onTap: onCityTap,
      ),
      _FilterSelectionField(
        key: const ValueKey<String>('collab-filter-profile-kinds'),
        label: 'Profil Türü',
        value: filter.profileKinds.isEmpty
            ? 'Müzisyen, Grup, Mekan, Stüdyo'
            : filter.profileKinds.map((kind) => kind.label).join(', '),
        icon: Icons.people_outline_rounded,
        onTap: onProfileKindsTap,
      ),
      _FilterSelectionField(
        key: const ValueKey<String>('collab-filter-role'),
        label: 'Rol / Enstrüman',
        value: filter.role ?? 'Tümü',
        icon: Icons.music_note_outlined,
        onTap: onRoleTap,
      ),
      _FilterSelectionField(
        key: const ValueKey<String>('collab-filter-genres'),
        label: 'Tarz (Opsiyonel)',
        value: filter.genres.isEmpty ? 'Tümü' : filter.genres.join(', '),
        icon: Icons.library_music_outlined,
        onTap: onGenresTap,
      ),
      if (showDate)
        _FilterSelectionField(
          key: const ValueKey<String>('collab-filter-date'),
          label: 'Tarih',
          value: _dateRangeText(filter.dateRange),
          icon: Icons.calendar_month_outlined,
          onTap: onDateTap,
        ),
      _FilterSelectionField(
        key: const ValueKey<String>('collab-filter-time'),
        label: 'Zaman',
        value: filter.timeWindows.isEmpty
            ? 'Tümü'
            : filter.timeWindows.map((window) => window.label).join(', '),
        icon: Icons.schedule_outlined,
        onTap: onTimesTap,
      ),
    ];

    return Column(
      children: [
        if (useColumns)
          for (var index = 0; index < fields.length; index += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: fields[index]),
                  if (index + 1 < fields.length) ...[
                    const SizedBox(width: 12),
                    Expanded(child: fields[index + 1]),
                  ] else ...[
                    const SizedBox(width: 12),
                    const Spacer(),
                  ],
                ],
              ),
            )
        else
          for (final field in fields)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: field),
        _FeeFilterSegment(value: filter.fee, onChanged: onFeeChanged),
      ],
    );
  }

  String _dateRangeText(CollabDateRange? range) {
    if (range == null) return 'Tümü';
    return '${_shortDate(range.start)} – ${_shortDate(range.end)}';
  }
}

class _FilterSelectionField extends StatelessWidget {
  const _FilterSelectionField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$label: $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 3, bottom: 7),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 49,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeeFilterSegment extends StatelessWidget {
  const _FeeFilterSegment({required this.value, required this.onChanged});

  final CollabFeeFilter value;
  final ValueChanged<CollabFeeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 3, bottom: 7),
          child: Text(
            'Ücret',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SegmentedButton<CollabFeeFilter>(
          segments: const [
            ButtonSegment(value: CollabFeeFilter.all, label: Text('Tümü')),
            ButtonSegment(value: CollabFeeFilter.paid, label: Text('Ücretli')),
            ButtonSegment(
              value: CollabFeeFilter.unspecified,
              label: Text('Belirtilmemiş'),
            ),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
          style: const ButtonStyle(
            visualDensity: VisualDensity(horizontal: -2, vertical: -1),
          ),
        ),
      ],
    );
  }
}

class _ApplyFiltersButton extends StatelessWidget {
  const _ApplyFiltersButton({
    required this.resultCount,
    required this.onPressed,
  });

  final int resultCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.brandGradient),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Center(
              child: Text(
                'Sonuçları Göster ($resultCount)',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.filter, required this.onChanged});

  final CollabDiscoveryFilter filter;
  final ValueChanged<CollabDiscoveryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (filter.city != null) {
      chips.add(
        _ActiveFilterChip(
          label: filter.city!,
          onDeleted: () => onChanged(filter.copyWith(clearCity: true)),
        ),
      );
    }
    if (filter.profileKinds.isNotEmpty) {
      chips.add(
        _ActiveFilterChip(
          label: filter.profileKinds.map((kind) => kind.label).join(', '),
          onDeleted: () => onChanged(
            filter.copyWith(profileKinds: const <CollabProfileKind>{}),
          ),
        ),
      );
    }
    if (filter.role != null) {
      chips.add(
        _ActiveFilterChip(
          label: filter.role!,
          onDeleted: () => onChanged(filter.copyWith(clearRole: true)),
        ),
      );
    }
    if (filter.genres.isNotEmpty) {
      chips.add(
        _ActiveFilterChip(
          label: filter.genres.join(', '),
          onDeleted: () => onChanged(filter.copyWith(genres: const <String>{})),
        ),
      );
    }
    if (filter.dateRange != null) {
      chips.add(
        _ActiveFilterChip(
          label:
              '${_shortDate(filter.dateRange!.start)} – ${_shortDate(filter.dateRange!.end)}',
          onDeleted: () => onChanged(filter.copyWith(clearDateRange: true)),
        ),
      );
    }
    if (filter.timeWindows.isNotEmpty) {
      chips.add(
        _ActiveFilterChip(
          label: filter.timeWindows.map((window) => window.label).join(', '),
          onDeleted: () => onChanged(
            filter.copyWith(timeWindows: const <CollabTimeWindow>{}),
          ),
        ),
      );
    }
    if (filter.fee != CollabFeeFilter.all) {
      chips.add(
        _ActiveFilterChip(
          label: filter.fee == CollabFeeFilter.paid
              ? 'Ücretli'
              : 'Ücret belirtilmemiş',
          onDeleted: () => onChanged(filter.copyWith(fee: CollabFeeFilter.all)),
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      side: BorderSide(color: Theme.of(context).dividerColor),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
    );
  }
}

class _SingleSelection<T> {
  const _SingleSelection(this.value) : didChoose = true;
  const _SingleSelection.cancelled() : value = null, didChoose = false;

  final T? value;
  final bool didChoose;
}

class _SingleSelectSheet<T> extends StatelessWidget {
  const _SingleSelectSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.allowAll,
  });

  final String title;
  final List<T> options;
  final T? selected;
  final String Function(T value) labelFor;
  final bool allowAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          if (allowAll)
            RadioListTile<T?>(
              value: null,
              groupValue: selected,
              title: const Text('Tümü'),
              onChanged: (_) =>
                  Navigator.of(context).pop(_SingleSelection<T>(null)),
            ),
          ...options.map(
            (option) => RadioListTile<T?>(
              value: option,
              groupValue: selected,
              title: Text(labelFor(option)),
              onChanged: (_) =>
                  Navigator.of(context).pop(_SingleSelection<T>(option)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiSelectSheet<T> extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelFor,
  });

  final String title;
  final List<T> options;
  final Set<T> selected;
  final String Function(T value) labelFor;

  @override
  State<_MultiSelectSheet<T>> createState() => _MultiSelectSheetState<T>();
}

class _MultiSelectSheetState<T> extends State<_MultiSelectSheet<T>> {
  late Set<T> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<T>.of(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: const Text('Tümünü temizle'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: widget.options
                    .map(
                      (option) => CheckboxListTile(
                        value: _selected.contains(option),
                        title: Text(widget.labelFor(option)),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selected.add(option);
                            } else {
                              _selected.remove(option);
                            }
                          });
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: const Text('Seçimleri Uygula'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoFilterResults extends StatelessWidget {
  const _NoFilterResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'Bu filtrelerle eşleşen ilan bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _shortDate(DateTime value) {
  const months = <String>[
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];
  return '${value.day} ${months[value.month - 1]}';
}
