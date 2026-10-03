import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_received_invitation.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_invite_decision_screen.dart';

import 'support/event_audience_fakes.dart';

void main() {
  late AudienceTestSessions sessions;
  late _BandRepository bands;
  late _ReadCubit reads;
  late GlobalKey<NavigatorState> navigator;

  setUp(() async {
    await serviceLocator.reset();
    sessions = AudienceTestSessions(
      audienceSession(user: 'recipient', role: 'ROLE_MUSICIAN'),
    );
    bands = _BandRepository();
    reads = _ReadCubit();
    navigator = GlobalKey<NavigatorState>();
    serviceLocator
      ..registerSingleton<AuthSessionManager>(sessions)
      ..registerSingleton<BandRepository>(bands);
  });

  tearDown(() async {
    await serviceLocator.reset();
    sessions.dispose();
  });

  Future<void> open(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [notificationTargetRouteObserver],
        home: const Scaffold(body: Text('Inbox')),
      ),
    );
    final ticket = NotificationTargetRead(
      notification: _notification,
      cubit: reads,
      sessions: sessions,
    );
    unawaited(
      navigator.currentState!.push(
        ticket.attach(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => const BandInviteDecisionScreen(
              args: BandInviteDecisionScreenArgs(
                bandId: 'band',
                bandName: 'Target Band',
                invitationId: 'original-invitation',
                expectedSessionKey: 'recipient',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'band invitation waits for both current invite and band content',
    (tester) async {
      await open(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(reads.ids, isEmpty);

      bands.invitation.complete(const Result.success(_invitation));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // The invitation's hero can render before its target band data is ready.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(reads.ids, isEmpty);

      bands.profile.complete(const Result.success(_band));
      await tester.pumpAndSettle();
      expect(find.text('Mevcut Üyeler'), findsOneWidget);
      expect(reads.ids, ['notification']);
      await tester.pump();
      expect(reads.ids, ['notification']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('band lookup failure leaves a valid invitation unread', (
    tester,
  ) async {
    bands.invitation.complete(const Result.success(_invitation));
    bands.profile.complete(
      const Result.failure(
        AppError(code: 'NETWORK', message: 'Band unavailable'),
      ),
    );
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('Band unavailable'), findsOneWidget);
    expect(reads.ids, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing current invitation stays unread despite loaded band', (
    tester,
  ) async {
    bands.profile.complete(const Result.success(_band));
    bands.invitation.complete(
      const Result.failure(
        AppError(code: '9206', message: 'Invitation no longer exists'),
      ),
    );
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('Bu davet artık geçerli değil.'), findsOneWidget);
    expect(find.text('Mevcut Üyeler'), findsNothing);
    expect(reads.ids, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacement invitation cannot consume the old inbox ticket', (
    tester,
  ) async {
    bands.profile.complete(const Result.success(_band));
    bands.invitation.complete(
      const Result.success(
        BandReceivedInvitation(
          bandId: 'band',
          bandName: 'Target Band',
          invitationId: 'new-invitation',
        ),
      ),
    );
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('Güncel daveti aç'), findsOneWidget);
    expect(reads.ids, isEmpty);

    await tester.tap(find.text('Güncel daveti aç'));
    await tester.pumpAndSettle();
    expect(find.text('Mevcut Üyeler'), findsOneWidget);
    expect(reads.ids, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

const _notification = AppNotification(
  id: 'notification',
  recipientId: 'recipient',
  type: 'BAND_INVITE_RECEIVED',
  title: 'Invitation',
  message: '',
  read: false,
  createdAt: null,
  payload: {'bandId': 'band', 'invitationId': 'original-invitation'},
);

const _invitation = BandReceivedInvitation(
  bandId: 'band',
  bandName: 'Target Band',
  invitationId: 'original-invitation',
);

const _band = BandProfile(
  id: 'band',
  name: 'Target Band',
  description: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundCloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  members: [],
);

class _BandRepository extends Fake implements BandRepository {
  // Initialize inside the widget test's fake-async zone, not outer setUp.
  late final invitation = Completer<Result<BandReceivedInvitation>>();
  late final profile = Completer<Result<BandProfile>>();

  @override
  Future<Result<BandReceivedInvitation>> getCurrentReceivedInvitation({
    required String bandId,
    required String expectedSessionKey,
  }) => invitation.future;

  @override
  Future<Result<BandProfile>> getPublicBandById(String bandId) =>
      profile.future;
}

class _ReadCubit extends Fake implements NotificationCubit {
  final ids = <String>[];

  @override
  bool get isClosed => false;

  @override
  Future<void> markAsRead(AppNotification notification) async {
    ids.add(notification.id);
  }
}
