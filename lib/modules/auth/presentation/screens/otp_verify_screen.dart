import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _emailInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_emailInitialized) return;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String && arg.isNotEmpty) {
      _emailController.text = arg;
    }
    _emailInitialized = true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.action == AuthAction.verify &&
            state.status == AuthStatus.success) {
          Navigator.pushNamed(context, AppRoutes.login);
        } else if (state.status == AuthStatus.failure &&
            (state.action == AuthAction.verify || state.action == AuthAction.resend)) {
          final message = state.error?.message ?? 'Verification failed';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
      builder: (context, state) {
        final isVerifying =
            state.status == AuthStatus.loading && state.action == AuthAction.verify;
        final isResending =
            state.status == AuthStatus.loading && state.action == AuthAction.resend;
        final resendInfo = state.resendResult;

        return AppScaffold(
          title: 'E-postayi dogrula',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text('E-postana gelen 6 haneli kodu gir.'),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Kod',
                  prefixIcon: Icon(Icons.verified_outlined),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isVerifying
                    ? null
                    : () {
                        final email = _emailController.text.trim();
                        final code = _codeController.text.trim();
                        if (email.isEmpty || code.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email ve kod gerekli.'),
                            ),
                          );
                          return;
                        }
                        context.read<AuthCubit>().verifyCode(
                              email: email,
                              code: code,
                            );
                      },
                child: Text(isVerifying ? 'Dogrulaniyor...' : 'Dogrula'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: isResending
                    ? null
                    : () {
                        final email = _emailController.text.trim();
                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email gerekli.'),
                            ),
                          );
                          return;
                        }
                        context.read<AuthCubit>().resendCode(email: email);
                      },
                child: Text(
                  isResending
                      ? 'Tekrar gonderiliyor...'
                      : 'Tekrar gonder (${resendInfo?.cooldownSeconds ?? 30}s)',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
