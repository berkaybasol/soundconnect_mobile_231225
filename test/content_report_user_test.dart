import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/content_report/data/content_report_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/content_report/domain/content_report.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/models/comment_item_model.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_entry.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_profile_share.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_overthinking_share_card.dart';
import 'package:soundconnect_23_12_25codx/modules/user_block/data/user_block_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/user_block/presentation/user_block_action.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _receipt = {'id': 'report-id', 'reportedAt': '2026-11-25T10:30:00Z'};

Future<void> _open(WidgetTester tester, Finder menu, String label) async {
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _selectReason(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<ContentReportReason>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Taciz veya hakaret').last);
  await tester.pumpAndSettle();
}

void main() {
  late AudienceTestSessions sessions;
  setUp(() {
    sessions = AudienceTestSessions(audienceSession());
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
  });
  tearDown(() => serviceLocator.reset());

  RecordingApiClient bind(ApiResponseHandler handler) {
    final api = RecordingApiClient(handler);
    serviceLocator.registerSingleton<ContentReportRepository>(
      ContentReportRepository(api, sessions),
    );
    return api;
  }

  testWidgets(
    'four public profiles send the account id and explicit type from their menu',
    (tester) async {
      final api = bind((_) => _receipt);
      serviceLocator.registerSingleton<UserBlockRepository>(
        UserBlockRepository(api, sessions),
        dispose: (repository) => repository.dispose(),
      );
      for (final kind in [
        ContentReportKind.listenerProfile,
        ContentReportKind.musicianProfile,
        ContentReportKind.venueProfile,
        ContentReportKind.studioProfile,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  UserBlockProfileMenu(
                    userId: 'profile-owner',
                    name: '@sanat',
                    reportKind: kind,
                    reportProfileId: kind == ContentReportKind.venueProfile
                        ? 'venue-id'
                        : null,
                  ),
                  UserBlockProfileMenu(
                    userId: 'listener',
                    name: '@kendim',
                    reportKind: kind,
                  ),
                ],
              ),
            ),
          ),
        );
        expect(find.byTooltip('Profil seçenekleri'), findsOneWidget);
        await _open(
          tester,
          find.byTooltip('Profil seçenekleri'),
          'Profili bildir',
        );
        await tester.tap(find.text('Bildirimi gönder'));
        await tester.pump();
        expect(find.text('Bir bildirim nedeni seç.'), findsOneWidget);
        await _selectReason(tester);
        await tester.tap(find.text('Bildirimi gönder'));
        await tester.pumpAndSettle();
        expect(find.text('Bildirimin alındı'), findsOneWidget);
        final sent = api.lastRequest;
        expect(sent.method, RecordedHttpMethod.post);
        expect(sent.path, '/api/v1/content-reports');
        expect(sent.requestContext?.expectedCredentialRevision, 0);
        expect(sent.requestContext?.expectedSessionKey, 'listener');
        expect(sent.requestContext?.expectedToken, 'token');
        expect(sent.body, {
          'kind': kind.wire,
          'targetId': 'profile-owner',
          'reason': 'HARASSMENT',
          if (kind == ContentReportKind.venueProfile) 'profileId': 'venue-id',
          'requestId': matches(RegExp(r'^[a-f0-9-]{36}$')),
        });
        await tester.tap(find.byTooltip('Kapat'));
        await tester.pumpAndSettle();
      }
      expect(api.requests, hasLength(4));
    },
  );

  testWidgets(
    'each visible comment and anonymous reply reports only its own id',
    (tester) async {
      final api = bind((_) => _receipt);
      Widget entry(
        String id, {
        String? parent,
        String author = 'other',
        bool deleted = false,
        bool anonymous = false,
      }) => CommentEntry(
        timeLabel: '',
        isReply: parent != null,
        canReport: true,
        comment: CommentItemModel.fromJson({
          'id': id,
          'text': id,
          'deleted': deleted,
          'parentCommentId': parent,
          'anonymousAuthor': anonymous,
          'user': {'id': author, 'username': author},
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                entry('root'),
                entry('reply', parent: 'root', anonymous: true),
                entry('deleted', deleted: true),
                entry('self', author: 'listener'),
              ],
            ),
          ),
        ),
      );
      expect(find.byTooltip('Yorum seçenekleri'), findsNWidgets(2));
      for (final isReply in [false, true]) {
        await _open(
          tester,
          find.byTooltip('Yorum seçenekleri').at(isReply ? 1 : 0),
          isReply ? 'Yanıtı bildir' : 'Yorumu bildir',
        );
        await _selectReason(tester);
        await tester.tap(find.text('Bildirimi gönder'));
        await tester.pumpAndSettle();
        expect(api.lastRequest.body, {
          'kind': 'COMMENT',
          'targetId': isReply ? 'reply' : 'root',
          'reason': 'HARASSMENT',
          'requestId': isA<String>(),
        });
        await tester.tap(find.byTooltip('Kapat'));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('a profile share retries the exact report after a lost receipt', (
    tester,
  ) async {
    final first = Completer<Object?>();
    var calls = 0;
    final api = bind((_) => ++calls == 1 ? first.future : _receipt);
    final post = OverthinkingPostModel.fromJson({
      'id': 'source-id',
      'title': 'Asıl yazı',
      'anonymous': true,
    });
    final share = OverthinkingProfileShare(
      shareId: 'share-id',
      note: 'Paylaşım notu',
      publishedAt: DateTime(2026),
      post: post,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenerOverthinkingShareCard(
              share: share,
              username: 'deniz',
              onOpen: () {},
            ),
          ),
        ),
      ),
    );
    await _open(
      tester,
      find.byTooltip('Paylaşım seçenekleri'),
      'Paylaşımı bildir',
    );
    await _selectReason(tester);
    await tester.enterText(find.byType(TextField), '  Bu notu bildiriyorum  ');
    await tester.tap(find.text('Bildirimi gönder'));
    await tester.pump();
    expect(api.requests, hasLength(1));
    first.completeError(const FormatException());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Bildirimin alındı'), findsOneWidget);
    expect(api.requests, hasLength(2));
    expect(api.requests.first.body, api.requests.last.body);
    expect(api.lastRequest.body, {
      'kind': 'OVERTHINKING_PROFILE_SHARE',
      'targetId': 'share-id',
      'description': 'Bu notu bildiriyorum',
      'reason': 'HARASSMENT',
      'requestId': isA<String>(),
    });
  });

  testWidgets(
    'replacing the session hides the pending form and discards the late receipt',
    (tester) async {
      final pending = Completer<Object?>();
      final api = bind((_) => pending.future);
      final comment = CommentItemModel.fromJson({
        'id': 'row',
        'text': 'Yorum metni',
        'anonymousAuthor': true,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentEntry(
              comment: comment,
              timeLabel: '',
              canReport: true,
            ),
          ),
        ),
      );
      await _open(tester, find.byTooltip('Yorum seçenekleri'), 'Yorumu bildir');
      await _selectReason(tester);
      await tester.tap(find.text('Bildirimi gönder'));
      await tester.pump();
      sessions.replace(audienceSession(token: 'new'));
      await tester.pump();
      expect(find.text('Oturum değişti'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      pending.complete(_receipt);
      await tester.pumpAndSettle();
      expect(find.text('Bildirimin alındı'), findsNothing);
      expect(api.requests, hasLength(1));
    },
  );
}
