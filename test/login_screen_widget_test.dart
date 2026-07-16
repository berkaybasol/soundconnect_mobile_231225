import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/auth_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/login_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/register_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/resend_code_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/login_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/register_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/resend_code_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/verify_code_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/login_screen.dart';

void main() {
  late _RecordingAuthRepository repository;
  late AuthCubit cubit;

  setUp(() {
    repository = _RecordingAuthRepository();
    cubit = AuthCubit(
      loginUseCase: LoginUseCase(repository),
      registerUseCase: RegisterUseCase(repository),
      verifyCodeUseCase: VerifyCodeUseCase(repository),
      resendCodeUseCase: ResendCodeUseCase(repository),
      tokenStore: _MemoryTokenStore(),
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  Widget app({Map<String, WidgetBuilder>? routes}) {
    return MaterialApp(
      routes: routes ?? const <String, WidgetBuilder>{},
      home: BlocProvider<AuthCubit>.value(value: cubit, child: LoginScreen()),
    );
  }

  testWidgets('renders secure login controls and toggles password visibility', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);
    final googleButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('google-sign-in-unavailable')),
    );
    expect(googleButton.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('rejects an empty username before authentication', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    _invokeLoginSubmit(tester);
    await tester.pump();

    expect(find.text('kullanıcı adı boş olamaz'), findsOneWidget);
    expect(repository.loginCalls, 0);
  });

  testWidgets('rejects an empty password before authentication', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextField).at(0), 'alice');
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      'alice',
    );

    _invokeLoginSubmit(tester);
    await tester.pump();

    expect(find.text('şifre boş olamaz'), findsOneWidget);
    expect(repository.loginCalls, 0);
  });

  testWidgets('accepts a short legacy password without normalizing it', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextField).at(0), '  alice  ');
    await tester.enterText(find.byType(TextField).at(1), ' abc ');
    _invokeLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
    expect(repository.lastUsername, 'alice');
    expect(repository.lastPassword, ' abc ');
  });

  testWidgets('rejects a password above the bcrypt boundary', (tester) async {
    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(
      find.byType(TextField).at(1),
      List<String>.filled(73, 'p').join(),
    );
    _invokeLoginSubmit(tester);
    await tester.pump();

    expect(
      find.text('Şifre UTF-8 olarak en fazla 72 bayt olmalı'),
      findsOneWidget,
    );
    expect(repository.loginCalls, 0);
  });

  testWidgets('trims username and accepts the ASCII bcrypt byte boundary', (
    tester,
  ) async {
    final maxPassword = List<String>.filled(72, 'p').join();
    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextField).at(0), '  alice  ');
    await tester.enterText(find.byType(TextField).at(1), maxPassword);

    final submit = find.text('Giriş yap');
    await tester.ensureVisible(submit);
    _invokeLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
    expect(repository.lastUsername, 'alice');
    expect(repository.lastPassword, maxPassword);
    expect(find.text('Rejected by test repository'), findsOneWidget);
  });

  testWidgets('accepts a multibyte password at exactly 72 UTF-8 bytes', (
    tester,
  ) async {
    final maxPassword = List<String>.filled(36, 'ş').join();
    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), maxPassword);

    _invokeLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
    expect(repository.lastPassword, maxPassword);
  });

  testWidgets('rejects a multibyte password above 72 UTF-8 bytes', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(
      find.byType(TextField).at(1),
      List<String>.filled(37, 'ş').join(),
    );

    _invokeLoginSubmit(tester);
    await tester.pump();

    expect(
      find.text('Şifre UTF-8 olarak en fazla 72 bayt olmalı'),
      findsOneWidget,
    );
    expect(repository.loginCalls, 0);
  });

  testWidgets('opens the registration route from the membership action', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        routes: <String, WidgetBuilder>{
          AppRoutes.register: (_) =>
              const Scaffold(body: Text('Registration destination')),
        },
      ),
    );

    final register = find.text('Üye ol');
    await tester.ensureVisible(register);
    await tester.tap(register);
    await tester.pumpAndSettle();

    expect(find.text('Registration destination'), findsOneWidget);
  });
}

void _invokeLoginSubmit(WidgetTester tester) {
  final submit = find.ancestor(
    of: find.text('Giriş yap'),
    matching: find.byType(InkWell),
  );
  expect(submit, findsOneWidget);
  final onTap = tester.widget<InkWell>(submit).onTap;
  expect(onTap, isNotNull);
  onTap!();
}

class _RecordingAuthRepository implements AuthRepository {
  int loginCalls = 0;
  String? lastUsername;
  String? lastPassword;

  @override
  Future<Result<LoginResult>> login({
    required String username,
    required String password,
  }) async {
    loginCalls++;
    lastUsername = username;
    lastPassword = password;
    return const Result<LoginResult>.failure(
      AppError(code: 'test_rejection', message: 'Rejected by test repository'),
    );
  }

  @override
  Future<Result<RegisterResult>> register({
    required String username,
    required String email,
    required String password,
    required String rePassword,
    required String role,
    String? venueName,
    String? venueAddress,
    String? phone,
    String? cityId,
    String? districtId,
    String? neighborhoodId,
  }) async {
    return const Result<RegisterResult>.failure(
      AppError(code: 'not_used', message: 'Not used'),
    );
  }

  @override
  Future<Result<ResendCodeResult>> resendCode({required String email}) async {
    return const Result<ResendCodeResult>.failure(
      AppError(code: 'not_used', message: 'Not used'),
    );
  }

  @override
  Future<Result<void>> verifyCode({
    required String email,
    required String code,
  }) async {
    return const Result<void>.failure(
      AppError(code: 'not_used', message: 'Not used'),
    );
  }
}

class _MemoryTokenStore implements TokenStore {
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token) async => this.token = token;
}
