part of 'overthinking_feed_screen.dart';

class OverthinkingCreateScreen extends StatefulWidget {
  const OverthinkingCreateScreen({super.key});
  @override
  State<OverthinkingCreateScreen> createState() =>
      _OverthinkingCreateScreenState();
}

class _OverthinkingCreateScreenState extends State<OverthinkingCreateScreen>
    with OverthinkingSessionBoundState<OverthinkingCreateScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _anonymous = true;
  bool _saving = false;
  String _clientRequestId = const Uuid().v4();
  bool _uncertainCreate = false;
  bool _retiredCreate = false;
  bool get _editingLocked => _saving || _uncertainCreate || _retiredCreate;
  bool _allowExit = false;
  SpotifyTrackPreview? _selectedTrack;
  String? _validationError;

  bool get _hasDraft =>
      _titleController.text.isNotEmpty ||
      _contentController.text.isNotEmpty ||
      _selectedTrack != null;

  bool get _canUseSession =>
      overthinkingSession.canWrite &&
      context.read<OverthinkingFeedCubit>().isSessionCurrent;

  @override
  void onOverthinkingSessionEnded() {
    _titleController.clear();
    _contentController.clear();
    _selectedTrack = null;
    _validationError = null;
    _saving = false;
    _uncertainCreate = false;
    _retiredCreate = false;
    _allowExit = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (!_canUseSession || _saving) return;
    final discard =
        !_hasDraft ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Yazıyı bırakmak istiyor musun?'),
                content: Text(
                  _uncertainCreate
                      ? 'Gönderimin sonucu doğrulanamadı; yazın paylaşılmış olabilir. Ayrılırsan bu taslak silinir. Yeni bir yazı göndermeden önce Yazılarım bölümünü kontrol et.'
                      : 'Henüz paylaşmadığın metin kaydedilmeyecek.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Yazmaya devam et'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Vazgeç'),
                  ),
                ],
              ),
            ) ==
            true;
    if (!discard || !mounted || !_canUseSession) return;
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canUseSession) Navigator.of(context).pop();
    });
  }

  Future<void> _submit() async {
    if (!_canUseSession || _saving || _retiredCreate) return;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty ||
        content.isEmpty ||
        title.length > 64 ||
        content.length > 10240) {
      setState(
        () => _validationError = title.isEmpty || content.isEmpty
            ? 'Başlık ve yazı alanlarını doldurmalısın.'
            : 'Başlık 64, yazı 10.240 karakter sınırını aşmamalı. Emojiler birden fazla yer kaplayabilir.',
      );
      return;
    }
    if (_selectedTrack != null &&
        (_selectedTrack!.spotifyUrl?.trim().isEmpty ?? true)) {
      setState(
        () => _validationError =
            'Bu şarkının Spotify bağlantısı yok. Başka bir şarkı seçebilirsin.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _validationError = null;
    });
    final ok = await context.read<OverthinkingFeedCubit>().createPost(
      clientRequestId: _clientRequestId,
      title: title,
      content: content,
      anonymous: _anonymous,
      spotifyTrackUrl: _selectedTrack?.spotifyUrl,
      spotifyArtistId: _selectedTrack?.artistIds.isNotEmpty == true
          ? _selectedTrack!.artistIds.first
          : null,
      spotifyTrackName: _selectedTrack?.name,
      spotifyArtistName: _selectedTrack?.artistNames.join(', '),
      spotifyAlbumImageUrl: _selectedTrack?.albumImageUrl,
    );
    if (!mounted || !_canUseSession) return;
    setState(() {
      _saving = false;
      _allowExit = ok;
    });
    if (ok) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _canUseSession) Navigator.of(context).pop(true);
      });
    } else {
      final error = context.read<OverthinkingFeedCubit>().state.error;
      final code = error?.code.trim().toUpperCase();
      final status = int.tryParse(code ?? '');
      setState(() {
        _retiredCreate = const {
          '9417',
          'OVERTHINKING_CREATE_KEY_CONFLICT',
          '9418',
          'OVERTHINKING_CREATE_ALREADY_DELETED',
        }.contains(code);
        // A timeout or malformed response may follow a committed transaction.
        // Freeze its payload and retry the same receipt key until reconciled.
        final definitiveRejection =
            (status != null &&
                status >= 400 &&
                status < 500 &&
                status != 408) ||
            const {
              '1001',
              '1002',
              '1101',
              '1102',
              '1103',
              '1308',
              '9401',
              '9402',
              '9403',
              '9404',
              '9407',
              '9411',
              'API_SESSION_FENCE',
              'OVERTHINKING_SESSION_CHANGED',
              'OVERTHINKING_SPOTIFY_SOURCE_INVALID',
            }.contains(code);
        _uncertainCreate = !_retiredCreate && !definitiveRejection;
        if (!_uncertainCreate && !_retiredCreate) {
          _clientRequestId = const Uuid().v4();
        }
        _validationError = _retiredCreate
            ? 'Bu gönderim yeniden yayınlanamaz. Yazılarım bölümünden güncel durumu kontrol et. Metnini kopyalayarak saklayabilirsin.'
            : _uncertainCreate
            ? 'Gönderimin sonucu doğrulanamadı. Gönderimi doğrula düğmesi aynı yazıyı kontrol eder; ikinci bir yazı oluşturmaz.'
            : error?.message ??
                  'Yazın paylaşılamadı. Metnin burada; yeniden deneyebilirsin.';
      });
    }
  }

  Future<void> _pickTrack() async {
    if (!_canUseSession || _editingLocked) return;
    final track = await showModalBottomSheet<SpotifyTrackPreview>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: OverthinkingPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => Theme(
        data: OverthinkingPalette.theme(context),
        child: OverthinkingSessionBoundary(
          session: overthinkingSession,
          child: const _OverthinkingSpotifyPickerSheet(),
        ),
      ),
    );
    if (track != null && mounted && _canUseSession && !_editingLocked) {
      setState(() => _selectedTrack = track);
    }
  }

  @override
  Widget build(BuildContext context) => !_canUseSession
      ? const OverthinkingUnavailableScreen()
      : Theme(
          data: OverthinkingPalette.theme(context),
          child: Builder(
            builder: (context) => PopScope(
              canPop: _allowExit || (!_hasDraft && !_saving),
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) _leave();
              },
              child: Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    tooltip: 'Geri',
                    onPressed: _saving ? null : _leave,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  title: const Text(
                    'Yeni yazı',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: OverthinkingPalette.lilac,
                      ),
                    ),
                  ],
                ),
                body: TableGroupOverviewBackdrop(
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                      children: [
                        const OverthinkingEyebrow(
                          'Overthinking',
                          color: OverthinkingPalette.accent,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Şimdi sen anlat.',
                          style: TextStyle(
                            color: TableGroupOverviewStyle.warmHeading,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.8,
                          ),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'Belki bir başkası da tam böyle hissediyordur.',
                          style: TextStyle(
                            color: OverthinkingPalette.muted,
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 25),
                        OverthinkingSurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const OverthinkingEyebrow('Yazın'),
                              const SizedBox(height: 10),
                              TextField(
                                key: const ValueKey('overthinking-title'),
                                controller: _titleController,
                                enabled: !_saving,
                                readOnly: _uncertainCreate || _retiredCreate,
                                maxLength: 64,
                                buildCounter:
                                    (
                                      context, {
                                      required currentLength,
                                      required isFocused,
                                      maxLength,
                                    }) => _WritingCounter(
                                      _titleController.text.length,
                                      64,
                                    ),
                                textInputAction: TextInputAction.next,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(
                                  color: OverthinkingPalette.text,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                                decoration: _writingDecoration(
                                  'Bir başlık bırak...',
                                ),
                              ),
                              const Divider(
                                color: OverthinkingPalette.border,
                                height: 24,
                              ),
                              TextField(
                                key: const ValueKey('overthinking-content'),
                                controller: _contentController,
                                enabled: !_saving,
                                readOnly: _uncertainCreate || _retiredCreate,
                                maxLength: 10240,
                                buildCounter:
                                    (
                                      context, {
                                      required currentLength,
                                      required isFocused,
                                      maxLength,
                                    }) => _WritingCounter(
                                      _contentController.text.length,
                                      10240,
                                    ),
                                minLines: 6,
                                maxLines: null,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(
                                  color: TableGroupOverviewStyle.bodyMuted,
                                  fontSize: 15,
                                  height: 1.7,
                                ),
                                decoration: _writingDecoration(
                                  'Aklından geçtiği gibi yaz. Toparlamak zorunda değilsin.',
                                  hintMaxLines: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        OverthinkingSurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const OverthinkingEyebrow(
                                'Paragrafların hangi melodiyle şekillendi?',
                              ),
                              const SizedBox(height: 14),
                              if (_selectedTrack == null)
                                InkWell(
                                  onTap: _editingLocked ? null : _pickTrack,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        FaIcon(
                                          FontAwesomeIcons.spotify,
                                          color: AppColors.spotifyGreen,
                                          size: 29,
                                        ),
                                        const SizedBox(width: 13),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Bir şarkı seç',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Spotify’dan · İsteğe bağlı',
                                                style: TextStyle(
                                                  color:
                                                      OverthinkingPalette.muted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.add_rounded,
                                          color: OverthinkingPalette.muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                _TrackTile(
                                  track: _selectedTrack!,
                                  onTap: _editingLocked ? null : _pickTrack,
                                  trailing: IconButton(
                                    tooltip: 'Şarkıyı kaldır',
                                    onPressed: _editingLocked
                                        ? null
                                        : () => setState(
                                            () => _selectedTrack = null,
                                          ),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        OverthinkingSurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const OverthinkingEyebrow(
                                'Kimliğini nasıl gösterelim?',
                              ),
                              const SizedBox(height: 15),
                              _IdentityOption(
                                selected: _anonymous,
                                icon: Icons.visibility_off_outlined,
                                title: 'Anonim',
                                description:
                                    'Yazın görünsün, kimliğin sende kalsın.',
                                onTap: _editingLocked
                                    ? null
                                    : () => setState(() => _anonymous = true),
                              ),
                              const SizedBox(height: 9),
                              _IdentityOption(
                                selected: !_anonymous,
                                icon: Icons.person_outline_rounded,
                                title: 'Profilimle',
                                description:
                                    'Kullanıcı adın ve profil fotoğrafınla paylaş.',
                                onTap: _editingLocked
                                    ? null
                                    : () => setState(() => _anonymous = false),
                              ),
                              if (_anonymous) ...[
                                const SizedBox(height: 13),
                                const Text(
                                  'Kimlik isteklerini Yazılarım bölümünden yönetebilirsin.',
                                  style: TextStyle(
                                    color: OverthinkingPalette.muted,
                                    fontSize: 11,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_validationError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _validationError!,
                              style: const TextStyle(
                                color: OverthinkingPalette.accent,
                                height: 1.5,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        OverthinkingPrimaryAction(
                          key: const ValueKey('overthinking-publish'),
                          onPressed: _saving || _retiredCreate ? null : _submit,
                          busy: _saving,
                          icon: Icons.edit_outlined,
                          label: _saving
                              ? 'Paylaşılıyor...'
                              : _uncertainCreate
                              ? 'Gönderimi doğrula'
                              : 'Yazıyı paylaş',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
}

InputDecoration _writingDecoration(String hint, {int? hintMaxLines}) =>
    InputDecoration(
      hintText: hint,
      hintMaxLines: hintMaxLines,
      hintStyle: const TextStyle(color: TableGroupOverviewStyle.tertiaryText),
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      counterStyle: const TextStyle(
        color: OverthinkingPalette.muted,
        fontSize: 10,
      ),
    );

class _WritingCounter extends StatelessWidget {
  const _WritingCounter(this.length, this.limit);
  final int length;
  final int limit;

  @override
  Widget build(BuildContext context) => Text(
    '$length/$limit',
    style: TextStyle(
      fontSize: 10,
      color: length > limit
          ? OverthinkingPalette.accent
          : OverthinkingPalette.muted,
    ),
  );
}

class _IdentityOption extends StatelessWidget {
  const _IdentityOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? TableGroupOverviewStyle.insetTop
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.gradientC : OverthinkingPalette.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 21,
              color: selected
                  ? OverthinkingPalette.lilac
                  : OverthinkingPalette.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: OverthinkingPalette.muted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: selected
                  ? OverthinkingPalette.lilac
                  : OverthinkingPalette.muted,
            ),
          ],
        ),
      ),
    ),
  );
}
