import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../domain/entities/user_status.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class OtpVerifyArgs {
  final String? email;
  final String? role;

  const OtpVerifyArgs({this.email, this.role});
}

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _codeController = TextEditingController();
  String? _email;
  String? _role;
  bool _emailInitialized = false;
  Timer? _countdownTimer;
  int _remainingSeconds = 180;

  String get _formattedRemaining {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _startCountdown(int seconds) {
    final initial = seconds;
    _countdownTimer?.cancel();
    setState(() {
      _remainingSeconds = initial.clamp(0, 3600);
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 0) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(value);
  }

  bool _isValidCode(String value) {
    final regex = RegExp(r'^\d{6}$');
    return regex.hasMatch(value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_emailInitialized) return;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is OtpVerifyArgs) {
      _email = arg.email;
      _role = arg.role;
    } else if (arg is String && arg.isNotEmpty) {
      _email = arg;
    }
    _startCountdown(180);
    _emailInitialized = true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.action == AuthAction.verify &&
            state.status == AuthStatus.success) {
          final isVenuePending = _role == 'ROLE_VENUE' ||
              state.registerResult?.status == UserStatus.pendingVenueRequest;
          if (isVenuePending) {
            Navigator.pushReplacementNamed(context, AppRoutes.venuePending);
            return;
          }
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
        final effectiveEmail = _email ?? state.registerResult?.email;
        final canSubmit =
            effectiveEmail != null && effectiveEmail.isNotEmpty;

        if (state.action == AuthAction.resend &&
            state.status == AuthStatus.success &&
            resendInfo != null) {
          _startCountdown(resendInfo.otpTtlSeconds.toInt());
        }

        return AppScaffold(
          title: 'E-postayi dogrula',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text('E-postana gelen 6 haneli kodu gir.'),
              const SizedBox(height: 6),
              Text(
                'Kod gecerliligi: $_formattedRemaining',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _codeController,
                builder: (context, value, child) {
                  final code = value.text.trim();
                  final isValid = _isValidCode(code);
                  final iconColor = isValid
                      ? AppColors.coralAlt
                      : Theme.of(context).disabledColor;

                  return TextField(
                    controller: _codeController,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Kod',
                      prefixIcon: Icon(Icons.verified_outlined, color: iconColor),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isVerifying || !canSubmit
                    ? null
                    : () {
                        if (effectiveEmail == null ||
                            effectiveEmail.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('email boş olamaz'),
                            ),
                          );
                          return;
                        }
                        if (!_isValidEmail(effectiveEmail)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('geçerli bir email giriniz'),
                            ),
                          );
                          return;
                        }
                        final code = _codeController.text.trim();
                        if (code.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('kod boş olamaz'),
                            ),
                          );
                          return;
                        }
                        if (_remainingSeconds <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kodun suresi doldu. Tekrar gonder.'),
                            ),
                          );
                          return;
                        }
                        if (!_isValidCode(code)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('kod 6 haneli olmalı'),
                            ),
                          );
                          return;
                        }
                        context.read<AuthCubit>().verifyCode(
                              email: effectiveEmail,
                              code: code,
                            );
                      },
                child: Text(isVerifying ? 'Dogrulaniyor...' : 'Dogrula'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: isResending || !canSubmit
                    ? null
                    : () {
                        if (effectiveEmail == null ||
                            effectiveEmail.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('email boş olamaz'),
                            ),
                          );
                          return;
                        }
                        if (!_isValidEmail(effectiveEmail)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('geçerli bir email giriniz'),
                            ),
                          );
                          return;
                        }
                        context
                            .read<AuthCubit>()
                            .resendCode(email: effectiveEmail);
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
