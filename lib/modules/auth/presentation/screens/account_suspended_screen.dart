import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/backstage_palette.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../widgets/membership_support.dart';

class AccountSuspendedScreen extends StatelessWidget {
  const AccountSuspendedScreen({super.key, required this.onReturnToLogin});

  final VoidCallback onReturnToLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? BackstagePalette.canvas : colors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('SoundConnect'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 32, 22, 16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: colors.errorContainer,
                foregroundColor: colors.onErrorContainer,
                child: const Icon(Icons.lock_outline_rounded, size: 30),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                'Hesabınız askıya alındı',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bu hesapla SoundConnect’e erişiminiz kapatıldı.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Material(
              color: dark
                  ? BackstagePalette.surface
                  : colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    link: true,
                    child: InkWell(
                      onTap: () => openMembershipSupport(
                        context,
                        Uri(scheme: 'mailto', path: membershipSupportEmail),
                        'E-posta uygulaması açılamadı.',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Karar hakkında bilgi almak için ',
                              ),
                              TextSpan(
                                text: membershipSupportEmail,
                                style: TextStyle(
                                  color: AppColors.accentText,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(text: ' adresine yazabilirsiniz.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  ListTile(
                    leading: FaIcon(
                      FontAwesomeIcons.whatsapp,
                      color: dark
                          ? const Color(0xFF88DEB0)
                          : const Color(0xFF16623B),
                    ),
                    title: const Text('WhatsApp ile destek al'),
                    trailing: const Icon(Icons.north_east_rounded, size: 18),
                    onTap: () => openMembershipSupport(
                      context,
                      membershipSupportWhatsApp(
                        'Merhaba, SoundConnect hesabımın askıya alınması hakkında bilgi almak istiyorum.',
                      ),
                      'WhatsApp bağlantısı açılamadı.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(22, 8, 22, 16),
        child: GradientOutline(
          child: TextButton.icon(
            onPressed: onReturnToLogin,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Giriş ekranına dön'),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: colors.onSurface,
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SessionAccessUnavailableScreen extends StatelessWidget {
  const SessionAccessUnavailableScreen({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 36),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  'Bağlantı kurulamadı',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Hesabınızın durumu doğrulanamadı. İnternete bağlanıp tekrar deneyin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
