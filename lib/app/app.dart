import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/auth/token_store.dart';
import '../core/di/service_locator.dart';
import '../modules/auth/presentation/screens/login_screen.dart';
import '../modules/auth/presentation/cubit/auth_cubit.dart';
import '../modules/location/presentation/cubit/location_cubit.dart';
import '../shared/theme/app_theme.dart';
import 'app_shell.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';

enum AppLaunchTarget { login, home }

AppLaunchTarget resolveLaunchTarget(String? token) {
  final hasStoredSession = (token ?? '').trim().isNotEmpty;
  if (hasStoredSession) {
    // Login-first flow: even with a cached token we start from login screen.
    return AppLaunchTarget.login;
  }
  return AppLaunchTarget.login;
}

class SoundConnectApp extends StatefulWidget {
  final Future<String?>? initialTokenFuture;

  const SoundConnectApp({super.key, this.initialTokenFuture});

  @override
  State<SoundConnectApp> createState() => _SoundConnectAppState();
}

class _SoundConnectAppState extends State<SoundConnectApp> {
  late final Future<String?> _initialTokenFuture;

  @override
  void initState() {
    super.initState();
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
          child: MaterialApp(
            title: 'SoundConnect',
            theme: AppTheme.light,
            darkTheme: AppTheme.navy,
            themeMode: ThemeMode.dark,
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: waitingForToken
                ? const _LaunchLoadingScreen()
                : switch (launchTarget) {
                    AppLaunchTarget.home => const AppShell(),
                    AppLaunchTarget.login => const LoginScreen(),
                  },
            routes: {
              AppRoutes.login: (_) => const LoginScreen(),
              AppRoutes.home: (_) => const AppShell(),
            },
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
