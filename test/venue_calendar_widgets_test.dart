import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_item.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_owner_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_search_result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_search_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_event_management_widgets.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_weekly_calendar_editor_screen.dart';

void main() {
  testWidgets(
    'draft explains future visibility and clears notice for this week',
    (tester) async {
      final repository = _FakeVenueEventRepository();
      await _openVenueDraft(tester, repository);
      final now = DateTime.now();
      for (final days in [15, 2]) {
        final date = find.text('Tarih');
        await tester.ensureVisible(date);
        await tester.pumpAndSettle();
        await tester.tap(date);
        await tester.pumpAndSettle();
        final picker = tester.widget<CalendarDatePicker>(
          find.byType(CalendarDatePicker),
        );
        final selected = DateTime(now.year, now.month, now.day + days);
        expect(picker.lastDate.isBefore(selected), isFalse);
        picker.onDateChanged(selected);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Seç'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('venue-future-event-notice')),
          days > 6 ? findsOneWidget : findsNothing,
        );
        expect(find.byType(Dialog), findsNothing);
        expect(repository.createCalls, 0);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('owner events are partitioned into week future and history', (
    tester,
  ) async {
    await serviceLocator.reset();
    addTearDown(serviceLocator.reset);
    final now = DateTime.now();
    VenueOwnerEventItem item(String title, int days) => VenueOwnerEventItem(
      id: title,
      title: title,
      posterImage: null,
      performerName: 'Sanatçı',
      musicianProfileId: null,
      eventDate: DateTime(now.year, now.month, now.day + days),
      startTime: '20:00',
      endTime: '22:00',
      description: null,
    );
    serviceLocator.registerSingleton<VenueEventRepository>(
      _FakeVenueEventRepository()
        ..items = [
          item('future-event', 7),
          item('past-event', -1),
          item('week-event', 6),
        ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: VenueWeeklyCalendarEditorScreen(ownerProfile: _ownerProfile),
      ),
    );
    await tester.pumpAndSettle();
    final headers = tester
        .widgetList<VenueCalendarHistoryHeader>(
          find.byType(VenueCalendarHistoryHeader),
        )
        .toList();
    expect(headers.map((header) => header.title), [
      'Bu Haftaki Etkinlikler',
      'Gelecek Etkinlikler',
      'Geçmiş Etkinlikler',
    ]);
    expect(headers.map((header) => header.count), [1, 1, 1]);
    expect(
      tester
          .widgetList<VenueCalendarEventCard>(
            find.byType(VenueCalendarEventCard),
          )
          .map((card) => card.title),
      ['week-event', 'future-event'],
    );
    await tester.scrollUntilVisible(
      find.byType(VenueCalendarPastEventCard),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<VenueCalendarPastEventCard>(
            find.byType(VenueCalendarPastEventCard),
          )
          .title,
      'past-event',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'venue-only calendar keeps original creation and history layout',
    (tester) async {
      await serviceLocator.reset();
      addTearDown(serviceLocator.reset);
      serviceLocator.registerSingleton<VenueEventRepository>(
        _FakeVenueEventRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: VenueWeeklyCalendarEditorScreen(ownerProfile: _ownerProfile),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Haftalık Takvim'), findsOneWidget);
      expect(find.text('Etkinlik Ekle'), findsOneWidget);
      expect(find.text('Geçmiş Etkinlikler'), findsOneWidget);
      expect(find.text('Etkinliklerim'), findsNothing);
      expect(find.text('Etkinlik Davetleri'), findsNothing);
      expect(
        find.byKey(const Key('musician-calendar-visibility-switch')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile-style calendar widgets fit a compact phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const VenueCalendarProfileHeader(
                    imageUrl: null,
                    venueName: 'soundconnectankara',
                    locationLabel: 'Çankaya • Ankara',
                  ),
                  const SizedBox(height: 20),
                  const VenueCalendarCreateButton(onTap: null, saving: false),
                  const SizedBox(height: 20),
                  VenueCalendarEventCard(
                    posterImage: null,
                    title: 'Cuma Gecesi Akustik Set',
                    dateLabel: '05.09.2026',
                    timeLabel: '21:30 – 23:30',
                    performerName: 'Luna Echo',
                    onTap: () {},
                    saving: false,
                    onDelete: () {},
                  ),
                  const SizedBox(height: 26),
                  const VenueCalendarHistoryHeader(count: 8),
                  const SizedBox(height: 10),
                  VenueCalendarPastEventCard(
                    posterImage: null,
                    title: 'Yaz Sezonu Kapanış Gecesi',
                    dateLabel: '30.08.2026',
                    timeLabel: '22:00 – 00:30',
                    performerName: 'Arsel',
                    onTap: () {},
                    saving: false,
                    onDelete: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('soundconnectankara'), findsOneWidget);
    expect(find.text('Etkinlik Ekle'), findsOneWidget);
    expect(find.text('Geçmiş Etkinlikler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact event cards support 200 percent text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    VenueCalendarEventCard(
                      posterImage: null,
                      title: 'Cuma Gecesi Akustik Set',
                      dateLabel: '05.09.2026',
                      timeLabel: '21:30 – 23:30',
                      performerName: 'Luna Echo ve Arkadaşları',
                      onTap: () {},
                      saving: false,
                      onDelete: () {},
                    ),
                    const SizedBox(height: 12),
                    VenueCalendarPastEventCard(
                      posterImage: null,
                      title: 'Yaz Sezonu Kapanış Gecesi',
                      dateLabel: '30.08.2026',
                      timeLabel: '22:00 – 00:30',
                      performerName: 'Arsel ve Arkadaşları',
                      onTap: () {},
                      saving: false,
                      onDelete: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cuma Gecesi Akustik Set'), findsOneWidget);
    expect(find.text('Yaz Sezonu Kapanış Gecesi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event draft sheet stays usable on a compact scaled viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await serviceLocator.reset();
    addTearDown(serviceLocator.reset);
    final eventRepository = _FakeVenueEventRepository();
    serviceLocator
      ..registerSingleton<VenueEventRepository>(eventRepository)
      ..registerSingleton<ProfileSearchRepository>(
        _FakeProfileSearchRepository(),
      );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: VenueWeeklyCalendarEditorScreen(ownerProfile: _ownerProfile),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Etkinlik Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('soundconnectankara'), findsNWidgets(2));
    expect(find.text('Yeni etkinlik'), findsOneWidget);
    expect(find.text('Etkinlik bilgileri'), findsOneWidget);
    expect(find.text('Sanatçı'), findsOneWidget);
    expect(find.text('Program'), findsOneWidget);
    expect(find.text('Etkinliği Oluştur'), findsOneWidget);
    expect(find.byTooltip('Bitiş saatini kaldır'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byTooltip('Bitiş saatini kaldır'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bitiş saatini kaldır'));
    await tester.pump();
    expect(find.text('Eklenmedi'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Etkinliği Oluştur'));
    await tester.pump();
    expect(
      find.text('Başlık, tarih ve başlangıç saati zorunlu.'),
      findsOneWidget,
    );
    expect(
      tester
          .getCenter(find.text('Başlık, tarih ve başlangıç saati zorunlu.'))
          .dy,
      lessThan(760),
    );
    expect(eventRepository.createCalls, 0);
  });

  testWidgets(
    'uncertain legacy venue save requires list inspection and never resends',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await serviceLocator.reset();
      addTearDown(serviceLocator.reset);
      final repository = _FakeVenueEventRepository()
        ..saveResult = const Result.failure(
          AppError(code: 'network', message: 'Timed out'),
        );
      serviceLocator
        ..registerSingleton<VenueEventRepository>(repository)
        ..registerSingleton<ProfileSearchRepository>(
          _FakeProfileSearchRepository(),
        );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: VenueWeeklyCalendarEditorScreen(ownerProfile: _ownerProfile),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Etkinlik Ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Etkinlik başlığı'),
        'Akustik Set',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Etkinliği Oluştur'));
      await tester.pumpAndSettle();
      expect(repository.createCalls, 1);
      expect(find.text('Tekrar dene'), findsNothing);
      expect(find.text('Listeyi kontrol et'), findsOneWidget);
      await tester.tap(find.text('Listeyi kontrol et'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-leave-uncertain-event')));
      await tester.pumpAndSettle();
      expect(repository.createCalls, 1);
      expect(repository.listCalls, 2);
      expect(find.text('Yeni etkinlik'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('definitive venue failure preserves the editable draft', (
    tester,
  ) async {
    final repository = _FakeVenueEventRepository()
      ..saveResult = const Result.failure(
        AppError(code: '400', message: 'Başlığı kontrol et.'),
      );
    await _openVenueDraft(tester, repository);
    final field = find.widgetWithText(TextField, 'Etkinlik başlığı');
    await tester.enterText(field, 'İlk başlık');
    await _submitVenueDraft(tester);
    expect(find.text('Yeni etkinlik'), findsOneWidget);
    expect(find.text('Başlığı kontrol et.'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, 'İlk başlık');
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Düzeltilen başlık');
    repository.saveResult = const Result.success(null);
    await _submitVenueDraft(tester);
    expect(repository.createCalls, 2);
    expect(repository.lastDraft!.title, 'Düzeltilen başlık');
    expect(find.text('Yeni etkinlik'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('venue save blocks duplicate submission and draft dismissal', (
    tester,
  ) async {
    final repository = _FakeVenueEventRepository()
      ..saving = Completer<Result<void>>();
    await _openVenueDraft(tester, repository);
    await tester.enterText(
      find.widgetWithText(TextField, 'Etkinlik başlığı'),
      'Akustik Set',
    );
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Etkinliği Oluştur'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Kaydediliyor...'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == 'Kapat',
            ),
          )
          .onPressed,
      isNull,
    );
    final button = tester.widget<VenueCalendarCreateButton>(
      find.byType(VenueCalendarCreateButton),
    );
    expect(button.saving, isTrue);
    button.onTap?.call();
    await tester.pump();
    expect(repository.createCalls, 1);
    repository.saving!.complete(const Result.success(null));
    await tester.pumpAndSettle();
    expect(find.text('Yeni etkinlik'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event draft ignores a stale performer search response', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await serviceLocator.reset();
    addTearDown(serviceLocator.reset);
    final firstSearch = Completer<Result<List<ProfileSearchResult>>>();
    var searchCount = 0;
    serviceLocator
      ..registerSingleton<VenueEventRepository>(_FakeVenueEventRepository())
      ..registerSingleton<ProfileSearchRepository>(
        _FakeProfileSearchRepository(
          onSearch: (_) {
            searchCount++;
            if (searchCount == 1) return firstSearch.future;
            return Future.value(const Result.success([]));
          },
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: VenueWeeklyCalendarEditorScreen(ownerProfile: _ownerProfile),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Etkinlik Ekle'));
    await tester.pumpAndSettle();

    final performerField = find.widgetWithText(TextField, 'Sanatçı veya grup');
    await tester.ensureVisible(performerField);
    await tester.pumpAndSettle();
    await tester.enterText(performerField, 'Ar');
    await tester.pump(const Duration(milliseconds: 321));
    expect(searchCount, 1);

    await tester.enterText(performerField, 'Ars');
    firstSearch.complete(
      const Result.success([
        ProfileSearchResult(
          type: ProfileSearchResultType.musician,
          targetId: 'stale-id',
          userId: 'stale-user-id',
          title: 'Eski Sonuç',
          subtitle: 'eski',
          imageUrl: null,
        ),
      ]),
    );
    await tester.pump();
    expect(find.text('Eski Sonuç'), findsNothing);

    await tester.pump(const Duration(milliseconds: 321));
    await tester.pump();
    expect(searchCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event draft finds a band and submits only its band id', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
    await serviceLocator.reset();
    addTearDown(serviceLocator.reset);
    final eventRepository = _FakeVenueEventRepository();
    final searchRepository = _FakeProfileSearchRepository(
      onSearch: (_) async => const Result.success([
        ProfileSearchResult(
          type: ProfileSearchResultType.musician,
          targetId: 'musician-id',
          userId: 'musician-user-id',
          title: 'bugrasahin',
          subtitle: 'bugrasahin',
          imageUrl: null,
        ),
        ProfileSearchResult(
          type: ProfileSearchResultType.band,
          targetId: 'band-id',
          userId: null,
          title: 'Şahbaz',
          subtitle: 'Band',
          imageUrl: null,
        ),
        ProfileSearchResult(
          type: ProfileSearchResultType.venue,
          targetId: 'venue-result-id',
          userId: 'venue-owner-id',
          title: 'Sahne Mekan',
          subtitle: 'Ankara',
          imageUrl: null,
        ),
      ]),
    );
    serviceLocator
      ..registerSingleton<VenueEventRepository>(eventRepository)
      ..registerSingleton<ProfileSearchRepository>(searchRepository);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: VenueWeeklyCalendarEditorScreen(ownerProfile: _ownerProfile),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Etkinlik Ekle'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Etkinlik başlığı'),
      'Sahbaz Gecesi',
    );
    final performerField = find.widgetWithText(TextField, 'Sanatçı veya grup');
    await tester.ensureVisible(performerField);
    await tester.pumpAndSettle();
    await tester.enterText(performerField, 'sah');
    await tester.pump(const Duration(milliseconds: 321));
    await tester.pumpAndSettle();

    expect(find.text('Şahbaz'), findsOneWidget);
    expect(find.text('Grup'), findsOneWidget);
    expect(find.text('Sahne Mekan'), findsNothing);
    expect(searchRepository.lastTypes, const {
      ProfileSearchResultType.musician,
      ProfileSearchResultType.band,
    });
    expect(find.byKey(const Key('venue-event-submit')), findsNothing);
    expect(tester.getRect(find.text('Şahbaz')).bottom, lessThan(600));

    await tester.tap(find.text('Şahbaz'));
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('venue-event-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('venue-event-submit')));
    await tester.pumpAndSettle();

    expect(eventRepository.createCalls, 1);
    expect(eventRepository.lastDraft?.bandId, 'band-id');
    expect(eventRepository.lastDraft?.musicianProfileId, isNull);
    expect(eventRepository.lastDraft?.manualPerformerName, isNull);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openVenueDraft(
  WidgetTester tester,
  _FakeVenueEventRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await serviceLocator.reset();
  addTearDown(serviceLocator.reset);
  serviceLocator
    ..registerSingleton<VenueEventRepository>(repository)
    ..registerSingleton<ProfileSearchRepository>(
      _FakeProfileSearchRepository(),
    );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: VenueWeeklyCalendarEditorScreen(ownerProfile: _ownerProfile),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Etkinlik Ekle'));
  await tester.pumpAndSettle();
}

Future<void> _submitVenueDraft(WidgetTester tester) async {
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.text('Etkinliği Oluştur'));
  await tester.pumpAndSettle();
}

const _ownerProfile = VenueOwnerProfile(
  venueProfileId: 'venue-profile-id',
  venueId: 'venue-id',
  ownerUserId: 'owner-id',
  venueName: 'soundconnectankara',
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
  cityId: 'city-id',
  cityName: 'Ankara',
  districtId: 'district-id',
  districtName: 'Çankaya',
  neighborhoodId: null,
  neighborhoodName: null,
  status: 'APPROVED',
  activeMusicians: [],
  activeBands: [],
  weeklyEvents: [],
);

class _FakeVenueEventRepository implements VenueEventRepository {
  List<VenueOwnerEventItem> items = [];
  int createCalls = 0;
  int listCalls = 0;
  Result<void> saveResult = const Result.success(null);
  Completer<Result<void>>? saving;
  VenueEventDraft? lastDraft;

  @override
  Future<Result<List<VenueOwnerEventItem>>> listByVenue(String venueId) async {
    listCalls++;
    return Result.success(items);
  }

  @override
  Future<Result<List<VenueOwnerEventItem>>> listPublicByVenue(
    String venueId,
  ) async {
    return const Result.success([]);
  }

  @override
  Future<Result<void>> create({
    required String venueId,
    required VenueEventDraft draft,
  }) async {
    createCalls++;
    lastDraft = draft;
    return saving?.future ?? saveResult;
  }

  @override
  Future<Result<void>> delete(String eventId) async {
    return const Result.success(null);
  }

  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) {
    throw UnimplementedError();
  }
}

class _FakeProfileSearchRepository implements ProfileSearchRepository {
  _FakeProfileSearchRepository({this.onSearch});

  final Future<Result<List<ProfileSearchResult>>> Function(String query)?
  onSearch;
  Set<ProfileSearchResultType>? lastTypes;

  @override
  Future<Result<List<ProfileSearchResult>>> searchProfiles(
    String query, {
    Set<ProfileSearchResultType>? types,
  }) {
    lastTypes = types;
    return onSearch?.call(query) ?? Future.value(const Result.success([]));
  }
}
