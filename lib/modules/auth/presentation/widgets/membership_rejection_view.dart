import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/backstage_palette.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import 'membership_support.dart';

class MembershipRejectionView extends StatelessWidget {
  const MembershipRejectionView({
    super.key,
    required this.isStudio,
    required this.onReturnToLogin,
    this.businessName,
    this.reason,
    this.statusActions = const [],
  });

  final bool isStudio;
  final VoidCallback? onReturnToLogin;
  final String? businessName;
  final String? reason;
  final List<Widget> statusActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final surface = dark ? BackstagePalette.surface : colors.surface;
    final outline = dark ? BackstagePalette.border : colors.outlineVariant;
    final shape = RoundedRectangleBorder(
      side: BorderSide(color: outline),
      borderRadius: BorderRadius.circular(16),
    );
    final kind = isStudio ? 'Stüdyo' : 'Mekân';
    return Scaffold(
      backgroundColor: dark ? BackstagePalette.canvas : null,
      appBar: AppBar(
        title: const Text('Başvuru durumu'),
        backgroundColor: dark ? BackstagePalette.canvas : null,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 37,
                backgroundColor: dark
                    ? BackstagePalette.surfaceRaised
                    : colors.surfaceContainerHigh,
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 36,
                  color: AppColors.accentText,
                ),
              ),
            ),
            if (businessName != null) ...[
              const SizedBox(height: 20),
              Text(
                businessName!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                '$kind başvurun reddedildi.',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 28),
            if (reason != null) ...[
              Material(
                color: surface,
                shape: shape,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: AppColors.accentText,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ret gerekçesi',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(reason!, style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              Text(
                'Bu başvuru için ret gerekçesi gösterilemiyor. Bilgi almak veya karara itiraz etmek için destek ekibimize ulaşabilirsin.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
            ],
            Semantics(
              header: true,
              child: Text(
                'Destek',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: surface,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: const Text(membershipSupportEmail),
                    onTap: () => openMembershipSupport(
                      context,
                      Uri(scheme: 'mailto', path: membershipSupportEmail),
                      'E-posta uygulaması açılamadı.',
                    ),
                  ),
                  Divider(indent: 16, endIndent: 16, height: 1, color: outline),
                  ListTile(
                    leading: const FaIcon(FontAwesomeIcons.whatsapp),
                    title: const Text('WhatsApp ile destek al'),
                    onTap: () => openMembershipSupport(
                      context,
                      membershipSupportWhatsApp(
                        'Merhaba, SoundConnect ${kind.toLowerCase()} başvurumun reddedilmesi hakkında bilgi almak istiyorum.',
                      ),
                      'WhatsApp bağlantısı açılamadı.',
                    ),
                  ),
                ],
              ),
            ),
            ...statusActions,
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: GradientOutline(
          child: TextButton.icon(
            onPressed: onReturnToLogin,
            icon: const Icon(Icons.arrow_back),
            label: const Text(
              'Giriş ekranına dön',
              textAlign: TextAlign.center,
            ),
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
