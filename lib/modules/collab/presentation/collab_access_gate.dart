import 'package:flutter/material.dart';

import '../../../app/router/app_route_guard.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/policy/access_policy.dart';

String _identity(AuthSession session) {
  final roles =
      session.roles
          .map((role) {
            final normalized = role.trim().toUpperCase();
            return normalized.startsWith('ROLE_')
                ? normalized
                : 'ROLE_$normalized';
          })
          .toSet()
          .toList()
        ..sort();
  return '${session.userId}|${roles.join(',')}|${session.isActive}|'
      '${session.requiresListenerProfileChoice}';
}

String? collabAccessIdentityFor([BuildContext? context]) {
  final inherited = context
      ?.getInheritedWidgetOfExactType<_CollabIdentityScope>()
      ?.identity;
  if (inherited != null) return inherited;
  return serviceLocator.isRegistered<AuthSessionManager>()
      ? _identity(serviceLocator<AuthSessionManager>().session)
      : null;
}

class _CollabIdentityScope extends InheritedWidget {
  const _CollabIdentityScope({required this.identity, required super.child});

  final String identity;

  @override
  bool updateShouldNotify(_CollabIdentityScope oldWidget) =>
      oldWidget.identity != identity;
}

/// Protects data construction as well as cached screens and modal snapshots.
/// A route belongs to the account/profile that opened it; token refresh alone
/// does not discard an otherwise unchanged account's form or scroll position.
class CollabAccessGate extends StatefulWidget {
  const CollabAccessGate({
    required this.builder,
    this.overlay = false,
    this.expectedIdentity,
    super.key,
  });

  final WidgetBuilder builder;
  final bool overlay;
  final String? expectedIdentity;

  @override
  State<CollabAccessGate> createState() => _CollabAccessGateState();
}

class _CollabAccessGateState extends State<CollabAccessGate> {
  AuthSessionManager? _sessions;
  String? _entryIdentity;

  @override
  void initState() {
    super.initState();
    if (serviceLocator.isRegistered<AuthSessionManager>()) {
      _sessions = serviceLocator<AuthSessionManager>();
      _entryIdentity =
          widget.expectedIdentity ?? collabAccessIdentityFor(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    // The standalone preview/test harness can omit authentication services.
    // Production registers them before constructing any application route.
    if (sessions == null) return widget.builder(context);
    return AnimatedBuilder(
      animation: sessions,
      builder: (context, _) {
        final session = sessions.session;
        if (!session.isAuthenticated ||
            !session.isActive ||
            session.requiresListenerProfileChoice ||
            !AccessPolicy.canAccessCollab(session.roles) ||
            _entryIdentity != _identity(session)) {
          return _CollabUnavailable(overlay: widget.overlay);
        }
        return _CollabIdentityScope(
          identity: _entryIdentity!,
          child: Builder(builder: widget.builder),
        );
      },
    );
  }
}

class _CollabUnavailable extends StatelessWidget {
  const _CollabUnavailable({required this.overlay});

  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      key: const Key('collab-access-unavailable'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Bu iş birliği içeriği mevcut oturumunda kullanılamıyor.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Geri dön'),
            onPressed: () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
                return;
              }
              navigator.pushNamedAndRemoveUntil(
                AppRouteGuard.startRouteFor(
                  serviceLocator<AuthSessionManager>().session,
                ),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
    if (overlay) {
      return Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(child: content),
      );
    }
    return Scaffold(
      body: SafeArea(child: Center(child: content)),
    );
  }
}

Future<T?> showCollabModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useSafeArea = false,
  bool isScrollControlled = false,
  bool? showDragHandle,
}) {
  final identity = collabAccessIdentityFor(context);
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: useSafeArea,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    builder: (_) => CollabAccessGate(
      builder: builder,
      overlay: true,
      expectedIdentity: identity,
    ),
  );
}

Future<T?> showCollabDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final identity = collabAccessIdentityFor(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => CollabAccessGate(
      builder: builder,
      overlay: true,
      expectedIdentity: identity,
    ),
  );
}
