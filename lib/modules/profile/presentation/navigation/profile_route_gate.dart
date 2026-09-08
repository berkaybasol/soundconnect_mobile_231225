import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router/app_route_guard.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import 'profile_route_resolver.dart';

class ProfileRouteGate extends StatefulWidget {
  final ProfileRouteTarget target;
  final WidgetBuilder publicBuilder;
  final ProfileRouteResolver resolver;

  const ProfileRouteGate({
    super.key,
    required this.target,
    required this.publicBuilder,
    this.resolver = const ProfileRouteResolver(),
  });

  @override
  State<ProfileRouteGate> createState() => _ProfileRouteGateState();
}

class _ProfileRouteGateState extends State<ProfileRouteGate> {
  AuthSessionManager? _manager;
  bool _started = false;
  bool _public = false;
  bool _loading = true;
  int _generation = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (serviceLocator.isRegistered<AuthSessionManager>()) {
      _manager = serviceLocator<AuthSessionManager>();
      _manager!.addListener(_onSessionChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_resolve());
    }
  }

  @override
  void didUpdateWidget(covariant ProfileRouteGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.kind != widget.target.kind ||
        oldWidget.target.id != widget.target.id) {
      unawaited(_resolve());
    }
  }

  @override
  void dispose() {
    _generation++;
    _manager?.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    _generation++;
    setState(() {
      _public = false;
      _loading = false;
      _error = 'Hesabın değişti. Profili yeniden açmak için tekrar dene.';
    });
  }

  Future<void> _resolve() async {
    if (!mounted) return;
    final generation = ++_generation;
    final session = _manager?.session ?? const AuthSession.guest();
    final target = widget.target;
    setState(() {
      _public = false;
      _loading = true;
      _error = null;
    });
    bool stillValid() =>
        mounted &&
        generation == _generation &&
        identical(_manager?.session ?? session, session);
    if (target.id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Profil bağlantısı geçersiz.';
      });
      return;
    }
    // A retry may run after logout, suspension or profile-choice changes.
    // Apply the same access rules as a fresh named-route navigation.
    final redirect = AppRouteGuard.redirectFor(target.publicRoute, session);
    if (redirect != null) {
      _replaceDestination(ProfileRouteDestination(redirect), stillValid);
      return;
    }
    if (!target.canResolveOwnership(session)) {
      setState(() {
        _public = true;
        _loading = false;
      });
      return;
    }
    try {
      final destination = await widget.resolver
          .resolve(target, session)
          .timeout(const Duration(seconds: 15));
      if (!mounted || !stillValid()) return;
      if (ModalRoute.of(context)?.isCurrent != true) {
        setState(() {
          _loading = false;
          _error = 'Profili açmak için tekrar dene.';
        });
        return;
      }
      if (destination == null) {
        setState(() {
          _public = true;
          _loading = false;
        });
        return;
      }
      _replaceDestination(destination, stillValid);
    } catch (_) {
      if (!stillValid()) return;
      setState(() {
        _loading = false;
        _error = 'Profil açılamadı. Lütfen tekrar dene.';
      });
    }
  }

  void _replaceDestination(
    ProfileRouteDestination destination,
    bool Function() stillValid,
  ) {
    // Replace only this entry, preserving the page beneath it for Back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!stillValid()) return;
      if (ModalRoute.of(context)?.isCurrent != true) {
        setState(() {
          _loading = false;
          _error = 'Profili açmak için tekrar dene.';
        });
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        destination.route,
        arguments: destination.arguments,
      );
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_public) return widget.publicBuilder(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? 'Profil açılamadı.',
                      textAlign: TextAlign.center,
                    ),
                    if (widget.target.id.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      GradientOutlineButton(
                        label: 'Tekrar dene',
                        onPressed: () {
                          if (mounted &&
                              !_loading &&
                              ModalRoute.of(context)?.isCurrent == true) {
                            unawaited(_resolve());
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
