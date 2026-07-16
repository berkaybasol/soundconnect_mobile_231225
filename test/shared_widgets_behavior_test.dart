import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_scaffold.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_text.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_text_field.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/placeholder_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/waveform_stub.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AppScaffold', () {
    testWidgets('renders title, actions, child, and scroll behavior', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppScaffold(
            title: 'Library',
            actions: const <Widget>[Icon(Icons.search)],
            child: const Text('Content'),
          ),
        ),
      );

      expect(find.text('Library'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('supports fixed and aligned content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppScaffold(
            title: 'Fixed',
            scrollable: false,
            centerContent: true,
            centerAlignment: Alignment.bottomRight,
            child: const Text('Aligned'),
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsNothing);
      final align = tester.widget<Align>(
        find.ancestor(of: find.text('Aligned'), matching: find.byType(Align)),
      );
      expect(align.alignment, Alignment.bottomRight);
    });
  });

  group('GradientOutlineButton', () {
    testWidgets('calls enabled action and renders leading widget', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        host(
          Center(
            child: GradientOutlineButton(
              label: 'Continue',
              leading: const Icon(Icons.arrow_forward),
              onPressed: () => calls++,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(calls, 1);
    });

    testWidgets('disabled and loading variants cannot trigger an action', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        host(
          Column(
            children: <Widget>[
              const GradientOutlineButton(label: 'Disabled', onPressed: null),
              GradientOutlineButton(
                label: 'Loading',
                onPressed: () => calls++,
                loading: true,
                leading: const Icon(Icons.check),
              ),
            ],
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      await tester.tap(find.text('Disabled'));
      await tester.tap(find.text('Loading'));
      expect(calls, 0);
    });
  });

  testWidgets('GradientText forwards text layout options', (tester) async {
    await tester.pumpWidget(
      host(
        const GradientText(
          text: 'A deliberately long label',
          gradient: LinearGradient(colors: <Color>[Colors.red, Colors.blue]),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.end,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('A deliberately long label'));
    expect(text.textAlign, TextAlign.end);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.softWrap, isFalse);
    expect(text.style?.fontSize, 18);
    expect(text.style?.color, Colors.white);
  });

  testWidgets('GradientTextField binds controller, focus and configuration', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        GradientTextField(
          controller: controller,
          label: 'Secret',
          prefixIcon: Icons.lock,
          obscureText: true,
          suffixIcon: const Icon(Icons.visibility),
        ),
      ),
    );

    final before = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect((before.decoration! as BoxDecoration).gradient, isNull);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.decoration?.hintText, 'Secret');
    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'top-secret');
    await tester.pump();
    expect(controller.text, 'top-secret');
    final focused = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect((focused.decoration! as BoxDecoration).gradient, isNotNull);

    tester.testTextInput.hide();
    await tester.pump();
  });

  testWidgets('PlaceholderScreen exposes its title and message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlaceholderScreen(title: 'Soon', message: 'Work in progress'),
      ),
    );

    expect(find.text('Soon'), findsOneWidget);
    expect(find.text('Work in progress'), findsOneWidget);
  });

  group('WaveformStub', () {
    test('seeded samples are deterministic, bounded and configurable', () {
      final first = WaveformStub.samplesFromSeed('track-42', length: 12);
      final second = WaveformStub.samplesFromSeed('track-42', length: 12);
      final other = WaveformStub.samplesFromSeed('track-43', length: 12);

      expect(first, second);
      expect(first, isNot(other));
      expect(first, hasLength(12));
      expect(first.every((sample) => sample >= 0.08 && sample <= 0.96), isTrue);
      expect(WaveformStub.samplesFromSeed('zero', length: 0), isEmpty);
    });

    testWidgets('renders custom slots and reports a clamped seek ratio', (
      tester,
    ) async {
      double? seek;
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 360,
            child: WaveformStub(
              leading: const Icon(Icons.album),
              footer: const Text('00:10 / 03:00'),
              height: 80,
              progress: 2,
              samples: const <double>[0.2, 0.5, 0.8],
              onSeek: (value) => seek = value,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.byIcon(Icons.album), findsOneWidget);
      expect(find.text('00:10 / 03:00'), findsOneWidget);
      final gesture = find.descendant(
        of: find.byType(WaveformStub),
        matching: find.byType(GestureDetector),
      );
      expect(gesture, findsOneWidget);
      final rect = tester.getRect(gesture);
      await tester.tapAt(Offset(rect.left + rect.width * 0.75, rect.center.dy));
      expect(seek, closeTo(0.75, 0.03));

      final detector = tester.widget<GestureDetector>(gesture);
      detector.onHorizontalDragUpdate!(
        DragUpdateDetails(
          localPosition: Offset(rect.width + 80, rect.height / 2),
          globalPosition: Offset(rect.right + 80, rect.center.dy),
        ),
      );
      expect(seek, 1);
      detector.onHorizontalDragUpdate!(
        DragUpdateDetails(
          localPosition: Offset(-80, rect.height / 2),
          globalPosition: Offset(rect.left - 80, rect.center.dy),
        ),
      );
      expect(seek, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
