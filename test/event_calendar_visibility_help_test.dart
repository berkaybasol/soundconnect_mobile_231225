import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_calendar_visibility_help.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_request_copy.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

const _dialogKey = Key('event-calendar-visibility-help-dialog');
const _dismissKey = Key('event-calendar-visibility-help-dismiss');

void main() {
  for (final type in EventPerformerTargetType.values) {
    for (final purpose in EventPerformerRequestPurpose.values) {
      testWidgets(
        'help shows target/purpose copy and is read-only: $type $purpose',
        (tester) async {
          final request = _request(type: type, purpose: purpose);
          final harness = await _mount(tester, request: request);
          expect(
            find.text(request.calendarVisibilityExplanation),
            findsOneWidget,
          );
          expect(find.text('Detaylar için dokun'), findsOneWidget);
          expect(find.textContaining('takvim anahtar'), findsNothing);
          final notice = find.byKey(
            const Key('event-calendar-visibility-notice'),
          );
          expect(notice, findsNothing);

          _opener(tester, request)();
          await tester.pumpAndSettle();
          expect(find.byKey(_dialogKey), findsOneWidget);
          expect(notice, findsOneWidget);
          expect(
            find.descendant(
              of: notice,
              matching: find.text(request.calendarVisibilityHelpParagraphs[1]),
            ),
            findsOneWidget,
          );
          expect(
            (tester.widget<DecoratedBox>(notice).decoration as BoxDecoration)
                .gradient,
            isA<LinearGradient>(),
          );
          expect(
            find.descendant(
              of: notice,
              matching: find.byIcon(Icons.info_outline_rounded),
            ),
            findsOneWidget,
          );
          expect(
            find.text(request.calendarVisibilityHelpTitle),
            findsOneWidget,
          );
          for (final paragraph in request.calendarVisibilityHelpParagraphs) {
            expect(find.text(paragraph), findsOneWidget);
          }
          expect(harness.host.currentState!.publication, isFalse);
          expect(harness.host.currentState!.publicationChanges, 0);
          await _dismiss(tester);
          expect(find.byKey(_dialogKey), findsNothing);
          expect(find.byKey(const Key('help-test-home')), findsOneWidget);
          expect(harness.host.currentState!.publication, isFalse);
          expect(harness.host.currentState!.publicationChanges, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('repeated saved opener presents only one dialog', (tester) async {
    final request = _request();
    final harness = await _mount(tester, request: request);
    final open = _opener(tester, request);
    open();
    open();
    await tester.pumpAndSettle();
    expect(find.byKey(_dialogKey), findsOneWidget);
    expect(harness.observer.dialogPushes, 1);
    await _dismiss(tester);
    open();
    await tester.pumpAndSettle();
    expect(harness.observer.dialogPushes, 2);
    await _dismiss(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disabled helper has no tap action and rejects a stale callback',
    (tester) async {
      final request = _request();
      final harness = await _mount(tester, request: request);
      final open = _opener(tester, request);
      harness.host.currentState!.change(enabled: false);
      await tester.pumpAndSettle();
      expect(tester.widget<InkWell>(_help(request)).onTap, isNull);
      open();
      await tester.pumpAndSettle();
      expect(find.byKey(_dialogKey), findsNothing);
      expect(harness.observer.dialogPushes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stale opener cannot open help over another route', (
    tester,
  ) async {
    final request = _request();
    final harness = await _mount(tester, request: request);
    final open = _opener(tester, request);
    _pushOtherRoute(harness);
    await tester.pumpAndSettle();
    open();
    await tester.pumpAndSettle();
    expect(find.text('Other route'), findsOneWidget);
    expect(find.byKey(_dialogKey, skipOffstage: false), findsNothing);
    expect(harness.observer.dialogPushes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale opener is harmless after helper is unmounted', (
    tester,
  ) async {
    final request = _request();
    final harness = await _mount(tester, request: request);
    final open = _opener(tester, request);
    harness.host.currentState!.change(visible: false);
    await tester.pumpAndSettle();
    open();
    await tester.pumpAndSettle();
    expect(find.byKey(_dialogKey), findsNothing);
    expect(harness.observer.dialogPushes, 0);
    expect(find.byKey(const Key('help-test-home')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved dismiss cannot pop a covering route or pop twice', (
    tester,
  ) async {
    final request = _request();
    final harness = await _mount(tester, request: request);
    _opener(tester, request)();
    await tester.pumpAndSettle();
    final dismiss = tester
        .widget<GradientOutlineButton>(find.byKey(_dismissKey))
        .onPressed!;
    _pushOtherRoute(harness);
    await tester.pumpAndSettle();
    dismiss();
    dismiss();
    await tester.pumpAndSettle();
    expect(find.text('Other route'), findsOneWidget);
    expect(harness.observer.popped, isEmpty);

    harness.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(_dialogKey), findsOneWidget);
    dismiss();
    dismiss();
    await tester.pumpAndSettle();
    expect(find.byKey(_dialogKey), findsNothing);
    expect(find.byKey(const Key('help-test-home')), findsOneWidget);
    expect(harness.observer.popped.length, 2);

    _pushOtherRoute(harness);
    await tester.pumpAndSettle();
    dismiss();
    await tester.pumpAndSettle();
    expect(find.text('Other route'), findsOneWidget);
    expect(harness.observer.popped.length, 2);
    expect(tester.takeException(), isNull);
  });

  final changedIdentities = <String, EventPerformerRequest>{
    'request id': _request(requestId: 'new-request'),
    'target id': _request(targetId: 'new-profile'),
    'target type': _request(type: EventPerformerTargetType.band),
    'request purpose': _request(
      purpose: EventPerformerRequestPurpose.profileVisibility,
    ),
  };
  for (final entry in changedIdentities.entries) {
    testWidgets(
      'changing ${entry.key} closes old help and permits fresh help',
      (tester) async {
        final original = _request();
        final harness = await _mount(tester, request: original);
        _opener(tester, original)();
        await tester.pumpAndSettle();
        harness.host.currentState!.change(request: entry.value);
        await tester.pumpAndSettle();
        expect(find.byKey(_dialogKey), findsNothing);
        expect(find.byKey(const Key('help-test-home')), findsOneWidget);
        expect(
          harness.observer.removed.whereType<DialogRoute<void>>(),
          hasLength(1),
        );
        expect(harness.observer.popped, isEmpty);
        _opener(tester, entry.value)();
        await tester.pumpAndSettle();
        expect(find.byKey(_dialogKey), findsOneWidget);
        expect(
          find.text(entry.value.calendarVisibilityHelpParagraphs.first),
          findsOneWidget,
        );
        await _dismiss(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final unmount in [false, true]) {
    testWidgets(
      '${unmount ? 'unmount' : 'identity change'} removes only owned dialog beneath another route',
      (tester) async {
        final request = _request();
        final harness = await _mount(tester, request: request);
        _opener(tester, request)();
        await tester.pumpAndSettle();
        final oldDismiss = tester
            .widget<GradientOutlineButton>(find.byKey(_dismissKey))
            .onPressed!;
        _pushOtherRoute(harness);
        await tester.pumpAndSettle();
        harness.host.currentState!.change(
          visible: !unmount,
          request: unmount ? null : _request(requestId: 'replacement'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Other route'), findsOneWidget);
        expect(find.byKey(_dialogKey, skipOffstage: false), findsNothing);
        expect(
          harness.observer.removed.whereType<DialogRoute<void>>(),
          hasLength(1),
        );
        expect(harness.observer.popped, isEmpty);
        oldDismiss();
        await tester.pumpAndSettle();
        expect(find.text('Other route'), findsOneWidget);
        harness.navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('help-test-home')), findsOneWidget);
        expect(find.byKey(_dialogKey), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scenario in [
    (name: '320dp at 200 percent', size: const Size(320, 640), inset: 0.0),
    (name: 'landscape at 200 percent', size: const Size(640, 320), inset: 0.0),
    (name: 'keyboard at 200 percent', size: const Size(320, 640), inset: 240.0),
  ]) {
    testWidgets(
      'long band explanation scrolls to an accessible dismiss: ${scenario.name}',
      (tester) async {
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final request = _request(type: EventPerformerTargetType.band);
        final harness = await _mount(
          tester,
          request: request,
          textScale: 2,
          bottomInset: scenario.inset,
        );
        _opener(tester, request)();
        await tester.pumpAndSettle();
        expect(find.byKey(_dialogKey), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final paragraph in request.calendarVisibilityHelpParagraphs) {
          expect(find.text(paragraph), findsOneWidget);
        }
        final dismiss = find.byKey(_dismissKey);
        await tester.ensureVisible(dismiss);
        await tester.pumpAndSettle();
        expect(tester.getSize(dismiss).height, greaterThanOrEqualTo(48));
        final bounds = tester.getRect(dismiss);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(scenario.size.width));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(
          bounds.bottom,
          lessThanOrEqualTo(scenario.size.height - scenario.inset),
        );
        await tester.tap(dismiss);
        await tester.pumpAndSettle();
        expect(find.byKey(_dialogKey), findsNothing);
        expect(harness.host.currentState!.publicationChanges, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Finder _help(EventPerformerRequest request) =>
    find.byKey(Key('event-calendar-visibility-help-${request.requestId}'));

VoidCallback _opener(WidgetTester tester, EventPerformerRequest request) =>
    tester.widget<InkWell>(_help(request)).onTap!;

Future<void> _dismiss(WidgetTester tester) async {
  final dismiss = find.byKey(_dismissKey);
  await tester.ensureVisible(dismiss);
  await tester.tap(dismiss);
  await tester.pumpAndSettle();
}

void _pushOtherRoute(_Harness harness) {
  harness.navigator.currentState!.push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'other'),
      builder: (_) => const Scaffold(body: Center(child: Text('Other route'))),
    ),
  );
}

Future<_Harness> _mount(
  WidgetTester tester, {
  required EventPerformerRequest request,
  double textScale = 1,
  double bottomInset = 0,
}) async {
  final harness = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      navigatorKey: harness.navigator,
      navigatorObservers: [harness.observer],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          viewInsets: EdgeInsets.only(bottom: bottomInset),
        ),
        child: child!,
      ),
      home: _HelpHost(key: harness.host, request: request),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

class _Harness {
  final navigator = GlobalKey<NavigatorState>();
  final host = GlobalKey<_HelpHostState>();
  final observer = _RouteObserver();
}

class _RouteObserver extends NavigatorObserver {
  int dialogPushes = 0;
  final popped = <Route<dynamic>>[];
  final removed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is DialogRoute<void>) dialogPushes++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      popped.add(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      removed.add(route);
}

class _HelpHost extends StatefulWidget {
  const _HelpHost({super.key, required this.request});
  final EventPerformerRequest request;

  @override
  State<_HelpHost> createState() => _HelpHostState();
}

class _HelpHostState extends State<_HelpHost> {
  late EventPerformerRequest request = widget.request;
  bool enabled = true;
  bool visible = true;
  bool publication = false;
  int publicationChanges = 0;

  void change({EventPerformerRequest? request, bool? enabled, bool? visible}) {
    setState(() {
      if (request != null) this.request = request;
      if (enabled != null) this.enabled = enabled;
      if (visible != null) this.visible = visible;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('help-test-home'),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CheckboxListTile(
          value: publication,
          title: const Text('Profilde göster'),
          onChanged: (value) => setState(() {
            publication = value ?? false;
            publicationChanges++;
          }),
        ),
        if (visible)
          EventCalendarVisibilityHelp(request: request, enabled: enabled),
      ],
    ),
  );
}

EventPerformerRequest _request({
  String requestId = 'invitation',
  String targetId = 'profile',
  EventPerformerTargetType type = EventPerformerTargetType.musician,
  EventPerformerRequestPurpose purpose =
      EventPerformerRequestPurpose.performerConsent,
}) => EventPerformerRequest(
  requestId: requestId,
  eventId: 'event',
  eventTitle: 'M-T1 — Katıl, gösterme',
  eventDate: DateTime(2026, 9, 6),
  startTime: '20:00:00',
  endTime: '22:00:00',
  venueId: 'venue',
  venueName: 'soundconnectankara',
  venueProfilePictureUrl: null,
  targetType: type,
  targetId: targetId,
  musicianProfileId: type == EventPerformerTargetType.musician
      ? targetId
      : null,
  bandId: type == EventPerformerTargetType.band ? targetId : null,
  performerName: type == EventPerformerTargetType.band
      ? 'Şahbaz'
      : 'bugrasahin',
  status: EventPerformerRequestStatus.pending,
  requestPurpose: purpose,
  profileCalendarApproved: false,
  createdAt: DateTime(2026, 9, 5),
  decidedAt: null,
);
