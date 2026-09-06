import 'package:flutter/material.dart';

import '../../core/auth/auth_session_manager.dart';
import '../../core/di/service_locator.dart';
import '../theme/app_colors.dart';
import 'gradient_outline_button.dart';

const Key sessionLogoutButtonKey = Key('session-logout-button');
const Key sessionLogoutMenuTileKey = Key('session-logout-menu-tile');
const Key sessionLogoutConfirmKey = Key('session-logout-confirm');

Future<bool> confirmAndLogoutSession(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final colors = Theme.of(dialogContext).colorScheme;
      final dialogColor = theme.brightness == Brightness.dark
          ? Color.alphaBlend(
              colors.onSurface.withValues(alpha: 0.035),
              colors.surface,
            )
          : colors.surface;
      return Dialog(
        backgroundColor: dialogColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.outline.withValues(alpha: 0.42)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => LinearGradient(
                      colors: AppColors.brandGradient,
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Çıkış yapılsın mı?',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    dialogContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu cihazdaki SoundConnect oturumun sonlandırılacak. İstediğin zaman tekrar giriş yapabilirsin.',
                  textAlign: TextAlign.center,
                  style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: GradientOutlineButton(
                    key: sessionLogoutConfirmKey,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    label: 'Çıkış yap',
                    leading: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => LinearGradient(
                        colors: AppColors.brandGradient,
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Vazgeç'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (confirmed != true || !context.mounted) return false;
  await serviceLocator<AuthSessionManager>().logout();
  return true;
}

class SessionLogoutMenuTile extends StatelessWidget {
  final VoidCallback onTap;

  const SessionLogoutMenuTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          indent: 10,
          endIndent: 10,
          color: Theme.of(context).dividerColor,
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: sessionLogoutMenuTileKey,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 12),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => LinearGradient(
                      colors: AppColors.brandGradient,
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.white,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Çıkış yap',
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
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
      tooltip: 'Çıkış yap',
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
