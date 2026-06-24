import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/auth/token_store.dart';
import '../core/di/service_locator.dart';
import '../modules/auth/presentation/screens/login_screen.dart';
import '../modules/auth/presentation/cubit/auth_cubit.dart';
import '../modules/auth/presentation/cubit/auth_state.dart';
import '../modules/event/presentation/screens/guest_event_home_screen.dart';
import '../modules/profile/presentation/screens/backstage_profiles_home_screen.dart';
import '../modules/location/presentation/cubit/location_cubit.dart';
import '../modules/notification/presentation/cubit/notification_cubit.dart';
import '../shared/theme/theme_controller.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';

enum AppLaunchTarget { guest, home }

AppLaunchTarget resolveLaunchTarget(String? _) {
  // Temporary guest-first launch flow while onboarding/home is in progress.
  return AppLaunchTarget.guest;
}

class SoundConnectApp extends StatefulWidget {
  final Future<String?>? initialTokenFuture;
  final ThemeController? themeController;

  const SoundConnectApp({
    super.key,
    this.initialTokenFuture,
    this.themeController,
  });

  @override
  State<SoundConnectApp> createState() => _SoundConnectAppState();
}

class _SoundConnectAppState extends State<SoundConnectApp> {
  late final Future<String?> _initialTokenFuture;
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController =
        widget.themeController ??
        (serviceLocator.isRegistered<ThemeController>()
            ? serviceLocator<ThemeController>()
            : ThemeController.memory());
    _initialTokenFuture =
        (widget.initialTokenFuture ?? serviceLocator<TokenStore>().readToken())
            .timeout(const Duration(seconds: 2), onTimeout: () => null)
            .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _initialTokenFuture,
      builder: (context, snapshot) {
        final launchTarget = resolveLaunchTarget(snapshot.data);
        final waitingForToken =
            snapshot.connectionState == ConnectionState.waiting;

        return MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>(create: (_) => serviceLocator<AuthCubit>()),
            BlocProvider<LocationCubit>(
              create: (_) => serviceLocator<LocationCubit>(),
            ),
            BlocProvider<NotificationCubit>.value(
              value: serviceLocator<NotificationCubit>(),
            ),
          ],
          child: _NotificationBootstrap(
            child: AnimatedBuilder(
              animation: _themeController,
              builder: (_, __) => MaterialApp(
                title: 'SoundConnect',
                theme: _themeController.lightTheme,
                darkTheme: _themeController.darkTheme,
                themeMode: _themeController.themeMode,
                onGenerateRoute: AppRouter.onGenerateRoute,
                home: waitingForToken
                    ? _LaunchLoadingScreen()
                    : switch (launchTarget) {
                        AppLaunchTarget.home =>
                          const BackstageProfilesHomeScreen(),
                        AppLaunchTarget.guest => GuestEventHomeScreen(),
                      },
                routes: {
                  AppRoutes.login: (_) => LoginScreen(),
                  AppRoutes.home: (_) => const BackstageProfilesHomeScreen(),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationBootstrap extends StatefulWidget {
  final Widget child;

  const _NotificationBootstrap({required this.child});

  @override
  State<_NotificationBootstrap> createState() => _NotificationBootstrapState();
}

class _NotificationBootstrapState extends State<_NotificationBootstrap> {
  @override
  void initState() {
    super.initState();
    unawaited(serviceLocator<NotificationCubit>().ensureStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) {
        return current.status == AuthStatus.success &&
            current.action == AuthAction.login &&
            current.loginResult?.token != null &&
            previous.loginResult?.token != current.loginResult?.token;
      },
      listener: (context, state) {
        unawaited(context.read<NotificationCubit>().ensureStarted());
      },
      child: widget.child,
    );
  }
}

class _LaunchLoadingScreen extends StatelessWidget {
  const _LaunchLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
