import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_commands.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_page.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_actor.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_application.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_job.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_listing.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_discovery_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_async_state.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_jobs_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_listing_detail_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_my_applications_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_discovery_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_my_applications_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/entities/instrument.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/instrument_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  late _DiscoveryRepository repository;
  late CollabDiscoveryCubit cubit;

  Widget app({String? initialListingId}) => MaterialApp(
    theme: AppTheme.navy,
    home: CollabDiscoveryScreen(
      initialListingId: initialListingId,
      cubit: cubit,
      locationRepository: const _LocationRepository(),
      instrumentRepository: const _InstrumentRepository(),
      showBottomNavigation: false,
    ),
  );

  setUp(() {
    repository = _DiscoveryRepository();
    cubit = CollabDiscoveryCubit(
      repository,
      searchDebounce: const Duration(milliseconds: 10),
    );
    if (serviceLocator.isRegistered<CollabListingDetailCubit>()) {
      serviceLocator.unregister<CollabListingDetailCubit>();
    }
    if (serviceLocator.isRegistered<CollabMyApplicationsCubit>()) {
      serviceLocator.unregister<CollabMyApplicationsCubit>();
    }
    if (serviceLocator.isRegistered<CollabJobsCubit>()) {
      serviceLocator.unregister<CollabJobsCubit>();
    }
    serviceLocator.registerFactory<CollabListingDetailCubit>(
      () => CollabListingDetailCubit(repository),
    );
    serviceLocator.registerFactory<CollabMyApplicationsCubit>(
      () => CollabMyApplicationsCubit(repository),
    );
    serviceLocator.registerFactory<CollabJobsCubit>(
      () => CollabJobsCubit(repository),
    );
  });

  tearDown(() async {
    await cubit.close();
    if (serviceLocator.isRegistered<CollabListingDetailCubit>()) {
      await serviceLocator.unregister<CollabListingDetailCubit>();
    }
    if (serviceLocator.isRegistered<CollabMyApplicationsCubit>()) {
      await serviceLocator.unregister<CollabMyApplicationsCubit>();
    }
    if (serviceLocator.isRegistered<CollabJobsCubit>()) {
      await serviceLocator.unregister<CollabJobsCubit>();
    }
  });

  testWidgets('loads the regular server feed by default', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(repository.queries, isNotEmpty);
    expect(repository.queries.first.cadence, CollabCadence.regular);
    expect(repository.queries.first.page, 0);
    expect(
      find.byKey(const ValueKey<String>('collab-brand-logo')),
      findsOneWidget,
    );
    expect(find.text('Düzenli fırsatlar'), findsOneWidget);
    expect(
      find.text('Kadıköy sahnesine bas gitarist arıyoruz'),
      findsOneWidget,
    );
    expect(
      tester
          .getCenter(
            find.byKey(const ValueKey<String>('collab-cadence-regular')),
          )
          .dx,
      lessThan(
        tester
            .getCenter(
              find.byKey(const ValueKey<String>('collab-cadence-extra')),
            )
            .dx,
      ),
    );
  });

  testWidgets('sends city, wanted, specialty and search filters to server', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('collab-quick-city')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İstanbul').last);
    await tester.pumpAndSettle();
    expect(repository.queries.last.cityId, 'city-34');

    await tester.tap(find.byKey(const ValueKey<String>('collab-quick-wanted')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Müzisyen arayan').last);
    await tester.pumpAndSettle();
    expect(repository.queries.last.wantedType, CollabProfileKind.musician);
    expect(
      find.byKey(const ValueKey<String>('collab-quick-specialty')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('collab-quick-specialty')),
    );
    await tester.pumpAndSettle();
    final specialtySearch = find.byKey(
      const ValueKey('collab-multi-select-search'),
    );
    await tester.enterText(specialtySearch, 'vok');
    await tester.pumpAndSettle();
    expect(find.text('Vokal'), findsOneWidget);
    await tester.enterText(specialtySearch, 'bas');
    await tester.pumpAndSettle();
    expect(find.text('Vokal'), findsNothing);
    await tester.tap(find.text('Bas Gitar').last);
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.instrumentIds, {'instrument-bass'});

    await tester.enterText(find.byType(TextField).first, '  bas gitar  ');
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(repository.queries.last.search, 'bas gitar');
  });

  testWidgets('appends the next page and persists bookmark changes', (
    tester,
  ) async {
    repository.hasSecondPage = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await cubit.loadMore();
    await tester.pumpAndSettle();

    expect(repository.queries.last.page, 1);
    expect(find.text('Stüdyo projesi için vokalist arıyoruz'), findsOneWidget);

    await tester.tap(find.byTooltip('İlanı kaydet').first);
    await tester.pumpAndSettle();
    expect(repository.saveCalls, 1);
    expect(cubit.state.items.first.savedByMe, isTrue);
    expect(find.byTooltip('Kaydedilenlerden çıkar'), findsOneWidget);
  });

  testWidgets('management menu opens the jobs section directly', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Collab işlerim'));
    await tester.pumpAndSettle();
    expect(find.text('Başvurularım'), findsOneWidget);
    expect(find.text('İşlerim'), findsOneWidget);
    expect(find.text('İlanlarım'), findsOneWidget);
    expect(find.text('Kaydedilen ilanlar'), findsOneWidget);

    await tester.tap(find.text('İşlerim'));
    await tester.pumpAndSettle();

    expect(find.byType(CollabMyApplicationsScreen), findsOneWidget);
    expect(find.text('Aktif bir Collab işin bulunmuyor.'), findsOneWidget);
  });

  testWidgets('shows a retry state and recovers after a server error', (
    tester,
  ) async {
    repository.failDiscovery = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('collab-discovery-retry')),
      findsOneWidget,
    );
    expect(find.text('İlanlar şu anda yüklenemiyor.'), findsOneWidget);

    repository.failDiscovery = false;
    await tester.tap(find.byKey(const ValueKey('collab-discovery-retry')));
    await tester.pumpAndSettle();

    expect(
      find.text('Kadıköy sahnesine bas gitarist arıyoruz'),
      findsOneWidget,
    );
    expect(repository.queries.length, 2);
  });

  testWidgets('opens a notification detail without waiting for discovery', (
    tester,
  ) async {
    repository.hangDiscovery = true;

    await tester.pumpWidget(app(initialListingId: 'listing-deep-link'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(repository.detailIds, <String>['listing-deep-link']);
    expect(find.text('Bildirimden açılan ilan'), findsOneWidget);
    expect(cubit.state.status, CollabLoadStatus.loading);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

const _publisher = CollabActor(
  actorId: 'actor-venue',
  profileType: CollabProfileKind.venue,
  sourceProfileId: 'venue-1',
  contactUserId: 'user-venue',
  displayName: 'Kadıköy Sahne',
  rating: 4.8,
  reviewCount: 24,
  completedJobCount: 76,
);

CollabListing _listing({
  required String id,
  required String title,
  CollabInstrumentSummary instrument = const CollabInstrumentSummary(
    id: 'instrument-bass',
    name: 'Bas Gitar',
  ),
}) => CollabListing(
  id: id,
  version: 1,
  status: CollabListingStatus.open,
  cadence: CollabCadence.regular,
  wantedType: CollabProfileKind.musician,
  instrument: instrument,
  title: title,
  description:
      'Sahnemizde düzenli çalışacak, repertuvara hakim bir müzisyen arıyoruz.',
  city: const CollabCitySummary(id: 'city-34', name: 'İstanbul'),
  genres: const <String>['Rock', 'Funk'],
  feeStatus: CollabFeeStatus.unspecified,
  publishedAt: DateTime.utc(2026, 8, 11, 9),
  createdAt: DateTime.utc(2026, 8, 11, 8),
  publisher: _publisher,
  ownedByMe: false,
  appliedByMe: false,
  savedByMe: false,
);

class _DiscoveryRepository implements CollabRepository {
  final List<CollabDiscoveryQuery> queries = <CollabDiscoveryQuery>[];
  bool failDiscovery = false;
  bool hangDiscovery = false;
  bool hasSecondPage = false;
  int saveCalls = 0;
  int unsaveCalls = 0;
  final List<String> detailIds = <String>[];
  final Completer<Result<CollabPage<CollabListing>>> hangingDiscovery =
      Completer<Result<CollabPage<CollabListing>>>();

  @override
  Future<Result<CollabPage<CollabListing>>> discover(
    CollabDiscoveryQuery query,
  ) async {
    queries.add(query);
    if (hangDiscovery) return hangingDiscovery.future;
    if (failDiscovery) {
      return const Result<CollabPage<CollabListing>>.failure(
        AppError(
          code: 'collab_unavailable',
          message: 'İlanlar şu anda yüklenemiyor.',
        ),
      );
    }
    final items = query.page == 0
        ? <CollabListing>[
            _listing(
              id: 'listing-1',
              title: 'Kadıköy sahnesine bas gitarist arıyoruz',
            ),
          ]
        : <CollabListing>[
            _listing(
              id: 'listing-2',
              title: 'Stüdyo projesi için vokalist arıyoruz',
              instrument: const CollabInstrumentSummary(
                id: 'instrument-vocal',
                name: 'Vokal',
              ),
            ),
          ];
    final last = !hasSecondPage || query.page > 0;
    return Result<CollabPage<CollabListing>>.success(
      CollabPage<CollabListing>(
        items: items,
        page: query.page,
        size: query.size,
        totalElements: hasSecondPage ? 2 : 1,
        totalPages: hasSecondPage ? 2 : 1,
        first: query.page == 0,
        last: last,
      ),
    );
  }

  @override
  Future<Result<CollabListing>> getListing(String listingId) async {
    detailIds.add(listingId);
    return Result<CollabListing>.success(
      _listing(id: listingId, title: 'Bildirimden açılan ilan'),
    );
  }

  @override
  Future<Result<void>> saveListing(String listingId) async {
    saveCalls++;
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> unsaveListing(String listingId) async {
    unsaveCalls++;
    return const Result<void>.success(null);
  }

  @override
  Future<Result<CollabPage<CollabApplication>>> getMyApplications({
    CollabApplicationStatus? status,
    int page = 0,
    int size = 20,
  }) async => Result<CollabPage<CollabApplication>>.success(
    CollabPage<CollabApplication>(
      items: const <CollabApplication>[],
      page: page,
      size: size,
      totalElements: 0,
      totalPages: 0,
      first: true,
      last: true,
    ),
  );

  @override
  Future<Result<CollabPage<CollabJob>>> getMyJobs({
    CollabJobStatus? status,
    int page = 0,
    int size = 20,
  }) async => Result<CollabPage<CollabJob>>.success(
    CollabPage<CollabJob>(
      items: const <CollabJob>[],
      page: page,
      size: size,
      totalElements: 0,
      totalPages: 0,
      first: true,
      last: true,
    ),
  );

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
        Instrument(id: 'instrument-guitar', name: 'Gitar'),
        Instrument(id: 'instrument-drums', name: 'Bateri'),
        Instrument(id: 'instrument-piano', name: 'Piyano'),
        Instrument(id: 'instrument-violin', name: 'Keman'),
        Instrument(id: 'instrument-cello', name: 'Çello'),
        Instrument(id: 'instrument-sax', name: 'Saksafon'),
        Instrument(id: 'instrument-trumpet', name: 'Trompet'),
        Instrument(id: 'instrument-turntable', name: 'Turntable'),
        Instrument(id: 'instrument-midi', name: 'MIDI Klavye'),
        Instrument(id: 'instrument-sampler', name: 'Sampler'),
      ]);
}
