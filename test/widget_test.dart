import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soundconnect_23_12_25codx/app/app.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/event/presentation/screens/guest_event_home_screen.dart';

void main() {
  setUpAll(setupDependencies);

  testWidgets('shows loading while token is resolving', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SoundConnectApp(initialTokenFuture: Completer<String?>().future),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Guest home renders when token is empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SoundConnectApp(initialTokenFuture: Future<String?>.value(null)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GuestEventHomeScreen), findsOneWidget);
  });

  testWidgets('Guest home renders when token exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SoundConnectApp(initialTokenFuture: Future<String?>.value('token')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GuestEventHomeScreen), findsOneWidget);
  });
}
