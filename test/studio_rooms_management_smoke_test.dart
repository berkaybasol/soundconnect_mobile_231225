import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/studio_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_page.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/entities/studio_room.dart';
import 'package:soundconnect_23_12_25codx/modules/studio/domain/studio_room_repository.dart';

void main() {
  setUp(() async => serviceLocator.reset());
  tearDown(() async => serviceLocator.reset());

  testWidgets('owner room management renders loading then empty state', (
    tester,
  ) async {
    final completer = Completer<Result<StudioPage<StudioRoom>>>();
    serviceLocator.registerSingleton<StudioRoomRepository>(
      _RoomRepositoryFake(() => completer.future),
    );
    await _openRooms(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(Result.success(_emptyPage));
    await tester.pumpAndSettle();

    expect(find.text('Henüz bir oda yok'), findsOneWidget);
    expect(find.text('İlk Odayı Oluştur'), findsOneWidget);
  });

  testWidgets('owner room management exposes retry after a load failure', (
    tester,
  ) async {
    var calls = 0;
    serviceLocator.registerSingleton<StudioRoomRepository>(
      _RoomRepositoryFake(() async {
        calls++;
        if (calls == 1) {
          return const Result.failure(
            AppError(code: 'network', message: 'Bağlantı kurulamadı.'),
          );
        }
        return Result.success(_emptyPage);
      }),
    );
    await _openRooms(tester);
    await tester.pumpAndSettle();

    expect(find.text('Bağlantı kurulamadı.'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);

    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Henüz bir oda yok'), findsOneWidget);
  });

  testWidgets('room create retry reuses one client request id', (tester) async {
    final requestIds = <String>[];
    var createAttempts = 0;
    serviceLocator.registerSingleton<StudioRoomRepository>(
      _RoomRepositoryFake(
        () async => Result.success(_emptyPage),
        createRoomCallback: (draft, clientRequestId) async {
          requestIds.add(clientRequestId);
          createAttempts++;
          if (createAttempts == 1) {
            return const Result.failure(
              AppError(code: 'network', message: 'Geçici bağlantı hatası.'),
            );
          }
          return Result.success(_createdRoom);
        },
      ),
    );
    await _openRooms(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yeni Oda Oluştur'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(0), 'prova odası');
    await tester.enterText(fields.at(2), '6');

    await tester.ensureVisible(find.text('Odayı Oluştur'));
    await tester.tap(find.text('Odayı Oluştur'));
    await tester.pumpAndSettle();
    expect(find.text('Geçici bağlantı hatası.'), findsOneWidget);

    await tester.ensureVisible(find.text('Odayı Oluştur'));
    await tester.tap(find.text('Odayı Oluştur'));
    await tester.pumpAndSettle();

    expect(requestIds, hasLength(2));
    expect(requestIds.first, requestIds.last);
    expect(find.text('Geçici bağlantı hatası.'), findsNothing);
  });

  testWidgets('room creation sends the selected approval policy', (
    tester,
  ) async {
    StudioRoomDraft? submittedDraft;
    serviceLocator.registerSingleton<StudioRoomRepository>(
      _RoomRepositoryFake(
        () async => Result.success(_emptyPage),
        createRoomCallback: (draft, _) async {
          submittedDraft = draft;
          return Result.success(_createdRoom);
        },
      ),
    );
    await _openRooms(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yeni Oda Oluştur'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'anında rezervasyon odası');
    await tester.enterText(fields.at(2), '4');

    final approvalSwitch = find.byKey(
      const Key('studio-room-approval-policy-switch'),
    );
    expect(approvalSwitch, findsOneWidget);
    expect(tester.widget<Switch>(approvalSwitch).value, isTrue);
    await tester.ensureVisible(approvalSwitch);
    await tester.tap(approvalSwitch);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Odayı Oluştur'));
    await tester.tap(find.text('Odayı Oluştur'));
    await tester.pumpAndSettle();

    expect(submittedDraft, isNotNull);
    expect(submittedDraft!.reservationApprovalRequired, isFalse);
  });
}

Future<void> _openRooms(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: StudioManagementPanelScreen(profile: _profile),
    ),
  );
  await tester.tap(find.text('Odalar'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

const _profile = StudioProfile(
  id: 'studio-1',
  userId: 'user-1',
  name: 'Test Stüdyo',
  description: null,
  profilePictureMediaId: null,
  profilePictureUrl: null,
  address: null,
  phone: null,
  website: null,
  facilities: [],
  instagramUrl: null,
  youtubeUrl: null,
  timeZone: 'Europe/Istanbul',
  version: 0,
  spotifyTrackIds: [],
  spotifyTracks: [],
  activeRoomCount: 0,
  backlineUnitCount: 0,
);

const _emptyPage = StudioPage<StudioRoom>(
  items: [],
  pageIndex: 0,
  pageSize: 10,
  totalItems: 0,
  totalPages: 0,
  isFirst: true,
  isLast: true,
);

final _createdRoom = StudioRoom(
  id: 'room-1',
  studioProfileId: 'studio-1',
  slotIndex: 0,
  name: 'Prova Odası',
  shortDescription: '',
  capacity: 6,
  hourlyPriceMinor: null,
  currency: null,
  reservationApprovalRequired: true,
  features: [],
  photos: [],
  todayLocalDate: DateTime(2026, 7, 24),
  todayReservationCount: 0,
  todayOccupiedHours: 0,
  todayAvailableHours: 14,
  todayAvailabilityStatus: StudioRoomAvailabilityStatus.available,
  version: 0,
);

class _RoomRepositoryFake implements StudioRoomRepository {
  _RoomRepositoryFake(this._listOwnerRooms, {this.createRoomCallback});

  final Future<Result<StudioPage<StudioRoom>>> Function() _listOwnerRooms;
  final Future<Result<StudioRoom>> Function(
    StudioRoomDraft draft,
    String clientRequestId,
  )?
  createRoomCallback;

  @override
  Future<Result<StudioPage<StudioRoom>>> listOwnerRooms({
    int page = 0,
    int size = 10,
  }) => _listOwnerRooms();

  @override
  Future<Result<StudioRoom>> createRoom(
    StudioRoomDraft draft, {
    required String clientRequestId,
  }) {
    final callback = createRoomCallback;
    if (callback == null) {
      throw StateError('Unexpected createRoom call');
    }
    return callback(draft, clientRequestId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
