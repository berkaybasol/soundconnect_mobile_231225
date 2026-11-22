import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/error/studio_rejection_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/google_auth_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/business_registration_details.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/user_status.dart';
import 'package:soundconnect_23_12_25codx/modules/location/presentation/cubit/location_cubit.dart';
import 'support/auth_widget_test_support.dart' show FakeLocationRepository;
import 'venue_application_session_test.dart'
    show applicantToken, applicantId, applicationId;
import 'package:soundconnect_23_12_25codx/modules/auth/domain/auth_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/login_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/register_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/resend_code_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/verify_code_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/login_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/register_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/request_password_reset_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/reset_password_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/resend_code_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/update_username_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/verify_code_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/login_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/otp_verify_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/register_screen.dart';

void main() {
  const studioName = 'Kovan Stüdyo';
  const reason =
      'Bina numarası eksik olduğu için stüdyonun adresini doğrulayamadık.';
  const rejectedStudio = StudioRejectionError(
    code: '1112',
    businessName: studioName,
    rejectionReason: reason,
  );
  late _RecordingAuthRepository repository;
  late AuthCubit cubit;
  late _MemoryTokenStore tokenStore;
  late AuthSessionManager sessionManager;

  setUp(() async {
    await serviceLocator.reset();
    repository = _RecordingAuthRepository();
    tokenStore = _MemoryTokenStore();
    sessionManager = AuthSessionManager(
      tokenStore: tokenStore,
      sessionStore: _MemoryAuthSessionStore(),
    );
    serviceLocator.registerSingleton<AuthSessionManager>(
      sessionManager,
      dispose: (manager) => manager.dispose(),
    );
    cubit = AuthCubit(
      loginUseCase: LoginUseCase(repository),
      registerUseCase: RegisterUseCase(repository),
      verifyCodeUseCase: VerifyCodeUseCase(repository),
      resendCodeUseCase: ResendCodeUseCase(repository),
      requestPasswordResetUseCase: RequestPasswordResetUseCase(repository),
      resetPasswordUseCase: ResetPasswordUseCase(repository),
      updateUsernameUseCase: UpdateUsernameUseCase(repository),
      tokenStore: tokenStore,
      sessionManager: sessionManager,
    );
  });

  tearDown(() async {
    await cubit.close();
    await serviceLocator.reset();
  });

  Widget app({
    Map<String, WidgetBuilder>? routes,
    NavigatorObserver? observer,
    bool includeCoveredLoginRoute = false,
    bool includeSourceRoute = false,
  }) {
    if (includeCoveredLoginRoute || includeSourceRoute) {
      return MaterialApp(
        navigatorObservers: <NavigatorObserver>[if (observer != null) observer],
        onGenerateInitialRoutes: (_) => <Route<dynamic>>[
          if (includeSourceRoute)
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/source'),
              builder: (_) => const Scaffold(body: Text('source-route')),
            ),
          for (
            var index = 0;
            index < (includeCoveredLoginRoute ? 2 : 1);
            index += 1
          )
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: AppRoutes.login),
              builder: (_) => BlocProvider<AuthCubit>.value(
                value: cubit,
                child: const LoginScreen(),
              ),
            ),
        ],
        routes: routes ?? const <String, WidgetBuilder>{},
      );
    }
    return MaterialApp(
      navigatorObservers: <NavigatorObserver>[if (observer != null) observer],
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
      find.byKey(const Key('google-sign-in')),
    );
    expect(googleButton.onPressed, isNotNull);

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

  Future<void> startGoogle(
    WidgetTester tester,
    _GoogleRepository google,
  ) async {
    serviceLocator.registerSingleton<GoogleAuthRepository>(google);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: cubit),
          BlocProvider<LocationCubit>(
            create: (_) => LocationCubit(FakeLocationRepository()),
          ),
        ],
        child: MaterialApp(
          home: const LoginScreen(),
          onGenerateRoute: AppRouter.onGenerateRoute,
          routes: {
            AppRoutes.listenerProfileChoice: (_) =>
                const Scaffold(body: Text('listener-choice')),
            AppRoutes.musicianProfile: (_) =>
                const Scaffold(body: Text('musician-profile')),
            AppRoutes.studioProfile: (_) =>
                const Scaffold(body: Text('studio-profile')),
            AppRoutes.venuePending: (_) =>
                const Scaffold(body: Text('venue-status')),
          },
        ),
      ),
    );
    final button = find.byKey(const Key('google-sign-in'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();
  }

  Future<void> chooseGoogleRole(WidgetTester tester, String roleLabel) async {
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text("SoundConnect'te ne yapmak istiyorsun?"), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    final role = find.text(roleLabel);
    await tester.ensureVisible(role);
    await tester.tap(role);
    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    expect(find.text('Kullanıcı adı oluştur'), findsOneWidget);
  }

  Future<void> enterGoogleUsername(WidgetTester tester, String username) async {
    final field = find.descendant(
      of: find.byKey(const Key('register-username-field')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, username);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Google account selection can be cancelled without starting a session',
    (tester) async {
      final google = _GoogleRepository()..idToken = null;
      await startGoogle(tester, google);
      expect(google.lookups, 0);
      expect(sessionManager.session.isAuthenticated, isFalse);
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Google username remains usable with the keyboard on a small phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.reset);
      await startGoogle(tester, _GoogleRepository());
      await chooseGoogleRole(tester, 'Sosyal Deneyim');

      final field = find.byKey(const Key('register-username-field'));
      await tester.tap(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      await tester.ensureVisible(field);
      expect(field.hitTestable(), findsOneWidget);
      expect(find.text('Hesabımı oluştur').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('Google email conflict keeps the password login available', (
    tester,
  ) async {
    final google = _GoogleRepository()..errorCode = '1116';
    await startGoogle(tester, google);
    expect(find.textContaining('Kullanıcı adın ve şifrenle'), findsOneWidget);
    expect(sessionManager.session.isAuthenticated, isFalse);
    expect(google.completions, isEmpty);
  });

  const studioWaiting = LoginResult(
    token: '',
    status: UserStatus.pendingStudioRequest,
    userId: 'user-id',
    applicationId: 'application-id',
  );
  testWidgets(
    'Google studio refresh with expired proof rejects a different account before lookup',
    (tester) async {
      String proof(String subject) =>
          'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': subject})))}.signature';
      final google = _GoogleRepository()
        ..existing = studioWaiting
        ..idToken = proof('applicant');
      await startGoogle(tester, google);
      google
        ..errorCode = '1101'
        ..idToken = proof('someone-else');
      final check = find.text('Başvuru durumunu kontrol et');
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(
        find.text('Başvurduğun Google hesabını seçerek tekrar dene.'),
        findsOneWidget,
      );
      expect(google.lookups, 2);
      expect(sessionManager.session.isAuthenticated, isFalse);
      await tester.ensureVisible(find.text('Giriş ekranına dön'));
      await tester.tap(find.text('Giriş ekranına dön'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );
  for (final studio in [false, true]) {
    testWidgets(
      'new Google business application sends its own fields and opens its status, studio=$studio',
      (tester) async {
        tester.view.physicalSize = const Size(500, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final google = _GoogleRepository()
          ..completed = studio
              ? studioWaiting
              : LoginResult(
                  token: applicantToken(),
                  status: UserStatus.pendingVenueRequest,
                  userId: applicantId,
                  applicationId: applicationId,
                  sessionScope: 'VENUE_APPLICATION',
                );
        await startGoogle(tester, google);
        await chooseGoogleRole(
          tester,
          studio ? 'Stüdyo temsilcisiyim' : 'Mekan temsilcisiyim',
        );
        await enterGoogleUsername(tester, 'MyPlace');
        await tester.tap(find.text('Devam et'));
        await tester.pumpAndSettle();
        expect(google.completions, isEmpty);
        for (final entry in {
          'business-name-field': '  My Place  ',
          'business-phone-field': '5551234567',
          'business-address-field': '  Moda  ',
        }.entries) {
          final field = find.descendant(
            of: find.byKey(Key(entry.key)),
            matching: find.byType(TextField),
          );
          await tester.ensureVisible(field);
          await tester.enterText(field, entry.value);
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final boxes = find.byType(DropdownButtonFormField<String>);
        var index = 0;
        for (final item in ['Istanbul', 'Kadikoy', 'Moda']) {
          await tester.ensureVisible(boxes.at(index));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<DropdownButtonFormField<String>>(boxes.at(index))
                .onChanged,
            isNotNull,
          );
          await tester.tap(boxes.at(index));
          await tester.pumpAndSettle();
          await tester.tap(find.text(item).last);
          await tester.pumpAndSettle();
          index++;
        }
        expect(find.byType(CheckboxListTile), findsNothing);
        final submit = find.text('Başvurumu gönder');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();
        await tester.runAsync(() async {});
        await tester.pumpAndSettle();
        expect(google.details?.toJson(), {
          if (studio) ...{
            'studioName': 'my place',
            'studioPhone': '05551234567',
            'studioAddress': 'Moda',
          } else ...{
            'venueName': 'my place',
            'phone': '5551234567',
            'venueAddress': 'Moda',
          },
          'cityId': 'city-1',
          'districtId': 'district-1',
          'neighborhoodId': 'neighborhood-1',
        });
        expect(google.completions, [
          ('myplace', studio ? 'ROLE_STUDIO' : 'ROLE_VENUE', true),
        ]);
        expect(
          find.text(studio ? 'Başvuru durumunu kontrol et' : 'venue-status'),
          findsOneWidget,
        );
        expect(sessionManager.session.isVenueApplicationSession, !studio);
        if (studio) {
          await tester.ensureVisible(find.text('Giriş ekranına dön'));
          await tester.tap(find.text('Giriş ekranına dön'));
          await tester.pumpAndSettle();
        }
        if (sessionManager.session.isAuthenticated) {
          await sessionManager.logout();
        }
      },
    );
  }
  for (final approved in [true, false]) {
    testWidgets(
      'returning Google studio applicant rechecks decision in place, approved=$approved',
      (tester) async {
        final google = _GoogleRepository()..existing = studioWaiting;
        await startGoogle(tester, google);
        expect(sessionManager.session.isAuthenticated, isFalse);
        final check = find.text('Başvuru durumunu kontrol et');
        expect(check, findsOneWidget);
        await tester.ensureVisible(check);
        await tester.tap(check);
        await tester.pumpAndSettle();
        expect(find.text('Başvurunun incelemesi sürüyor.'), findsOneWidget);
        if (approved) {
          google.existing = LoginResult(
            token: _token(role: 'ROLE_STUDIO'),
            userId: 'user-id',
            roles: const ['ROLE_STUDIO'],
          );
        } else {
          google.rejection = rejectedStudio;
        }
        await tester.ensureVisible(check);
        await tester.tap(check);
        await tester.pump();
        await tester.runAsync(() async {});
        await tester.pumpAndSettle();
        expect(
          find.text(
            approved ? 'studio-profile' : 'Stüdyo başvurun reddedildi.',
          ),
          findsOneWidget,
        );
        if (!approved) {
          expect(find.text(studioName), findsOneWidget);
          expect(find.text(reason), findsOneWidget);
        }
        expect(sessionManager.session.isAuthenticated, approved);
        expect(google.completions, isEmpty);
        if (approved) await sessionManager.logout();
      },
    );
  }

  for (final google in [false, true]) {
    testWidgets('rejected studio reads its reason at sign-in, Google=$google', (
      tester,
    ) async {
      if (google) {
        await startGoogle(
          tester,
          _GoogleRepository()..rejection = rejectedStudio,
        );
      } else {
        repository.loginResult = Result.failure(
          StudioRejectionError.forLogin(rejectedStudio),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<AuthCubit>.value(
              value: cubit,
              child: const LoginScreen(),
            ),
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        );
        await tester.enterText(find.byType(TextField).first, 'studio');
        await tester.enterText(find.byType(TextField).last, 'password123');
        _invokeLoginSubmit(tester);
        await tester.pumpAndSettle();
      }
      expect(find.text(studioName), findsOneWidget);
      expect(find.text(reason), findsOneWidget);
      expect(find.text('Ret gerekçesi'), findsOneWidget);
      expect(sessionManager.session.isAuthenticated, isFalse);
    });
  }
  for (final failure in ['1118', 'google_configuration']) {
    testWidgets(
      'Google error $failure offers the normal email registration form',
      (tester) async {
        final google = _GoogleRepository()..errorCode = failure;
        await startGoogle(tester, google);
        await tester.tap(find.text('E-postayla kayıt'));
        await tester.pumpAndSettle();
        expect(find.byType(RegisterScreen), findsOneWidget);
        expect(find.text('Kullanıcı adı oluştur'), findsOneWidget);
        expect(sessionManager.session.isAuthenticated, isFalse);
      },
    );
  }

  testWidgets(
    'existing Google musician uses the normal authenticated destination',
    (tester) async {
      final google = _GoogleRepository()
        ..existing = LoginResult(token: _token(role: 'ROLE_MUSICIAN'));
      await startGoogle(tester, google);
      expect(find.text('musician-profile'), findsOneWidget);
      expect(google.completions, isEmpty);
      await sessionManager.logout();
    },
  );

  testWidgets(
    'Google listener signs up once from the shared steps without another checkbox',
    (tester) async {
      final google = _GoogleRepository();
      await startGoogle(tester, google);
      expect(sessionManager.session.isAuthenticated, isFalse);
      await chooseGoogleRole(tester, 'Sosyal Deneyim');
      await enterGoogleUsername(tester, '  MyName ');
      expect(google.completions, isEmpty);
      expect(sessionManager.session.isAuthenticated, isFalse);
      expect(find.byType(CheckboxListTile), findsNothing);
      final submit = find.text('Hesabımı oluştur');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      await tester.runAsync(() async {});
      await tester.pumpAndSettle();
      expect(google.completions, [('myname', 'ROLE_LISTENER', true)]);
      expect(find.text('listener-choice'), findsOneWidget);
      expect(sessionManager.session.isAuthenticated, isTrue);
      await sessionManager.logout();
    },
  );

  testWidgets(
    'Google musician can correct a taken name without restarting registration',
    (tester) async {
      final google = _GoogleRepository()..completionErrorCode = '1002';
      await startGoogle(tester, google);
      await chooseGoogleRole(tester, 'Muzisyenim');
      await enterGoogleUsername(tester, 'TakenName');
      await tester.tap(find.text('Hesabımı oluştur'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bu kullanıcı adı alınmış. Farklı bir ad seç.'),
        findsOneWidget,
      );
      expect(find.text('Kullanıcı adı oluştur'), findsOneWidget);
      expect(sessionManager.session.isAuthenticated, isFalse);

      google.completionErrorCode = null;
      await enterGoogleUsername(tester, 'NewName');
      await tester.tap(find.text('Hesabımı oluştur'));
      await tester.pump();
      await tester.runAsync(() async {});
      await tester.pumpAndSettle();
      expect(google.lookups, 1);
      expect(google.completions, [
        ('takenname', 'ROLE_MUSICIAN', true),
        ('newname', 'ROLE_MUSICIAN', true),
      ]);
      expect(find.text('musician-profile'), findsOneWidget);
      await sessionManager.logout();
    },
  );

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
    await tester.enterText(find.byType(TextField).at(0), '  AlIcE  ');
    await tester.enterText(find.byType(TextField).at(1), ' abc ');
    _invokeLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
    expect(repository.lastUsername, 'alice');
    expect(repository.lastPassword, ' abc ');
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      'alice',
    );
  });

  testWidgets('rapid login taps make one request while authentication waits', (
    tester,
  ) async {
    final pending = Completer<Result<LoginResult>>();
    repository.loginCompleter = pending;
    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), 'password');

    _invokeLoginSubmit(tester);
    _invokeLoginSubmit(tester);

    expect(repository.loginCalls, 1);

    pending.complete(
      const Result.failure(
        AppError(code: 'test_rejection', message: 'Rejected once'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rejected once'), findsOneWidget);
  });

  testWidgets(
    'in-flight login blocks back and anonymous links until one success handoff',
    (tester) async {
      final pending = Completer<Result<LoginResult>>();
      repository
        ..loginCompleter = pending
        ..loginResult = Result<LoginResult>.success(
          LoginResult(
            token: _token(role: 'ROLE_MUSICIAN'),
            username: 'alice',
          ),
        );
      await tester.pumpWidget(
        app(
          includeSourceRoute: true,
          routes: <String, WidgetBuilder>{
            AppRoutes.musicianProfile: (_) =>
                const Scaffold(body: Text('musician-profile-destination')),
            AppRoutes.register: (_) =>
                const Scaffold(body: Text('register-destination')),
            AppRoutes.forgotPassword: (_) =>
                const Scaffold(body: Text('forgot-destination')),
          },
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), 'alice');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      _invokeLoginSubmit(tester);
      await tester.pump();

      final forgotButton = tester.widget<TextButton>(
        find.byKey(const Key('forgot-password-button')),
      );
      final registerButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Üye ol'),
      );
      expect(forgotButton.onPressed, isNull);
      expect(registerButton.onPressed, isNull);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('source-route'), findsNothing);

      pending.complete(repository.loginResult);
      await tester.pump();
      await tester.runAsync(() async {});
      await tester.pumpAndSettle();

      expect(find.text('musician-profile-destination'), findsOneWidget);
      expect(sessionManager.session.isAuthenticated, isTrue);
      expect(tester.takeException(), isNull);

      await sessionManager.logout();
    },
  );

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

  testWidgets('opens the anonymous forgot-password route', (tester) async {
    await tester.pumpWidget(
      app(
        routes: <String, WidgetBuilder>{
          AppRoutes.forgotPassword: (_) =>
              const Scaffold(body: Text('Forgot password destination')),
        },
      ),
    );

    await tester.tap(find.byKey(const Key('forgot-password-button')));
    await tester.pumpAndSettle();

    expect(find.text('Forgot password destination'), findsOneWidget);
  });

  testWidgets(
    'unverified login resumes OTP with the server email and allows login after back',
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
      });
      repository.loginResult = const Result<LoginResult>.failure(
        AppError(
          code: 'auth_email_verification_required',
          message: 'E-posta doğrulaması gerekli.',
          details: <String>['berna.account@example.com'],
        ),
      );
      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(
        app(
          observer: observer,
          routes: <String, WidgetBuilder>{
            AppRoutes.otpVerify: (_) => BlocProvider<AuthCubit>.value(
              value: cubit,
              child: const OtpVerifyScreen(),
            ),
            AppRoutes.musicianProfile: (_) =>
                const Scaffold(body: Text('musician-profile-destination')),
          },
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), 'berna');
      await tester.enterText(find.byType(TextField).at(1), 'new-password');

      _invokeLoginSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.byType(OtpVerifyScreen), findsOneWidget);
      expect(find.text('berna.account@example.com'), findsOneWidget);
      final otpRoute = observer.pushedRouteSettings.singleWhere(
        (settings) => settings.name == AppRoutes.otpVerify,
      );
      final args = otpRoute.arguments! as OtpVerifyArgs;
      expect(args.email, 'berna.account@example.com');
      expect(args.resumedRegistration, isTrue);
      expect(args.role, isNull);
      expect(repository.loginCalls, 1);
      expect(repository.resendCalls, 0);
      expect(tokenStore.token, isNull);
      expect(cubit.state.loginResult, isNull);
      expect(sessionManager.session.isAuthenticated, isFalse);
      expect(find.text('musician-profile-destination'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      repository.loginResult = Result<LoginResult>.success(
        LoginResult(
          token: _token(role: 'ROLE_MUSICIAN'),
          username: 'berna',
        ),
      );

      _invokeLoginSubmit(tester);
      await tester.pump();
      await tester.runAsync(() async {});
      await tester.pumpAndSettle();

      expect(repository.loginCalls, 2);
      expect(repository.lastUsername, 'berna');
      expect(repository.lastPassword, 'new-password');
      expect(find.text('musician-profile-destination'), findsOneWidget);
      expect(sessionManager.session.isAuthenticated, isTrue);
      expect(tester.takeException(), isNull);
      await sessionManager.logout();
    },
  );

  for (final membership in [
    (
      role: 'ROLE_VENUE',
      route: AppRoutes.venueProfile,
      notice: 'Mekân profilin hazır!',
    ),
    (
      role: 'ROLE_STUDIO',
      route: AppRoutes.studioProfile,
      notice: 'Stüdyo profilin hazır!',
    ),
  ]) {
    testWidgets(
      'approved ${membership.role} login opens own profile with a short notice',
      (tester) async {
        repository.loginResult = Result.success(
          LoginResult(
            token: _token(role: membership.role),
            username: 'approved-owner',
          ),
        );
        final observer = _RecordingNavigatorObserver();
        await tester.pumpWidget(
          app(
            observer: observer,
            routes: {
              membership.route: (_) =>
                  const Scaffold(body: Text('own-profile')),
              AppRoutes.home: (_) =>
                  const Scaffold(body: Text('unexpected-home')),
            },
          ),
        );
        await tester.enterText(find.byType(TextField).at(0), 'approved-owner');
        await tester.enterText(find.byType(TextField).at(1), 'password');
        _invokeLoginSubmit(tester);
        await tester.pump();
        await tester.runAsync(() async {});
        await tester.pumpAndSettle();
        expect(find.text('own-profile'), findsOneWidget);
        expect(find.text(membership.notice), findsOneWidget);
        expect(
          observer.pushedRouteNames.where((name) => name == membership.route),
          hasLength(1),
        );
        expect(find.text('unexpected-home'), findsNothing);
        expect(
          Navigator.of(tester.element(find.text('own-profile'))).canPop(),
          isFalse,
        );
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.text(membership.notice), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await sessionManager.logout();
      },
    );
  }

  testWidgets('wrong credentials stay on login without creating a session', (
    tester,
  ) async {
    repository.loginResult = const Result<LoginResult>.failure(
      AppError(
        code: 'auth_invalid_credentials',
        message: 'Kullanıcı adı veya şifre hatalı.',
      ),
    );
    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(app(observer: observer));
    await tester.enterText(find.byType(TextField).at(0), 'berna');
    await tester.enterText(find.byType(TextField).at(1), 'wrong-password');

    _invokeLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Kullanıcı adı veya şifre hatalı.'), findsOneWidget);
    expect(observer.pushedRouteNames, isNot(contains(AppRoutes.otpVerify)));
    expect(tokenStore.token, isNull);
    expect(sessionManager.session.isAuthenticated, isFalse);
  });

  for (final pendingCase
      in <({String errorCode, String route, String destination})>[
        (
          errorCode: 'auth_pending_venue_approval',
          route: AppRoutes.venuePending,
          destination: 'Venue pending destination',
        ),
        (
          errorCode: 'auth_pending_studio_approval',
          route: AppRoutes.studioPending,
          destination: 'Studio pending destination',
        ),
        (
          errorCode: 'auth_studio_application_rejected',
          route: AppRoutes.studioRejected,
          destination: 'Studio rejected destination',
        ),
      ]) {
    testWidgets(
      'redirects ${pendingCase.errorCode} login failures to the decision screen',
      (tester) async {
        repository.loginResult = Result<LoginResult>.failure(
          AppError(code: pendingCase.errorCode, message: 'Pending'),
        );
        await tester.pumpWidget(
          app(
            routes: <String, WidgetBuilder>{
              pendingCase.route: (_) =>
                  Scaffold(body: Text(pendingCase.destination)),
            },
          ),
        );
        await tester.enterText(find.byType(TextField).at(0), 'pending-user');
        await tester.enterText(find.byType(TextField).at(1), 'password123');

        _invokeLoginSubmit(tester);
        await tester.pumpAndSettle();

        expect(find.text(pendingCase.destination), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  }

  testWidgets(
    'only the current stacked login route handles a shared pending redirect',
    (tester) async {
      const destination = 'Venue pending destination';
      repository.loginResult = const Result<LoginResult>.failure(
        AppError(code: 'auth_pending_venue_approval', message: 'Pending'),
      );
      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(
        app(
          observer: observer,
          includeCoveredLoginRoute: true,
          routes: <String, WidgetBuilder>{
            AppRoutes.venuePending: (_) =>
                const Scaffold(body: Text(destination)),
          },
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), 'pending-user');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      _invokeLoginSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text(destination), findsOneWidget);
      expect(
        observer.pushedRouteNames.where(
          (name) => name == AppRoutes.venuePending,
        ),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
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

class _GoogleRepository implements GoogleAuthRepository {
  StudioRejectionError? rejection;
  String? idToken = 'mock-google-identity';
  String? errorCode;
  String? completionErrorCode;
  LoginResult? existing;
  LoginResult? completed;
  BusinessRegistrationDetails? details;
  int lookups = 0;
  final completions = <(String, String, bool)>[];
  @override
  Future<String?> chooseAccount() async => idToken;
  @override
  Future<LoginResult?> signIn(String idToken, int revision) async {
    lookups++;
    if (rejection != null) throw ApiException(rejection!);
    if (errorCode != null) {
      throw ApiException(AppError(code: errorCode!, message: ''));
    }
    return existing;
  }

  @override
  Future<LoginResult> complete({
    required String idToken,
    required String username,
    required String role,
    required bool consent,
    required int revision,
    BusinessRegistrationDetails? business,
  }) async {
    completions.add((username, role, consent));
    if (completionErrorCode != null) {
      throw ApiException(AppError(code: completionErrorCode!, message: ''));
    }
    details = business;
    return completed ??
        LoginResult(
          token: _token(role: role),
          username: username,
          requiresListenerProfileChoice: role == 'ROLE_LISTENER',
        );
  }
}

class _RecordingAuthRepository extends AuthRepository {
  int loginCalls = 0;
  int resendCalls = 0;
  String? lastUsername;
  String? lastPassword;
  Result<LoginResult> loginResult = const Result<LoginResult>.failure(
    AppError(code: 'test_rejection', message: 'Rejected by test repository'),
  );
  Completer<Result<LoginResult>>? loginCompleter;

  @override
  Future<Result<LoginResult>> login({
    required String username,
    required String password,
  }) async {
    loginCalls++;
    lastUsername = username;
    lastPassword = password;
    return loginCompleter?.future ?? loginResult;
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
    String? studioName,
    String? studioAddress,
    String? studioPhone,
  }) async {
    return const Result<RegisterResult>.failure(
      AppError(code: 'not_used', message: 'Not used'),
    );
  }

  @override
  Future<Result<ResendCodeResult>> resendCode({required String email}) async {
    resendCalls++;
    return const Result<ResendCodeResult>.failure(
      AppError(code: 'not_used', message: 'Not used'),
    );
  }

  @override
  Future<Result<VerifyCodeResult>> verifyCode({
    required String email,
    required String code,
  }) async {
    return const Result<VerifyCodeResult>.failure(
      AppError(code: 'not_used', message: 'Not used'),
    );
  }

  @override
  Future<Result<void>> requestPasswordReset({
    required String identifier,
  }) async {
    return const Result<void>.failure(
      AppError(code: 'not_used', message: 'Not used'),
    );
  }

  @override
  Future<Result<void>> resetPassword({
    required String identifier,
    required String code,
    required String password,
    required String rePassword,
  }) async {
    return const Result<void>.failure(
      AppError(code: 'not_used', message: 'Not used'),
    );
  }

  @override
  Future<Result<String>> updateUsername({required String username}) async {
    return const Result<String>.failure(
      AppError(code: 'not_used', message: 'Not used'),
    );
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String?> pushedRouteNames = <String?>[];
  final List<RouteSettings> pushedRouteSettings = <RouteSettings>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRouteNames.add(route.settings.name);
    pushedRouteSettings.add(route.settings);
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

class _MemoryAuthSessionStore implements AuthSessionStore {
  AuthSessionMetadata? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthSessionMetadata?> read() async => value;

  @override
  Future<void> write(AuthSessionMetadata metadata) async => value = metadata;
}

String _token({required String role}) {
  String encode(Map<String, Object> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiresAt = DateTime.utc(2035).millisecondsSinceEpoch ~/ 1000;
  return '${encode(const <String, Object>{'alg': 'HS256'})}.'
      '${encode(<String, Object>{
        'sub': 'user-id',
        'roles': <String>[role],
        'exp': expiresAt,
      })}.signature';
}
