import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/gradient_text_field.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.action != AuthAction.login) return;
        if (state.status == AuthStatus.success) {
          Navigator.pushNamed(context, AppRoutes.home);
        } else if (state.status == AuthStatus.failure) {
          final message = state.error?.message ?? 'Login failed';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
      builder: (context, state) {
        final isLoading =
            state.status == AuthStatus.loading && state.action == AuthAction.login;

        return AppScaffold(
          title: '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 180,
                ),
              ),
              const SizedBox(height: 28),
              GradientTextField(
                controller: _usernameController,
                label: 'Kullanici adi',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              GradientTextField(
                controller: _passwordController,
                label: 'Sifre',
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
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      AppColors.coralLight,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset('assets/fish.png', height: 16),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Sifreni mi unuttun?',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () {
                        final username = _usernameController.text.trim();
                        final password = _passwordController.text.trim();
                        if (username.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('kullanıcı adı boş olamaz'),
                            ),
                          );
                          return;
                        }
                        if (password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('şifre boş olamaz'),
                            ),
                          );
                          return;
                        }
                        if (password.length < 3 || password.length > 30) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('kullanıcı adı 3-30 karakter olmalı'),
                            ),
                          );
                          return;
                        }
                        context.read<AuthCubit>().login(
                              username: username,
                              password: password,
                            );
                      },
                child: Text(isLoading ? 'Giris yapiliyor...' : 'Giris yap'),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'veya',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {},
                icon: Image.asset('assets/google.png', height: 20),
                label: const Text('Google ile devam et'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hesabin yok mu?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                    child: const Text('Uye ol'),
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
