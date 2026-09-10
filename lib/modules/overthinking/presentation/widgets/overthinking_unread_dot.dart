import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_colors.dart';
import '../cubit/overthinking_incoming_unread_binding.dart';
import '../cubit/overthinking_incoming_unread_scope.dart';

/// The same discreet indicator at every entrance to the incoming requests.
class OverthinkingUnreadDot extends StatelessWidget {
  const OverthinkingUnreadDot({
    super.key,
    required this.hasUnread,
    required this.child,
    this.badgeKey,
  });

  final bool? hasUnread;
  final Widget child;
  final Key? badgeKey;

  @override
  Widget build(BuildContext context) => Semantics(
    label: hasUnread == true ? 'Yeni kimlik isteği var' : null,
    child: Badge(
      key: badgeKey,
      isLabelVisible: hasUnread == true,
      backgroundColor: AppColors.gradientC,
      smallSize: 7,
      child: child,
    ),
  );
}

/// Navigation entries observe the inbox without marking requests as seen.
class OverthinkingBoundUnreadDot extends StatelessWidget {
  const OverthinkingBoundUnreadDot({
    super.key,
    required this.child,
    required this.badgeKey,
  });

  final Widget child;
  final Key badgeKey;

  @override
  Widget build(BuildContext context) {
    final unread = findOverthinkingIncomingUnreadScope();
    if (unread == null) return child;
    return BlocBuilder<OverthinkingIncomingUnreadScope, bool?>(
      bloc: unread,
      builder: (context, hasUnread) => OverthinkingUnreadDot(
        hasUnread: hasUnread,
        badgeKey: badgeKey,
        child: child,
      ),
    );
  }
}
