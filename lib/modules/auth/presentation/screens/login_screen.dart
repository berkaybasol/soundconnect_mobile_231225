import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/router/app_route_guard.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_theme_variant.dart';
import '../../../../shared/theme/theme_controller.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/gradient_text_field.dart';
import '../../domain/password_policy.dart';
import '../../domain/username_policy.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginRouteArgs {
  const LoginRouteArgs({this.initialNotice});

  final String? initialNotice;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialNotice});

  final String? initialNotice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordObscured = true;

  @override
  void initState() {
    super.initState();
    final notice = widget.initialNotice?.trim();
    if (notice == null || notice.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(notice)));
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _canonicalizeUsername() {
    final username = UsernamePolicy.normalize(_usernameController.text);
    if (_usernameController.text != username) {
      _usernameController.value = TextEditingValue(
        text: username,
        selection: TextSelection.collapsed(offset: username.length),
      );
    }
    return username;
  }

  @override
  Widget build(BuildContext context) {
    final themeController = serviceLocator.isRegistered<ThemeController>()
        ? serviceLocator<ThemeController>()
        : ThemeController.memory();
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.action != AuthAction.login) return;
        if (state.status == AuthStatus.success) {
          final session = serviceLocator<AuthSessionManager>().session;
          final route = AppRouteGuard.startRouteFor(session);
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(route, (route) => false);
        } else if (state.status == AuthStatus.failure) {
          final pendingRoute = switch (state.error?.code) {
            'auth_pending_venue_approval' => AppRoutes.venuePending,
            'auth_pending_studio_approval' => AppRoutes.studioPending,
            'auth_studio_application_rejected' => AppRoutes.studioRejected,
            _ => null,
          };
          if (pendingRoute != null) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(pendingRoute, (route) => false);
            return;
          }
          final message =
              state.error?.message ??
              'Giriş yapılamadı. Bilgilerini kontrol edip tekrar deneyebilirsin.';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        final isLoading =
            state.status == AuthStatus.loading &&
            state.action == AuthAction.login;

        return AppScaffold(
          title: '',
          actions: [
            PopupMenuButton<AppThemeVariant>(
              tooltip: 'Tema seç',
              initialValue: themeController.variant,
              onSelected: themeController.setVariant,
              itemBuilder: (_) => AppThemeVariant.values
                  .map(
                    (variant) => PopupMenuItem<AppThemeVariant>(
                      value: variant,
                      child: Text(variant.label),
                    ),
                  )
                  .toList(),
              icon: const Icon(Icons.palette_outlined),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 24),
              Center(child: Image.asset('assets/logo.png', height: 180)),
              SizedBox(height: 28),
              GradientTextField(
                controller: _usernameController,
                label: 'Kullanıcı adı',
                prefixIcon: Icons.person_outline,
              ),
              SizedBox(height: 16),
              GradientTextField(
                controller: _passwordController,
                label: 'Şifre',
                prefixIcon: Icons.lock_outline,
                obscureText: _isPasswordObscured,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _isPasswordObscured = !_isPasswordObscured;
                    });
                  },
                  icon: Icon(
                    _isPasswordObscured
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      AppColors.coralLight,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset('assets/fish.png', height: 16),
                  ),
                  SizedBox(width: 4),
                  TextButton(
                    key: const Key('forgot-password-button'),
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.forgotPassword),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Şifreni mi unuttun?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: isLoading
                    ? null
                    : () {
                        final username = _canonicalizeUsername();
                        final password = _passwordController.text;
                        if (username.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('kullanıcı adı boş olamaz')),
                          );
                          return;
                        }
                        if (PasswordPolicy.isBlank(password)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('şifre boş olamaz')),
                          );
                          return;
                        }
                        if (PasswordPolicy.exceedsBcryptLimit(password)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Şifre UTF-8 olarak en fazla 72 bayt olmalı',
                              ),
                            ),
                          );
                          return;
                        }
                        context.read<AuthCubit>().login(
                          username: username,
                          password: password,
                        );
                      },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLoading
                          ? [
                              Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.7),
                              Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.7),
                            ]
                          : AppColors.brandGradient,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(1),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isLoading ? 'Giriş yapılıyor...' : 'Giriş yap',
                        style: TextStyle(
                          color: isLoading
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'veya',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              SizedBox(height: 14),
              Tooltip(
                message: 'Google ile giris yakinda kullanima acilacak',
                child: OutlinedButton.icon(
                  key: const Key('google-sign-in-unavailable'),
                  onPressed: null,
                  icon: Image.asset('assets/google.png', height: 20),
                  label: Text('Google ile devam et (yakinda)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hesabın yok mu?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.register),
                    child: Text('Üye ol'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
