import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_session_manager.dart';
import '../../core/di/service_locator.dart';
import '../theme/app_colors.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _supportEmail = 'destek@soundconnect.com.tr';
  static const _whatsAppNumber = '905378581093';
  static const _whatsAppGreen = Color(0xFF25D366);

  String get _usernameLine {
    if (!serviceLocator.isRegistered<AuthSessionManager>()) return '';
    final username = serviceLocator<AuthSessionManager>().session.username;
    if (username == null || username.trim().isEmpty) return '';
    return '\n\nKullanıcı adım: @$username';
  }

  Future<void> _openExternal(
    BuildContext context,
    Uri uri,
    String failureMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    } on Object {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    }
  }

  Future<void> _openEmailSupport(BuildContext context) {
    return _openExternal(
      context,
      Uri(
        scheme: 'mailto',
        path: _supportEmail,
        queryParameters: {
          'subject': 'SoundConnect Destek',
          'body':
              'Merhaba, SoundConnect hesabımla ilgili destek almak '
              'istiyorum.$_usernameLine',
        },
      ),
      'E-posta uygulaması açılamadı.',
    );
  }

  Future<void> _openWhatsAppSupport(BuildContext context) {
    return _openExternal(
      context,
      Uri.https('wa.me', '/$_whatsAppNumber', {
        'text':
            'Merhaba, SoundConnect hesabımla ilgili destek almak '
            'istiyorum.$_usernameLine',
      }),
      'WhatsApp bağlantısı açılamadı.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.navBlueDeep,
              Theme.of(context).colorScheme.surfaceContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.coralAlt.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const _GradientIcon(
                    icon: Icons.support_agent_rounded,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Nasıl yardımcı olabiliriz?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'SoundConnect ile ilgili soru, öneri veya yaşadığın bir '
                  'sorun için destek ekibimize ulaşabilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openEmailSupport(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text.rich(
                      TextSpan(
                        text: 'Bize ',
                        children: [
                          const TextSpan(
                            text: _supportEmail,
                            style: TextStyle(
                              color: _whatsAppGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const TextSpan(
                            text: ' adresinden e-posta gönderebilirsin.',
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openWhatsAppSupport(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text.rich(
                      TextSpan(
                        text: 'veya ',
                        children: [
                          const TextSpan(
                            text: 'buraya dokunarak',
                            style: TextStyle(
                              color: _whatsAppGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: FaIcon(
                                FontAwesomeIcons.whatsapp,
                                color: _whatsAppGreen,
                                size: 15,
                              ),
                            ),
                          ),
                          const TextSpan(
                            text: 'WhatsApp üzerinden bize ulaşabilirsin.',
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _GradientOutlineButton(
                  label: 'Geri dön',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientIcon extends StatelessWidget {
  const _GradientIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: AppColors.brandGradient,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Icon(icon, size: size),
    );
  }
}

class _GradientOutlineButton extends StatelessWidget {
  const _GradientOutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: CustomPaint(
        painter: _GradientBorderPainter(
          borderRadius: 18,
          strokeWidth: 1.4,
          colors: AppColors.brandGradient,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  const _GradientBorderPainter({
    required this.borderRadius,
    required this.strokeWidth,
    required this.colors,
  });

  final double borderRadius;
  final double strokeWidth;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rRect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );
    final paint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.colors != colors;
  }
}
