import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/media_asset.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_count_row.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_public_video_tab.dart';

void main() {
  testWidgets(
    'public video shows unknown counts while loading and real zero after success',
    (tester) async {
      final repository = _Repository();
      final cubit = InteractionStatsCubit(repository);
      addTearDown(cubit.close);
      await _mount(tester, cubit);
      await tester.pump();
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0'), findsNothing);
      expect(find.text('210'), findsNothing);
      expect(find.text('44'), findsNothing);
      repository.count.complete(const Result.success(0));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    },
  );

  testWidgets(
    'failed public video stats retain unknown markers and display recovered server counts',
    (tester) async {
      final repository = _Repository();
      final cubit = InteractionStatsCubit(repository);
      addTearDown(cubit.close);
      await _mount(tester, cubit);
      repository.count.complete(
        const Result.failure(AppError(code: 'network', message: 'Offline')),
      );
      await tester.pumpAndSettle();
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0'), findsNothing);
      repository.count = Completer<Result<int>>();
      final retry = cubit.load(
        targetType: 'MEDIA',
        targetId: 'video',
        force: true,
      );
      repository.count.complete(const Result.success(19));
      await retry;
      await tester.pumpAndSettle();
      expect(find.text('19'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    },
  );

  testWidgets(
    'shared media count row distinguishes unknown values from actual zero',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileCountRow(likeCount: null, commentCount: 0),
          ),
        ),
      );
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('null'), findsNothing);
    },
  );
}

Future<void> _mount(WidgetTester tester, InteractionStatsCubit cubit) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: ProfilePublicVideoTab(
              items: const [
                MediaAsset(
                  id: 'video',
                  kind: 'VIDEO',
                  sourceUrl: null,
                  playbackUrl: null,
                  thumbnailUrl: null,
                  title: 'Live',
                  durationSeconds: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );

class _Repository extends Fake implements EngagementRepository {
  Completer<Result<int>> count = Completer<Result<int>>();
  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) => count.future;
  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) async => const Result.success(false);
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 3));
}
