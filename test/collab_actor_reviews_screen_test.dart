import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

class _ReviewsRepository implements CollabRepository {
  _ReviewsRepository(this.reviews);

  final List<CollabReview> reviews;
  final List<int> requestedPages = <int>[];

  @override
  Future<Result<CollabPage<CollabReview>>> getActorReviews(
    String actorId, {
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    return Result<CollabPage<CollabReview>>.success(
      CollabPage<CollabReview>(
        items: reviews,
        page: page,
        size: size,
        totalElements: reviews.length,
        totalPages: reviews.isEmpty ? 0 : 1,
        first: true,
        last: true,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
