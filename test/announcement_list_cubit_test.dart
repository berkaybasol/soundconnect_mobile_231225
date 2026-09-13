import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/domain/entities/announcement.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/presentation/cubit/announcement_list_cubit.dart';
import 'support/announcement_fixtures.dart';
import 'support/event_audience_fakes.dart';

void main() {
  test(
    'cyclic continuation stops requests and a refresh resets cursor history',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      final repository = AnnouncementTestRepository();
      final cubit = AnnouncementListCubit(repository, sessions);
      addTearDown(() async {
        await cubit.close();
        sessions.dispose();
      });
      var count = 0;
      repository.onPage = (_) async {
        count++;
        return Result.success(
          AnnouncementPage(
            items: [repository.current],
            hasMore: true,
            nextCursor: count.isOdd ? 'A' : 'B',
          ),
        );
      };
      await cubit.refresh();
      await cubit.loadMore();
      await cubit.loadMore();
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.error, contains('ilerleyemedi'));
      await cubit.loadMore();
      expect(count, 3);
      await cubit.refresh();
      expect(cubit.state.hasMore, isTrue);
      expect(cubit.state.error, isNull);
      expect(count, 4);
    },
  );
  test(
    'refresh supersedes old pagination, dedupes IDs and retains hidden records',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      final repository = AnnouncementTestRepository();
      final cubit = AnnouncementListCubit(repository, sessions);
      addTearDown(() async {
        await cubit.close();
        sessions.dispose();
      });
      final first = Announcement.fromJson(announcementFixture(hidden: true));
      final second = Announcement.fromJson(
        announcementFixture(id: announcementFixtureSecondId),
      );
      repository.onPage = (_) async => Result.success(
        AnnouncementPage(items: [first], hasMore: true, nextCursor: 'page2'),
      );
      await cubit.refresh();
      expect(cubit.state.items.single.feedHidden, isTrue);
      final pending = Completer<Result<AnnouncementPage>>();
      repository.onPage = (_) => pending.future;
      final old = cubit.loadMore();
      final duplicate = cubit.loadMore();
      await duplicate;
      expect(repository.reads, hasLength(2));
      repository.onPage = (_) async =>
          Result.success(AnnouncementPage(items: [second], hasMore: false));
      await cubit.refresh();
      pending.complete(
        Result.success(AnnouncementPage(items: [first], hasMore: false)),
      );
      await old;
      expect(cubit.state.items.map((item) => item.id), [
        announcementFixtureSecondId,
      ]);
    },
  );
  test(
    'load-more failure keeps current records and retries same cursor',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      final repository = AnnouncementTestRepository();
      final cubit = AnnouncementListCubit(repository, sessions);
      addTearDown(() async {
        await cubit.close();
        sessions.dispose();
      });
      repository.onPage = (_) async => Result.success(
        AnnouncementPage(
          items: [repository.current],
          hasMore: true,
          nextCursor: 'next',
        ),
      );
      await cubit.refresh();
      repository.onPage = (_) async => const Result.failure(
        AppError(code: 'network', message: 'Tekrar dene'),
      );
      await cubit.loadMore();
      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.hasMore, isTrue);
      expect(cubit.state.error, 'Tekrar dene');
      repository.onPage = (_) async => Result.success(
        AnnouncementPage(
          items: [
            repository.current,
            Announcement.fromJson(
              announcementFixture(id: announcementFixtureSecondId),
            ),
          ],
          hasMore: false,
        ),
      );
      await cubit.loadMore();
      expect(repository.reads.last.cursor, 'next');
      expect(cubit.state.items, hasLength(2));
    },
  );
  test(
    'permission revocation clears state and rejects late A-B-A page',
    () async {
      final identity = announcementAdminSession();
      final sessions = AudienceTestSessions(identity);
      final repository = AnnouncementTestRepository();
      final cubit = AnnouncementListCubit(repository, sessions, admin: true);
      addTearDown(() async {
        await cubit.close();
        sessions.dispose();
      });
      final pending = Completer<Result<AnnouncementPage>>();
      repository.onPage = (_) => pending.future;
      final loading = cubit.refresh(filter: AnnouncementStatus.draft);
      sessions.replace(const AuthSession.guest());
      sessions.replace(identity);
      pending.complete(
        Result.success(
          AnnouncementPage(items: [repository.current], hasMore: false),
        ),
      );
      await loading;
      expect(cubit.state.accessRevoked, isTrue);
      expect(cubit.state.items, isEmpty);
      await cubit.refresh();
      expect(repository.reads, hasLength(1));
    },
  );
}
