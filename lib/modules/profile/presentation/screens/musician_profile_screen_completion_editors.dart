part of 'musician_profile_screen.dart';

enum MusicianProfileCompletionEditor {
  instruments,
  profileDetails,
  portfolio,
  photoAndSocialLinks,
}

MusicianProfileCompletionEditor? musicianProfileCompletionEditorForCode(
  String? code,
) => switch (code?.trim().toUpperCase()) {
  'INSTRUMENTS' => MusicianProfileCompletionEditor.instruments,
  'STAGE_NAME_AND_BIO' => MusicianProfileCompletionEditor.profileDetails,
  'PORTFOLIO' => MusicianProfileCompletionEditor.portfolio,
  'PROFILE_PHOTO_AND_SOCIAL_LINKS' =>
    MusicianProfileCompletionEditor.photoAndSocialLinks,
  _ => null,
};

Future<void> showMusicianPortfolioCompletionEditor(
  BuildContext context, {
  required MusicianProfile profile,
}) => showProfileTrackUploadSheet(
  hostContext: context,
  profileId: profile.id,
  ownerType: 'MUSICIAN_PROFILE',
  profileType: 'MUSICIAN',
);

Future<void> showMusicianPhotoAndSocialLinksCompletionEditor(
  BuildContext context, {
  required MusicianProfile profile,
  required Future<void> Function() onEditPhoto,
  required Future<void> Function(ProfileSocialPlatform platform)
  onEditSocialLink,
}) async {
  final action = await showModalBottomSheet<_MusicianIdentityEditorAction>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.navBlueDeep,
    builder: (_) => _MusicianPhotoAndSocialLinksCompletionEditor(
      profile: profile,
    ),
  );
  if (!context.mounted || action == null) return;
  final platform = action.platform;
  if (platform == null) {
    await onEditPhoto();
  } else {
    await onEditSocialLink(platform);
  }
}

class _MusicianIdentityEditorAction {
  const _MusicianIdentityEditorAction.photo() : platform = null;
  const _MusicianIdentityEditorAction.social(this.platform);

  final ProfileSocialPlatform? platform;
}

class _MusicianPhotoAndSocialLinksCompletionEditor extends StatelessWidget {
  const _MusicianPhotoAndSocialLinksCompletionEditor({required this.profile});

  final MusicianProfile profile;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const Key('musician-photo-social-completion-editor'),
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _MusicianCompletionEditorHeading(
          icon: Icons.account_circle_outlined,
          title: 'Fotoğraf ve bağlantılar',
          description:
              'Profil fotoğrafını ve sana ulaşılabilecek müzik bağlantılarını buradan tamamla.',
        ),
        const SizedBox(height: 20),
        _MusicianCompletionActionTile(
          actionKey: const Key('musician-completion-edit-photo'),
          icon: Icons.add_a_photo_outlined,
          title: profile.profilePicture?.trim().isNotEmpty == true
              ? 'Profil fotoğrafını değiştir'
              : 'Profil fotoğrafı ekle',
          onTap: () => Navigator.of(
            context,
          ).pop(const _MusicianIdentityEditorAction.photo()),
        ),
        const SizedBox(height: 14),
        Text(
          'Sosyal bağlantılar',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (final platform in ProfileSocialPlatform.values) ...[
          _MusicianCompletionActionTile(
            actionKey: ValueKey(
              'musician-completion-edit-social-${platform.name}',
            ),
            icon: Icons.link_rounded,
            title:
                '${platform.label} ${socialUrlForMusicianProfile(profile, platform)?.trim().isNotEmpty == true ? 'düzenle' : 'ekle'}',
            onTap: () => Navigator.of(context).pop(
              _MusicianIdentityEditorAction.social(platform),
            ),
          ),
          if (platform != ProfileSocialPlatform.values.last)
            const SizedBox(height: 8),
        ],
      ],
    ),
  );
}

