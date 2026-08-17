import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/register_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/user_status.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/username_availability.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/otp_verify_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/register_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/location/presentation/cubit/location_cubit.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_text_field.dart';

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

  Widget app({bool includeSourceRoute = false}) {
    Widget registration() => MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<LocationCubit>.value(value: locationCubit),
      ],
      child: RegisterScreen(),
    );

    return MaterialApp(
      routes: <String, WidgetBuilder>{
        AppRoutes.otpVerify: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final otpArgs = args is OtpVerifyArgs ? args : null;
          return Scaffold(body: Text('otp:${otpArgs?.email}:${otpArgs?.role}'));
        },
      },
      home: includeSourceRoute ? null : registration(),
      onGenerateInitialRoutes: includeSourceRoute
          ? (_) => <Route<dynamic>>[
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/source'),
                builder: (_) => const Scaffold(body: Text('source-route')),
              ),
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: AppRoutes.register),
                builder: (_) => registration(),
              ),
            ]
          : null,
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

  testWidgets('shows a taken username inline and blocks the next step', (
    tester,
  ) async {
    _useLargeSurface(tester);
    authRepository.usernameAvailabilityResult = const Result.success(
      UsernameAvailability(username: 'taken-user', available: false),
    );
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.enterText(
      find.byType(TextField).hitTestable(),
      '  Taken-User  ',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('register-username-taken')), findsOneWidget);
    expect(find.text('Bu kullanıcı adı zaten kullanılıyor.'), findsOneWidget);

    await _tapPrimary(tester);
    await tester.pumpAndSettle();

    expect(find.text('Kullanıcı adı oluştur'), findsOneWidget);
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
      find.text('Şifren çok uzun. Biraz kısaltıp tekrar dene.'),
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
      find.text('Şifren çok uzun. Biraz kısaltıp tekrar dene.'),
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
      await tester.pumpWidget(app(includeSourceRoute: true));
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

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('source-route'), findsNothing);

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
    await _tapPrimary(tester);
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
    expect(
      tester
          .widget<GradientTextField>(
            find.byKey(const Key('business-address-field')),
          )
          .label,
      'Açık Adres',
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('business-address-field'))).dy,
      greaterThan(
        tester
            .getTopLeft(find.byKey(const Key('business-neighborhood-dropdown')))
            .dy,
      ),
    );
    await _enterBusinessField(
      tester,
      const Key('business-name-field'),
      '  Sound Hall  ',
    );
    await _enterBusinessField(
      tester,
      const Key('business-address-field'),
      '  Main Street  ',
    );
    await _enterBusinessField(
      tester,
      const Key('business-phone-field'),
      '  555  ',
    );

    await _chooseDropdown(tester, 0, 'Istanbul');
    await _chooseDropdown(tester, 1, 'Kadikoy');
    await _tapPrimary(tester);
    await tester.pump();
    expect(authRepository.registerCalls, 0);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text(
        'Şehir, ilçe, mahalle ve Açık Adres dahil mekan bilgilerini eksiksiz doldur.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await _chooseDropdown(tester, 2, 'Moda');
    await _tapPrimary(tester);
    await tester.pump();
    await tester.pumpAndSettle();

    final registration = authRepository.lastRegistration;
    expect(registration?.role, 'ROLE_VENUE');
    expect(registration?.venueName, 'sound hall');
    expect(registration?.venueAddress, 'Main Street');
    expect(registration?.phone, '555');
    expect(registration?.cityId, 'city-1');
    expect(registration?.districtId, 'district-1');
    expect(registration?.neighborhoodId, 'neighborhood-1');
    expect(find.text('otp:venue@example.com:ROLE_VENUE'), findsOneWidget);
  });

  testWidgets('studio role submits studio identity and location for approval', (
    tester,
  ) async {
    _useLargeSurface(tester);
    authRepository.registerResult = const Result.success(
      RegisterResult(
        email: 'studio@example.com',
        status: UserStatus.pendingStudioRequest,
        otpTtlSeconds: 180,
        mailQueued: true,
      ),
    );
    await tester.pumpWidget(app());
    await tester.pump();
    await _completeSharedRegistrationSteps(tester);

    expect(find.text('Prodüktörüm'), findsNothing);
    expect(find.text('Organizatörüm'), findsNothing);

    final studioRole = find.text('Stüdyo temsilcisiyim');
    await tester.ensureVisible(studioRole);
    await tester.tap(studioRole);
    await tester.pumpAndSettle();
    await _tapPrimary(tester);
    await tester.pumpAndSettle();

    expect(find.text('Stüdyo bilgilerini paylaş'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
    expect(
      tester
          .widget<GradientTextField>(
            find.byKey(const Key('business-address-field')),
          )
          .label,
      'Açık Adres',
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('business-address-field'))).dy,
      greaterThan(
        tester
            .getTopLeft(find.byKey(const Key('business-neighborhood-dropdown')))
            .dy,
      ),
    );
    await _enterBusinessField(
      tester,
      const Key('business-name-field'),
      '  Devo Studio  ',
    );
    await _enterBusinessField(
      tester,
      const Key('business-address-field'),
      '  Moda Caddesi  ',
    );
    await _enterBusinessField(
      tester,
      const Key('business-phone-field'),
      '  555 123 45 67  ',
    );
    await _chooseDropdown(tester, 0, 'Istanbul');
    await _chooseDropdown(tester, 1, 'Kadikoy');
    await _chooseDropdown(tester, 2, 'Moda');
    await _tapPrimary(tester);
    await tester.pumpAndSettle();

    final registration = authRepository.lastRegistration;
    expect(registration?.role, 'ROLE_STUDIO');
    expect(registration?.studioName, 'devo studio');
    expect(registration?.studioAddress, 'Moda Caddesi');
    expect(registration?.studioPhone, '05551234567');
    expect(registration?.venueName, isNull);
    expect(registration?.phone, isNull);
    expect(registration?.cityId, 'city-1');
    expect(registration?.districtId, 'district-1');
    expect(registration?.neighborhoodId, 'neighborhood-1');
    expect(find.text('otp:studio@example.com:ROLE_STUDIO'), findsOneWidget);
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
    '  Listener_Name  ',
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

Future<void> _enterBusinessField(
  WidgetTester tester,
  Key key,
  String value,
) async {
  final field = find.descendant(
    of: find.byKey(key),
    matching: find.byType(TextField),
  );
  expect(field, findsOneWidget);
  await tester.enterText(field, value);
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
