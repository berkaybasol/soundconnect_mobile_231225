import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/register_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/resend_code_result.dart';

import 'support/auth_widget_test_support.dart';

void main() {
  test(
    'register coalesces submissions while its request is in flight',
    () async {
      final repository = RecordingAuthRepository();
      final pending = Completer<Result<RegisterResult>>();
      repository.registerCompleter = pending;
      final cubit = createAuthCubit(repository);
      addTearDown(cubit.close);

      Future<void> submit() => cubit.register(
        username: 'musician',
        email: 'musician@example.com',
        password: 'password',
        rePassword: 'password',
        role: 'ROLE_MUSICIAN',
      );

      final first = submit();
      final second = submit();

      expect(repository.registerCalls, 1);

      pending.complete(repository.registerResult);
      await Future.wait(<Future<void>>[first, second]);

      repository.registerCompleter = null;
      await submit();
      expect(repository.registerCalls, 2);
    },
  );

  test('verify and resend share one OTP action flight', () async {
    final repository = RecordingAuthRepository();
    final pending = Completer<Result<void>>();
    repository.verifyCompleter = pending;
    final cubit = createAuthCubit(repository);
    addTearDown(cubit.close);

    final verify = cubit.verifyCode(
      email: 'musician@example.com',
      code: '123456',
    );
    final duplicateVerify = cubit.verifyCode(
      email: 'musician@example.com',
      code: '123456',
    );
    final competingResend = cubit.resendCode(email: 'musician@example.com');

    expect(repository.verifyCalls, 1);
    expect(repository.resendCalls, 0);

    pending.complete(const Result.success(null));
    await Future.wait(<Future<void>>[verify, duplicateVerify, competingResend]);

    repository.verifyCompleter = null;
    repository.resendResult = const Result.success(
      ResendCodeResult(
        otpTtlSeconds: 180,
        mailQueued: true,
        cooldownSeconds: 30,
      ),
    );
    await cubit.resendCode(email: 'musician@example.com');
    expect(repository.resendCalls, 1);
  });
}
