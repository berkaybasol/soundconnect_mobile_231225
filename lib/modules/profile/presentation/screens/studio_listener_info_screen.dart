import 'package:flutter/material.dart';

import '../../../../app/router/app_route_guard.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/profile_brand_title.dart';
import 'profile_public_bottom_bar.dart';
import 'profile_bottom_navigation.dart';

bool isStudioRestrictedListener(AuthSession? session) =>
    session != null &&
    session.isAuthenticated &&
    session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']);

/// Guards direct widget entries before any studio repository or Cubit is built.
class StudioListenerAccessGate extends StatelessWidget {
  const StudioListenerAccessGate({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final sessions = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    if (sessions == null) return builder(context);
    return AnimatedBuilder(
      animation: sessions,
      builder: (context, _) {
        if (isStudioRestrictedListener(sessions.session)) {
          return const StudioListenerInfoScreen();
        }
        // Dispose the old account's providers and pending reads on a change.
        return KeyedSubtree(
          key: ObjectKey(sessions.session),
          // Async surface callbacks must receive a context that is removed
          // with this subtree, not the AnimatedBuilder that survives denial.
          child: Builder(builder: builder),
        );
      },
    );
  }
}

class StudioListenerInfoScreen extends StatelessWidget {
  const StudioListenerInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigator = Navigator.of(context);
    return Scaffold(
      key: const Key('studio-listener-info'),
      appBar: AppBar(
        title: const ProfileBrandTitle(),
        centerTitle: true,
        leading: navigator.canPop()
            ? BackButton(key: const Key('studio-listener-back'))
            : null,
      ),
      bottomNavigationBar: ProfilePublicBottomBar(
        currentIndex: 0,
        mainstageCurrentIndex: 0,
        stageMode: StageMode.mainstage,
        allowCurrentDestinationNavigation: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            key: const Key('studio-listener-scroll'),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 56)
                    .clamp(0, double.infinity)
                    .toDouble(),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: AppColors.brandGradient,
                            ),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.surface,
                            ),
                            child: Icon(
                              Icons.graphic_eq_rounded,
                              size: 44,
                              color: AppColors.socialPink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Stüdyolar Backstage’de',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Stüdyolar, SoundConnect’in iş birliği tarafında yer alıyor. '
                        'Stüdyo profilleri ve SoundConnect’in sunduğu diğer iş birliği '
                        'akışları dinleyici hesabına açık değil.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 24),
                      GradientOutline(
                        radius: 22,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.socialPink.withValues(alpha: .08),
                                AppColors.socialPurple.withValues(alpha: .08),
                              ],
                            ),
                          ),
                          child: Text(
                            'Sen de müzik sektörünün bir parçasıysan, sana uygun '
                            'farklı bir hesap oluşturarak iş birliği akışlarına katılabilirsin.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      GradientOutlineButton(
                        key: const Key('studio-listener-return'),
                        label: 'Geri dön',
                        maxLines: 2,
                        horizontalPadding: 16,
                        leading: const Icon(Icons.arrow_back_rounded, size: 22),
                        onPressed: () {
                          if (navigator.canPop()) {
                            navigator.pop();
                            return;
                          }
                          final session =
                              serviceLocator.isRegistered<AuthSessionManager>()
                              ? serviceLocator<AuthSessionManager>().session
                              : null;
                          // A direct/root entry has no previous screen. Follow
                          // the existing account start route in that case only.
                          replaceProfileBottomNavigationRoute(
                            context,
                            session == null
                                ? AppRoutes.listenerProfile
                                : AppRouteGuard.startRouteFor(session),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
