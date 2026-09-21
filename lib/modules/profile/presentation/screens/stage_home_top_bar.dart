import 'package:flutter/material.dart';
import '../../../../app/widgets/app_global_actions.dart';
import '../../../../shared/widgets/profile_menu_actions.dart';

class StageHomeTopBar extends StatelessWidget {
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onMenuTap;
  final int? unreadCountOverride;
  final String searchHint;

  const StageHomeTopBar({
    super.key,
    this.onSearchTap,
    this.onNotificationsTap,
    this.onMenuTap,
    this.unreadCountOverride,
    this.searchHint = 'Müzisyen, dinleyici, grup, stüdyo veya mekân ara',
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
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
                        searchHint,
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
          AppNotificationButton(
            onPressed: onNotificationsTap,
            unreadCountOverride: unreadCountOverride,
            iconSize: 31,
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
