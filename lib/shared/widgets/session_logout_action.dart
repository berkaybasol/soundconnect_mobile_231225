import 'package:flutter/material.dart';

import '../../core/auth/auth_session_manager.dart';
import '../../core/di/service_locator.dart';
import 'gradient_outline_button.dart';

const Key sessionLogoutButtonKey = Key('session-logout-button');
const Key sessionLogoutConfirmKey = Key('session-logout-confirm');

Future<bool> confirmAndLogoutSession(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Oturumu Kapat'),
      content: const Text(
        'SoundConnect hesabından çıkış yapmak üzeresin. Daha sonra tekrar giriş yapabilirsin.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Vazgeç'),
        ),
        GradientOutlineButton(
          key: sessionLogoutConfirmKey,
          label: 'Oturumu Kapat',
          leading: const Icon(Icons.logout),
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return false;
  await serviceLocator<AuthSessionManager>().logout();
  return true;
}

class SessionLogoutIconButton extends StatefulWidget {
  const SessionLogoutIconButton({super.key});

  @override
  State<SessionLogoutIconButton> createState() =>
      _SessionLogoutIconButtonState();
}

class _SessionLogoutIconButtonState extends State<SessionLogoutIconButton> {
  bool _loggingOut = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: sessionLogoutButtonKey,
      tooltip: 'Oturumu Kapat',
      onPressed: _loggingOut ? null : _confirmAndLogout,
      icon: _loggingOut
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.manage_accounts_outlined),
    );
  }

  Future<void> _confirmAndLogout() async {
    setState(() => _loggingOut = true);
    try {
      await confirmAndLogoutSession(context);
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }
}
