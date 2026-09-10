import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/overthinking_session.dart';
import 'overthinking_design.dart';

mixin OverthinkingSessionBoundState<T extends StatefulWidget> on State<T> {
  late final OverthinkingSession overthinkingSession;

  @override
  void initState() {
    super.initState();
    overthinkingSession = OverthinkingSession(
      serviceLocator.isRegistered<AuthSessionManager>()
          ? serviceLocator<AuthSessionManager>()
          : null,
    )..addListener(_sessionChanged);
  }

  void onOverthinkingSessionEnded() {}

  void _sessionChanged() {
    onOverthinkingSessionEnded();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    overthinkingSession
      ..removeListener(_sessionChanged)
      ..dispose();
    super.dispose();
  }
}

/// Separate Navigator routes (dialogs and sheets) must share the parent's
/// captured session; capturing again in their deferred builder is too late.
class OverthinkingSessionBoundary extends StatelessWidget {
  const OverthinkingSessionBoundary({
    super.key,
    required this.session,
    required this.child,
    this.requireAccount = true,
  });
  final OverthinkingSession session;
  final Widget child;
  final bool requireAccount;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) =>
        (requireAccount ? session.canWrite : session.isCurrent)
        ? child
        : const OverthinkingUnavailableScreen(),
  );
}

class OverthinkingUnavailableScreen extends StatelessWidget {
  const OverthinkingUnavailableScreen({super.key, this.postMissing = false});
  final bool postMissing;

  @override
  Widget build(BuildContext context) => Theme(
    data: OverthinkingPalette.theme(context),
    child: Scaffold(
      appBar: AppBar(title: const Text('Overthinking')),
      body: TableGroupOverviewBackdrop(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  postMissing
                      ? 'Bu yazı artık erişilebilir değil.'
                      : OverthinkingSession.error.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: OverthinkingPalette.text,
                    fontSize: 16,
                  ),
                ),
                if (!postMissing) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.overthinkingFeed,
                          (_) => false,
                        ),
                    child: const Text('Akışı yeniden aç'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
