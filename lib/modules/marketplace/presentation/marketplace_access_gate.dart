import 'package:flutter/material.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/di/service_locator.dart';
import '../domain/marketplace_models.dart';
import 'marketplace_visual_theme.dart';

class _MarketplaceScope extends InheritedWidget {
  const _MarketplaceScope({
    required this.session,
    required this.canAct,
    required super.child,
  });
  final AuthSession session;
  final bool Function() canAct;
  @override
  bool updateShouldNotify(_MarketplaceScope oldWidget) =>
      !identical(session, oldWidget.session);
}

bool marketplaceCanAct(BuildContext context) =>
    context.mounted &&
    (context.getInheritedWidgetOfExactType<_MarketplaceScope>()?.canAct() ??
        false);

AuthSession? marketplaceSessionFor(BuildContext context) => context.mounted
    ? context.getInheritedWidgetOfExactType<_MarketplaceScope>()?.session
    : null;

/// A route/modal belongs to the session that opened it. Removing access also
/// unmounts its forms, stopping late callbacks from adopting another account.
class MarketplaceAccessGate extends StatefulWidget {
  const MarketplaceAccessGate({
    required this.builder,
    this.expectedSession,
    this.sessions,
    super.key,
  });
  final WidgetBuilder builder;
  final AuthSession? expectedSession;
  final AuthSessionManager? sessions;
  @override
  State<MarketplaceAccessGate> createState() => _MarketplaceAccessGateState();
}

class _MarketplaceAccessGateState extends State<MarketplaceAccessGate> {
  AuthSessionManager? _sessions;
  AuthSession? _entry;
  bool _revoked = false;
  bool _disposed = false;
  bool _canAct() =>
      !_disposed &&
      !_revoked &&
      _entry != null &&
      identical(_entry, _sessions?.session) &&
      canUseMarketplace(_entry!);
  @override
  void initState() {
    super.initState();
    _sessions =
        widget.sessions ??
        (serviceLocator.isRegistered<AuthSessionManager>()
            ? serviceLocator<AuthSessionManager>()
            : null);
    _entry = widget.expectedSession ?? _sessions?.session;
    _sessions?.addListener(_changed);
  }

  void _changed() {
    if (!identical(_entry, _sessions?.session)) _revoked = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _disposed = true;
    _sessions?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _sessions?.session;
    if (_canAct() && session != null) {
      return _MarketplaceScope(
        session: session,
        canAct: _canAct,
        child: Builder(builder: widget.builder),
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 42),
                const SizedBox(height: 16),
                const Text(
                  'Ekipman Pazarı bu oturumda kullanılamıyor.',
                  textAlign: TextAlign.center,
                ),
                if (Navigator.of(context).canPop())
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Geri dön'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Route<T> marketplaceRoute<T>(BuildContext context, WidgetBuilder builder) {
  final session = marketplaceSessionFor(context);
  return MaterialPageRoute<T>(
    builder: (_) => MarketplaceThemeScope(
      child: MarketplaceAccessGate(expectedSession: session, builder: builder),
    ),
  );
}

Future<T?> marketplaceDialog<T>(BuildContext context, WidgetBuilder builder) {
  if (!marketplaceCanAct(context)) return Future<T?>.value();
  final session = marketplaceSessionFor(context);
  return showDialog<T>(
    context: context,
    builder: (_) =>
        MarketplaceAccessGate(expectedSession: session, builder: builder),
  );
}

Future<T?> marketplaceSheet<T>(BuildContext context, WidgetBuilder builder) {
  if (!marketplaceCanAct(context)) return Future<T?>.value();
  final session = marketplaceSessionFor(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        MarketplaceAccessGate(expectedSession: session, builder: builder),
  );
}
