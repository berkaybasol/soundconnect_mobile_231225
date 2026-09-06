import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/band_repository.dart';
import '../../domain/entities/band_profile.dart';
import '../../domain/entities/event_performer_request.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/event_performer_request_repository.dart';
import '../../domain/musician_profile_repository.dart';
import 'event_performer_requests_screen.dart';
import 'event_profile_publications_screen.dart';
import 'event_management_hub.dart';
import '../../domain/event_profile_publication_repository.dart';

@visibleForTesting
class EventInvitationNavigationDependencies {
  const EventInvitationNavigationDependencies({
    required this.sessionKeyProvider,
    this.sessionChanges,
    this.loadMyProfile,
    this.loadBand,
    this.requests,
    this.publications,
  });

  final String? Function() sessionKeyProvider;
  final Listenable? sessionChanges;
  final Future<Result<MusicianProfile>> Function()? loadMyProfile;
  final Future<Result<BandProfile>> Function(String bandId)? loadBand;
  final EventPerformerRequestRepository? requests;
  final EventProfilePublicationRepository? publications;
}

final _activeInvitationEntries = Expando<bool>();
final _activeManagementMenus = Expando<bool>();

Future<void> openEventManagement(
  BuildContext context, {
  required EventPerformerTargetType targetType,
  required String targetId,
  EventInvitationNavigationDependencies? dependencies,
}) async {
  final navigator = Navigator.of(context);
  final route = ModalRoute.of(context);
  if (_activeManagementMenus[navigator] == true || route?.isCurrent == false) {
    return;
  }
  final manager = serviceLocator.isRegistered<AuthSessionManager>()
      ? serviceLocator<AuthSessionManager>()
      : null;
  final session =
      dependencies?.sessionKeyProvider ?? () => manager?.session.userId;
  final expected = session();
  final token = manager?.session.token;
  _activeManagementMenus[navigator] = true;
  try {
    final destination = await showEventManagementHub(context);
    if (destination == null ||
        !context.mounted ||
        !navigator.mounted ||
        route?.isCurrent == false ||
        expected != session() ||
        token != manager?.session.token) {
      return;
    }
    await openEventInvitations(
      context,
      targetType: targetType,
      targetId: targetId,
      dependencies: dependencies,
      destination: destination,
    );
  } finally {
    _activeManagementMenus[navigator] = false;
  }
}

/// Consent is independent of calendar publication. Entry checks only session
/// and performer ownership, never the personal or band calendar preference.
Future<void> openEventInvitations(
  BuildContext context, {
  EventPerformerTargetType? targetType,
  String? targetId,
  EventInvitationNavigationDependencies? dependencies,
  EventManagementDestination destination =
      EventManagementDestination.invitations,
}) async {
  final navigator = Navigator.of(context);
  if (_activeInvitationEntries[navigator] == true) return;
  final originRoute = ModalRoute.of(context);
  final id = targetId?.trim();
  if ((targetType == null) != (targetId == null) || id == '') {
    _showInvitationMessage(context, 'Davetin ait olduğu profil doğrulanamadı.');
    return;
  }

  final manager = serviceLocator.isRegistered<AuthSessionManager>()
      ? serviceLocator<AuthSessionManager>()
      : null;
  final readSession =
      dependencies?.sessionKeyProvider ?? () => manager?.session.userId;
  final expectedSession = readSession()?.trim();
  final expectedToken = dependencies == null ? manager?.session.token : null;
  bool sameSession() =>
      expectedSession != null &&
      expectedSession.isNotEmpty &&
      readSession()?.trim() == expectedSession &&
      (dependencies != null ||
          (manager?.session.token == expectedToken &&
              manager?.session.isAuthenticated == true &&
              manager?.session.isActive == true));
  bool canNavigate() =>
      context.mounted &&
      navigator.mounted &&
      (originRoute == null || originRoute.isCurrent) &&
      sameSession();
  if (!sameSession()) {
    _showInvitationMessage(
      context,
      'Davetleri görmek için yeniden giriş yapmalısın.',
    );
    return;
  }

  final type = targetType ?? EventPerformerTargetType.musician;
  String? resolvedId;
  Future<bool> verifyTarget() async {
    try {
      if (type == EventPerformerTargetType.band) {
        final load =
            dependencies?.loadBand ??
            serviceLocator<BandRepository>().getBandById;
        final result = await load(id!);
        final band = result.data;
        if (!sameSession() ||
            !result.isSuccess ||
            band == null ||
            band.id.trim() != id) {
          return false;
        }
        final founder = band.members.any(
          (member) =>
              member.userId.trim() == expectedSession &&
              member.isFounder &&
              member.status.trim().toUpperCase() == 'ACTIVE',
        );
        if (founder) resolvedId = id;
        return founder;
      }
      final load =
          dependencies?.loadMyProfile ??
          serviceLocator<MusicianProfileRepository>().getMyProfile;
      final result = await load();
      final profile = result.data;
      if (!sameSession() ||
          !result.isSuccess ||
          profile == null ||
          profile.id.trim().isEmpty ||
          profile.userId.trim() != expectedSession ||
          (id != null && id != profile.id) ||
          (resolvedId != null && resolvedId != profile.id)) {
        return false;
      }
      resolvedId = profile.id;
      return true;
    } catch (_) {
      return false;
    }
  }

  _activeInvitationEntries[navigator] = true;
  try {
    while (canNavigate()) {
      final authorized = await verifyTarget();
      if (!canNavigate()) return;
      if (authorized) {
        final unavailable = await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => _InvitationSessionGuard(
              sameSession: sameSession,
              verifyTarget: verifyTarget,
              sessionChanges: dependencies?.sessionChanges ?? manager,
              targetType: type,
              targetId: resolvedId!,
              requests: dependencies?.requests,
              publications: dependencies?.publications,
              destination: destination,
              sessionKeyProvider: readSession,
            ),
          ),
        );
        if (unavailable != true || !canNavigate()) return;
      }
      if (!context.mounted) return;
      final retry = await _showUnavailableDialog(context);
      if (retry != true || !canNavigate()) return;
    }
  } finally {
    _activeInvitationEntries[navigator] = false;
  }
}

