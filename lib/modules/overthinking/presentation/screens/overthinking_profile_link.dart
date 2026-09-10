import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../dm/domain/dm_user_profile_resolver.dart';
import '../../../dm/domain/entities/dm_profile_target.dart';
import '../../../dm/presentation/dm_profile_navigation.dart';
import '../../domain/overthinking_session.dart';
import 'overthinking_design.dart';
import 'overthinking_session_guard.dart';

/// Adds navigation without changing the caller's contextual identity display.
/// Anonymous authors must pass no userId and keep [enabled] false.
class OverthinkingProfileLink extends StatefulWidget {
  const OverthinkingProfileLink({
    super.key,
    required this.child,
    this.userId,
    this.enabled = true,
    this.semanticsLabel,
    this.isCurrent,
  });

  final Widget child;
  final String? userId;
  final bool enabled;
  final String? semanticsLabel;
  final bool Function()? isCurrent;

  @override
  State<OverthinkingProfileLink> createState() =>
      _OverthinkingProfileLinkState();
}

class _OverthinkingProfileLinkState extends State<OverthinkingProfileLink>
    with OverthinkingSessionBoundState<OverthinkingProfileLink> {
  int _identityGeneration = 0;

  bool get _enabled =>
      widget.enabled &&
      widget.userId?.trim().isNotEmpty == true &&
      overthinkingSession.canWrite &&
      (widget.isCurrent?.call() ?? true);

  @override
  void didUpdateWidget(OverthinkingProfileLink oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.enabled != widget.enabled) {
      ++_identityGeneration;
    }
  }

  Future<void> _open() async {
    if (!_enabled) return;
    final generation = _identityGeneration;
    await openOverthinkingUserProfile(
      context,
      widget.userId,
      isCurrent: () => mounted && _enabled && generation == _identityGeneration,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    final label = widget.semanticsLabel ?? 'Profili görüntüle';
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(12),
          child: widget.child,
        ),
      ),
    );
  }
}

// A weak route key coalesces avatar/name taps across different cards, without
// retaining disposed routes or using user IDs as globally cached destinations.
final Expando<bool> _openingProfile = Expando<bool>();

Future<void> openOverthinkingUserProfile(
  BuildContext context,
  String? userId, {
  bool enabled = true,
  AuthSessionManager? sessions,
  DmUserProfileResolver? resolver,
  bool Function()? isCurrent,
}) async {
  final id = userId?.trim() ?? '';
  if (!context.mounted ||
      !enabled ||
      id.isEmpty ||
      isCurrent?.call() == false) {
    return;
  }
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent || _openingProfile[route] == true) {
    return;
  }
  final manager =
      sessions ??
      (serviceLocator.isRegistered<AuthSessionManager>()
          ? serviceLocator<AuthSessionManager>()
          : null);
  final expected = manager?.session;
  if (expected?.isAuthenticated != true ||
      expected?.isActive != true ||
      expected?.requiresListenerProfileChoice == true) {
    return;
  }
  final lease = OverthinkingSession(manager);
  if (!lease.canWrite) {
    lease.dispose();
    return;
  }
  bool current() =>
      context.mounted &&
      route.isCurrent &&
      lease.canWrite &&
      (isCurrent?.call() ?? true);
  _openingProfile[route] = true;
  try {
    // Only the canonical resolver knows the profile ID/type. Contextual user
    // IDs, raw names and cached avatars must never become destination hints.
    final actualResolver = resolver ?? serviceLocator<DmUserProfileResolver>();
    final resolved = await actualResolver.resolveByUserId(userId: id);
    if (!context.mounted || !current()) return;
    final targets = <String, DmProfileTarget>{
      for (final target in resolved)
        if (target.id.trim().isNotEmpty)
          '${target.type.name}:${target.id.trim()}': target,
    }.values.toList(growable: false);
    if (targets.isEmpty) {
      _profileMessage(context, 'Profil şu anda açılamıyor.');
      return;
    }
    final selected = targets.length == 1
        ? targets.single
        : await showModalBottomSheet<DmProfileTarget>(
            context: context,
            useSafeArea: true,
            backgroundColor: OverthinkingPalette.surface,
            builder: (sheetContext) => OverthinkingSessionBoundary(
              session: lease,
              child: _ProfileChoices(targets: targets),
            ),
          );
    if (!context.mounted || !current() || selected == null) return;
    final destination = dmProfileRouteFor(selected);
    if (destination == null) return;
    await Navigator.of(
      context,
    ).pushNamed(destination.routeName, arguments: destination.arguments);
  } catch (_) {
    if (context.mounted && current()) {
      _profileMessage(context, 'Profil açılamadı. Yeniden deneyebilirsin.');
    }
  } finally {
    lease.dispose();
    _openingProfile[route] = false;
  }
}

void _profileMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(context, tone: AppSnackBarTone.info, content: Text(message)),
    );

class _ProfileChoices extends StatelessWidget {
  const _ProfileChoices({required this.targets});
  final List<DmProfileTarget> targets;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Profili görüntüle',
              style: TextStyle(
                color: OverthinkingPalette.text,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          for (final target in targets)
            ListTile(
              leading: Icon(switch (target.type) {
                DmProfileTargetType.listener => Icons.headphones_rounded,
                DmProfileTargetType.musician => Icons.music_note_rounded,
                DmProfileTargetType.studio => Icons.graphic_eq_rounded,
                DmProfileTargetType.venue => Icons.storefront_rounded,
              }, color: OverthinkingPalette.lilac),
              title: Text(
                target.type.displayLabel,
                style: const TextStyle(color: OverthinkingPalette.text),
              ),
              onTap: () => Navigator.of(context).pop(target),
            ),
        ],
      ),
    ),
  );
}
