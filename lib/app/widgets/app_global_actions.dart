import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/auth_session_manager.dart';
import '../../core/di/service_locator.dart';
import '../../modules/notification/presentation/cubit/notification_cubit.dart';
import '../../modules/profile/presentation/screens/backstage_profile_search_sheet.dart';
import '../../shared/theme/app_colors.dart';
import '../router/app_routes.dart';

/// Application-level discovery and notifications, separate from module tools.
/// Both actions reuse the destinations and notification state from the feed.
class AppGlobalActions extends StatefulWidget {
  const AppGlobalActions({this.onBeforeNavigate, super.key});

  final Future<bool> Function()? onBeforeNavigate;

  @override
  State<AppGlobalActions> createState() => _AppGlobalActionsState();
}

class _AppGlobalActionsState extends State<AppGlobalActions> {
  bool _opening = false;

  Future<void> _open(Future<void> Function() action) async {
    if (_opening) return;
    final manager = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    final session = manager?.session;
    final route = ModalRoute.of(context);
    setState(() => _opening = true);
    try {
      final allowed =
          await (widget.onBeforeNavigate?.call() ?? Future<bool>.value(true));
      if (!mounted ||
          !allowed ||
          route?.isCurrent == false ||
          (manager != null && !identical(manager.session, session))) {
        return;
      }
      await action();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'SoundConnect genel araçları',
        child: Container(
          height: 48,
          width: 98,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const ValueKey('app-global-search'),
                tooltip: 'SoundConnect’te profil ara',
                onPressed: _opening
                    ? null
                    : () => _open(() => showBackstageProfileSearch(context)),
                icon: const Icon(Icons.search_rounded, size: 23),
                color: scheme.onSurface,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                padding: EdgeInsets.zero,
              ),
              AppNotificationButton(
                key: const ValueKey('app-global-notifications'),
                enabled: !_opening,
                onPressed: () => _open(
                  () => Navigator.of(
                    context,
                  ).pushNamed<void>(AppRoutes.notifications),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared with the original feed header; never starts a second subscription.
class AppNotificationButton extends StatelessWidget {
  const AppNotificationButton({
    this.onPressed,
    this.unreadCountOverride,
    this.iconSize = 23,
    this.enabled = true,
    super.key,
  });

  final VoidCallback? onPressed;
  final int? unreadCountOverride;
  final double iconSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Production provides the existing app-wide cubit. Isolated previews can
    // render a quiet bell without creating services or network subscriptions.
    final count =
        unreadCountOverride ??
        context.select<NotificationCubit?, int>(
          (cubit) => cubit?.state.unreadCount ?? 0,
        );
    final VoidCallback? action = !enabled
        ? null
        : onPressed ??
              () => Navigator.of(context).pushNamed(AppRoutes.notifications);
    return Semantics(
      label: count > 0 ? 'Bildirimler, $count okunmamış' : 'Bildirimler',
      excludeSemantics: true,
      button: true,
      enabled: enabled,
      onTap: action,
      child: IconButton(
        tooltip: 'Bildirimler',
        onPressed: action,
        color: Theme.of(context).colorScheme.onSurface,
        iconSize: iconSize,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        padding: EdgeInsets.zero,
        icon: Badge(
          isLabelVisible: count > 0,
          backgroundColor: AppColors.coralAlt,
          textColor: AppColors.onAccent,
          label: Text(
            count > 99 ? '99+' : '$count',
            textScaler: TextScaler.noScaling,
          ),
          child: const Icon(Icons.notifications_none_outlined),
        ),
      ),
    );
  }
}
