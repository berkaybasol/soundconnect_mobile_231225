import '../../core/auth/auth_session_manager.dart';
import '../../modules/collab/data/collab_repository_impl.dart';
import '../../modules/engagement/data/engagement_repository_impl.dart';
import '../../modules/engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../modules/follow/data/band_follow_repository_impl.dart';
import '../../modules/follow/data/follow_repository_impl.dart';
import '../../modules/musician_feed/presentation/cubit/musician_feed_cubit.dart';
import '../../modules/promotion/data/promotion_repository_impl.dart';
import '../data/preview_scenario_store.dart';
import 'preview_api_client.dart';
import 'preview_feed_repository.dart';

class PreviewServiceBundle {
  PreviewServiceBundle({required this.store, required this.sessions}) {
    api = PreviewApiClient(store, sessions);
    feed = PreviewFeedRepository(store);
    engagement = EngagementRepositoryImpl(api, sessions: sessions);
    announcementEngagement = EngagementRepositoryImpl(
      api,
      sessions: sessions,
      announcementSource: 'FEED',
    );
    follow = FollowRepositoryImpl(api);
    bandFollow = BandFollowRepositoryImpl(api);
    collab = CollabRepositoryImpl(api);
    promotions = PromotionRepositoryImpl(api, sessions: sessions);
  }
  final PreviewScenarioStore store;
  final AuthSessionManager sessions;
  late final PreviewApiClient api;
  late final PreviewFeedRepository feed;
  late final EngagementRepositoryImpl engagement;
  late final EngagementRepositoryImpl announcementEngagement;
  late final FollowRepositoryImpl follow;
  late final BandFollowRepositoryImpl bandFollow;
  late final CollabRepositoryImpl collab;
  late final PromotionRepositoryImpl promotions;

  MusicianFeedCubit createFeedCubit() => MusicianFeedCubit(
    feed,
    engagement,
    collabRepository: collab,
    followRepository: follow,
    bandFollowRepository: bandFollow,
    sessions: sessions,
    announcementEngagementRepository: announcementEngagement,
  );
  CommentThreadCubit createCommentsCubit() =>
      CommentThreadCubit(engagement, sessions: sessions);
  InteractionStatsCubit createStatsCubit() =>
      InteractionStatsCubit(engagement, sessions: sessions);
}
