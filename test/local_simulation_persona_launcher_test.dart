import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/simulation/local_simulation_config.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/widgets/local_simulation_persona_launcher.dart';

void main() {
  const persona = LocalSimulationPersona(
    key: 'musician-ist-01',
    username: 'denizkaraca',
    displayName: 'Deniz Karaca',
    state: LocalSimulationObserverState.complete,
    description: 'Tam profil',
  );

  testWidgets('disabled launcher is unreachable and inert', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocalSimulationPersonaLauncher(
            enabled: false,
            isBusy: false,
            personas: const [persona],
            configuredPassword: 'never-used',
            onSelected: (_, __) => calls += 1,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('local-simulation-persona-launcher')),
      findsNothing,
    );
    expect(calls, 0);
  });

  testWidgets('uses the developer-supplied password without displaying it', (
    tester,
  ) async {
    LocalSimulationPersona? selected;
    String? receivedPassword;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              LocalSimulationPersonaLauncher(
                enabled: true,
                isBusy: false,
                personas: const [persona],
                configuredPassword: 'local-secret',
                onSelected: (value, password) {
                  selected = value;
                  receivedPassword = password;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('local-simulation-persona-launcher')),
    );
    await tester.pumpAndSettle();
    expect(find.text('local-secret'), findsNothing);

    await tester.tap(
      find.byKey(const Key('local-simulation-persona-musician-ist-01')),
    );
    await tester.pumpAndSettle();

    expect(selected, same(persona));
    expect(receivedPassword, 'local-secret');
    expect(find.text('local-secret'), findsNothing);
  });

  testWidgets('requests an unconfigured password without persisting it', (
    tester,
  ) async {
    String? receivedPassword;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              LocalSimulationPersonaLauncher(
                enabled: true,
                isBusy: false,
                personas: const [persona],
                configuredPassword: '',
                onSelected: (_, password) => receivedPassword = password,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('local-simulation-persona-launcher')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('local-simulation-persona-musician-ist-01')),
    );
    await tester.pumpAndSettle();

    final passwordField = find.byKey(
      const Key('local-simulation-password'),
    );
    expect(passwordField, findsOneWidget);
    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
    await tester.pump();
    expect(find.text('Şifre boş olamaz'), findsOneWidget);

    await tester.enterText(passwordField, 'typed-secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
    await tester.pumpAndSettle();

    expect(receivedPassword, 'typed-secret');
    expect(find.text('typed-secret'), findsNothing);
  });
}
