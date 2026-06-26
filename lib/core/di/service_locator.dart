import 'package:get_it/get_it.dart';

import '../../modules/auth/data/auth_repository_impl.dart';
import '../../modules/auth/domain/auth_repository.dart';
import '../../modules/auth/domain/usecases/login_usecase.dart';
import '../../modules/auth/domain/usecases/register_usecase.dart';
import '../../modules/auth/domain/usecases/resend_code_usecase.dart';
import '../../modules/auth/domain/usecases/verify_code_usecase.dart';
import '../../modules/auth/presentation/cubit/auth_cubit.dart';
import '../../modules/dm/data/dm_repository_impl.dart';
import '../../modules/dm/data/dm_realtime_client.dart';
import '../../modules/dm/data/dm_user_profile_resolver_impl.dart';
import '../../modules/dm/domain/dm_repository.dart';
import '../../modules/dm/domain/dm_user_profile_resolver.dart';
import '../../modules/dm/presentation/cubit/dm_badge_cubit.dart';
import '../../modules/dm/presentation/cubit/dm_chat_cubit.dart';
import '../../modules/dm/presentation/cubit/dm_conversations_cubit.dart';
import '../../modules/event/data/event_discovery_repository_impl.dart';
import '../../modules/event/domain/event_discovery_repository.dart';
import '../../modules/engagement/data/engagement_repository_impl.dart';
import '../../modules/engagement/domain/engagement_repository.dart';
import '../../modules/engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../modules/artist_venue/data/artist_venue_connection_repository_impl.dart';
import '../../modules/artist_venue/domain/artist_venue_connection_repository.dart';
import '../../modules/artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import '../../modules/follow/data/follow_repository_impl.dart';
import '../../modules/follow/data/band_follow_repository_impl.dart';
import '../../modules/follow/domain/band_follow_repository.dart';
import '../../modules/follow/domain/follow_repository.dart';
import '../../modules/follow/presentation/cubit/follow_action_cubit.dart';
import '../../modules/follow/presentation/cubit/follow_count_cubit.dart';
import '../../modules/location/data/location_repository_impl.dart';
import '../../modules/location/domain/location_repository.dart';
import '../../modules/location/presentation/cubit/location_cubit.dart';
import '../../modules/instrument/data/instrument_repository_impl.dart';
import '../../modules/instrument/domain/instrument_repository.dart';
import '../../modules/instrument/presentation/cubit/instrument_cubit.dart';
import '../../modules/notification/data/notification_realtime_client.dart';
import '../../modules/notification/data/notification_repository_impl.dart';
import '../../modules/notification/domain/notification_repository.dart';
import '../../modules/notification/presentation/cubit/notification_cubit.dart';
import '../../modules/overthinking/data/overthinking_repository_impl.dart';
import '../../modules/overthinking/domain/overthinking_repository.dart';
import '../../modules/overthinking/presentation/cubit/overthinking_feed_cubit.dart';
import '../../modules/profile/data/musician_profile_repository_impl.dart';
import '../../modules/profile/data/listener_profile_repository_impl.dart';
import '../../modules/profile/data/band_repository_impl.dart';
import '../../modules/profile/data/musician_search_repository_impl.dart';
import '../../modules/profile/data/media_gallery_repository_impl.dart';
import '../../modules/profile/data/profile_media_management_repository_impl.dart';
import '../../modules/profile/data/profile_media_repository_impl.dart';
import '../../modules/profile/data/profile_media_upload_repository_impl.dart';
import '../../modules/profile/data/profile_search_repository_impl.dart';
import '../../modules/profile/data/track_management_repository_impl.dart';
import '../../modules/profile/data/venue_directory_repository_impl.dart';
import '../../modules/profile/data/venue_event_repository_impl.dart';
import '../../modules/profile/data/venue_profile_repository_impl.dart';
import '../../modules/profile/domain/musician_profile_repository.dart';
import '../../modules/profile/domain/listener_profile_repository.dart';
import '../../modules/profile/domain/band_repository.dart';
import '../../modules/profile/domain/musician_search_repository.dart';
import '../../modules/profile/domain/media_gallery_repository.dart';
import '../../modules/profile/domain/profile_media_management_repository.dart';
import '../../modules/profile/domain/profile_media_repository.dart';
import '../../modules/profile/domain/profile_media_upload_repository.dart';
import '../../modules/profile/domain/profile_search_repository.dart';
import '../../modules/profile/domain/track_management_repository.dart';
import '../../modules/profile/domain/venue_directory_repository.dart';
import '../../modules/profile/domain/venue_event_repository.dart';
import '../../modules/profile/domain/venue_profile_repository.dart';
import '../../modules/profile/presentation/cubit/musician_profile_cubit.dart';
import '../../modules/profile/presentation/cubit/listener_profile_cubit.dart';
import '../../modules/profile/presentation/cubit/profile_media_cubit.dart';
import '../../modules/profile/presentation/cubit/venue_profile_cubit.dart';
import '../../modules/promotion/data/promotion_repository_impl.dart';
import '../../modules/promotion/domain/promotion_repository.dart';
import '../../modules/spotify/data/spotify_repository_impl.dart';
import '../../modules/spotify/domain/spotify_repository.dart';
import '../../modules/spotify/presentation/cubit/spotify_preview_cubit.dart';
import '../../modules/setlist/data/setlist_repository_impl.dart';
import '../../modules/setlist/domain/setlist_repository.dart';
import '../../modules/tablegroup/data/table_group_repository_impl.dart';
import '../../modules/tablegroup/data/table_group_chat_realtime_client.dart';
import '../../modules/tablegroup/domain/table_group_repository.dart';
import '../../modules/tablegroup/presentation/cubit/table_group_create_cubit.dart';
import '../../modules/tablegroup/presentation/cubit/table_group_list_cubit.dart';
import '../auth/token_store.dart';
import '../network/api_client.dart';
import '../network/dio_api_client.dart';

