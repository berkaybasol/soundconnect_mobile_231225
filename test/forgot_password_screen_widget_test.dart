import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/forgot_password_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/auth_widget_test_support.dart';

void main() {
  late RecordingAuthRepository repository;
  late AuthCubit cubit;

  setUp(() {
    repository = RecordingAuthRepository();
    cubit = createAuthCubit(repository);
  });

  tearDown(() async {
    await cubit.close();
  });

  Widget app() {
    return MaterialApp(
      home: BlocProvider<AuthCubit>.value(
        value: cubit,
        child: const ForgotPasswordScreen(),
      ),
    );
  }

  testWidgets(
    'confirms the account and requests a code only after valid passwords',
    (tester) async {
      final completer = Completer<Result<void>>();
      repository.requestPasswordResetCompleter = completer;
      await tester.pumpWidget(app());

      expect(
        find.byKey(const Key('forgot-password-step-indicator')),
        findsOneWidget,
      );
      await tester.enterText(
        _field(const Key('forgot-password-identifier-field')),
        '  User@Example.COM  ',
      );
      await tester.tap(find.byKey(const Key('forgot-password-request-button')));
      await tester.pumpAndSettle();

      expect(repository.requestPasswordResetCalls, 0);
      expect(
        find.byKey(const Key('forgot-password-confirmation-account')),
        findsOneWidget,
      );
      expect(
        find.text('Bu hesapla devam etmek istiyor musun?'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('forgot-password-account-avatar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('forgot-password-edit-identifier-button')),
        findsNothing,
      );
      expect(find.byKey(const Key('forgot-password-code-field')), findsNothing);

      await tester.tap(find.byKey(const Key('forgot-password-confirm-button')));
      await tester.pumpAndSettle();

      expect(repository.requestPasswordResetCalls, 0);
      expect(
        find.byKey(const Key('forgot-password-new-password-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('forgot-password-repeat-password-field')),
        findsOneWidget,
      );

      await _enterPasswords(tester);
      await tester.ensureVisible(
        find.byKey(const Key('forgot-password-password-continue-button')),
      );
      await tester.tap(
        find.byKey(const Key('forgot-password-password-continue-button')),
      );
      await tester.pump();

      expect(repository.requestPasswordResetCalls, 1);
      expect(repository.lastPasswordResetIdentifier, 'user@example.com');
      expect(
        tester
            .widget<GradientOutlineButton>(
              find.byKey(const Key('forgot-password-password-continue-button')),
            )
            .onPressed,
        isNull,
      );

      completer.complete(const Result.success(null));
      repository.requestPasswordResetCompleter = null;
      await tester.pumpAndSettle();

      expect(find.text('Şifre sıfırlama kodu gönderildi.'), findsOneWidget);
      expect(
        find.byKey(const Key('forgot-password-code-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('forgot-password-new-password-field')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('forgot-password-selected-identifier')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('forgot-password-edit-identifier-button')),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(const Key('forgot-password-resend-button')),
      );
      await tester.tap(find.byKey(const Key('forgot-password-resend-button')));
      await tester.pumpAndSettle();

      expect(repository.requestPasswordResetCalls, 2);
      expect(repository.lastPasswordResetIdentifier, 'user@example.com');
    },
  );

  testWidgets('blocks mismatched passwords before sending a code', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await _advanceToPassword(tester, 'user@example.com');

    await tester.enterText(
      _field(const Key('forgot-password-new-password-field')),
      'password123',
    );
    await tester.enterText(
      _field(const Key('forgot-password-repeat-password-field')),
      'different123',
    );
    await tester.ensureVisible(
      find.byKey(const Key('forgot-password-password-continue-button')),
    );
    await tester.tap(
      find.byKey(const Key('forgot-password-password-continue-button')),
    );
    await tester.pump();

    expect(repository.requestPasswordResetCalls, 0);
    expect(find.text('Şifreler eşleşmeli.'), findsOneWidget);
    expect(find.byKey(const Key('forgot-password-code-field')), findsNothing);
  });

  testWidgets('blocks an unknown username before the confirmation screen', (
    tester,
  ) async {
    repository.passwordResetAccountResult = const Result.failure(
      AppError(
        code: '1109',
        message: 'Bu kullanıcı adıyla kayıtlı bir hesap bulunamadı.',
      ),
    );
    await tester.pumpWidget(app());
    await tester.enterText(
      _field(const Key('forgot-password-identifier-field')),
      '  BeRkAy  ',
    );
    await tester.tap(find.byKey(const Key('forgot-password-request-button')));
    await tester.pumpAndSettle();

    expect(repository.lastPasswordResetAccountIdentifier, 'berkay');
    expect(repository.requestPasswordResetCalls, 0);
    expect(
      find.byKey(const Key('forgot-password-request-error')),
      findsOneWidget,
    );
    expect(
      find.text('Bu kullanıcı adıyla kayıtlı bir hesap bulunamadı.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('forgot-password-confirmation-account')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('forgot-password-new-password-field')),
      findsNothing,
    );
    expect(find.byKey(const Key('forgot-password-code-field')), findsNothing);
  });

  testWidgets('blocks an unknown email before the confirmation screen', (
    tester,
  ) async {
    repository.passwordResetAccountResult = const Result.failure(
      AppError(
        code: '1108',
        message: 'Bu e-posta adresiyle kayıtlı bir hesap bulunamadı.',
      ),
    );
    await tester.pumpWidget(app());
    await tester.enterText(
      _field(const Key('forgot-password-identifier-field')),
      '  Missing@Example.COM  ',
    );
    await tester.tap(find.byKey(const Key('forgot-password-request-button')));
    await tester.pumpAndSettle();

    expect(
      repository.lastPasswordResetAccountIdentifier,
      'missing@example.com',
    );
    expect(repository.requestPasswordResetCalls, 0);
    expect(
      find.text('Bu e-posta adresiyle kayıtlı bir hesap bulunamadı.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('forgot-password-confirmation-account')),
      findsNothing,
    );
    expect(find.byKey(const Key('forgot-password-code-field')), findsNothing);
  });

  testWidgets('accepts an at-sign username supported by the backend', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await _advanceToPassword(tester, '  Foo@Bar  ');
    await _enterPasswords(tester);

    await tester.ensureVisible(
      find.byKey(const Key('forgot-password-password-continue-button')),
    );
    await tester.tap(
      find.byKey(const Key('forgot-password-password-continue-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.lastPasswordResetIdentifier, 'foo@bar');
    expect(find.byKey(const Key('forgot-password-code-field')), findsOneWidget);
  });

  testWidgets('validates the code and shows the completed state', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await _advanceToCode(tester);

    await tester.enterText(
      _field(const Key('forgot-password-code-field')),
      '12',
    );
    await tester.ensureVisible(
      find.byKey(const Key('forgot-password-reset-button')),
    );
    await tester.tap(find.byKey(const Key('forgot-password-reset-button')));
    await tester.pump();

    expect(repository.resetPasswordCalls, 0);
    expect(find.text('Sıfırlama kodu 6 haneli olmalı.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.enterText(
      _field(const Key('forgot-password-code-field')),
      '123456',
    );
    await tester.tap(find.byKey(const Key('forgot-password-reset-button')));
    await tester.pumpAndSettle();

    expect(repository.resetPasswordCalls, 1);
    expect(repository.lastResetIdentifier, 'user@example.com');
    expect(repository.lastResetCode, '123456');
    expect(repository.lastResetPassword, 'password123');
    expect(repository.lastResetRePassword, 'password123');
    expect(
      find.byKey(const Key('forgot-password-success-title')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('forgot-password-code-field')), findsNothing);
  });

  testWidgets('keeps the code step open for an expired or invalid code', (
    tester,
  ) async {
    repository.resetPasswordResult = const Result.failure(
      AppError(
        code: 'auth_password_reset_code_invalid',
        message: 'Kod geçersiz veya süresi dolmuş.',
      ),
    );
    await tester.pumpWidget(app());
    await _advanceToCode(tester);

    await tester.enterText(
      _field(const Key('forgot-password-code-field')),
      '123456',
    );
    await tester.tap(find.byKey(const Key('forgot-password-reset-button')));
    await tester.pump();

    expect(find.text('Kod geçersiz veya süresi dolmuş.'), findsOneWidget);
    expect(find.byKey(const Key('forgot-password-code-field')), findsOneWidget);
  });
}

Finder _field(Key key) {
  return find.descendant(of: find.byKey(key), matching: find.byType(TextField));
}

Future<void> _advanceToPassword(WidgetTester tester, String identifier) async {
  await tester.enterText(
    _field(const Key('forgot-password-identifier-field')),
    identifier,
  );
  await tester.tap(find.byKey(const Key('forgot-password-request-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('forgot-password-confirm-button')));
  await tester.pumpAndSettle();
}

Future<void> _enterPasswords(WidgetTester tester) async {
  await tester.enterText(
    _field(const Key('forgot-password-new-password-field')),
    'password123',
  );
  await tester.enterText(
    _field(const Key('forgot-password-repeat-password-field')),
    'password123',
  );
}

Future<void> _advanceToCode(WidgetTester tester) async {
  await _advanceToPassword(tester, ' User@Example.COM ');
  await _enterPasswords(tester);
  await tester.ensureVisible(
    find.byKey(const Key('forgot-password-password-continue-button')),
  );
  await tester.tap(
    find.byKey(const Key('forgot-password-password-continue-button')),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('forgot-password-code-field')), findsOneWidget);
}
