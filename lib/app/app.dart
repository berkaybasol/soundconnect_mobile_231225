import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/auth/token_store.dart';
import '../core/di/service_locator.dart';
import '../modules/auth/presentation/cubit/auth_cubit.dart';
import '../modules/location/presentation/cubit/location_cubit.dart';
import '../shared/theme/app_theme.dart';
import 'app_shell.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';

class SoundConnectApp extends StatefulWidget {
  const SoundConnectApp({super.key});

  @override
  State<SoundConnectApp> createState() => _SoundConnectAppState();
}

class _SoundConnectAppState extends State<SoundConnectApp> {
  late final Future<String?> _initialTokenFuture;

  @override
  void initState() {
    super.initState();
    _initialTokenFuture = serviceLocator<TokenStore>().readToken();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _initialTokenFuture,
      builder: (context, snapshot) {
        final hasToken = (snapshot.data ?? '').trim().isNotEmpty;

        return MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>(
              create: (_) => serviceLocator<AuthCubit>(),
            ),
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
            initialRoute: hasToken ? AppRoutes.home : AppRoutes.login,
            routes: {
              AppRoutes.home: (_) => const AppShell(),
            },
          ),
        );
      },
    );
  }
}