class _MusicianCompletionActionTile extends StatelessWidget {
  const _MusicianCompletionActionTile({
    required this.actionKey,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.inputFill,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      key: actionKey,
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            BrandGradientIcon.social(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

Future<bool> showMusicianProfileDetailsEditor(
  BuildContext context, {
  required MusicianProfile profile,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.navBlueDeep,
      builder: (_) => _MusicianProfileDetailsEditor(profile: profile),
    ) ??
    false;

Future<bool> showMusicianInstrumentEditor(
  BuildContext context, {
  required MusicianProfile profile,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.navBlueDeep,
      builder: (_) => _MusicianInstrumentEditor(profile: profile),
    ) ??
    false;

class _MusicianProfileDetailsEditor extends StatefulWidget {
  const _MusicianProfileDetailsEditor({required this.profile});

  final MusicianProfile profile;

  @override
  State<_MusicianProfileDetailsEditor> createState() =>
      _MusicianProfileDetailsEditorState();
}

class _MusicianProfileDetailsEditorState
    extends State<_MusicianProfileDetailsEditor> {
  late final TextEditingController _stageName;
  late final TextEditingController _bio;
  late final String _sessionUserId;
  late final String _sessionToken;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stageName = TextEditingController(text: widget.profile.stageName ?? '');
    _bio = TextEditingController(text: widget.profile.bio ?? '');
    final session = serviceLocator<AuthSessionManager>().session;
    _sessionUserId = session.userId?.trim() ?? '';
    _sessionToken = session.token?.trim() ?? '';
  }

  @override
  void dispose() {
    _stageName.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool get _sessionIsCurrent {
    final session = serviceLocator<AuthSessionManager>().session;
    return session.isAuthenticated &&
        session.isActive &&
        session.userId?.trim() == _sessionUserId &&
        session.token?.trim() == _sessionToken &&
        widget.profile.userId.trim() == _sessionUserId;
  }

  Future<void> _save() async {
    final stageName = _stageName.text.trim();
    final bio = _bio.text.trim();
    if (_saving) return;
    if (stageName.isEmpty) {
      setState(() => _error = 'Sahne adı boş bırakılamaz.');
      return;
    }
    if (!_sessionIsCurrent) {
      setState(() => _error = 'Oturum değişti. Lütfen yeniden dene.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await serviceLocator<MusicianProfileRepository>()
        .updateMyProfile(
          MusicianProfileSaveRequest(stageName: stageName, description: bio),
          expectedSessionKey: _sessionUserId,
        );
    if (!mounted) return;
    if (!_sessionIsCurrent) {
      setState(() {
        _saving = false;
        _error = 'Oturum değişti. Değişiklik sonucu gösterilmedi.';
      });
      return;
    }
    final updatedProfile = result.data;
    if (!result.isSuccess || updatedProfile == null) {
      setState(() {
        _saving = false;
        _error = result.error?.message ?? 'Profil bilgileri kaydedilemedi.';
      });
      return;
    }
    if (!_sameMusicianIdentity(updatedProfile, widget.profile)) {
      setState(() {
        _saving = false;
        _error = 'Profil kimliği doğrulanamadı. Lütfen yeniden dene.';
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        2,
        18,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MusicianCompletionEditorHeading(
              icon: Icons.badge_outlined,
              title: 'Profil bilgileri',
              description:
                  'Sahne adın ve biyografin hem profilinde hem de profesyonel keşif alanlarında kullanılır.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _stageName,
              enabled: !_saving,
              maxLength: 255,
              textInputAction: TextInputAction.next,
              decoration: _completionInputDecoration(
                context,
                label: 'Sahne adı',
                hint: 'Sahnede kullandığın ad',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bio,
              enabled: !_saving,
              maxLength: 1024,
              minLines: 4,
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
              decoration: _completionInputDecoration(
                context,
                label: 'Biyografi',
                hint: 'Müziğini, deneyimini ve aradığın işleri kısaca anlat',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 2),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            GradientOutlineButton(
              label: 'Bilgileri kaydet',
              loading: _saving,
              onPressed: _saving ? null : _save,
              backgroundColor: AppColors.navBlue,
              leading: const Icon(Icons.check_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicianInstrumentEditor extends StatefulWidget {
  const _MusicianInstrumentEditor({required this.profile});

  final MusicianProfile profile;

  @override
  State<_MusicianInstrumentEditor> createState() =>
      _MusicianInstrumentEditorState();
}

class _MusicianInstrumentEditorState extends State<_MusicianInstrumentEditor> {
  final _search = TextEditingController();
  late final String _sessionUserId;
  late final String _sessionToken;
  List<Instrument> _instruments = const [];
  Set<String> _selectedIds = const {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = serviceLocator<AuthSessionManager>().session;
    _sessionUserId = session.userId?.trim() ?? '';
    _sessionToken = session.token?.trim() ?? '';
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _sessionIsCurrent {
    final session = serviceLocator<AuthSessionManager>().session;
    return session.isAuthenticated &&
        session.isActive &&
        session.userId?.trim() == _sessionUserId &&
        session.token?.trim() == _sessionToken &&
        widget.profile.userId.trim() == _sessionUserId;
  }

  Future<void> _load() async {
    if (_loading && _instruments.isNotEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    late Result<List<Instrument>> catalogResult;
    late Result<MusicianFeedPreferences> preferencesResult;
    await Future.wait<void>([
      () async {
        catalogResult = await serviceLocator<InstrumentRepository>().getAll();
      }(),
      () async {
        preferencesResult =
            await serviceLocator<MusicianFeedPreferencesRepository>().get();
      }(),
    ]);
    if (!mounted || !_sessionIsCurrent) return;
    final instruments = catalogResult.data;
    if (!catalogResult.isSuccess || instruments == null) {
      setState(() {
        _loading = false;
        _error = catalogResult.error?.message ?? 'Enstrümanlar yüklenemedi.';
      });
      return;
    }
    final validIds = instruments.map((instrument) => instrument.id).toSet();
    final selected = preferencesResult.isSuccess
        ? preferencesResult.data?.instruments
              .map((instrument) => instrument.id)
              .where(validIds.contains)
              .toSet()
        : null;
    final fallbackNames = widget.profile.instruments
        .map(_completionSearchKey)
        .toSet();
    setState(() {
      _instruments = List.unmodifiable(instruments);
      _selectedIds = Set.unmodifiable(
        selected ??
            instruments
                .where(
                  (instrument) => fallbackNames.contains(
                    _completionSearchKey(instrument.name),
                  ),
                )
                .map((instrument) => instrument.id)
                .toSet(),
      );
      _loading = false;
      _error = preferencesResult.isSuccess
          ? null
          : 'Mevcut seçim doğrulanamadı; profildeki bilgiler gösteriliyor.';
    });
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    if (!_sessionIsCurrent) {
      setState(() => _error = 'Oturum değişti. Lütfen yeniden dene.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await serviceLocator<MusicianProfileRepository>()
        .updateMyProfile(
          MusicianProfileSaveRequest(
            instrumentIds: _selectedIds.toList(growable: false)..sort(),
          ),
          expectedSessionKey: _sessionUserId,
        );
    if (!mounted) return;
    if (!_sessionIsCurrent) {
      setState(() {
        _saving = false;
        _error = 'Oturum değişti. Değişiklik sonucu gösterilmedi.';
      });
      return;
    }
    final updatedProfile = result.data;
    if (!result.isSuccess || updatedProfile == null) {
      setState(() {
        _saving = false;
        _error = result.error?.message ?? 'Enstrümanlar kaydedilemedi.';
      });
      return;
    }
    if (!_sameMusicianIdentity(updatedProfile, widget.profile)) {
      setState(() {
        _saving = false;
        _error = 'Profil kimliği doğrulanamadı. Lütfen yeniden dene.';
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _toggle(String id) {
    if (_saving) return;
    final next = Set<String>.of(_selectedIds);
    if (!next.remove(id)) {
      if (next.length >= 50) {
        setState(() => _error = 'En fazla 50 enstrüman seçebilirsin.');
        return;
      }
      next.add(id);
    }
    setState(() {
      _selectedIds = Set.unmodifiable(next);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _completionSearchKey(_search.text);
    final visible = _instruments
        .where(
          (instrument) =>
              query.isEmpty ||
              _completionSearchKey(instrument.name).contains(query),
        )
        .toList(growable: false);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .86,
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
            const _MusicianCompletionEditorHeading(
              icon: Icons.music_note_rounded,
              title: 'Enstrümanların',
              description:
                  'Seçimlerin sana uygun Collab fırsatlarını sıralamak için kullanılır.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              enabled: !_loading && !_saving,
              onChanged: (_) => setState(() {}),
              decoration: _completionInputDecoration(
                context,
                label: 'Enstrüman ara',
                hint: 'Örn. gitar, vokal, prodüksiyon',
                prefixIcon: const BrandGradientIcon.social(
                  Icons.search_rounded,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_selectedIds.length} seçim',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _instrumentBody(visible)),
            if (_error != null) ...[
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
            GradientOutlineButton(
              label: 'Enstrümanları kaydet',
              loading: _saving,
              onPressed: _loading || _saving ? null : _save,
              backgroundColor: AppColors.navBlue,
              leading: const Icon(Icons.check_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }

  Widget _instrumentBody(List<Instrument> visible) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_instruments.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tekrar dene'),
        ),
      );
    }
    if (visible.isEmpty) {
      return Center(
        child: Text(
          'Bu aramayla eşleşen enstrüman yok.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final instrument = visible[index];
        final selected = _selectedIds.contains(instrument.id);
        return CheckboxListTile(
          key: ValueKey('musician-instrument-${instrument.id}'),
          value: selected,
          enabled: !_saving,
          onChanged: (_) => _toggle(instrument.id),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? AppColors.coral : AppColors.border,
            ),
          ),
          tileColor: AppColors.inputFill,
          title: Text(
            instrument.name,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

class _MusicianCompletionEditorHeading extends StatelessWidget {
  const _MusicianCompletionEditorHeading({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.navBlue,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(child: BrandGradientIcon.social(icon, size: 23)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

InputDecoration _completionInputDecoration(
  BuildContext context, {
  required String label,
  required String hint,
  Widget? prefixIcon,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  prefixIcon: prefixIcon,
  filled: true,
  fillColor: AppColors.inputFill,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: AppColors.coral, width: 1.4),
  ),
);

String _completionSearchKey(String value) => value
    .trim()
    .replaceAll('İ', 'i')
    .replaceAll('I', 'i')
    .replaceAll('ı', 'i')
    .toLowerCase();

bool _sameMusicianIdentity(MusicianProfile updated, MusicianProfile original) =>
    updated.id.trim().isNotEmpty &&
    updated.id.trim() == original.id.trim() &&
    updated.userId.trim().isNotEmpty &&
    updated.userId.trim() == original.userId.trim();
