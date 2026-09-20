part of 'musician_profile_screen.dart';

class MusicianProfileCompletionScreen extends StatefulWidget {
  const MusicianProfileCompletionScreen({super.key, required this.profile});

  final MusicianProfile profile;

  @override
  State<MusicianProfileCompletionScreen> createState() =>
      _MusicianProfileCompletionScreenState();
}

class _MusicianProfileCompletionScreenState
    extends State<MusicianProfileCompletionScreen> {
  bool _cityPickerOpen = false;
  final _instrumentSearch = TextEditingController();
  late final ProfileActionSession _session;
  late final MusicianFeedOpportunityCityController _city;
  late final MusicianInstrumentController _instruments;
  bool _saving = false;
  bool _changed = false;
  bool _leaving = false;
  bool _allowPop = false;
  int _instrumentLimit = 6;
  String? _saveError;

  bool get _isCurrent =>
      _session.isCurrent && _session.userId == widget.profile.userId;
  bool get _dirty => _city.hasChanges || _instruments.hasChanges;

  @override
  void initState() {
    super.initState();
    _session = ProfileActionSession(roles: const ['MUSICIAN', 'ROLE_MUSICIAN']);
    final preferences = serviceLocator<MusicianFeedPreferencesRepository>();
    _city = MusicianFeedOpportunityCityController(
      preferencesRepository: preferences,
      locationRepository: serviceLocator<LocationRepository>(),
      isCurrent: () => _isCurrent,
    );
    _instruments = MusicianInstrumentController(
      profile: widget.profile,
      instrumentsRepository: serviceLocator<InstrumentRepository>(),
      preferencesRepository: preferences,
      profileRepository: serviceLocator<MusicianProfileRepository>(),
      sessions: serviceLocator<AuthSessionManager>(),
    );
    _city.addListener(_rebuild);
    _instruments.addListener(_rebuild);
    _session.manager?.addListener(_rebuild);
    unawaited(Future.wait([_city.load(), _instruments.load()]));
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session.manager?.removeListener(_rebuild);
    _city.dispose();
    _instruments.dispose();
    _instrumentSearch.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_dirty || !_isCurrent) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    if (_city.hasChanges) {
      final saved = await _city.save();
      if (!mounted) return;
      if (!saved || !_isCurrent) {
        _showSaveFailure(_city.error ?? 'Şehir tercihi kaydedilemedi.');
        return;
      }
      _changed = true;
    }
    if (_instruments.hasChanges) {
      final saved = await _instruments.save();
      if (!mounted) return;
      if (!saved || !_isCurrent) {
        _showSaveFailure(
          _changed && _isCurrent
              ? 'Kaydedilen değişiklikler korundu. Enstrüman seçimin kaydedilemedi; tekrar deneyebilirsin.'
              : _instruments.error ?? 'Enstrümanlar kaydedilemedi.',
        );
        return;
      }
      _changed = true;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: const Text('Değişikliklerin kaydedildi.'),
        ),
      );
  }

  void _showSaveFailure(String message) {
    setState(() {
      _saving = false;
      _saveError = message;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text(message),
        ),
      );
  }

  Future<void> _leave() async {
    if (_saving || _leaving) return;
    _leaving = true;
    if (_dirty && _isCurrent) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kaydedilmemiş değişikliklerin var'),
          content: const Text(
            'Sayfadan ayrılırsan kaydetmediğin seçimler silinir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Düzenlemeye devam et'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Değişiklikleri bırak'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (discard != true) {
        _leaving = false;
        return;
      }
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(_changed);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final enabled = !_saving && _isCurrent;
    final scheme = Theme.of(context).colorScheme;
    return PopScope<bool>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        key: const Key('musician-profile-completion-page'),
        appBar: AppBar(
          title: const Text('Profil Tamamlama'),
          centerTitle: true,
          leading: BackButton(onPressed: _saving ? null : _leave),
        ),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Akışını sana göre hazırlayalım.',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fırsat görmek istediğin şehri ve çaldığın enstrümanları aynı yerden düzenle.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                _sectionTitle(Icons.tune_rounded, 'Akış Tercihleri'),
                const SizedBox(height: 8),
                Text(
                  'Collab ve etkinlikler için fırsat şehrin.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                _citySection(enabled),
                const SizedBox(height: 24),
                Divider(color: AppColors.border),
                const SizedBox(height: 24),
                _sectionTitle(Icons.music_note_rounded, 'Enstrümanlarım'),
                const SizedBox(height: 8),
                Text(
                  'Çaldığın enstrümanları ve müzikteki branşlarını seç.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                _instrumentSection(enabled),
                if (!_isCurrent)
                  _errorText('Oturum değişti. Bu sayfayı yeniden aç.'),
                if (_saveError != null) _errorText(_saveError!),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                12 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: GradientOutlineButton(
                key: const Key('musician-profile-completion-save'),
                label: 'Değişiklikleri kaydet',
                maxLines: 2,
                horizontalPadding: 14,
                leading: const Icon(Icons.check_rounded, size: 20),
                loading: _saving,
                onPressed:
                    enabled && _dirty && !_city.loading && !_instruments.loading
                    ? _save
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) => Row(
    children: [
      BrandGradientIcon(icon, size: 23),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );

  Widget _errorText(String message) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );

  Widget _citySection(bool enabled) {
    if (_city.loading) return const LinearProgressIndicator();
    if (_city.preferences == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _errorText(_city.error ?? 'Şehirler yüklenemedi.'),
          TextButton.icon(
            onPressed: enabled ? _city.load : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Şehirleri yeniden yükle'),
          ),
        ],
      );
    }
    final selected = _city.cities
        .where((item) => item.id == _city.selectedId)
        .firstOrNull;
    final selectedName =
        selected?.name ?? _city.preferences?.opportunityCity?.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    child: InkWell(
                      key: const Key('musician-completion-city-field'),
                      onTap: enabled ? _pickCity : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            const BrandGradientIcon(
                              Icons.location_on_rounded,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fırsat şehrin',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _city.selectedId == null
                                        ? 'Şehir seç'
                                        : selectedName ?? 'Seçili şehir',
                                    style: TextStyle(
                                      color: _city.selectedId == null
                                          ? AppColors.textMuted
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_city.selectedId != null)
                  IconButton(
                    key: const Key('musician-completion-city-clear'),
                    tooltip: 'Şehir seçimini kaldır',
                    onPressed: enabled ? () => _city.selectCity(null) : null,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
              ],
            ),
          ),
        ),
        if (_city.error != null) _errorText(_city.error!),
      ],
    );
  }

  Future<void> _pickCity() async {
    if (_cityPickerOpen || _saving || !_isCurrent || _city.loading) return;
    _cityPickerOpen = true;
    final route = ModalRoute.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final selected = await showLocationPickerSheet(
        context,
        title: 'Fırsat şehrini seç',
        options: {for (final city in _city.cities) city.id: city.name},
        selected: _city.selectedId,
        searchLabel: 'Şehir ara',
        searchKey: const Key('musician-completion-city-search'),
        optionKeyFor: (id) => ValueKey('musician-completion-city-$id'),
      );
      if (selected != null &&
          mounted &&
          _isCurrent &&
          route?.isCurrent != false) {
        _city.selectCity(selected);
      }
    } finally {
      _cityPickerOpen = false;
    }
  }

  Widget _instrumentSection(bool enabled) {
    if (_instruments.loading) return const LinearProgressIndicator();
    if (_instruments.instruments.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _errorText(_instruments.error ?? 'Enstrümanlar yüklenemedi.'),
          TextButton.icon(
            onPressed: enabled ? _instruments.load : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Enstrümanları yeniden yükle'),
          ),
        ],
      );
    }
    final query = _completionSearchKey(_instrumentSearch.text);
    final results = _instruments.instruments
        .where(
          (item) =>
              query.isEmpty || _completionSearchKey(item.name).contains(query),
        )
        .toList();
    final selected = _instruments.instruments.where(
      (item) => _instruments.selectedIds.contains(item.id),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_instruments.selectedIds.length} enstrüman seçili',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final item in selected)
                InputChip(
                  side: BorderSide(color: AppColors.border),
                  key: ValueKey('musician-completion-selected-${item.id}'),
                  label: Text(item.name),
                  deleteButtonTooltipMessage: '${item.name} seçimini kaldır',
                  onDeleted: enabled
                      ? () => _instruments.toggle(item.id)
                      : null,
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          key: const Key('musician-completion-instrument-search'),
          controller: _instrumentSearch,
          enabled: enabled,
          onChanged: (_) => setState(() => _instrumentLimit = 6),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: _completionInputDecoration(
            context,
            label: 'Enstrüman ara',
            hint: 'Örn. gitar, vokal, prodüksiyon',
            prefixIcon: const BrandGradientIcon(Icons.search_rounded, size: 21),
          ),
        ),
        const SizedBox(height: 12),
        for (final item in results.take(_instrumentLimit)) ...[
          CheckboxListTile(
            key: ValueKey('musician-instrument-${item.id}'),
            value: _instruments.selectedIds.contains(item.id),
            enabled: enabled,
            onChanged: (_) => _instruments.toggle(item.id),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(item.name),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _instruments.selectedIds.contains(item.id)
                    ? AppColors.coral
                    : AppColors.border,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (results.isEmpty) const Text('Bu aramayla eşleşen enstrüman yok.'),
        if (results.length > _instrumentLimit)
          TextButton(
            onPressed: enabled
                ? () => setState(() => _instrumentLimit += 12)
                : null,
            child: const Text('Daha fazla göster'),
          ),
        if (_instruments.error != null) _errorText(_instruments.error!),
      ],
    );
  }
}
