import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/profile_menu_actions.dart';
import '../../../notification/presentation/cubit/notification_cubit.dart';
import '../../../notification/presentation/cubit/notification_state.dart';

class StageHomeTopBar extends StatelessWidget {
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onMenuTap;

  const StageHomeTopBar({
    super.key,
    this.onSearchTap,
    this.onNotificationsTap,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onSearchTap,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: textColor, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Müzisyen, dinleyici, grup, stüdyo veya mekân ara',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          BlocBuilder<NotificationCubit, NotificationState>(
            builder: (context, state) {
              return IconButton(
                onPressed:
                    onNotificationsTap ??
                    () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.notifications),
                icon: _NotificationBell(unreadCount: state.unreadCount),
                iconSize: 31,
                splashRadius: 24,
                tooltip: 'Bildirimler',
              );
            },
          ),
          IconButton(
            onPressed: onMenuTap,
            icon: const ProfileMenuLogo(),
            splashRadius: 24,
            tooltip: 'Menü',
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int unreadCount;

  const _NotificationBell({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) {
      return const Icon(Icons.notifications_none_outlined);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none_outlined),
        Positioned(
          right: -8,
          top: -6,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.coralAlt,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
