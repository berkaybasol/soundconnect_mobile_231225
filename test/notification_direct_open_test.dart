import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_direct_open.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';

void main() {
  late BuildContext origin;
  late GlobalKey<NavigatorState> nav;
  Future<void> mount(WidgetTester tester) async {
    nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      navigatorObservers: [notificationTargetRouteObserver],
      home: Builder(builder: (context) {
        origin = context;
        return const Scaffold(body: Text('Mevcut ürün sayfası'));
      }),
    ));
  }

  testWidgets('slow lookup and duplicate tap leave origin visible with no route', (tester) async {
    await mount(tester);
    final result = Completer<bool>();
    var requests = 0;
    Future<bool> resolve() { requests++; return result.future; }
    unawaited(NotificationDirectOpen.start(origin, identity: 'one', builder: (_) => _Probe(resolve)));
    await tester.pump();
    unawaited(NotificationDirectOpen.start(origin, identity: 'one', builder: (_) => _Probe(resolve)));
    await tester.pump();
    expect(requests, 1);
    expect(find.text('Mevcut ürün sayfası'), findsOneWidget);
    expect(nav.currentState!.canPop(), isFalse);
    result.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Gerçek hedef'), findsOneWidget);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Mevcut ürün sayfası'), findsOneWidget);
    expect(nav.currentState!.canPop(), isFalse);
  });

  testWidgets('error retry stays on origin and does not add an error page', (tester) async {
    await mount(tester);
    var attempts = 0;
    unawaited(NotificationDirectOpen.start(origin, identity: 'one', builder: (_) => _Probe(() async => ++attempts > 1)));
    await tester.pumpAndSettle();
    expect(find.text('Mevcut ürün sayfası'), findsOneWidget);
    expect(find.text('Bu içerik şu anda açılamıyor.'), findsOneWidget);
    expect(nav.currentState!.canPop(), isFalse);
    await tester.pump(const Duration(seconds: 12));
    expect(attempts, 1);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Gerçek hedef'), findsOneWidget);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Bu içerik şu anda açılamıyor.'), findsNothing);
  });

  testWidgets('retry and a duplicate selection share a new future and preserve replacement', (tester) async {
    await mount(tester);
    // A real replacement origin has a previous product page to return to.
    unawaited(nav.currentState!.push(MaterialPageRoute<void>(builder: (context) {
      origin = context;
      return const Scaffold(body: Text('Replacement origin'));
    })));
    await tester.pumpAndSettle();
    var attempts = 0;
    final pending = Completer<bool>();
    Future<bool> resolve() async => ++attempts == 1 ? false : pending.future;
    final first = NotificationDirectOpen.start(origin, identity: 'retry', replaceOrigin: true, builder: (_) => _Probe(resolve));
    await tester.pumpAndSettle();
    await first;
    final retry = tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed;
    retry();
    retry();
    var duplicateDone = false;
    unawaited(NotificationDirectOpen.start(origin, identity: 'retry', replaceOrigin: true, builder: (_) => _Probe(resolve)).then((_) => duplicateDone = true));
    await tester.pump();
    expect(attempts, 2);
    expect(duplicateDone, isFalse);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(duplicateDone, isTrue);
    expect(find.text('Gerçek hedef'), findsOneWidget);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Mevcut ürün sayfası'), findsOneWidget);
    expect(nav.currentState!.canPop(), isFalse);
  });

  testWidgets('new exact selection fences the old delayed response', (tester) async {
    await mount(tester);
    final old = Completer<bool>();
    unawaited(NotificationDirectOpen.start(origin, identity: 'one', builder: (_) => _Probe(() => old.future)));
    await tester.pump();
    unawaited(NotificationDirectOpen.start(origin, identity: 'two', builder: (_) => _Probe(() async => false)));
    await tester.pumpAndSettle();
    old.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Gerçek hedef'), findsNothing);
    expect(nav.currentState!.canPop(), isFalse);
  });

  testWidgets('normal cold navigator context resolves its real foreground route', (tester) async {
    await mount(tester);
    unawaited(NotificationDirectOpen.start(nav.currentContext!, identity: 'cold', builder: (_) => _Probe(() async => true)));
    await tester.pumpAndSettle();
    expect(find.text('Gerçek hedef'), findsOneWidget);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(nav.currentState!.canPop(), isFalse);
  });

  testWidgets('replacing the origin disposes pending work and releases caller before late lookup', (tester) async {
    await mount(tester);
    final pending = Completer<bool>();
    var callerReleased = false;
    unawaited(NotificationDirectOpen.start(
      origin,
      identity: 'origin-replaced',
      builder: (_) => _Probe(() => pending.future),
    ).then((_) => callerReleased = true));
    await tester.pump();
    expect(find.byType(_Probe, skipOffstage: false), findsOneWidget);
    expect(callerReleased, isFalse);
    unawaited(nav.currentState!.pushReplacement(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Yeni ürün sayfası')),
    )));
    await tester.pumpAndSettle();
    expect(callerReleased, isTrue);
    expect(find.byType(_Probe, skipOffstage: false), findsNothing);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Yeni ürün sayfası'), findsOneWidget);
    expect(find.text('Gerçek hedef'), findsNothing);
    expect(nav.currentState!.canPop(), isFalse);
  });
}

class _Probe extends StatefulWidget {
  const _Probe(this.resolve);
  final Future<bool> Function() resolve;
  @override
  State<_Probe> createState() => _ProbeState();
}
class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => open());
  }
  Future<void> open() async {
    final success = await widget.resolve();
    if (!mounted || NotificationDirectOpen.routeOf(context)?.isCurrent != true) return;
    if (success) {
      unawaited(NotificationDirectOpen.push(context, MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Gerçek hedef')),
      )));
    } else {
      NotificationDirectOpen.feedback(context, message: 'Bu içerik şu anda açılamıyor.', retry: open);
    }
  }
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
