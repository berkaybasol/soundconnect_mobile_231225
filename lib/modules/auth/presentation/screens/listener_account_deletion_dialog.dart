import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../domain/account_deletion_repository.dart';

class ListenerAccountDeletionDialog extends StatefulWidget {
  const ListenerAccountDeletionDialog({
    super.key,
    required this.repository,
    required this.sessions,
  });
  final AccountDeletionRepository repository;
  final AuthSessionManager sessions;

  @override
  State<ListenerAccountDeletionDialog> createState() =>
      _ListenerAccountDeletionDialogState();
}

class _ListenerAccountDeletionDialogState
    extends State<ListenerAccountDeletionDialog> {
  final _password = TextEditingController();
  late final AuthSession _session;
  bool _acknowledged = false;
  bool _busy = false;
  bool _sessionEnded = false;
  String? _error;

  bool get _current =>
      !_sessionEnded &&
      identical(widget.sessions.session, _session) &&
      canDeleteListenerAccount(_session);

  @override
  void initState() {
    super.initState();
    _session = widget.sessions.session;
    widget.sessions.addListener(_changed);
  }

  void _changed() {
    if (identical(widget.sessions.session, _session) || !mounted) return;
    _password.clear();
    setState(() {
      _sessionEnded = true;
      _busy = false;
      _acknowledged = false;
      _error =
          'Oturum kapandı veya değişti. Bu ekranda silme sonucu doğrulanamadı.';
    });
  }

  @override
  void dispose() {
    widget.sessions.removeListener(_changed);
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy || !_current || !_acknowledged || _password.text.isEmpty) return;
    final password = _password.text;
    _password.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.repository.deleteListenerAccount(
      expectedSession: _session,
      currentPassword: password,
    );
    if (!mounted || !_current) return;
    if (result.isSuccess && result.data == true) {
      Navigator.of(context).pop(true);
      return;
    }
    final code = result.error?.code;
    setState(() {
      _busy = false;
      _error = const {'1006', 'ACCOUNT_DELETION_REAUTH_REQUIRED'}.contains(code)
          ? 'Şifren doğrulanamadı. Mevcut hesap şifreni yeniden gir.'
          : const {
              '1007',
              'ACCOUNT_DELETION_UNSUPPORTED_PROFILE',
            }.contains(code)
          ? 'Bu işlem yalnızca dinleyici hesapları için kullanılabilir.'
          : const {'1008', 'ACCOUNT_DELETED'}.contains(code)
          ? 'Bu hesap daha önce silinmiş. Oturumunu kapatabilirsin.'
          : 'Silme işleminin sonucu doğrulanamadı. Bağlantını kontrol et. Yeniden denemek için şifreni tekrar gir.';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Hesabını kalıcı olarak sil'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Hesabın hemen ve kalıcı olarak silinir. Geri alma veya bekleme süresi yoktur. Profilin, avatarın, yazıların, profil paylaşımların ve kişisel kimlik bilgilerin kaldırılır. Oturumun kapatılır.\n\nDiğer kişilerin mesaj geçmişi “Silinmiş hesap” adıyla kalır.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('account-delete-password'),
              controller: _password,
              enabled: !_busy && _current,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Mevcut şifren'),
              onChanged: (_) => setState(() {}),
            ),
            CheckboxListTile(
              key: const Key('account-delete-acknowledge'),
              contentPadding: EdgeInsets.zero,
              value: _acknowledged,
              onChanged: _busy || !_current
                  ? null
                  : (value) => setState(() => _acknowledged = value == true),
              title: const Text('Hesabımı kalıcı olarak silmek istiyorum.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('account-delete-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('account-delete-cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('account-delete-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed:
              !_busy && _current && _acknowledged && _password.text.isNotEmpty
              ? _delete
              : null,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kalıcı olarak sil'),
        ),
      ],
    ),
  );
}
