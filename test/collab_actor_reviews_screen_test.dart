import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_page.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_review.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_actor_reviews_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_actor_reviews_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/collab_test_support.dart';

void main() {
  testWidgets('shows paged Collab ratings and comments', (tester) async {
    final repository = _ReviewsRepository(<CollabReview>[
      CollabReview(
        id: 'review-1',
        jobId: 'job-1',
        reviewer: musicianActor,
        target: venueActor,
        rating: 5,
        comment: 'İletişimi güçlü, çok iyi bir sahneydi.',
        createdAt: DateTime.utc(2026, 8, 11, 12),
      ),
    ]);
    final cubit = CollabActorReviewsCubit(repository);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: CollabActorReviewsScreen(
          actor: venueActor,
          cubit: cubit,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Collab Değerlendirmeleri'), findsOneWidget);
    expect(find.text('İletişimi güçlü, çok iyi bir sahneydi.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '5 üzerinden 5 yıldız',
        description: 'five-star accessibility semantics',
      ),
      findsOneWidget,
    );
    expect(repository.requestedPages, <int>[0]);

    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });

  testWidgets('shows an explicit empty-review state', (tester) async {
    final repository = _ReviewsRepository(const <CollabReview>[]);
    final cubit = CollabActorReviewsCubit(repository);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: CollabActorReviewsScreen(
          actor: venueActor,
          cubit: cubit,
          showBottomNavigation: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Henüz Collab değerlendirmesi yok.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });

  testWidgets(
    'deep-link pagination stops after failure and manual retry reveals off-screen review',
    (tester) async {
      final reviews = List<CollabReview>.generate(
        21,
        (index) => CollabReview(
          id: 'review-$index',
          jobId: 'job-$index',
          reviewer: musicianActor,
          target: venueActor,
          rating: 5,
          comment: index == 20 ? 'Hedef değerlendirme yorumu' : 'Yorum $index',
          createdAt: DateTime.utc(
            2026,
            8,
            11,
            12,
          ).add(Duration(minutes: index)),
        ),
      );
      final repository = _ReviewsRepository(reviews, failPageOneOnce: true);
      final cubit = CollabActorReviewsCubit(repository);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: CollabActorReviewsScreen(
            actor: venueActor,
            initialReviewId: 'review-20',
            cubit: cubit,
            showBottomNavigation: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.requestedPages, <int>[0, 1]);
      await tester.pump(const Duration(seconds: 5));
      expect(repository.requestedPages, <int>[0, 1]);

      final footer = find.byKey(
        const ValueKey<String>('collab-actor-reviews-load-more-footer'),
      );
      final verticalScrollable = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
            description: 'the vertical actor reviews scrollable',
          )
          .first;
      await tester.scrollUntilVisible(
        footer,
        300,
        scrollable: verticalScrollable,
      );
      await tester.ensureVisible(footer);
      await tester.pumpAndSettle();
      expect(footer, findsOneWidget);
      final retry = find.descendant(
        of: footer,
        matching: find.widgetWithText(TextButton, 'Devamını yeniden yükle'),
      );
      expect(retry, findsOneWidget);
      await tester.ensureVisible(retry);
      await tester.pump();
      expect(retry.hitTestable(), findsOneWidget);
      await tester.tap(retry.hitTestable());
      await tester.pumpAndSettle();

      expect(repository.requestedPages, <int>[0, 1, 1]);
      expect(find.text('Hedef değerlendirme yorumu'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await cubit.close();
    },
  );
}

class _ReviewsRepository implements CollabRepository {
  _ReviewsRepository(this.reviews, {this.failPageOneOnce = false});

  final List<CollabReview> reviews;
  final bool failPageOneOnce;
  final List<int> requestedPages = <int>[];
  bool _pageOneFailed = false;

  @override
  Future<Result<CollabPage<CollabReview>>> getActorReviews(
    String actorId, {
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    if (page == 1 && failPageOneOnce && !_pageOneFailed) {
      _pageOneFailed = true;
      return const Result.failure(
        AppError(code: 'temporary', message: 'Devam sayfası yüklenemedi.'),
      );
    }
    final totalPages = reviews.isEmpty
        ? 0
        : (reviews.length + size - 1) ~/ size;
    return Result<CollabPage<CollabReview>>.success(
      CollabPage<CollabReview>(
        items: reviews.skip(page * size).take(size).toList(growable: false),
        page: page,
        size: size,
        totalElements: reviews.length,
        totalPages: totalPages,
        first: page == 0,
        last: page + 1 >= totalPages,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
