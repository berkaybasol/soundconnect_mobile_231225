import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_theme_variant.dart';
import '../../../../shared/theme/theme_controller.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/gradient_text_field.dart';
import '../../domain/entities/user_status.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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
          if (state.loginResult?.status == UserStatus.pendingVenueRequest) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.venuePending, (route) => false);
            return;
          }
          final stageMode = _stageModeFromToken(state.loginResult?.token);
          final route = stageMode == StageMode.mainstage
              ? AppRoutes.listenerProfile
              : AppRoutes.home;
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(route, (route) => false);
        } else if (state.status == AuthStatus.failure) {
          final message = state.error?.message ?? 'Login failed';
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
              tooltip: 'Tema Sec',
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
                    onPressed: () {},
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
                        final username = _usernameController.text.trim();
                        final password = _passwordController.text.trim();
                        if (username.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('kullanıcı adı boş olamaz')),
                          );
                          return;
                        }
                        if (password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('şifre boş olamaz')),
                          );
                          return;
                        }
                        if (password.length < 3 || password.length > 30) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Şifre 3-30 karakter olmalı'),
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
              OutlinedButton.icon(
                onPressed: () {},
                icon: Image.asset('assets/google.png', height: 20),
                label: Text('Google ile devam et'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hesabin yok mu?',
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

  StageMode _stageModeFromToken(String? token) {
    final roles = _rolesFromToken(token);
    return StageModeResolver.fromRoles(roles);
  }

  List<String> _rolesFromToken(String? token) {
    final raw = token?.trim() ?? '';
    if (raw.isEmpty) return const [];

    final parts = raw.split('.');
    if (parts.length < 2) return const [];

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = jsonDecode(payload);
      if (map is! Map<String, dynamic>) return const [];

      final dynamic rolesValue =
          map['roles'] ?? map['authorities'] ?? map['role'];
      if (rolesValue is List) {
        return rolesValue
            .map((role) => role.toString().trim())
            .where((role) => role.isNotEmpty)
            .toList();
      }
      if (rolesValue is String) {
        return rolesValue
            .split(',')
            .map((role) => role.trim())
            .where((role) => role.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    return const [];
  }
}
