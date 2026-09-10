import 'package:flutter/material.dart';

import 'overthinking_unread_dot.dart';

class OverthinkingIncomingRequestIcon extends StatelessWidget {
  const OverthinkingIncomingRequestIcon({
    super.key,
    required this.hasUnread,
    this.size = 17,
  });

  final bool? hasUnread;
  final double size;

  @override
  Widget build(BuildContext context) {
    return OverthinkingUnreadDot(
      hasUnread: hasUnread,
      badgeKey: const ValueKey('overthinking-incoming-request-dot'),
      child: ExcludeSemantics(child: Icon(Icons.inbox_outlined, size: size)),
    );
  }
}
