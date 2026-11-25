import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/error/studio_rejection_error.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import 'membership_rejection_view.dart';
import 'membership_support.dart';

enum PendingMembershipType { venue, studio, studioRejected }

class MembershipStatusCheck extends StatelessWidget {
  const MembershipStatusCheck({
    super.key,
    required this.checking,
    required this.onCheck,
    this.notice,
  });

  final bool checking;
  final VoidCallback onCheck;
  final String? notice;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (notice != null)
        Semantics(
          liveRegion: true,
          child: Text(notice!, textAlign: TextAlign.center),
        ),
      OutlinedButton(
        onPressed: checking ? null : onCheck,
        child: Text(
          checking ? 'Kontrol ediliyor…' : 'Başvuru durumunu kontrol et',
        ),
      ),
      const SizedBox(height: 8),
    ],
  );
}

class MembershipPendingView extends StatelessWidget {
  const MembershipPendingView({
    super.key,
    this.membershipType = PendingMembershipType.venue,
    this.statusAction,
    this.studioDecision,
    required this.onReturnToLogin,
  });

  final PendingMembershipType membershipType;
  final Widget? statusAction;
  final StudioRejectionError? studioDecision;
  final VoidCallback? onReturnToLogin;

  bool get _isStudio => membershipType != PendingMembershipType.venue;

  @override
  Widget build(BuildContext context) {
    if (membershipType == PendingMembershipType.studioRejected) {
      return MembershipRejectionView(
        isStudio: true,
        onReturnToLogin: onReturnToLogin,
        businessName: studioDecision?.businessName,
        reason: studioDecision?.rejectionReason,
      );
    }
    final theme = Theme.of(context);
    final supportGreen = theme.brightness == Brightness.light
        ? const Color(0xFF0D7133)
        : const Color(0xFF25D366);
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
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (AppColors.isLight
                                        ? AppColors.decorativeGradient.first
                                        : AppColors.coralAlt)
                                    .withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _GradientIcon(
                        icon: Icons.verified_outlined,
                        size: 44,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Hesabın inceleniyor...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      _isStudio
                          ? 'Stüdyo üyeliğini incelemeye aldık. Gün içinde ekibimiz seninle iletişime geçecek.'
                          : 'Mekan üyeliğini incelemeye aldık. Gün içinde ekibimiz seninle iletişime geçecek.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        text: 'Soruların için ',
                        children: [
                          TextSpan(
                            text: membershipSupportEmail,
                            style: TextStyle(
                              color: supportGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(text: ' adresine e-posta gönderebilirsin.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => openMembershipSupport(
                        context,
                        membershipSupportWhatsApp(
                          _isStudio
                              ? 'Merhaba, SoundConnect stüdyo başvurum hakkında bilgi almak istiyorum.'
                              : 'Merhaba, SoundConnect mekan başvurum hakkında bilgi almak istiyorum.',
                        ),
                        'WhatsApp bağlantısı açılamadı.',
                      ),
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: kMinInteractiveDimension,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(4),
                        child: Text.rich(
                          TextSpan(
                            text: 'veya ',
                            children: [
                              TextSpan(
                                text: 'buraya dokunarak',
                                style: TextStyle(
                                  color: supportGreen,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(text: ' '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: FaIcon(
                                    FontAwesomeIcons.whatsapp,
                                    color: supportGreen,
                                    size: 15,
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: 'WhatsApp üzerinden bize ulaşabilirsin.',
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 28),
                    if (statusAction != null) statusAction!,
                    GradientOutline(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: theme.colorScheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: onReturnToLogin,
                        child: const Text(
                          'Giriş ekranına dön',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
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
}

class _GradientIcon extends StatelessWidget {
  const _GradientIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: AppColors.decorativeGradient,
        ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
      },
      child: Icon(icon, size: size),
    );
  }
}
