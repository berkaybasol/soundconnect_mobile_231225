import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/auth/token_store.dart';
import '../core/di/service_locator.dart';
import '../modules/auth/presentation/screens/login_screen.dart';
import '../modules/auth/presentation/cubit/auth_cubit.dart';
import '../modules/event/presentation/screens/guest_event_home_screen.dart';
import '../modules/location/presentation/cubit/location_cubit.dart';
import '../shared/theme/theme_controller.dart';
import 'app_shell.dart';
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
          ],
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
                      AppLaunchTarget.home => AppShell(),
                      AppLaunchTarget.guest => GuestEventHomeScreen(),
                    },
              routes: {
                AppRoutes.login: (_) => LoginScreen(),
                AppRoutes.home: (_) => AppShell(),
              },
            ),
          ),
        );
      },
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
