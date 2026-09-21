import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/event_plan_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_plan.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_item.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_management.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_owner_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_search_result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_plan_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_search_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_plan_performer_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_plan_preview_sheet.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_event_plan_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_weekly_calendar_editor_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme_controller.dart';
import 'event_plan_repository_test.dart' show planJson;

void main() {
  late _Plans plans;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppThemeController.instance.setVariant(AppThemeVariant.light);
    await serviceLocator.reset();
    plans = _Plans();
    serviceLocator.registerSingleton<EventPlanRepository>(plans);
    serviceLocator.registerSingleton<VenueEventRepository>(_Events());
    serviceLocator.registerSingleton<ProfileSearchRepository>(_Search());
  });
  tearDown(serviceLocator.reset);
  tearDown(() => AppThemeController.instance.setVariant(AppThemeVariant.dark));

  Future<void> size(
    WidgetTester tester, {
    double width = 420,
    double height = 1000,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> render(WidgetTester tester, String name) async {
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('.local-verification/event-plans')
        ..createSync(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget app(Widget child, {double scale = 1}) => RepaintBoundary(
    child: MaterialApp(
      theme: AppTheme.current,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    ),
  );

  void seedOwnerPlans() {
    EventPlan ownerPlan(String id, String status, String title) {
      final json = planJson();
      return EventPlanRepositoryImpl.decodePlan({
        ...json,
        'id': id,
        'status': status,
        'posterUrl': null,
        'definition': <String, dynamic>{
          ...json['definition'],
          'template': <String, dynamic>{
            ...json['definition']['template'],
            'title': title,
          },
        },
      });
    }

    // The API order deliberately places a historical plan before the active one.
    plans.ownerItems = [
      ownerPlan('completed-plan', 'COMPLETED', 'Tamamlanan program'),
      ownerPlan('plan-1', 'ACTIVE', 'Aktif program'),
      ownerPlan('stopped-plan', 'STOPPED', 'Durdurulan program'),
    ];
  }

  testWidgets(
    'owner management drops private plan data when the session changes',
    (tester) async {
      await size(tester, height: 1400);
      final sessions = _Sessions();
      serviceLocator.registerSingleton<AuthSessionManager>(sessions);
      seedOwnerPlans();
      await tester.pumpWidget(
        app(const VenueWeeklyCalendarEditorScreen(ownerProfile: _owner)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('venue-management-plans-tab')));
      await tester.pumpAndSettle();
      expect(find.text('Aktif program'), findsOneWidget);
      sessions.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Aktif program'), findsNothing);
      expect(find.text('Tamamlanan program'), findsNothing);
      expect(
        find.text('Oturum değişti. Etkinlik yönetimini yeniden aç.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Etkinlikleri yenile'));
      await tester.pumpAndSettle();
      expect(plans.ownerListCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preview exclusions are reconfirmed and cancel creates nothing', (
    tester,
  ) async {
    await size(tester);
    EventPlanDefinition? chosen;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                chosen = await showModalBottomSheet<EventPlanDefinition>(
                  context: context,
                  isScrollControlled: true,
                  constraints: const BoxConstraints(maxHeight: 850),
                  builder: (_) => EventPlanPreviewSheet(
                    definition: plans.plan.definition,
                    repository: plans,
                  ),
                );
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-preview-2026-09-25')));
    await tester.pump();
    await render(tester, 'preview');
    final confirm = tester
        .widget<OutlinedButton>(find.byKey(const Key('plan-preview-confirm')))
        .onPressed!;
    confirm();
    confirm();
    await tester.pumpAndSettle();
    expect(plans.previews, hasLength(2));
    expect(chosen!.excludedDates.map(eventPlanDate), ['2026-09-25']);
    expect(plans.previews.last.excludedDates.map(eventPlanDate), [
      '2026-09-25',
    ]);
    expect(plans.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'owner management separates event and plan tabs with plan history collapsed',
    (tester) async {
      await size(tester, width: 390, height: 1300);
      seedOwnerPlans();
      await tester.pumpWidget(
        app(const VenueWeeklyCalendarEditorScreen(ownerProfile: _owner)),
      );
      await tester.pumpAndSettle();
      final eventsTab = find.byKey(const Key('venue-management-events-tab'));
      final plansTab = find.byKey(const Key('venue-management-plans-tab'));
      final history = find.byKey(const Key('venue-plans-history'));
      final active = find.byKey(const ValueKey('owner-event-plan-plan-1'));
      final stopped = find.byKey(
        const ValueKey('owner-event-plan-stopped-plan'),
      );
      final completed = find.byKey(
        const ValueKey('owner-event-plan-completed-plan'),
      );

      expect(find.text('Etkinlik Yönetimi'), findsOneWidget);
      expect(eventsTab, findsOneWidget);
      expect(plansTab, findsOneWidget);
      expect(find.text('Etkinlikler'), findsOneWidget);
      expect(find.text('Planlar'), findsOneWidget);
      for (final key in [
        'venue-events-this-week',
        'venue-events-future',
        'venue-events-past',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget);
      }
      expect(active, findsNothing);
      expect(stopped, findsNothing);
      expect(completed, findsNothing);
      expect(history, findsNothing);
      await render(tester, 'owner-management-light');

      await tester.tap(plansTab);
      await tester.pumpAndSettle();
      expect(active, findsOneWidget);
      expect(history, findsOneWidget);
      expect(find.text('Geçmiş planlar'), findsOneWidget);
      expect(stopped, findsNothing);
      expect(completed, findsNothing);
      expect(find.byKey(const Key('venue-events-this-week')), findsNothing);
      expect(
        tester.getTopLeft(active).dy,
        lessThan(tester.getTopLeft(history).dy),
      );
      await render(tester, 'owner-management-plans-light');

      await AppThemeController.instance.setVariant(AppThemeVariant.dark);
      await tester.pumpWidget(
        app(const VenueWeeklyCalendarEditorScreen(ownerProfile: _owner)),
      );
      await tester.pumpAndSettle();
      expect(active, findsOneWidget);
      expect(stopped, findsNothing);
      expect(completed, findsNothing);
      await render(tester, 'owner-management-plans-dark');
      await tester.tap(eventsTab);
      await tester.pumpAndSettle();
      expect(active, findsNothing);
      expect(stopped, findsNothing);
      expect(completed, findsNothing);
      await render(tester, 'owner-management-dark');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded plan history survives tab switches and a plan detail return refresh',
    (tester) async {
      await size(tester, width: 390, height: 1300);
      seedOwnerPlans();
      await tester.pumpWidget(
        app(const VenueWeeklyCalendarEditorScreen(ownerProfile: _owner)),
      );
      await tester.pumpAndSettle();
      final eventsTab = find.byKey(const Key('venue-management-events-tab'));
      final plansTab = find.byKey(const Key('venue-management-plans-tab'));
      final history = find.byKey(const Key('venue-plans-history'));
      final active = find.byKey(const ValueKey('owner-event-plan-plan-1'));
      final stopped = find.byKey(
        const ValueKey('owner-event-plan-stopped-plan'),
      );
      final completed = find.byKey(
        const ValueKey('owner-event-plan-completed-plan'),
      );

      await tester.tap(plansTab);
      await tester.pumpAndSettle();
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(active, findsOneWidget);
      expect(stopped, findsOneWidget);
      expect(completed, findsOneWidget);
      expect(
        tester.getTopLeft(active).dy,
        lessThan(tester.getTopLeft(history).dy),
      );
      expect(
        tester.getTopLeft(history).dy,
        lessThan(tester.getTopLeft(stopped).dy),
      );
      expect(
        tester.getTopLeft(history).dy,
        lessThan(tester.getTopLeft(completed).dy),
      );

      await tester.tap(eventsTab);
      await tester.pumpAndSettle();
      expect(active, findsNothing);
      expect(stopped, findsNothing);
      expect(completed, findsNothing);
      await tester.tap(plansTab);
      await tester.pumpAndSettle();
      expect(stopped, findsOneWidget);
      expect(completed, findsOneWidget);

      final readsBeforeDetail = plans.ownerListCalls;
      await tester.ensureVisible(active);
      await tester.tap(active);
      await tester.pumpAndSettle();
      expect(find.byType(VenueEventPlanScreen), findsOneWidget);
      expect(plans.ownerReads, ['plan-1']);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(VenueEventPlanScreen), findsNothing);
      expect(plans.ownerListCalls, greaterThan(readsBeforeDetail));
      expect(history, findsOneWidget);
      expect(active, findsOneWidget);
      expect(stopped, findsOneWidget);
      expect(completed, findsOneWidget);
      expect(find.byKey(const Key('venue-events-this-week')), findsNothing);
      expect(plans.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed plan page retries the requested page and draft cancellation keeps it',
    (tester) async {
      await size(tester, width: 390, height: 1300);
      plans.plan = EventPlanRepositoryImpl.decodePlan({
        ...planJson(),
        'posterUrl': null,
      });
      var failLastPage = true;
      plans.ownerPageResult = (page) {
        if (page == 2 && failLastPage) {
          failLastPage = false;
          return const Result.failure(
            AppError(code: 'network', message: 'Plan sayfası alınamadı.'),
          );
        }
        return Result.success(
          EventPlanPage(items: [plans.plan], page: page, hasNext: page < 2),
        );
      };
      await tester.pumpWidget(
        app(const VenueWeeklyCalendarEditorScreen(ownerProfile: _owner)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('venue-management-plans-tab')));
      await tester.pumpAndSettle();
      for (var page = 1; page <= 2; page++) {
        final next = find.text('Sonraki planlar');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(plans.ownerRequestedPages, [0, 1, 2]);
      expect(find.text('Plan sayfası alınamadı.'), findsOneWidget);
      final retry = find.widgetWithText(TextButton, 'Yenile');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(plans.ownerRequestedPages, [0, 1, 2, 2]);
      expect(find.text('Plan sayfası alınamadı.'), findsNothing);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Sonraki planlar'),
            )
            .onPressed,
        isNull,
      );

      final create = find.byKey(const Key('venue-management-create-plan'));
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      expect(plans.ownerRequestedPages, [0, 1, 2, 2, 2]);
      expect(create, findsOneWidget);
      expect(plans.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new plan action opens a repeating draft without creating data', (
    tester,
  ) async {
    await size(tester, width: 390, height: 1200);
    await tester.pumpWidget(
      app(const VenueWeeklyCalendarEditorScreen(ownerProfile: _owner)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('venue-management-plans-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('venue-management-create-plan')));
    await tester.pumpAndSettle();

    expect(find.text('Yeni plan'), findsOneWidget);
    final repeat = find.byKey(const Key('event-repeat-toggle'));
    expect(
      tester
          .widget<CupertinoSwitch>(
            find.descendant(of: repeat, matching: find.byType(CupertinoSwitch)),
          )
          .value,
      isTrue,
    );
    for (var day = 1; day <= 7; day++) {
      expect(find.byKey(ValueKey('plan-weekday-$day')), findsOneWidget);
    }
    expect(find.byKey(const Key('plan-until-toggle')), findsOneWidget);
    expect(plans.previews, isEmpty);
    expect(plans.writes, 0);
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni plan'), findsNothing);
    expect(
      find.byKey(const Key('venue-management-create-plan')),
      findsOneWidget,
    );
    expect(plans.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'future edit previews preserve exceptions outside selectable dates and keep version context',
    (tester) async {
      await size(tester, width: 390, height: 1200);
      await AppThemeController.instance.setVariant(AppThemeVariant.dark);
      plans.plan = EventPlanRepositoryImpl.decodePlan({
        ...planJson(version: 7),
        'posterUrl': null,
      });
      plans.previewDates = [DateTime(2026, 9, 25), DateTime(2026, 9, 28)];
      plans.preservedDates = [
        EventPlanPreservedDate(
          scheduledDate: DateTime(2026, 9, 21),
          eventDate: DateTime(2026, 9, 21),
          status: 'STARTED',
        ),
        EventPlanPreservedDate(
          scheduledDate: DateTime(2026, 10, 12),
          eventDate: DateTime(2026, 10, 12),
          status: 'CANCELLED',
        ),
        EventPlanPreservedDate(
          scheduledDate: DateTime(2026, 10, 13),
          eventDate: DateTime(2026, 10, 13),
          status: 'SKIPPED',
        ),
        EventPlanPreservedDate(
          scheduledDate: DateTime(2026, 10, 16),
          eventDate: DateTime(2026, 10, 17),
          status: 'OVERRIDDEN',
        ),
      ];
      await tester.pumpWidget(
        app(
          VenueEventPlanScreen(
            planId: plans.plan.id,
            ownerProfile: _owner,
            repository: plans,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gelecek etkinlikleri düzenle / uzat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('venue-event-submit')));
      await tester.pumpAndSettle();
      expect(plans.previewContexts, [('plan-1', 7)]);
      expect(find.text('2 tarih seçili'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      expect(find.text('Korunan tarihler'), findsOneWidget);
      for (final date in plans.preservedDates) {
        final key = eventPlanDate(date.scheduledDate);
        final row = find.byKey(ValueKey('plan-preserved-$key'));
        expect(row, findsOneWidget);
        expect(find.byKey(ValueKey('plan-preview-$key')), findsNothing);
        expect(
          find.descendant(of: row, matching: find.byType(Checkbox)),
          findsNothing,
        );
      }
      expect(find.text('17 Ekim 2026 Cumartesi'), findsOneWidget);
      expect(
        find.text('Ayrı düzenlendi; bu değişiklikten etkilenmez'),
        findsOneWidget,
      );
      expect(find.text('Atlandı; yeniden eklenmez'), findsOneWidget);
      expect(find.text('İptal edildi; yeniden eklenmez'), findsOneWidget);
      expect(find.text('Başladı; bu değişiklikten etkilenmez'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plan-preview-2026-09-25')));
      await tester.pumpAndSettle();
      expect(find.text('1 tarih seçili'), findsOneWidget);
      await render(tester, 'edit-preview-preserved');
      await tester.tap(find.byKey(const Key('plan-preview-confirm')));
      await tester.pumpAndSettle();
      expect(plans.previewContexts, [('plan-1', 7), ('plan-1', 7)]);
      expect(plans.updatedPlan?.version, 7);
      expect(plans.updatedDefinition?.excludedDates.map(eventPlanDate), [
        '2026-09-25',
      ]);
      expect(plans.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stale final edit preview stays open and cannot save', (
    tester,
  ) async {
    await size(tester);
    plans.previewFailureAfter = 1;
    EventPlanDefinition? chosen;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                chosen = await showModalBottomSheet<EventPlanDefinition>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => EventPlanPreviewSheet(
                    definition: plans.plan.definition,
                    repository: plans,
                    planId: plans.plan.id,
                    expectedVersion: plans.plan.version,
                  ),
                );
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-preview-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(EventPlanPreviewSheet), findsOneWidget);
    expect(find.text('Program değişti. Yeniden aç.'), findsOneWidget);
    expect(chosen, isNull);
    expect(plans.writes, 0);
    expect(plans.previewContexts, [('plan-1', 0), ('plan-1', 0)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recurrence form has finite or indefinite end, no count and stable submission identity',
    (tester) async {
      await size(tester, height: 1200);
      final requests = <String>[];
      final definitions = <EventPlanDefinition>[];
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  unawaited(
                    showVenueEventDraft(
                      context,
                      ownerProfile: _owner,
                      initialDraft: plans.plan.definition.template.toDraft(
                        DateTime(2026, 9, 21),
                      ),
                      performerName: plans.plan.performerName,
                      onSave: (_) async => const Result.success(null),
                      onPlanSave: (definition, request) async {
                        requests.add(request);
                        definitions.add(definition);
                        return const Result.failure(
                          AppError(code: '400', message: 'Düzeltebilirsin.'),
                        );
                      },
                    ),
                  );
                },
                child: const Text('Oluştur'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Oluştur'));
      await tester.pumpAndSettle();
      final repeat = find.byKey(const Key('event-repeat-toggle'));
      await tester.ensureVisible(repeat);
      await tester.tap(repeat);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan-until-toggle')), findsOneWidget);
      expect(find.textContaining('Tekrar sayısı'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('plan-until-toggle')));
      await tester.pumpAndSettle();
      await render(tester, 'recurrence-form');
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.byKey(const Key('venue-event-submit')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('plan-preview-confirm')));
        await tester.pumpAndSettle();
      }
      expect(requests.length, 2);
      expect(requests[0], requests[1]);
      expect(definitions.first.untilDate, isNull);
      expect(definitions.first.template.musicianProfileId, 'musician-1');
      expect(definitions.first.template.posterImage, 'raw-asset-id');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same-day finite plan edit retains its first-day exclusion with a timed draft',
    (tester) async {
      await size(tester, height: 1200);
      final day = DateTime(2026, 9, 22);
      final definition = EventPlanDefinition(
        venueId: _owner.venueId,
        startDate: day,
        untilDate: day,
        weekdays: [2],
        excludedDates: [day],
        template: plans.plan.definition.template,
      );
      plans.previewDates = [day];
      EventPlanDefinition? saved;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showVenueEventDraft(
                  context,
                  ownerProfile: _owner,
                  initialDraft: definition.template.toDraft(
                    DateTime(2026, 9, 22, 1, 50),
                  ),
                  initialPlan: definition,
                  editingPlanId: 'plan-1',
                  editingPlanVersion: 0,
                  onSave: (_) async => throw StateError('Expected a plan edit'),
                  onPlanSave: (value, _) async {
                    saved = value;
                    return const Result.success(null);
                  },
                ),
                child: const Text('Düzenle'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Düzenle'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('venue-event-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('Tekrar günlerini ve bitiş tarihini kontrol et.'),
        findsNothing,
      );
      expect(plans.previews, hasLength(1));
      expect(plans.previews.single.startDate, day);
      expect(plans.previews.single.untilDate, day);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('plan-preview-2026-09-22')),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('plan-preview-confirm')));
      await tester.pumpAndSettle();
      expect(saved!.startDate, day);
      expect(saved!.untilDate, day);
      expect(saved!.excludedDates, [day]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ambiguous creation disables a second write until list reconciliation',
    (tester) async {
      await size(tester, height: 1200);
      var writes = 0;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  unawaited(
                    showVenueEventDraft(
                      context,
                      ownerProfile: _owner,
                      initialDraft: plans.plan.definition.template.toDraft(
                        DateTime(2026, 9, 21),
                      ),
                      initialPlan: plans.plan.definition,
                      performerName: plans.plan.performerName,
                      onSave: (_) async => const Result.success(null),
                      onPlanSave: (_, _) async {
                        writes++;
                        return const Result.failure(
                          AppError(code: 'network', message: 'lost'),
                        );
                      },
                    ),
                  );
                },
                child: const Text('Oluştur'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Oluştur'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('venue-event-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plan-preview-confirm')));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Listeyi kontrol et'), findsOneWidget);
      await tester.tap(find.byKey(const Key('venue-event-submit')));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Kayıt sonucu henüz doğrulanmadı'), findsOneWidget);
    },
  );

  testWidgets(
    'performer requires explicit scope decision with publication off by default',
    (tester) async {
      await size(tester, width: 360, height: 1100);
      await tester.pumpWidget(
        app(
          EventPlanPerformerScreen(
            targetType: EventPerformerTargetType.musician,
            targetId: 'musician-1',
            repository: plans,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
      expect(
        find.textContaining('Mekan programı durdurana kadar'),
        findsOneWidget,
      );
      await render(tester, 'performer-consent');
      await tester.tap(find.byKey(const ValueKey('plan-accept-plan-1')));
      await tester.pumpAndSettle();
      expect(plans.writes, 0);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Programı onayla').last,
      );
      await tester.pumpAndSettle();
      expect(plans.decision, 'ACCEPT');
      expect(plans.publication, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('changed program cannot be accepted from stale confirmation', (
    tester,
  ) async {
    await size(tester);
    await tester.pumpWidget(
      app(
        EventPlanPerformerScreen(
          targetType: EventPerformerTargetType.musician,
          targetId: 'musician-1',
          repository: plans,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-accept-plan-1')));
    await tester.pumpAndSettle();
    plans.plan = EventPlanRepositoryImpl.decodePlan(planJson(version: 1));
    await tester.tap(find.widgetWithText(FilledButton, 'Programı onayla').last);
    await tester.pumpAndSettle();
    expect(plans.writes, 0);
    expect(find.textContaining('Program değişti.'), findsOneWidget);
  });

  testWidgets('withdraw keeps explicit semantics and fits large text', (
    tester,
  ) async {
    await size(tester, width: 320, height: 1200);
    plans.plan = EventPlanRepositoryImpl.decodePlan({
      ...planJson(),
      'consentStatus': 'ACCEPTED',
      'decisionAllowed': false,
      'withdrawAllowed': true,
    });
    await tester.pumpWidget(
      app(
        EventPlanPerformerScreen(
          targetType: EventPerformerTargetType.musician,
          targetId: 'musician-1',
          repository: plans,
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('plan-withdraw-plan-1')),
    );
    await tester.tap(find.byKey(const ValueKey('plan-withdraw-plan-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Onayımı geri çek'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Onayımı geri çek'));
    await tester.pumpAndSettle();
    expect(plans.decision, 'WITHDRAW');
    expect(plans.publication, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed programs can extend while stopped programs cannot', (
    tester,
  ) async {
    await size(tester);
    for (final status in ['COMPLETED', 'STOPPED']) {
      plans.plan = EventPlanRepositoryImpl.decodePlan({
        ...planJson(),
        'status': status,
      });
      await tester.pumpWidget(
        app(
          VenueEventPlanScreen(
            key: ValueKey(status),
            planId: 'plan-1',
            ownerProfile: _owner,
            repository: plans,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Gelecek etkinlikleri düzenle / uzat'),
        status == 'COMPLETED' ? findsOneWidget : findsNothing,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'session change during performer recheck clears busy state and cannot write',
    (tester) async {
      await size(tester);
      final sessions = _Sessions();
      addTearDown(sessions.dispose);
      await tester.pumpWidget(
        app(
          EventPlanPerformerScreen(
            targetType: EventPerformerTargetType.musician,
            targetId: 'musician-1',
            repository: plans,
            sessions: sessions,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-accept-plan-1')));
      await tester.pumpAndSettle();
      final pending = Completer<Result<EventPlan>>();
      plans.performerRead = pending.future;
      await tester.tap(
        find.widgetWithText(FilledButton, 'Programı onayla').last,
      );
      await tester.pump();
      sessions.signOut();
      await tester.pumpAndSettle();
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, true);
      expect(find.text('Akustik Akşamlar'), findsNothing);
      pending.complete(Result.success(plans.plan));
      await tester.pumpAndSettle();
      expect(plans.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'session change dismisses an open consent dialog and unlocks navigation',
    (tester) async {
      await size(tester);
      final sessions = _Sessions();
      addTearDown(sessions.dispose);
      await tester.pumpWidget(
        app(
          EventPlanPerformerScreen(
            targetType: EventPerformerTargetType.musician,
            targetId: 'musician-1',
            repository: plans,
            sessions: sessions,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-accept-plan-1')));
      await tester.pumpAndSettle();
      sessions.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, true);
      expect(plans.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('stopped plan can cancel prepared dates without restarting', (
    tester,
  ) async {
    await size(tester);
    plans.plan = EventPlanRepositoryImpl.decodePlan({
      ...planJson(),
      'status': 'STOPPED',
    });
    await tester.pumpWidget(
      app(
        VenueEventPlanScreen(
          planId: 'plan-1',
          ownerProfile: _owner,
          repository: plans,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hazırlanmış gelecek etkinlikleri iptal et'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Etkinlikleri iptal et'),
    );
    await tester.pumpAndSettle();
    expect(plans.stopCancelFuture, true);
    expect(find.text('Gelecek etkinlikleri düzenle / uzat'), findsNothing);
  });
  testWidgets(
    'owner mutation session change unlocks page and discards late result',
    (tester) async {
      await size(tester);
      final sessions = _Sessions();
      addTearDown(sessions.dispose);
      await tester.pumpWidget(
        app(
          VenueEventPlanScreen(
            planId: 'plan-1',
            ownerProfile: _owner,
            repository: plans,
            sessions: sessions,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planı durdur'));
      await tester.pumpAndSettle();
      final pending = Completer<Result<EventPlan>>();
      plans.stopWrite = pending.future;
      await tester.tap(find.widgetWithText(FilledButton, 'Durdur'));
      await tester.pump();
      sessions.signOut();
      await tester.pumpAndSettle();
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, true);
      pending.complete(Result.success(plans.plan));
      await tester.pumpAndSettle();
      expect(find.text('Akustik Akşamlar'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'single occurrence edit preserves raw references and immutable scheduled key',
    (tester) async {
      await size(tester, height: 1200);
      plans.plan = EventPlanRepositoryImpl.decodePlan({
        ...planJson(),
        'posterUrl': null,
      });
      plans.rows = [
        EventPlanOccurrence(
          scheduledDate: DateTime(2026, 9, 25),
          eventDate: DateTime(2026, 9, 26),
          status: 'OVERRIDDEN',
          eventId: 'event-1',
          template: plans.plan.definition.template,
        ),
      ];
      await tester.pumpWidget(
        app(
          VenueEventPlanScreen(
            planId: 'plan-1',
            ownerProfile: _owner,
            repository: plans,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bu tarihi düzenle'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-repeat-toggle')), findsNothing);
      await tester.tap(find.byKey(const Key('venue-event-submit')));
      await tester.pumpAndSettle();
      expect(
        eventPlanDate(plans.editedOccurrence!.scheduledDate),
        '2026-09-25',
      );
      expect(eventPlanDate(plans.editedDate!), '2026-09-26');
      expect(plans.editedTemplate!.posterImage, 'raw-asset-id');
      expect(plans.editedTemplate!.musicianProfileId, 'musician-1');
      expect(tester.takeException(), isNull);
    },
  );

  setUpAll(() async {
    final file = File('C:/Windows/Fonts/segoeui.ttf');
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}

class _Plans extends Fake implements EventPlanRepository {
  EventPlan plan = EventPlanRepositoryImpl.decodePlan(planJson());
  List<EventPlan>? ownerItems;
  final List<String> ownerReads = [];
  int ownerListCalls = 0;
  final List<int> ownerRequestedPages = [];
  Result<EventPlanPage<EventPlan>> Function(int page)? ownerPageResult;
  final List<EventPlanDefinition> previews = [];
  final List<(String?, int?)> previewContexts = [];
  List<DateTime> previewDates = [DateTime(2026, 9, 21), DateTime(2026, 9, 25)];
  List<EventPlanPreservedDate> preservedDates = [];
  int? previewFailureAfter;
  EventPlan? updatedPlan;
  EventPlanDefinition? updatedDefinition;
  int writes = 0;
  String? decision;
  bool? publication;
  Future<Result<EventPlan>>? performerRead, stopWrite;
  bool? stopCancelFuture;
  List<EventPlanOccurrence> rows = [];
  EventPlanOccurrence? editedOccurrence;
  DateTime? editedDate;
  EventPlanTemplate? editedTemplate;
  @override
  Future<Result<EventPlanPreview>> preview(
    EventPlanDefinition definition, {
    String? planId,
    int? expectedVersion,
  }) async {
    previews.add(definition);
    previewContexts.add((planId, expectedVersion));
    if (previewFailureAfter != null && previews.length > previewFailureAfter!) {
      return const Result.failure(
        AppError(code: '409', message: 'Program değişti. Yeniden aç.'),
      );
    }
    return Result.success(
      EventPlanPreview(
        dates: previewDates
            .where(
              (d) => !definition.excludedDates.any(
                (x) => eventPlanDate(x) == eventPlanDate(d),
              ),
            )
            .toList(),
        throughDate: DateTime(2026, 10, 18),
        hasMore: true,
        serverNow: DateTime.utc(2026, 9, 21, 10),
        preservedDates: preservedDates,
      ),
    );
  }

  @override
  Future<Result<EventPlan>> update(
    EventPlan plan,
    EventPlanDefinition definition,
  ) async {
    updatedPlan = plan;
    updatedDefinition = definition;
    writes++;
    return Result.success(plan);
  }

  @override
  Future<Result<EventPlanPage<EventPlan>>> listOwner(
    String venueId, {
    int page = 0,
  }) async {
    ownerListCalls++;
    ownerRequestedPages.add(page);
    if (ownerPageResult != null) return ownerPageResult!(page);
    return Result.success(
      EventPlanPage(items: ownerItems ?? [plan], page: page, hasNext: false),
    );
  }

  @override
  Future<Result<EventPlan>> getOwner(String id) async {
    ownerReads.add(id);
    return Result.success(
      (ownerItems ?? [plan]).firstWhere((item) => item.id == id),
    );
  }

  @override
  Future<Result<EventPlan>> getPerformer(String id) async =>
      performerRead ?? Result.success(plan);
  @override
  Future<Result<EventPlanPage<EventPlanOccurrence>>> occurrences(
    String id, {
    int page = 0,
  }) async =>
      Result.success(EventPlanPage(items: rows, page: page, hasNext: false));
  @override
  Future<Result<EventPlanPage<EventPlan>>> listPerformer(
    EventPerformerTargetType type,
    String id, {
    int page = 0,
  }) async =>
      Result.success(EventPlanPage(items: [plan], page: page, hasNext: false));
  @override
  Future<Result<EventPlan>> decide(
    EventPlan plan,
    String decision, {
    bool? showOnProfile,
  }) async {
    writes++;
    this.decision = decision;
    publication = showOnProfile;
    return Result.success(plan);
  }

  @override
  Future<Result<EventPlan>> stop(
    EventPlan plan, {
    required bool cancelFuture,
  }) async {
    stopCancelFuture = cancelFuture;
    return stopWrite ?? Result.success(plan);
  }

  @override
  Future<Result<EventPlan>> editOccurrence(
    EventPlan plan,
    EventPlanOccurrence occurrence, {
    required DateTime eventDate,
    required EventPlanTemplate template,
  }) async {
    editedOccurrence = occurrence;
    editedDate = eventDate;
    editedTemplate = template;
    return Result.success(plan);
  }
}

class _Sessions extends ChangeNotifier implements AuthSessionManager {
  AuthSession value = AuthSession.authenticated(
    token: 'token',
    userId: 'owner',
    username: 'Owner',
    accountStatus: 'ACTIVE',
    roles: ['ROLE_MUSICIAN'],
    permissions: [],
    expiresAt: DateTime(2100),
    isAdmin: false,
  );
  @override
  AuthSession get session => value;
  void signOut() {
    value = const AuthSession.guest();
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Events extends Fake implements VenueEventRepository {
  @override
  Future<Result<VenueEventManagementSnapshot>> loadManagement(
    String id,
  ) async => Result.success(
    VenueEventManagementSnapshot(
      upcomingEvents: const [],
      pastCount: 0,
      historyAsOf: DateTime.now(),
    ),
  );

  @override
  Future<Result<VenueEventHistoryPage>> loadHistory(
    String id, {
    required DateTime asOf,
    String? cursor,
  }) async => const Result.success(
    VenueEventHistoryPage(items: [], nextCursor: null, hasNext: false),
  );

  @override
  Future<Result<List<VenueOwnerEventItem>>> listByVenue(String id) async =>
      const Result.success([]);
}

class _Search extends Fake implements ProfileSearchRepository {
  @override
  Future<Result<List<ProfileSearchResult>>> searchProfiles(
    String query, {
    Set<ProfileSearchResultType>? types,
  }) async => const Result.success([]);
}

const _owner = VenueOwnerProfile(
  venueProfileId: 'venue-profile',
  venueId: 'venue-1',
  ownerUserId: 'owner',
  venueName: 'Ankara Sahne',
  bio: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  websiteUrl: null,
  address: null,
  phone: null,
  website: null,
  description: null,
  musicStartTime: null,
  cityId: null,
  cityName: 'Ankara',
  districtId: null,
  districtName: 'Çankaya',
  neighborhoodId: null,
  neighborhoodName: null,
  status: 'APPROVED',
  activeMusicians: [],
  activeBands: [],
  weeklyEvents: [],
);
