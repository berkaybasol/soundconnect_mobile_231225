import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/account_deletion_repository.dart';

part 'listener_account_deletion_sheet_details.dart';

class AccountDeletionDialog extends StatefulWidget {
  const AccountDeletionDialog({
    super.key,
    required this.repository,
    required this.sessions,
    required this.expectedSession,
    required this.expectedRevision,
    this.chooseGoogleAccount,
  });
  final AccountDeletionRepository repository;
  final AuthSessionManager sessions;
  final AuthSession expectedSession;
  final int expectedRevision;
  final Future<String?> Function()? chooseGoogleAccount;

  @override
  State<AccountDeletionDialog> createState() => _AccountDeletionDialogState();
}

class _AccountDeletionDialogState extends State<AccountDeletionDialog> {
  final _password = TextEditingController();
  bool _verifying = false;
  bool _useGoogle = false;
  bool _acknowledged = false;
  bool _busy = false;
  bool _sessionEnded = false;
  String? _error;
  List<BandDeletionOption>? _bands;
  bool _loadingBands = false;
  final _decisions = <String, BandDeletionDecision>{};
  AccountDeletionProfile? get _profile =>
      accountDeletionProfile(widget.expectedSession);
  bool get _needsBands => _profile == AccountDeletionProfile.musician;
  bool get _bandsReady =>
      !_needsBands ||
      (_bands != null &&
          _bands!.every((b) => _decisions.containsKey(b.bandId)));

  bool get _current =>
      !_sessionEnded &&
      identical(widget.sessions.session, widget.expectedSession) &&
      widget.sessions.credentialRevision == widget.expectedRevision &&
      _profile != null;

  bool get _canSubmit =>
      _verifying &&
      !_busy &&
      _current &&
      _bandsReady &&
      _acknowledged &&
      (_useGoogle || _password.text.isNotEmpty);

  @override
  void initState() {
    super.initState();
    widget.sessions.addListener(_changed);
    if (_needsBands) _loadBands();
  }

  Future<void> _loadBands({bool stale = false}) async {
    if (_loadingBands || !_current) return;
    setState(() {
      _loadingBands = true;
      _bands = null;
      _decisions.clear();
      _error = stale
          ? 'Band üyelikleri değişti. Güncel seçenekleri yeniden kontrol et.'
          : null;
    });
    final result = await widget.repository.getBandOptions(
      widget.expectedSession,
    );
    if (!mounted || !_current) return;
    setState(() {
      _loadingBands = false;
      _bands = result.isSuccess ? result.data : null;
      if (_bands == null) _error = 'Band üyeliklerin yüklenemedi. Tekrar dene.';
    });
  }

  void _changed() {
    if (_current || _sessionEnded || !mounted) return;
    _password.clear();
    setState(() {
      _sessionEnded = true;
      _busy = false;
      _acknowledged = false;
      _error = null;
    });
  }

  @override
  void dispose() {
    widget.sessions.removeListener(_changed);
    _password.dispose();
    super.dispose();
  }

