import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/resend_code_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/login_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/otp_verify_screen.dart';
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

  Widget app({
    OtpVerifyArgs? args,
    NavigatorObserver? observer,
    bool includeRegistrationRoute = false,
    bool includeCoveredOtpRoute = false,
  }) {
    return MaterialApp(
      initialRoute: AppRoutes.otpVerify,
      navigatorObservers: <NavigatorObserver>[if (observer != null) observer],
      onGenerateInitialRoutes: (_) => <Route<dynamic>>[
        if (includeRegistrationRoute)
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: AppRoutes.register),
            builder: (_) => const Scaffold(body: Text('register-source')),
          ),
        if (includeCoveredOtpRoute)
          MaterialPageRoute<void>(
            settings: RouteSettings(name: AppRoutes.otpVerify, arguments: args),
            builder: (_) => BlocProvider<AuthCubit>.value(
              value: cubit,
              child: const OtpVerifyScreen(),
            ),
          ),
        MaterialPageRoute<void>(
          settings: RouteSettings(name: AppRoutes.otpVerify, arguments: args),
          builder: (_) => BlocProvider<AuthCubit>.value(
            value: cubit,
            child: const OtpVerifyScreen(),
          ),
        ),
      ],
      routes: <String, WidgetBuilder>{
        AppRoutes.login: (_) => const _LoginTarget(),
        AppRoutes.venuePending: (_) =>
            const Scaffold(body: Text('venue-pending-target')),
        AppRoutes.studioPending: (_) =>
            const Scaffold(body: Text('studio-pending-target')),
      },
    );
  }

  testWidgets('renders countdown and disables actions when email is absent', (
    tester,
  ) async {
    _disposeOtpAfterTest(tester);
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.textContaining('3:00'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    final verifyButton = tester.widget<GradientOutlineButton>(
      find.byType(GradientOutlineButton),
    );
    final resendButton = tester.widget<TextButton>(find.byType(TextButton));
    expect(verifyButton.onPressed, isNull);
    expect(resendButton.onPressed, isNull);
  });

  testWidgets('rejects invalid email before submit', (tester) async {
    _disposeOtpAfterTest(tester);
    await tester.pumpWidget(
      app(args: const OtpVerifyArgs(email: 'invalid-email')),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.byType(GradientOutlineButton));
    await tester.pump();
    expect(repository.verifyCalls, 0);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('rejects a non-six-digit code before submit', (tester) async {
    _disposeOtpAfterTest(tester);
    await tester.pumpWidget(
      app(args: const OtpVerifyArgs(email: 'valid@example.com')),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '12345');
    await tester.tap(find.byType(GradientOutlineButton));
    await tester.pump();
    expect(repository.verifyCalls, 0);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('maps verify fields and disables the button while in flight', (
    tester,
  ) async {
    _disposeOtpAfterTest(tester);
    const failure = AppError(code: 'otp_invalid', message: 'Code rejected');
    final completer = Completer<Result<void>>();
    repository.verifyCompleter = completer;
    await tester.pumpWidget(
      app(args: const OtpVerifyArgs(email: 'valid@example.com')),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '123456');

    await tester.tap(find.byType(GradientOutlineButton));
    await tester.pump();

    expect(repository.verifyCalls, 1);
    expect(repository.lastVerifyEmail, 'valid@example.com');
    expect(repository.lastVerifyCode, '123456');
    final loadingButton = tester.widget<GradientOutlineButton>(
      find.byType(GradientOutlineButton),
    );
    expect(loadingButton.onPressed, isNull);
    expect(loadingButton.loading, isTrue);

    completer.complete(const Result.failure(failure));
    await tester.pump();
    await tester.pump();
    expect(find.text('Code rejected'), findsOneWidget);
  });

  testWidgets(
    'rapid verify taps make one request and lock resend until completion',
    (tester) async {
      _disposeOtpAfterTest(tester);
      final completer = Completer<Result<void>>();
      repository.verifyCompleter = completer;
      await tester.pumpWidget(
        app(args: const OtpVerifyArgs(email: 'valid@example.com')),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '123456');

      await tester.tap(find.byType(GradientOutlineButton));
      await tester.tap(find.byType(GradientOutlineButton));
      await tester.pump();

      expect(repository.verifyCalls, 1);
      expect(repository.resendCalls, 0);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );

      completer.complete(
        const Result.failure(
          AppError(code: 'otp_invalid', message: 'Code rejected'),
        ),
      );
      await tester.pump();
      await tester.pump();
    },
  );

  testWidgets('in-flight verification blocks back until the success handoff', (
    tester,
  ) async {
    _disposeOtpAfterTest(tester);
    final completer = Completer<Result<void>>();
    repository.verifyCompleter = completer;
    await tester.pumpWidget(
      app(
        args: const OtpVerifyArgs(
          email: 'musician@example.com',
          role: 'ROLE_MUSICIAN',
        ),
        includeRegistrationRoute: true,
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.byType(GradientOutlineButton));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(OtpVerifyScreen), findsOneWidget);
    expect(find.text('register-source'), findsNothing);

    completer.complete(const Result.success(null));
    await tester.pumpAndSettle();

    expect(find.text('login-target'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resend maps email and restarts countdown from server TTL', (
    tester,
  ) async {
    _disposeOtpAfterTest(tester);
    repository.resendResult = const Result.success(
      ResendCodeResult(otpTtlSeconds: 7, mailQueued: true, cooldownSeconds: 9),
    );
    await tester.pumpWidget(
      app(args: const OtpVerifyArgs(email: 'valid@example.com')),
    );
    await tester.pump();

    await tester.tap(find.byType(TextButton));
    await tester.pump();
    await tester.pump();

    expect(repository.resendCalls, 1);
    expect(repository.lastResendEmail, 'valid@example.com');
    expect(find.textContaining('0:07'), findsOneWidget);
    expect(find.textContaining('(9s)'), findsOneWidget);
  });

  for (final scenario in <({String role, String target})>[
    (role: 'ROLE_VENUE', target: 'venue-pending-target'),
    (role: 'ROLE_STUDIO', target: 'login-target'),
    (role: 'ROLE_LISTENER', target: 'login-target'),
  ]) {
    testWidgets(
      'verify success routes ${scenario.role} to ${scenario.target}',
      (tester) async {
        _disposeOtpAfterTest(tester);
        await tester.pumpWidget(
          app(
            args: OtpVerifyArgs(
              email: 'valid@example.com',
              role: scenario.role,
            ),
          ),
        );
        await tester.pump();
        await tester.enterText(find.byType(TextField), '123456');

        await tester.tap(find.byType(GradientOutlineButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();

        expect(find.text(scenario.target), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Studio verify success explains login and never assumes pending status',
    (tester) async {
      _disposeOtpAfterTest(tester);
      await tester.pumpWidget(
        app(
          args: const OtpVerifyArgs(
            email: 'studio@example.com',
            role: 'ROLE_STUDIO',
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '123456');

      await tester.tap(find.byType(GradientOutlineButton));
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpAndSettle();

      expect(find.text('login-target'), findsOneWidget);
      expect(
        find.text(
          'E-posta doğrulandı. Başvuru durumunu görmek için '
          'kullanıcı adın ve şifrenle giriş yap.',
        ),
        findsOneWidget,
      );
      expect(find.text('studio-pending-target'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'only the current stacked OTP route handles shared verification success',
    (tester) async {
      _disposeOtpAfterTest(tester);
      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(
        app(
          args: const OtpVerifyArgs(
            email: 'musician@example.com',
            role: 'ROLE_MUSICIAN',
          ),
          observer: observer,
          includeRegistrationRoute: true,
          includeCoveredOtpRoute: true,
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump(const Duration(milliseconds: 999));

      await tester.tap(find.byType(GradientOutlineButton));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('login-target'), findsOneWidget);
      expect(
        observer.pushedRouteNames.where((name) => name == AppRoutes.login),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _LoginTarget extends StatelessWidget {
  const _LoginTarget();

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final notice = args is LoginRouteArgs ? args.initialNotice : null;
    return Scaffold(
      body: Column(
        children: [
          const Text('login-target'),
          if (notice != null) Text(notice),
        ],
      ),
    );
  }
}

void _disposeOtpAfterTest(WidgetTester tester) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String?> pushedRouteNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRouteNames.add(route.settings.name);
  }
}
