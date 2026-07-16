import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/register_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/user_status.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/otp_verify_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/register_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/location/presentation/cubit/location_cubit.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/auth_widget_test_support.dart';

void main() {
  late RecordingAuthRepository authRepository;
  late FakeLocationRepository locationRepository;
  late AuthCubit authCubit;
  late LocationCubit locationCubit;

  setUp(() {
    authRepository = RecordingAuthRepository();
    locationRepository = FakeLocationRepository();
    authCubit = createAuthCubit(authRepository);
    locationCubit = LocationCubit(locationRepository);
  });

  tearDown(() async {
    await authCubit.close();
    await locationCubit.close();
  });

  Widget app() {
    return MaterialApp(
      routes: <String, WidgetBuilder>{
        AppRoutes.otpVerify: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final otpArgs = args is OtpVerifyArgs ? args : null;
          return Scaffold(body: Text('otp:${otpArgs?.email}:${otpArgs?.role}'));
        },
      },
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<LocationCubit>.value(value: locationCubit),
        ],
        child: RegisterScreen(),
      ),
    );
  }

  testWidgets('renders the first step and blocks usernames outside bounds', (
    tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Kaydol'), findsOneWidget);
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(locationRepository.citiesCalls, 1);

    await _tapPrimary(tester);
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(authRepository.registerCalls, 0);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).hitTestable(), 'ab');
    await _tapPrimary(tester);
    await tester.pump();
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(authRepository.registerCalls, 0);
  });

  testWidgets('requires eight characters when registering', (tester) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(app());
    await tester.pump();
    await _reachPasswordStep(tester);

    final passwordFields = find.byType(TextField).hitTestable();
    final tooShort = List<String>.filled(7, 'p').join();
    await tester.enterText(passwordFields.at(0), tooShort);
    await tester.enterText(passwordFields.at(1), tooShort);
    await _tapPrimary(tester);
    await tester.pump();

    expect(find.text('Şifren en az 8 karakterden oluşmalı.'), findsOneWidget);
  });

  testWidgets('rejects an ASCII password above 72 UTF-8 bytes', (tester) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(app());
    await tester.pump();
    await _reachPasswordStep(tester);

    final passwordFields = find.byType(TextField).hitTestable();
    final tooLong = List<String>.filled(73, 'p').join();
    await tester.enterText(passwordFields.at(0), tooLong);
    await tester.enterText(passwordFields.at(1), tooLong);
    await _tapPrimary(tester);
    await tester.pump();

    expect(
      find.text('Şifren UTF-8 olarak en fazla 72 bayt olmalı.'),
      findsOneWidget,
    );
  });

  testWidgets('accepts an ASCII password at exactly 72 UTF-8 bytes', (
    tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(app());
    await tester.pump();
    await _reachPasswordStep(tester);

    final passwordFields = find.byType(TextField).hitTestable();
    final maximum = List<String>.filled(72, 'p').join();
    await tester.enterText(passwordFields.at(0), maximum);
    await tester.enterText(passwordFields.at(1), maximum);
    await _tapPrimary(tester);
    await tester.pumpAndSettle();

    expect(find.text("SoundConnect'te ne yapmak istiyorsun?"), findsOneWidget);
    expect(authRepository.registerCalls, 0);
  });

  testWidgets('enforces the 72-byte boundary for multibyte passwords', (
    tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(app());
    await tester.pump();
    await _reachPasswordStep(tester);

    var passwordFields = find.byType(TextField).hitTestable();
    final aboveMaximum = List<String>.filled(37, 'ş').join();
    await tester.enterText(passwordFields.at(0), aboveMaximum);
    await tester.enterText(passwordFields.at(1), aboveMaximum);
    await _tapPrimary(tester);
    await tester.pump();

    expect(
      find.text('Şifren UTF-8 olarak en fazla 72 bayt olmalı.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    passwordFields = find.byType(TextField).hitTestable();
    final maximum = List<String>.filled(36, 'ş').join();
    await tester.enterText(passwordFields.at(0), maximum);
    await tester.enterText(passwordFields.at(1), maximum);
    await _tapPrimary(tester);
    await tester.pumpAndSettle();

    expect(find.text("SoundConnect'te ne yapmak istiyorsun?"), findsOneWidget);
    expect(authRepository.registerCalls, 0);
  });

  testWidgets(
    'submits trimmed listener data and disables controls while loading',
    (tester) async {
      _useLargeSurface(tester);
      final completer = Completer<Result<RegisterResult>>();
      authRepository.registerCompleter = completer;
      await tester.pumpWidget(app());
      await tester.pump();
      await _completeSharedRegistrationSteps(tester);

      expect(_primaryButton(tester).label, 'Tamamla');
      await _tapPrimary(tester);
      await tester.pump();

      expect(authRepository.registerCalls, 1);
      expect(authRepository.lastRegistration?.username, 'listener_name');
      expect(authRepository.lastRegistration?.email, 'listener@example.com');
      expect(authRepository.lastRegistration?.role, 'ROLE_LISTENER');
      expect(authRepository.lastRegistration?.venueName, isNull);
      expect(_primaryButton(tester).onPressed, isNull);
      expect(_primaryButton(tester).label, 'Kaydediliyor...');

      completer.complete(
        const Result.success(
          RegisterResult(
            email: 'listener@example.com',
            status: UserStatus.inactive,
            otpTtlSeconds: 180,
            mailQueued: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('otp:listener@example.com:ROLE_LISTENER'),
        findsOneWidget,
      );
    },
  );

  testWidgets('venue role requires the complete location hierarchy', (
    tester,
  ) async {
    _useLargeSurface(tester);
    authRepository.registerResult = const Result.success(
      RegisterResult(
        email: 'venue@example.com',
        status: UserStatus.pendingVenueRequest,
        otpTtlSeconds: 180,
        mailQueued: true,
      ),
    );
    await tester.pumpWidget(app());
    await tester.pump();
    await _completeSharedRegistrationSteps(tester);

    final venueRole = find.text('Mekan temsilcisiyim');
    await tester.ensureVisible(venueRole);
    await tester.tap(venueRole);
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
    final fields = find.byType(TextField).hitTestable();
    await tester.enterText(fields.at(0), '  Sound Hall  ');
    await tester.enterText(fields.at(1), '  Main Street  ');
    await tester.enterText(fields.at(2), '  555  ');

    await _chooseDropdown(tester, 0, 'Istanbul');
    await _chooseDropdown(tester, 1, 'Kadikoy');
    await _tapPrimary(tester);
    await tester.pump();
    expect(authRepository.registerCalls, 0);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await _chooseDropdown(tester, 2, 'Moda');
    await _tapPrimary(tester);
    await tester.pump();
    await tester.pumpAndSettle();

    final registration = authRepository.lastRegistration;
    expect(registration?.role, 'ROLE_VENUE');
    expect(registration?.venueName, 'Sound Hall');
    expect(registration?.venueAddress, 'Main Street');
    expect(registration?.phone, '555');
    expect(registration?.cityId, 'city-1');
    expect(registration?.districtId, 'district-1');
    expect(registration?.neighborhoodId, 'neighborhood-1');
    expect(find.text('otp:venue@example.com:ROLE_VENUE'), findsOneWidget);
  });
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _completeSharedRegistrationSteps(WidgetTester tester) async {
  await _reachPasswordStep(tester);

  final passwordFields = find.byType(TextField).hitTestable();
  await tester.enterText(passwordFields.at(0), 'password123');
  await tester.enterText(passwordFields.at(1), 'password123');
  await _tapPrimary(tester);
  await tester.pumpAndSettle();
}

Future<void> _reachPasswordStep(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextField).hitTestable(),
    '  listener_name  ',
  );
  await _tapPrimary(tester);
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byType(TextField).hitTestable(),
    '  listener@example.com  ',
  );
  await _tapPrimary(tester);
  await tester.pumpAndSettle();
}

GradientOutlineButton _primaryButton(WidgetTester tester) {
  return tester.widget<GradientOutlineButton>(
    find.byType(GradientOutlineButton),
  );
}

Future<void> _tapPrimary(WidgetTester tester) async {
  final callback = _primaryButton(tester).onPressed;
  expect(callback, isNotNull);
  callback!();
  await tester.pump();
}

Future<void> _chooseDropdown(
  WidgetTester tester,
  int index,
  String label,
) async {
  final dropdowns = find.byType(DropdownButtonFormField<String>);
  await tester.ensureVisible(dropdowns.at(index));
  await tester.tap(dropdowns.at(index));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
