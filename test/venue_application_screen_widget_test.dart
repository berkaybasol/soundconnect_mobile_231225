import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/register_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/user_status.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/otp_verify_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/venue_application_screen.dart';
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

  Widget app({VenueApplicationArgs? args, bool includeSourceRoute = false}) {
    Widget application() => MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<LocationCubit>.value(value: locationCubit),
      ],
      child: VenueApplicationScreen(args: args),
    );

    return MaterialApp(
      routes: <String, WidgetBuilder>{
        AppRoutes.otpVerify: (context) {
          final routeArgs = ModalRoute.of(context)?.settings.arguments;
          final otpArgs = routeArgs is OtpVerifyArgs ? routeArgs : null;
          return Scaffold(body: Text('otp:${otpArgs?.email}:${otpArgs?.role}'));
        },
      },
      home: includeSourceRoute ? null : application(),
      onGenerateInitialRoutes: includeSourceRoute
          ? (_) => <Route<dynamic>>[
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/source'),
                builder: (_) => const Scaffold(body: Text('source-route')),
              ),
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: AppRoutes.venueApplication),
                builder: (_) => application(),
              ),
            ]
          : null,
    );
  }

  testWidgets('renders the form and rejects a missing registration argument', (
    tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
    expect(locationRepository.citiesCalls, 1);

    await tester.tap(find.byType(GradientOutlineButton));
    await tester.pump();

    expect(authRepository.registerCalls, 0);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Kayıt bilgileri eksik.'), findsOneWidget);
  });

  testWidgets('shows location failure and retry invokes the repository again', (
    tester,
  ) async {
    locationRepository.citiesResult = const Result.failure(
      AppError(code: 'cities_failed', message: 'Location unavailable'),
    );
    _useLargeSurface(tester);
    await tester.pumpWidget(app(args: _args));
    await tester.pump();
    await tester.pump();

    expect(find.text('Location unavailable'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(locationRepository.citiesCalls, 1);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    await tester.pump();
    expect(locationRepository.citiesCalls, 2);
  });

  testWidgets('requires neighborhood and maps the complete venue submission', (
    tester,
  ) async {
    final completer = Completer<Result<RegisterResult>>();
    authRepository.registerCompleter = completer;
    authRepository.registerResult = const Result.success(
      RegisterResult(
        email: 'venue@example.com',
        status: UserStatus.pendingVenueRequest,
        otpTtlSeconds: 180,
        mailQueued: true,
      ),
    );
    _useLargeSurface(tester);
    await tester.pumpWidget(app(args: _args, includeSourceRoute: true));
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<GradientTextField>(
            find.byKey(const Key('venue-application-address-field')),
          )
          .label,
      'Açık Adres',
    );
    expect(
      tester
          .getTopLeft(find.byKey(const Key('venue-application-address-field')))
          .dy,
      greaterThan(
        tester
            .getTopLeft(find.byType(DropdownButtonFormField<String>).at(2))
            .dy,
      ),
    );
    await _enterField(
      tester,
      const Key('venue-application-name-field'),
      '  Sound Hall  ',
    );
    await _enterField(
      tester,
      const Key('venue-application-address-field'),
      '  Main Street  ',
    );
    await _enterField(
      tester,
      const Key('venue-application-phone-field'),
      '  555  ',
    );
    await _chooseDropdown(tester, 0, 'Istanbul');
    await _chooseDropdown(tester, 1, 'Kadikoy');

    await tester.tap(find.byType(GradientOutlineButton).hitTestable());
    await tester.pump();
    expect(authRepository.registerCalls, 0);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text(
        'Şehir, ilçe, mahalle ve Açık Adres dahil mekan bilgilerini eksiksiz doldur.',
      ),
      findsOneWidget,
    );

    await _chooseDropdown(tester, 2, 'Moda');
    await tester.tap(find.byType(GradientOutlineButton).hitTestable());
    await tester.pump();

    expect(authRepository.registerCalls, 1);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(VenueApplicationScreen), findsOneWidget);
    expect(find.text('source-route'), findsNothing);

    completer.complete(authRepository.registerResult);
    await tester.pumpAndSettle();

    final registration = authRepository.lastRegistration;
    expect(registration?.username, 'venue_owner');
    expect(registration?.email, 'venue@example.com');
    expect(registration?.role, 'ROLE_VENUE');
    expect(registration?.venueName, 'sound hall');
    expect(registration?.venueAddress, 'Main Street');
    expect(registration?.phone, '555');
    expect(registration?.cityId, 'city-1');
    expect(registration?.districtId, 'district-1');
    expect(registration?.neighborhoodId, 'neighborhood-1');
    expect(find.text('otp:venue@example.com:ROLE_VENUE'), findsOneWidget);
  });
}

final VenueApplicationArgs _args = VenueApplicationArgs(
  username: 'venue_owner',
  email: 'venue@example.com',
  password: 'password123',
  rePassword: 'password123',
  role: 'ROLE_VENUE',
);

void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
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

Future<void> _enterField(WidgetTester tester, Key key, String value) async {
  final field = find.descendant(
    of: find.byKey(key),
    matching: find.byType(TextField),
  );
  expect(field, findsOneWidget);
  await tester.enterText(field, value);
}
