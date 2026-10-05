part of 'collab_discovery_screen.dart';

class _QuickSingleSelectSheet<T> extends StatelessWidget {
  const _QuickSingleSelectSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelFor,
  });

  final String title;
  final List<T> options;
  final T? selected;
  final String Function(T value) labelFor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: Padding(
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
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  RadioListTile<T?>(
                    value: null,
                    groupValue: selected,
                    title: const Text('Tümü'),
                    onChanged: (_) =>
                        Navigator.of(context).pop(_QuickSelection<T>(null)),
                  ),
                  ...options.map(
                    (option) => RadioListTile<T?>(
                      value: option,
                      groupValue: selected,
                      title: Text(labelFor(option)),
                      onChanged: (_) =>
                          Navigator.of(context).pop(_QuickSelection<T>(option)),
                    ),
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

class _QuickMultiSelectSheet<T> extends StatefulWidget {
  const _QuickMultiSelectSheet({
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
  State<_QuickMultiSelectSheet<T>> createState() =>
      _QuickMultiSelectSheetState<T>();
}

class _QuickMultiSelectSheetState<T> extends State<_QuickMultiSelectSheet<T>> {
  late Set<T> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<T>.of(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    final normalizedQuery = _query.trim().toLowerCase();
    final visibleOptions = normalizedQuery.isEmpty
        ? widget.options
        : widget.options
              .where(
                (option) => widget
                    .labelFor(option)
                    .toLowerCase()
                    .contains(normalizedQuery),
              )
              .toList(growable: false);
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
                  child: const Text('Temizle'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.options.length > 12) ...[
              TextField(
                key: const ValueKey('collab-multi-select-search'),
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Seçeneklerde ara',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
            ],
            Flexible(
              child: visibleOptions.isEmpty
                  ? const Center(child: Text('Eşleşen seçenek bulunamadı.'))
                  : ListView(
                      shrinkWrap: true,
                      children: visibleOptions
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
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialtyOption {
  const _SpecialtyOption._({
    required this.label,
    this.instrumentId,
    this.branch,
  });

  factory _SpecialtyOption.instrument(Instrument instrument) =>
      _SpecialtyOption._(label: instrument.name, instrumentId: instrument.id);

  factory _SpecialtyOption.branch(CollabBranch branch) =>
      _SpecialtyOption._(label: branch.label, branch: branch);

  final String label;
  final String? instrumentId;
  final CollabBranch? branch;

  @override
  bool operator ==(Object other) =>
      other is _SpecialtyOption &&
      other.instrumentId == instrumentId &&
      other.branch == branch;

  @override
  int get hashCode => Object.hash(instrumentId, branch);
}

class _DiscoveryFailureState extends StatelessWidget {
  const _DiscoveryFailureState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              key: const ValueKey('collab-discovery-retry'),
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.loading,
    required this.hasNext,
    required this.hasError,
    required this.onRetry,
  });

  final bool loading;
  final bool hasNext;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }
    if (hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton.icon(
            key: const ValueKey('collab-discovery-load-more-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Devamını tekrar yükle'),
          ),
        ),
      );
    }
    return SizedBox(height: hasNext ? 12 : 4);
  }
}

class _EmptyDiscoveryState extends StatelessWidget {
  const _EmptyDiscoveryState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              'Bu seçimlere uygun ilan bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onClear,
              child: const Text('Filtreleri temizle'),
            ),
          ],
        ),
      ),
    );
  }
}
