import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Widget screen({CollabListing? initialListing}) => MaterialApp(
    theme: AppTheme.navy,
    home: CollabCreateListingScreen(
      cubit: cubit,
      locationRepository: const _LocationRepository(),
      instrumentRepository: const _InstrumentRepository(),
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
    expect(find.byKey(const ValueKey('create-step-preview')), findsOneWidget);
    expect(find.text('draftSaved'), findsNothing);
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

CollabListing _listing({
  required CollabListingStatus status,
  CollabListingInput? input,
  int version = 1,
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
  );
}

class _EditorRepository implements CollabRepository {
  final List<CollabActor> actors = const <CollabActor>[
    _venueActor,
    _studioActor,
  ];
  Completer<Result<CollabListing>>? pendingCreate;
  CollabListing? storedListing;
  CollabListingInput? lastInput;
  String? lastCreateRequestId;
  int createDraftCalls = 0;
  int updateDraftCalls = 0;
  int publishDraftCalls = 0;
  int updateListingCalls = 0;

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
    final listing = _listing(
      status: CollabListingStatus.draft,
      input: input,
      version: expectedVersion + 1,
    );
    storedListing = listing;
    return Result<CollabListing>.success(listing);
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