void _showInvitationMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool?> _showUnavailableDialog(BuildContext context) {
  final theme = Theme.of(context);
  var finished = false;
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      void finish(bool retry) {
        if (finished || ModalRoute.of(dialogContext)?.isCurrent != true) return;
        finished = true;
        Navigator.of(dialogContext).pop(retry);
      }

      return Dialog(
        key: const Key('event-invitations-unavailable'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: theme.dividerColor),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Davetlere erişilemiyor',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Profilin veya grup yetkin doğrulanamadı. Bağlantını kontrol edip tekrar deneyebilirsin.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: GradientOutlineButton(
                  key: const Key('event-invitations-retry'),
                  label: 'Tekrar dene',
                  leading: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: () => finish(true),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => finish(false),
                  child: const Text('Şimdi değil'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _InvitationSessionGuard extends StatefulWidget {
  const _InvitationSessionGuard({
    required this.sameSession,
    required this.verifyTarget,
    required this.sessionChanges,
    required this.targetType,
    required this.targetId,
    required this.sessionKeyProvider,
    this.requests,
    this.publications,
    required this.destination,
  });
  final bool Function() sameSession;
  final Future<bool> Function() verifyTarget;
  final Listenable? sessionChanges;
  final EventPerformerTargetType targetType;
  final String targetId;
  final String? Function() sessionKeyProvider;
  final EventPerformerRequestRepository? requests;
  final EventProfilePublicationRepository? publications;
  final EventManagementDestination destination;

  @override
  State<_InvitationSessionGuard> createState() =>
      _InvitationSessionGuardState();
}

class _InvitationSessionGuardState extends State<_InvitationSessionGuard>
    with WidgetsBindingObserver {
  bool _visible = false;
  bool _closing = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _visible = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.sessionChanges?.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!widget.sameSession()) _close(null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closing) return;
    final generation = ++_generation;
    setState(() => _visible = false);
    if (state == AppLifecycleState.resumed) unawaited(_recheck(generation));
  }

  Future<void> _recheck(int generation) async {
    final authorized = await widget.verifyTarget();
    if (!mounted || _closing || generation != _generation) return;
    if (!widget.sameSession()) {
      _close(null);
    } else if (!authorized) {
      _close(true);
    } else {
      setState(() => _visible = true);
    }
  }

  void _close(bool? unavailable) {
    if (!mounted || _closing) return;
    _closing = true;
    ++_generation;
    setState(() => _visible = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route, unavailable);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.sessionChanges?.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _visible && !_closing && widget.sameSession()
      ? widget.destination == EventManagementDestination.events
            ? EventProfilePublicationsScreen(
                targetType: widget.targetType,
                targetId: widget.targetId,
                repository: widget.publications,
                sessionKeyProvider: widget.sessionKeyProvider,
                showPeriods: true,
              )
            : EventPerformerRequestsScreen(
                targetType: widget.targetType,
                targetId: widget.targetId,
                repository: widget.requests,
                sessionKeyProvider: widget.sessionKeyProvider,
                status:
                    widget.destination == EventManagementDestination.rejected
                    ? EventPerformerRequestStatus.rejected
                    : EventPerformerRequestStatus.pending,
              )
      : const Scaffold(body: Center(child: CircularProgressIndicator()));
}