  void _showVerification(bool verifying) {
    if (_busy ||
        !_current ||
        (verifying && !_bandsReady) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    FocusScope.of(context).unfocus();
    _password.clear();
    setState(() {
      _verifying = verifying;
      _acknowledged = false;
      _useGoogle = false;
      _error = null;
    });
  }

  void _selectGoogle(bool google) {
    if (_busy || !_current || google == _useGoogle) return;
    FocusScope.of(context).unfocus();
    _password.clear();
    setState(() {
      _useGoogle = google;
      _error = null;
    });
  }

  Future<void> _delete() async {
    final route = ModalRoute.of<bool>(context);
    if (!_canSubmit || route == null || !route.isCurrent) return;
    final password = _password.text;
    _password.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    String? googleIdToken;
    if (_useGoogle) {
      try {
        googleIdToken = await widget.chooseGoogleAccount!();
      } catch (_) {
        if (!mounted) return;
        _changed();
        if (_current) {
          setState(() {
            _busy = false;
            _error = 'Google hesabın doğrulanamadı. Tekrar dene.';
          });
        }
        return;
      }
      if (!mounted) return;
      _changed();
      if (!_current) return;
      if (googleIdToken == null || !route.isCurrent) {
        setState(() => _busy = false);
        return;
      }
    }
    final result = await widget.repository.deleteAccount(
      expectedSession: widget.expectedSession,
      currentPassword: _useGoogle ? null : password,
      googleIdToken: googleIdToken,
      bandDecisions: _decisions.values.toList(growable: false),
    );
    if (!mounted) return;
    final session = widget.sessions.session;
    final signedOut = !session.isAuthenticated && !session.isSuspendedNotice;
    if (result.isSuccess && result.data == true && (_current || signedOut)) {
      final navigator = Navigator.of(context);
      if (route.isCurrent) {
        navigator.pop(true);
      } else if (route.isActive) {
        navigator.removeRoute(route, true);
      }
      return;
    }
    _changed();
    if (!_current) return;
    final code = result.error?.code;
    if (_needsBands &&
        (code == '9223' || code == 'BAND_DELETION_DECISION_CONFLICT')) {
      setState(() {
        _busy = false;
        _verifying = false;
        _acknowledged = false;
        _useGoogle = false;
      });
      await _loadBands(stale: true);
      return;
    }
    setState(() {
      _busy = false;
      _error = switch (code) {
        '1006' || 'ACCOUNT_DELETION_REAUTH_REQUIRED' =>
          _useGoogle
              ? 'Google hesabın doğrulanamadı. SoundConnect hesabını açtığın Google hesabını seç.'
              : 'Şifren doğrulanamadı. Mevcut hesap şifreni yeniden gir.',
        '1007' || 'ACCOUNT_DELETION_UNSUPPORTED_PROFILE' =>
          'Bu hesap için silme işlemi kullanılamıyor.',
        '1008' || 'ACCOUNT_DELETED' =>
          'Bu hesap daha önce silinmiş. Oturumunu kapatabilirsin.',
        '1104' ||
        '429' => 'Çok fazla deneme yaptın. Bir süre sonra tekrar dene.',
        '1117' =>
          'Google doğrulaması şu anda kullanılamıyor. Daha sonra tekrar dene.',
        _ =>
          'Silme işleminin sonucu doğrulanamadı. Bağlantını kontrol edip yeniden dene.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = dark ? AppColors.originalDark : AppColors.lightPalette;
    final message = _current
        ? _error
        : 'Oturum kapandı veya değişti. Bu ekranda silme sonucu doğrulanamadı.';
    final enabled = !_busy && _current;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    );
    return PopScope<bool>(
      canPop: !_busy && (!_verifying || !_current),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _verifying) _showVerification(false);
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            key: ValueKey(_verifying),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DeletionHeader(verifying: _verifying, colors: colors),
                const SizedBox(height: 16),
                if (!_verifying) ...[
                  _DeletionEffects(colors: colors, profile: _profile),
                  if (_needsBands && _current) ...[
                    if (_loadingBands)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(
                          semanticsLabel: 'Band üyeliklerin yükleniyor',
                        ),
                      )
                    else if (_bands == null)
                      TextButton(
                        onPressed: _loadBands,
                        child: const Text('Yeniden yükle'),
                      )
                    else
                      for (final band in _bands!)
                        _BandDeletionChoice(
                          option: band,
                          selection: _decisions[band.bandId],
                          onChanged: (choice) =>
                              setState(() => _decisions[band.bandId] = choice),
                        ),
                  ],
                ] else ...[
                  if (_current)
                    for (final band in _bands ?? <BandDeletionOption>[])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _decisionSummary(band, _decisions[band.bandId]!),
                        ),
                      ),
                  if (widget.chooseGoogleAccount != null)
                    _DeletionMethodSelector(
                      colors: colors,
                      google: _useGoogle,
                      onChanged: enabled ? _selectGoogle : null,
                    ),
                  if (_useGoogle)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Devam ettiğinde SoundConnect’e giriş yaptığın Google hesabını seç.',
                        style: TextStyle(color: colors.textMuted),
                      ),
                    )
                  else
                    TextField(
                      key: const Key('account-delete-password'),
                      controller: _password,
                      enabled: enabled,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Mevcut şifren',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  CheckboxListTile(
                    key: const Key('account-delete-acknowledge'),
                    contentPadding: EdgeInsets.zero,
                    value: _acknowledged,
                    onChanged: enabled
                        ? (value) =>
                              setState(() => _acknowledged = value == true)
                        : null,
                    title: Text(
                      'Hesabımı kalıcı olarak silmek istiyorum.',
                      style: TextStyle(fontSize: 14, color: colors.textPrimary),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
                if (message != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        message,
                        key: const Key('account-delete-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                if (!_verifying)
                  OutlinedButton(
                    key: const Key('account-delete-next'),
                    onPressed: enabled && _bandsReady
                        ? () => _showVerification(true)
                        : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.inputFill,
                      foregroundColor: colors.textPrimary,
                      minimumSize: const Size(0, 48),
                      shape: buttonShape,
                      side: BorderSide(color: colors.border),
                    ),
                    child: const Text('Doğrulamaya geç'),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Semantics(
                      liveRegion: _busy,
                      child: GradientOutlineButton(
                        key: const Key('account-delete-confirm'),
                        label: _busy
                            ? 'İşlem sürüyor'
                            : _useGoogle
                            ? 'Google ile doğrula ve sil'
                            : 'Hesabımı kalıcı olarak sil',
                        onPressed: _canSubmit ? _delete : null,
                        loading: _busy,
                        horizontalPadding: 16,
                        strokeWidth: 1,
                        maxLines: null,
                      ),
                    ),
                  ),
                TextButton(
                  key: const Key('account-delete-cancel'),
                  onPressed: _busy
                      ? null
                      : () {
                          if (ModalRoute.of(context)?.isCurrent == true &&
                              !_busy) {
                            Navigator.of(context).pop(false);
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Vazgeç'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