final GetIt serviceLocator = GetIt.instance;

void setupDependencies() {
  serviceLocator
    ..registerLazySingleton<TokenStore>(() => const SecureTokenStore())
    ..registerLazySingleton<ApiClient>(
      () => DioApiClient(tokenStore: serviceLocator<TokenStore>()),
    )
    ..registerLazySingleton<LocationRepository>(
      () => LocationRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<EventDiscoveryRepository>(
      () => EventDiscoveryRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerFactory<LocationCubit>(
      () => LocationCubit(serviceLocator<LocationRepository>()),
    )
    ..registerLazySingleton<ArtistVenueConnectionRepository>(
      () => ArtistVenueConnectionRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerFactory<ArtistVenueConnectionsCubit>(
      () => ArtistVenueConnectionsCubit(
        serviceLocator<ArtistVenueConnectionRepository>(),
      ),
    )
    ..registerLazySingleton<InstrumentRepository>(
      () => InstrumentRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerFactory<InstrumentCubit>(
      () => InstrumentCubit(serviceLocator<InstrumentRepository>()),
    )
    ..registerLazySingleton<NotificationRepository>(
      () => NotificationRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<NotificationRealtimeClient>(
      () => NotificationRealtimeClient(),
    )
    ..registerLazySingleton<NotificationCubit>(
      () => NotificationCubit(
        serviceLocator<NotificationRepository>(),
        serviceLocator<TokenStore>(),
        realtimeClient: serviceLocator<NotificationRealtimeClient>(),
      ),
    )
    ..registerLazySingleton<MusicianProfileRepository>(
      () => MusicianProfileRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<ListenerProfileRepository>(
      () => ListenerProfileRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<BandRepository>(
      () => BandRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerFactory<MusicianProfileCubit>(
      () => MusicianProfileCubit(serviceLocator<MusicianProfileRepository>()),
    )
    ..registerFactory<ListenerProfileCubit>(
      () => ListenerProfileCubit(serviceLocator<ListenerProfileRepository>()),
    )
    ..registerLazySingleton<ProfileMediaRepository>(
      () => ProfileMediaRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<MediaGalleryRepository>(
      () => MediaGalleryRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<ProfileMediaManagementRepository>(
      () => ProfileMediaManagementRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<ProfileMediaUploadRepository>(
      () => ProfileMediaUploadRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<VenueDirectoryRepository>(
      () => VenueDirectoryRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<ProfileSearchRepository>(
      () => ProfileSearchRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<MusicianSearchRepository>(
      () => MusicianSearchRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<VenueEventRepository>(
      () => VenueEventRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<TrackManagementRepository>(
      () => TrackManagementRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerFactory<ProfileMediaCubit>(
      () => ProfileMediaCubit(serviceLocator<ProfileMediaRepository>()),
    )
    ..registerLazySingleton<VenueProfileRepository>(
      () => VenueProfileRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<PromotionRepository>(
      () => PromotionRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerFactory<VenueProfileCubit>(
      () => VenueProfileCubit(serviceLocator<VenueProfileRepository>()),
    )
    ..registerLazySingleton<FollowRepository>(
      () => FollowRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<BandFollowRepository>(
      () => BandFollowRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerFactory<FollowActionCubit>(
      () => FollowActionCubit(serviceLocator<FollowRepository>()),
    )
    ..registerFactory<FollowCountCubit>(
      () => FollowCountCubit(serviceLocator<FollowRepository>()),
    )
    ..registerLazySingleton<SpotifyRepository>(
      () => SpotifyRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<SetlistRepository>(
      () => SetlistRepositoryImpl(
        serviceLocator<ApiClient>(),
        serviceLocator<TokenStore>(),
      ),
    )
    ..registerLazySingleton<TableGroupRepository>(
      () => TableGroupRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<TableGroupChatRealtimeClient>(
      () => TableGroupChatRealtimeClient(),
    )
    ..registerLazySingleton<EngagementRepository>(
      () => EngagementRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerFactory<TableGroupCreateCubit>(
      () => TableGroupCreateCubit(
        tableGroupRepository: serviceLocator<TableGroupRepository>(),
        locationRepository: serviceLocator<LocationRepository>(),
      ),
    )
    ..registerFactory<TableGroupListCubit>(
      () => TableGroupListCubit(
        tableGroupRepository: serviceLocator<TableGroupRepository>(),
        locationRepository: serviceLocator<LocationRepository>(),
      ),
    )
    ..registerFactory<SpotifyPreviewCubit>(
      () => SpotifyPreviewCubit(serviceLocator<SpotifyRepository>()),
    )
    ..registerFactory<InteractionStatsCubit>(
      () => InteractionStatsCubit(serviceLocator<EngagementRepository>()),
    )
    ..registerFactory<CommentThreadCubit>(
      () => CommentThreadCubit(serviceLocator<EngagementRepository>()),
    )
    ..registerLazySingleton<OverthinkingRepository>(
      () => OverthinkingRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerFactory<OverthinkingFeedCubit>(
      () => OverthinkingFeedCubit(
        overthinkingRepository: serviceLocator<OverthinkingRepository>(),
        engagementRepository: serviceLocator<EngagementRepository>(),
      ),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<LoginUseCase>(
      () => LoginUseCase(serviceLocator<AuthRepository>()),
    )
    ..registerLazySingleton<RegisterUseCase>(
      () => RegisterUseCase(serviceLocator<AuthRepository>()),
    )
    ..registerLazySingleton<VerifyCodeUseCase>(
      () => VerifyCodeUseCase(serviceLocator<AuthRepository>()),
    )
    ..registerLazySingleton<ResendCodeUseCase>(
      () => ResendCodeUseCase(serviceLocator<AuthRepository>()),
    )
    ..registerFactory<AuthCubit>(
      () => AuthCubit(
        loginUseCase: serviceLocator<LoginUseCase>(),
        registerUseCase: serviceLocator<RegisterUseCase>(),
        verifyCodeUseCase: serviceLocator<VerifyCodeUseCase>(),
        resendCodeUseCase: serviceLocator<ResendCodeUseCase>(),
        tokenStore: serviceLocator<TokenStore>(),
      ),
    )
    ..registerLazySingleton<DmRepository>(
      () => DmRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<DmUserProfileResolver>(
      () => DmUserProfileResolverImpl(
        apiClient: serviceLocator<ApiClient>(),
        musicianSearchRepository: serviceLocator<MusicianSearchRepository>(),
        musicianProfileRepository: serviceLocator<MusicianProfileRepository>(),
        venueDirectoryRepository: serviceLocator<VenueDirectoryRepository>(),
        venueProfileRepository: serviceLocator<VenueProfileRepository>(),
      ),
    )
    ..registerLazySingleton<DmRealtimeClient>(() => DmRealtimeClient())
    ..registerLazySingleton<DmBadgeCubit>(
      () => DmBadgeCubit(
        serviceLocator<DmRepository>(),
        serviceLocator<TokenStore>(),
        realtimeClient: serviceLocator<DmRealtimeClient>(),
      ),
    )
    ..registerFactory<DmConversationsCubit>(
      () => DmConversationsCubit(
        serviceLocator<DmRepository>(),
        serviceLocator<TokenStore>(),
        realtimeClient: serviceLocator<DmRealtimeClient>(),
      ),
    )
    ..registerFactory<DmChatCubit>(
      () => DmChatCubit(
        serviceLocator<DmRepository>(),
        serviceLocator<TokenStore>(),
        realtimeClient: serviceLocator<DmRealtimeClient>(),
      ),
    );
}
