import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../dm/domain/dm_user_profile_resolver.dart';
import '../../dm/domain/entities/dm_profile_target.dart';

/// Existing profile choice followed by a fresh visibility check. Cached
/// selection text never authorizes navigation after the sheet is dismissed.
Future<DmProfileTarget?> selectNotificationProfile({
  required BuildContext context,
  required List<DmProfileTarget> profiles,
  required FollowUserProfileResolver resolver,
  required String userId,
  required AuthSession session,
  required bool Function() isCurrent,
}) async {
  if (!context.mounted || !isCurrent() || profiles.isEmpty) return null;
  final single = profiles.singleOrNull;
  if (single != null) return single;
  final selected = await showModalBottomSheet<DmProfileTarget>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Açmak istediğin profili seç')),
          for (final profile in profiles)
            ListTile(
              title: Text(profile.displayName),
              subtitle: Text(switch (profile.type) {
                DmProfileTargetType.musician => 'Müzisyen',
                DmProfileTargetType.venue => 'Mekân',
                DmProfileTargetType.listener => 'Dinleyici',
                DmProfileTargetType.studio => 'Stüdyo',
              }),
              onTap: () => Navigator.pop(sheetContext, profile),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted || !isCurrent() || selected == null) return null;
  final fresh = await resolver.resolveFreshForFollow(
    userId: userId,
    session: session,
  );
  if (!context.mounted || !isCurrent() || !fresh.isSuccess) return null;
  return fresh.data
      ?.where(
        (p) =>
            !p.isStudioRestricted &&
            p.id == selected.id &&
            p.type == selected.type,
      )
      .firstOrNull;
}
