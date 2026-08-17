import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_commands.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_actor.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_listing.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_listing_editor_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_create_listing_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/entities/instrument.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/instrument_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  late _EditorRepository repository;
  late CollabListingEditorCubit cubit;

  Widget screen({
    CollabListing? initialListing,
    LocationRepository locationRepository = const _LocationRepository(),
    InstrumentRepository instrumentRepository = const _InstrumentRepository(),
  }) => MaterialApp(
    theme: AppTheme.navy,
    home: CollabCreateListingScreen(
      cubit: cubit,
      locationRepository: locationRepository,
      instrumentRepository: instrumentRepository,
      initialListing: initialListing,
      showBottomNavigation: false,
    ),
  );

  Widget host({CollabListing? initialListing}) => MaterialApp(
    theme: AppTheme.navy,
    home: _CreateHost(cubit: cubit, initialListing: initialListing),
  );

  setUp(() {
    repository = _EditorRepository();
    cubit = CollabListingEditorCubit(
      repository,
      requestIdFactory: () => 'request-create-1',
    );
  });

  tearDown(() async => cubit.close());

  Future<void> goToInformation(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('collab-create-continue')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('create-step-information')),
      findsOneWidget,
    );
  }

  Future<void> fillRequiredRegularFields(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('collab-create-title')),
      'Kadıköy sahnesine bas gitarist arıyoruz',
    );
    await tester.enterText(
      find.byKey(const ValueKey('collab-create-description')),
      'Düzenli sahnelerimizde repertuvara hakim bir bas gitarist arıyoruz.',
    );

    await tester.tap(find.byKey(const ValueKey('collab-create-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İstanbul').last);
    await tester.pumpAndSettle();

    final specialty = find.byKey(const ValueKey('collab-create-specialty'));
    await tester.ensureVisible(specialty);
    await tester.pumpAndSettle();
    await tester.tap(specialty);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bas Gitar').last);
    await tester.pumpAndSettle();
  }

  Future<void> goToPreview(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('collab-create-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-step-preview')), findsOneWidget);
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('starts blank, regular and backed by owned actors/catalogs', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(cubit.state.input?.cadence, CollabCadence.regular);
    expect(cubit.state.input?.title, isEmpty);
    expect(cubit.state.selectedActor, _venueActor);
    expect(find.text('Düzenli'), findsOneWidget);
    expect(find.text('Ekstra'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Düzenli')).dy,
      lessThan(tester.getCenter(find.text('Ekstra')).dy),
    );

    await goToInformation(tester);
    expect(
      find.byKey(const ValueKey('collab-create-location')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('collab-create-specialty')),
      findsOneWidget,
    );
    expect(find.text('Sahne Tarihi'), findsNothing);
    expect(find.text('Saat'), findsNothing);
    expect(find.text('Ücret'), findsWidgets);
    expect(find.text('Türkü'), findsOneWidget);
    expect(find.text('Türk Sanat Müziği'), findsOneWidget);
    expect(find.text('Piyasa'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('collab-create-publisher-picker')),
      findsNothing,
    );
  });

  testWidgets('studio publisher does not show a redundant profile picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(
        initialListing: _listing(
          status: CollabListingStatus.draft,
          input: const CollabListingInput(
            publisherActorId: 'actor-studio',
            cadence: CollabCadence.regular,
            wantedType: CollabProfileKind.musician,
            instrumentId: 'instrument-bass',
            title: 'Stüdyo için bas gitarist aranıyor',
            description:
                'Düzenli kayıt projelerinde çalışacak bir bas gitarist arıyoruz.',
            cityId: 'city-34',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await goToInformation(tester);

    expect(cubit.state.selectedActor, _studioActor);
    expect(
      find.byKey(const ValueKey('collab-create-publisher-picker')),
      findsNothing,
    );
  });

  testWidgets('musician with a band can choose the publishing profile', (
    tester,
  ) async {
    await cubit.close();
    repository = _EditorRepository(
      actors: const <CollabActor>[_musicianActor, _bandActor],
    );
    cubit = CollabListingEditorCubit(
      repository,
      requestIdFactory: () => 'request-create-musician',
    );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await goToInformation(tester);

    final picker = find.byKey(const ValueKey('collab-create-publisher-picker'));
    expect(picker, findsOneWidget);
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(find.text('Ece Yılmaz'), findsWidgets);
    expect(find.text('Gece Hattı'), findsOneWidget);
  });

  testWidgets('empty specialty label and hint never overlap on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await goToInformation(tester);

    final specialty = find.byKey(const ValueKey('collab-create-specialty'));
    await tester.ensureVisible(specialty);
    await tester.pumpAndSettle();
    final label = find.text('Enstrüman / Branş');
    final hint = find.text('Seçmek için dokun');
    expect(label, findsOneWidget);
    expect(hint, findsOneWidget);
    expect(tester.getRect(label).overlaps(tester.getRect(hint)), isFalse);
  });

  testWidgets(
    'searches the complete specialty catalog without duplicate branch labels',
    (tester) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      await goToInformation(tester);

      final specialty = find.byKey(const ValueKey('collab-create-specialty'));
      await tester.ensureVisible(specialty);
      await tester.tap(specialty);
      await tester.pumpAndSettle();

      expect(find.text('Vokal'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('collab-specialty-search')),
        'vok',
      );
      await tester.pumpAndSettle();
      expect(find.text('Bas Gitar'), findsNothing);
      expect(find.text('Vokal'), findsOneWidget);

      await tester.tap(find.text('Vokal'));
      await tester.pumpAndSettle();
      expect(cubit.state.input?.branch, CollabBranch.vocal);
      expect(cubit.state.input?.instrumentId, isNull);
    },
  );

  testWidgets('extra exposes only the bounded stage date and time inputs', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ekstra'));
    await tester.pump();
    await goToInformation(tester);

    expect(cubit.state.input?.cadence, CollabCadence.extra);
    expect(find.text('Sahne Tarihi'), findsOneWidget);
    expect(find.text('Saat'), findsOneWidget);
    expect(find.text('Kontenjan'), findsNothing);
    expect(find.text('Performans Süresi'), findsNothing);
  });

  testWidgets('publishes once when the primary action is tapped twice', (
    tester,
  ) async {
    repository.pendingCreate = Completer<Result<CollabListing>>();
    await tester.pumpWidget(host());
    await tester.tap(find.text('Oluşturmayı Aç'));
    await tester.pumpAndSettle();
    await goToInformation(tester);
    await fillRequiredRegularFields(tester);
    await goToPreview(tester);

    final publish = find.byKey(const ValueKey('collab-create-publish'));
    await reveal(tester, publish);
    await tester.tap(publish);
    await tester.tap(publish);

    expect(repository.createDraftCalls, 1);
    repository.completePendingCreate();
    await tester.pumpAndSettle();

    expect(repository.createDraftCalls, 1);
    expect(repository.publishDraftCalls, 1);
    expect(repository.lastCreateRequestId, 'request-create-1');
    expect(find.text('published'), findsOneWidget);
  });

  testWidgets('invalid open edit never reports a false successful update', (
    tester,
  ) async {
    final listing = _listing(status: CollabListingStatus.open);
    repository.storedListing = listing;
    await tester.pumpWidget(host(initialListing: listing));
    await tester.tap(find.text('Oluşturmayı Aç'));
    await tester.pumpAndSettle();
    await goToInformation(tester);
    await goToPreview(tester);

    cubit.updateInput(cubit.state.input!.copyWith(title: ''));
    await tester.pump();
    final save = find.byKey(const ValueKey('collab-create-publish'));
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.updateListingCalls, 0);
    expect(cubit.state.validationErrors, isNotEmpty);
    expect(
      find.byKey(const ValueKey('collab-validation-summary')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('create-step-preview')), findsOneWidget);
    expect(find.text('published'), findsNothing);
  });

  testWidgets('invalid existing draft never reports a false draft save', (
    tester,
  ) async {
    final draft = _listing(status: CollabListingStatus.draft);
    repository.storedListing = draft;
    await tester.pumpWidget(host(initialListing: draft));
    await tester.tap(find.text('Oluşturmayı Aç'));
    await tester.pumpAndSettle();
    await goToInformation(tester);
    await goToPreview(tester);

    cubit.updateInput(cubit.state.input!.copyWith(description: 'kısa'));
    await tester.pump();
    final saveDraft = find.byKey(const ValueKey('collab-create-save-draft'));
    await reveal(tester, saveDraft);
    await tester.tap(saveDraft);
    await tester.pumpAndSettle();

    expect(repository.updateDraftCalls, 0);
    expect(cubit.state.validationErrors, isNotEmpty);
    expect(
      find.byKey(const ValueKey('collab-validation-summary')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('create-step-preview')), findsOneWidget);
    expect(find.text('draftSaved'), findsNothing);
  });

  testWidgets('open listing without applications keeps all terms editable', (
    tester,
  ) async {
    final listing = _listing(
      status: CollabListingStatus.open,
      applicationCount: 0,
    );
    repository.storedListing = listing;
    await tester.pumpWidget(screen(initialListing: listing));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ekstra'));
    await tester.pump();
    expect(cubit.state.input?.cadence, CollabCadence.extra);
    await goToInformation(tester);
    await tester.enterText(
      find.byKey(const ValueKey('collab-create-title')),
      'Güncellenmiş açık ilan başlığı',
    );
    expect(cubit.state.input?.title, 'Güncellenmiş açık ilan başlığı');
  });

  testWidgets(
    'version conflict keeps local form until server reload is chosen',
    (tester) async {
      final localDraft = _listing(status: CollabListingStatus.draft);
      final remoteDraft = _listing(
        status: CollabListingStatus.draft,
        input: const CollabListingInput(
          publisherActorId: 'actor-venue',
          cadence: CollabCadence.regular,
          wantedType: CollabProfileKind.musician,
          instrumentId: 'instrument-bass',
          title: 'Diğer cihazdaki güncel başlık',
          description:
              'Diğer cihazda kaydedilmiş ve sunucudan geri alınmış açıklama.',
          cityId: 'city-34',
          genres: <String>['Rock'],
        ),
        version: 2,
      );
      repository
        ..updateDraftError = const AppError(
          code: '9317',
          message: 'İlan başka bir cihazda değiştirildi.',
        )
        ..latestListing = remoteDraft;
      await tester.pumpWidget(screen(initialListing: localDraft));
      await tester.pumpAndSettle();
      cubit.updateInput(
        cubit.state.input!.copyWith(title: 'Bu cihazdaki yerel başlık'),
      );

      await cubit.saveDraft();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('collab-conflict-keep-local')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('collab-conflict-load-server')),
        findsOneWidget,
      );
      expect(cubit.state.input?.title, 'Bu cihazdaki yerel başlık');
      expect(cubit.state.conflictListing?.version, 2);

      await tester.tap(
        find.byKey(const ValueKey('collab-conflict-load-server')),
      );
      await tester.pumpAndSettle();

      expect(cubit.state.input?.title, 'Diğer cihazdaki güncel başlık');
      expect(cubit.state.listing?.version, 2);
      expect(cubit.state.hasUnresolvedConflict, isFalse);
    },
  );

  testWidgets('open listing with applications locks every job term', (
    tester,
  ) async {
    final listing = _listing(
      status: CollabListingStatus.open,
      applicationCount: 1,
    );
    repository.storedListing = listing;
    await tester.pumpWidget(screen(initialListing: listing));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ekstra'));
    await tester.pump();
    expect(cubit.state.input?.cadence, CollabCadence.regular);
    await goToInformation(tester);
    expect(
      find.byKey(const ValueKey('collab-open-fields-locked')),
      findsOneWidget,
    );
    final originalTitle = cubit.state.input!.title;
    final titleField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('collab-create-title')),
        matching: find.byType(EditableText),
      ),
    );
    expect(titleField.readOnly, isTrue);
    cubit.updateInput(
      cubit.state.input!.copyWith(title: 'Değişmemesi gereken başlık'),
    );
    expect(cubit.state.input?.title, originalTitle);
  });

  testWidgets('instrument failure keeps city and non-instrument form usable', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(instrumentRepository: const _FailingInstrumentRepository()),
    );
    await tester.pumpAndSettle();
    await goToInformation(tester);

    expect(
      find.byKey(const ValueKey('collab-instrument-catalog-warning')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('collab-create-location')),
      findsOneWidget,
    );
  });

  testWidgets('existing decimal fee is preserved and remains editable', (
    tester,
  ) async {
    final listing = _listing(
      status: CollabListingStatus.open,
      input: const CollabListingInput(
        publisherActorId: 'actor-venue',
        cadence: CollabCadence.regular,
        wantedType: CollabProfileKind.musician,
        instrumentId: 'instrument-bass',
        title: 'Kadıköy sahnesine bas gitarist arıyoruz',
        description:
            'Düzenli sahnelerimizde repertuvara hakim bir bas gitarist arıyoruz.',
        cityId: 'city-34',
        genres: <String>['Rock', 'Funk'],
        feeAmountMinor: 150075,
        currency: 'TRY',
      ),
    );
    repository.storedListing = listing;
    await tester.pumpWidget(screen(initialListing: listing));
    await tester.pumpAndSettle();
    await goToInformation(tester);

    final fee = find.byKey(const ValueKey('collab-create-fee'));
    await reveal(tester, fee);
    expect(tester.widget<TextFormField>(fee).controller!.text, '1500,75');
    await tester.enterText(fee, '1234,56');
    expect(cubit.state.input?.feeAmountMinor, 123456);
  });

  testWidgets('dirty editor requires confirmation before leaving', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Oluşturmayı Aç'));
    await tester.pumpAndSettle();
    await goToInformation(tester);
    await tester.enterText(
      find.byKey(const ValueKey('collab-create-title')),
      'Kaybolmaması gereken değişiklik',
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Değişiklikler silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Düzenlemeye Devam Et'));
    await tester.pumpAndSettle();
    expect(find.text('İlan Oluştur'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Değişiklikleri Sil'));
    await tester.pumpAndSettle();
    expect(find.text('Oluşturmayı Aç'), findsOneWidget);
  });
}

const _venueActor = CollabActor(
  actorId: 'actor-venue',
  profileType: CollabProfileKind.venue,
  sourceProfileId: 'venue-profile',
  contactUserId: 'venue-user',
  displayName: 'Kadıköy Sahne',
  rating: 4.8,
  reviewCount: 36,
  completedJobCount: 112,
);

const _studioActor = CollabActor(
  actorId: 'actor-studio',
  profileType: CollabProfileKind.studio,
  sourceProfileId: 'studio-profile',
  contactUserId: 'studio-user',
  displayName: 'Northline Studio',
  rating: 4.7,
  reviewCount: 18,
  completedJobCount: 45,
);

const _musicianActor = CollabActor(
  actorId: 'actor-musician',
  profileType: CollabProfileKind.musician,
  sourceProfileId: 'musician-profile',
  contactUserId: 'musician-user',
  displayName: 'Ece Yılmaz',
  rating: 4.9,
  reviewCount: 24,
  completedJobCount: 61,
);

const _bandActor = CollabActor(
  actorId: 'actor-band',
  profileType: CollabProfileKind.band,
  sourceProfileId: 'band-profile',
  contactUserId: 'musician-user',
  displayName: 'Gece Hattı',
  rating: 4.6,
  reviewCount: 15,
  completedJobCount: 38,
);

CollabListing _listing({
  required CollabListingStatus status,
  CollabListingInput? input,
  int version = 1,
  int applicationCount = 0,
}) {
  final value =
      input ??
      const CollabListingInput(
        publisherActorId: 'actor-venue',
        cadence: CollabCadence.regular,
        wantedType: CollabProfileKind.musician,
        instrumentId: 'instrument-bass',
        title: 'Kadıköy sahnesine bas gitarist arıyoruz',
        description:
            'Düzenli sahnelerimizde repertuvara hakim bir bas gitarist arıyoruz.',
        cityId: 'city-34',
        genres: <String>['Rock', 'Funk'],
      );
  final actor = value.publisherActorId == _studioActor.actorId
      ? _studioActor
      : _venueActor;
  return CollabListing(
    id: 'listing-editor-1',
    version: version,
    status: status,
    cadence: value.cadence,
    wantedType: value.wantedType,
    instrument: value.instrumentId == null
        ? null
        : CollabInstrumentSummary(
            id: value.instrumentId!,
            name: value.instrumentId == 'instrument-bass'
                ? 'Bas Gitar'
                : 'Vokal',
          ),
    branch: value.branch,
    customSpecialty: value.customSpecialty,
    title: value.title,
    description: value.description,
    city: const CollabCitySummary(id: 'city-34', name: 'İstanbul'),
    genres: value.genres,
    scheduledAt: value.scheduledAt,
    expiresAt: value.cadence == CollabCadence.extra ? value.scheduledAt : null,
    feeAmountMinor: value.feeAmountMinor,
    currency: value.currency,
    feeStatus: value.feeAmountMinor == null
        ? CollabFeeStatus.unspecified
        : CollabFeeStatus.specified,
    publishedAt: status == CollabListingStatus.open
        ? DateTime.utc(2026, 8, 11, 10)
        : null,
    createdAt: DateTime.utc(2026, 8, 11, 9),
    publisher: actor,
    ownedByMe: true,
    appliedByMe: false,
    savedByMe: false,
    applicationCount: applicationCount,
  );
}

class _EditorRepository implements CollabRepository {
  _EditorRepository({
    this.actors = const <CollabActor>[_venueActor, _studioActor],
  });

  final List<CollabActor> actors;
  Completer<Result<CollabListing>>? pendingCreate;
  CollabListing? storedListing;
  CollabListingInput? lastInput;
  String? lastCreateRequestId;
  int createDraftCalls = 0;
  int updateDraftCalls = 0;
  int publishDraftCalls = 0;
  int updateListingCalls = 0;
  int getListingCalls = 0;
  AppError? updateDraftError;
  CollabListing? latestListing;

  @override
  Future<Result<List<CollabActor>>> getMyActors() async =>
      Result<List<CollabActor>>.success(actors);

  @override
  Future<Result<CollabListing>> createDraft(
    CollabListingInput input, {
    required String clientRequestId,
  }) async {
    createDraftCalls++;
    lastInput = input;
    lastCreateRequestId = clientRequestId;
    final pending = pendingCreate;
    if (pending != null) return pending.future;
    final listing = _listing(status: CollabListingStatus.draft, input: input);
    storedListing = listing;
    return Result<CollabListing>.success(listing);
  }

  void completePendingCreate() {
    final pending = pendingCreate!;
    final listing = _listing(
      status: CollabListingStatus.draft,
      input: lastInput,
    );
    storedListing = listing;
    pendingCreate = null;
    pending.complete(Result<CollabListing>.success(listing));
  }

  @override
  Future<Result<CollabListing>> updateDraft(
    String listingId,
    CollabListingInput input, {
    required int expectedVersion,
  }) async {
    updateDraftCalls++;
    lastInput = input;
    final error = updateDraftError;
    if (error != null) return Result<CollabListing>.failure(error);
    final listing = _listing(
      status: CollabListingStatus.draft,
      input: input,
      version: expectedVersion + 1,
    );
    storedListing = listing;
    return Result<CollabListing>.success(listing);
  }

  @override
  Future<Result<CollabListing>> getListing(String listingId) async {
    getListingCalls++;
    final listing = latestListing;
    if (listing != null) return Result<CollabListing>.success(listing);
    return const Result<CollabListing>.failure(
      AppError(code: '9300', message: 'İlan bulunamadı.'),
    );
  }

  @override
  Future<Result<CollabListing>> publishDraft(
    String listingId, {
    required int expectedVersion,
  }) async {
    publishDraftCalls++;
    final listing = storedListing!.copyWith(
      status: CollabListingStatus.open,
      version: expectedVersion + 1,
    );
    storedListing = listing;
    return Result<CollabListing>.success(listing);
  }

  @override
  Future<Result<CollabListing>> updateListing(
    String listingId,
    CollabListingInput input, {
    required int expectedVersion,
  }) async {
    updateListingCalls++;
    lastInput = input;
    final listing = _listing(
      status: CollabListingStatus.open,
      input: input,
      version: expectedVersion + 1,
    );
    storedListing = listing;
    return Result<CollabListing>.success(listing);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocationRepository implements LocationRepository {
  const _LocationRepository();

  @override
  Future<Result<List<City>>> getCities() async =>
      const Result<List<City>>.success(<City>[
        City(id: 'city-34', name: 'İstanbul'),
        City(id: 'city-06', name: 'Ankara'),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InstrumentRepository implements InstrumentRepository {
  const _InstrumentRepository();

  @override
  Future<Result<List<Instrument>>> getAll() async =>
      const Result<List<Instrument>>.success(<Instrument>[
        Instrument(id: 'instrument-bass', name: 'Bas Gitar'),
        Instrument(id: 'instrument-vocal', name: 'Vokal'),
      ]);
}

class _FailingInstrumentRepository implements InstrumentRepository {
  const _FailingInstrumentRepository();

  @override
  Future<Result<List<Instrument>>> getAll() async =>
      const Result<List<Instrument>>.failure(
        AppError(
          code: 'INSTRUMENT_CATALOG_UNAVAILABLE',
          message: 'Enstrüman kataloğu alınamadı.',
        ),
      );
}

class _CreateHost extends StatefulWidget {
  const _CreateHost({required this.cubit, this.initialListing});

  final CollabListingEditorCubit cubit;
  final CollabListing? initialListing;

  @override
  State<_CreateHost> createState() => _CreateHostState();
}

class _CreateHostState extends State<_CreateHost> {
  CollabCreateListingResult? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: result == null
            ? ElevatedButton(
                onPressed: () async {
                  final next = await Navigator.of(context)
                      .push<CollabCreateListingResult>(
                        MaterialPageRoute<CollabCreateListingResult>(
                          builder: (_) => CollabCreateListingScreen(
                            cubit: widget.cubit,
                            locationRepository: const _LocationRepository(),
                            instrumentRepository: const _InstrumentRepository(),
                            initialListing: widget.initialListing,
                            showBottomNavigation: false,
                          ),
                        ),
                      );
                  if (mounted) setState(() => result = next);
                },
                child: const Text('Oluşturmayı Aç'),
              )
            : Text(result!.name),
      ),
    );
  }
}
