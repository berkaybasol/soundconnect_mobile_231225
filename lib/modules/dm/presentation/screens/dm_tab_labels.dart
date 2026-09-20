import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_colors.dart';
import '../cubit/dm_badge_cubit.dart';
import '../cubit/dm_badge_state.dart';

class DmPrimaryMessagesTab extends StatelessWidget {
  const DmPrimaryMessagesTab({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return Tab(
      child: BlocBuilder<DmBadgeCubit, DmBadgeState>(
        builder: (context, state) => DmPrimaryMessagesTabLabel(
          unreadCount: state.unreadCount,
          compact: compact,
        ),
      ),
    );
  }
}

class DmPrimaryMessagesTabLabel extends StatelessWidget {
  const DmPrimaryMessagesTabLabel({
    super.key,
    required this.unreadCount,
    this.compact = false,
  });

  final int unreadCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Birincil Mesajlar',
          excludeSemantics: true,
          child: Text(compact ? 'Birincil' : 'Birincil Mesajlar'),
        ),
        if (unreadCount > 0) ...[
          const SizedBox(width: 7),
          Semantics(
            label: '$unreadCount okunmamis birincil mesaj',
            child: Container(
              key: const Key('dm-primary-unread-dot'),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppColors.coralAlt,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
