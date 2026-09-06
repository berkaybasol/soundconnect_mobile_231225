import 'package:get_it/get_it.dart';

import '../../modules/auth/data/auth_repository_impl.dart';
import '../../modules/admin/data/admin_repository_impl.dart';
import '../../modules/admin/domain/admin_repository.dart';
import '../../modules/admin/presentation/cubit/admin_panel_cubit.dart';
import '../../modules/auth/domain/auth_repository.dart';
import '../../modules/auth/domain/usecases/check_username_availability_usecase.dart';
import '../../modules/auth/domain/usecases/login_usecase.dart';
import '../../modules/auth/domain/usecases/register_usecase.dart';
import '../../modules/auth/domain/usecases/request_password_reset_usecase.dart';
import '../../modules/auth/domain/usecases/resolve_password_reset_account_usecase.dart';
import '../../modules/auth/domain/usecases/reset_password_usecase.dart';
import '../../modules/auth/domain/usecases/resend_code_usecase.dart';
import '../../modules/auth/domain/usecases/update_username_usecase.dart';
import '../../modules/auth/domain/usecases/verify_code_usecase.dart';
import '../../modules/auth/presentation/cubit/auth_cubit.dart';
import '../../modules/collab/data/collab_repository_impl.dart';
import '../../modules/collab/data/collab_idempotency_store.dart';
import '../../modules/collab/domain/collab_repository.dart';
import '../../modules/collab/presentation/cubit/collab_actor_reviews_cubit.dart';
import '../../modules/collab/presentation/cubit/collab_discovery_cubit.dart';
import '../../modules/collab/presentation/cubit/collab_incoming_applications_cubit.dart';
import '../../modules/collab/presentation/cubit/collab_jobs_cubit.dart';
import '../../modules/collab/presentation/cubit/collab_listing_detail_cubit.dart';
import '../../modules/collab/presentation/cubit/collab_listing_editor_cubit.dart';
import '../../modules/collab/presentation/cubit/collab_my_applications_cubit.dart';
import '../../modules/collab/presentation/cubit/collab_my_listings_cubit.dart';
import '../../modules/collab/presentation/cubit/collab_saved_listings_cubit.dart';
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
import '../../modules/profile/data/musician_calendar_repository_impl.dart';
import '../../modules/profile/data/band_calendar_repository_factory.dart';
import '../../modules/profile/data/listener_profile_repository_impl.dart';
import '../../modules/profile/data/band_repository_impl.dart';
import '../../modules/profile/data/musician_search_repository_impl.dart';
import '../../modules/profile/data/media_gallery_repository_impl.dart';
import '../../modules/profile/data/profile_media_management_repository_impl.dart';
import '../../modules/profile/data/profile_media_repository_impl.dart';
import '../../modules/profile/data/profile_media_upload_repository_impl.dart';
import '../../modules/profile/data/pending_draft_media_cleanup_store.dart';
import '../../modules/profile/data/pending_profile_upload_store.dart';
import '../../modules/profile/data/profile_search_repository_impl.dart';
import '../../modules/profile/data/studio_profile_repository_impl.dart';
import '../../modules/profile/data/track_management_repository_impl.dart';
import '../../modules/profile/data/venue_directory_repository_impl.dart';
import '../../modules/profile/data/venue_event_repository_impl.dart';
import '../../modules/profile/data/event_performer_request_repository_impl.dart';
import '../../modules/profile/data/event_profile_publication_repository_impl.dart';
import '../../modules/profile/data/venue_profile_repository_impl.dart';
import '../../modules/profile/domain/musician_profile_repository.dart';
import '../../modules/profile/domain/musician_calendar_repository.dart';
import '../../modules/profile/domain/listener_profile_repository.dart';
import '../../modules/profile/domain/band_repository.dart';
import '../../modules/profile/domain/musician_search_repository.dart';
import '../../modules/profile/domain/media_gallery_repository.dart';
import '../../modules/profile/domain/profile_media_management_repository.dart';
import '../../modules/profile/domain/profile_media_repository.dart';
import '../../modules/profile/domain/profile_media_upload_repository.dart';
import '../../modules/profile/domain/profile_search_repository.dart';
import '../../modules/profile/domain/studio_profile_repository.dart';
import '../../modules/profile/domain/track_management_repository.dart';
import '../../modules/profile/domain/venue_directory_repository.dart';
import '../../modules/profile/domain/venue_event_repository.dart';
import '../../modules/profile/domain/event_performer_request_repository.dart';
import '../../modules/profile/domain/event_profile_publication_repository.dart';
import '../../modules/profile/domain/venue_profile_repository.dart';
import '../../modules/profile/presentation/cubit/musician_profile_cubit.dart';
import '../../modules/profile/presentation/cubit/listener_profile_cubit.dart';
import '../../modules/profile/presentation/cubit/profile_media_cubit.dart';
import '../../modules/profile/presentation/cubit/studio_profile_cubit.dart';
import '../../modules/profile/presentation/cubit/venue_profile_cubit.dart';
import '../../modules/promotion/data/promotion_repository_impl.dart';
import '../../modules/promotion/domain/promotion_repository.dart';
import '../../modules/spotify/data/spotify_repository_impl.dart';
import '../../modules/spotify/domain/spotify_repository.dart';
import '../../modules/spotify/presentation/cubit/spotify_preview_cubit.dart';
import '../../modules/studio/data/backline_catalog_repository_impl.dart';
import '../../modules/studio/data/studio_equipment_repository_impl.dart';
import '../../modules/studio/data/studio_room_repository_impl.dart';
import '../../modules/studio/domain/backline_catalog_repository.dart';
import '../../modules/studio/domain/studio_equipment_repository.dart';
import '../../modules/studio/domain/studio_room_repository.dart';
import '../../modules/setlist/data/setlist_repository_impl.dart';
import '../../modules/setlist/domain/setlist_repository.dart';
import '../../modules/tablegroup/data/table_group_repository_impl.dart';
import '../../modules/tablegroup/data/table_group_venue_option_repository_impl.dart';
import '../../modules/tablegroup/data/table_group_chat_realtime_client.dart';
import '../../modules/tablegroup/data/table_group_game_repository_impl.dart';
import '../../modules/tablegroup/domain/table_group_game_repository.dart';
import '../../modules/tablegroup/domain/table_group_repository.dart';
import '../../modules/tablegroup/domain/table_group_venue_option_repository.dart';
import '../../modules/tablegroup/presentation/cubit/table_group_create_cubit.dart';
import '../../modules/tablegroup/presentation/cubit/table_group_list_cubit.dart';
import '../auth/token_store.dart';
import '../auth/auth_session_manager.dart';
import '../policy/access_policy.dart';
import '../auth/auth_session_store.dart';
import '../deep_link/pending_app_deep_link_store.dart';
import '../network/api_client.dart';
import '../network/dio_api_client.dart';

final GetIt serviceLocator = GetIt.instance;

void setupDependencies() {
  serviceLocator
    ..registerLazySingleton<TokenStore>(() => const SecureTokenStore())
    ..registerLazySingleton<AuthSessionStore>(
      () => const SecureAuthSessionStore(),
    )
    ..registerLazySingleton<AuthSessionManager>(
      () => AuthSessionManager(
        tokenStore: serviceLocator<TokenStore>(),
        sessionStore: serviceLocator<AuthSessionStore>(),
        onSessionEnded: _stopSessionServices,
      ),
    )
    ..registerLazySingleton<PendingAppDeepLinkStore>(
      SharedPreferencesPendingAppDeepLinkStore.new,
    )
    ..registerLazySingleton<AppDeepLinkInbox>(
      () => AppDeepLinkInbox(store: serviceLocator<PendingAppDeepLinkStore>()),
    )
    ..registerLazySingleton<ApiClient>(
      () => DioApiClient(
        tokenStore: serviceLocator<TokenStore>(),
        sessionManager: serviceLocator<AuthSessionManager>(),
      ),
    )
    ..registerLazySingleton<AdminRepository>(
      () => AdminRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerFactory<AdminPanelCubit>(
      () => AdminPanelCubit(serviceLocator<AdminRepository>()),
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
    ..registerLazySingleton<CollabRepository>(
      () => CollabRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<CollabIdempotencyStore>(
      () => SharedPreferencesCollabIdempotencyStore(
        tokenStore: serviceLocator<TokenStore>(),
      ),
    )
    ..registerFactory<CollabDiscoveryCubit>(
      () => CollabDiscoveryCubit(serviceLocator<CollabRepository>()),
    )
    ..registerFactory<CollabListingDetailCubit>(
      () => CollabListingDetailCubit(
        serviceLocator<CollabRepository>(),
        idempotencyStore: serviceLocator<CollabIdempotencyStore>(),
      ),
    )
    ..registerFactory<CollabListingEditorCubit>(
      () => CollabListingEditorCubit(
        serviceLocator<CollabRepository>(),
        idempotencyStore: serviceLocator<CollabIdempotencyStore>(),
      ),
    )
    ..registerFactory<CollabMyListingsCubit>(
      () => CollabMyListingsCubit(serviceLocator<CollabRepository>()),
    )
    ..registerFactory<CollabMyApplicationsCubit>(
      () => CollabMyApplicationsCubit(serviceLocator<CollabRepository>()),
    )
    ..registerFactory<CollabIncomingApplicationsCubit>(
      () => CollabIncomingApplicationsCubit(serviceLocator<CollabRepository>()),
    )
    ..registerFactory<CollabJobsCubit>(
      () => CollabJobsCubit(
        serviceLocator<CollabRepository>(),
        idempotencyStore: serviceLocator<CollabIdempotencyStore>(),
      ),
    )
    ..registerFactory<CollabSavedListingsCubit>(
      () => CollabSavedListingsCubit(serviceLocator<CollabRepository>()),
    )
    ..registerFactory<CollabActorReviewsCubit>(
      () => CollabActorReviewsCubit(serviceLocator<CollabRepository>()),
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
    ..registerLazySingleton<MusicianCalendarRepository>(
      () => MusicianCalendarRepositoryImpl(
        serviceLocator<ApiClient>(),
        sessionKeyProvider: () =>
            serviceLocator<AuthSessionManager>().session.userId,
      ),
      dispose: (repository) => repository.dispose(),
    )
    ..registerLazySingleton<BandCalendarRepositoryFactory>(
      () => BandCalendarRepositoryFactory(
        serviceLocator<ApiClient>(),
        sessionKeyProvider: () =>
            serviceLocator<AuthSessionManager>().session.userId,
        refreshes: serviceLocator<MusicianCalendarRepository>().changes,
        onSettingsConfirmed:
            serviceLocator<MusicianCalendarRepository>().invalidate,
      ),
      dispose: (factory) => factory.dispose(),
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
      () => ProfileMediaUploadRepositoryImpl(
        serviceLocator<ApiClient>(),
        pendingStore: SharedPreferencesPendingProfileUploadStore(),
        pendingDraftCleanupStore:
            SharedPreferencesPendingDraftMediaCleanupStore(),
        sessionKeyProvider: () =>
            serviceLocator<AuthSessionManager>().session.userId,
      ),
    )
    ..registerLazySingleton<VenueDirectoryRepository>(
      () => VenueDirectoryRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<ProfileSearchRepository>(
      () => ProfileSearchRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<StudioProfileRepository>(
      () => StudioProfileRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<StudioRoomRepository>(
      () => StudioRoomRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<StudioEquipmentRepository>(
      () => StudioEquipmentRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<BacklineCatalogRepository>(
      () => BacklineCatalogRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<MusicianSearchRepository>(
      () => MusicianSearchRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<VenueEventRepository>(
      () => VenueEventRepositoryImpl(
        serviceLocator<ApiClient>(),
        sessionKeyProvider: () =>
            serviceLocator<AuthSessionManager>().session.userId,
      ),
    )
    ..registerLazySingleton<EventPerformerRequestRepository>(
      () => EventPerformerRequestRepositoryImpl(
        serviceLocator<ApiClient>(),
        sessionKeyProvider: () =>
            serviceLocator<AuthSessionManager>().session.userId,
        onDecision: () =>
            serviceLocator<MusicianCalendarRepository>().invalidate(),
      ),
    )
    ..registerLazySingleton<EventProfilePublicationRepository>(
      () => EventProfilePublicationRepositoryImpl(
        serviceLocator<ApiClient>(),
        sessionKeyProvider: () =>
            serviceLocator<AuthSessionManager>().session.userId,
        onPublicationChanged: () =>
            serviceLocator<MusicianCalendarRepository>().invalidate(),
      ),
    )
    ..registerLazySingleton<TrackManagementRepository>(
      () => TrackManagementRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerFactory<ProfileMediaCubit>(
      () => ProfileMediaCubit(serviceLocator<ProfileMediaRepository>()),
    )
    ..registerFactory<StudioProfileCubit>(
      () => StudioProfileCubit(serviceLocator<StudioProfileRepository>()),
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
    ..registerLazySingleton<TableGroupVenueOptionRepository>(
      () => TableGroupVenueOptionRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<TableGroupGameRepository>(
      () => TableGroupGameRepositoryImpl(serviceLocator<ApiClient>()),
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
        venueOptionRepository:
            serviceLocator<TableGroupVenueOptionRepository>(),
        canCreateOrJoin: () => AccessPolicy.canCreateOrJoinTableGroups(
          serviceLocator<AuthSessionManager>().session.roles,
        ),
      ),
    )
    ..registerFactory<TableGroupListCubit>(
      () => TableGroupListCubit(
        tableGroupRepository: serviceLocator<TableGroupRepository>(),
        locationRepository: serviceLocator<LocationRepository>(),
        canCreateOrJoin: () => AccessPolicy.canCreateOrJoinTableGroups(
          serviceLocator<AuthSessionManager>().session.roles,
        ),
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
      () => AuthRepositoryImpl(
        serviceLocator<ApiClient>(),
        sessionKeyProvider: () =>
            serviceLocator<AuthSessionManager>().session.userId,
      ),
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
    ..registerLazySingleton<RequestPasswordResetUseCase>(
      () => RequestPasswordResetUseCase(serviceLocator<AuthRepository>()),
    )
    ..registerLazySingleton<CheckUsernameAvailabilityUseCase>(
      () => CheckUsernameAvailabilityUseCase(serviceLocator<AuthRepository>()),
    )
    ..registerLazySingleton<ResolvePasswordResetAccountUseCase>(
      () =>
          ResolvePasswordResetAccountUseCase(serviceLocator<AuthRepository>()),
    )
    ..registerLazySingleton<ResetPasswordUseCase>(
      () => ResetPasswordUseCase(serviceLocator<AuthRepository>()),
    )
    ..registerLazySingleton<UpdateUsernameUseCase>(
      () => UpdateUsernameUseCase(serviceLocator<AuthRepository>()),
    )
    ..registerFactory<AuthCubit>(
      () => AuthCubit(
        loginUseCase: serviceLocator<LoginUseCase>(),
        registerUseCase: serviceLocator<RegisterUseCase>(),
        verifyCodeUseCase: serviceLocator<VerifyCodeUseCase>(),
        resendCodeUseCase: serviceLocator<ResendCodeUseCase>(),
        requestPasswordResetUseCase:
            serviceLocator<RequestPasswordResetUseCase>(),
        resetPasswordUseCase: serviceLocator<ResetPasswordUseCase>(),
        updateUsernameUseCase: serviceLocator<UpdateUsernameUseCase>(),
        checkUsernameAvailabilityUseCase:
            serviceLocator<CheckUsernameAvailabilityUseCase>(),
        resolvePasswordResetAccountUseCase:
            serviceLocator<ResolvePasswordResetAccountUseCase>(),
        tokenStore: serviceLocator<TokenStore>(),
        sessionManager: serviceLocator<AuthSessionManager>(),
      ),
    )
    ..registerLazySingleton<DmRepository>(
      () => DmRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerLazySingleton<DmUserProfileResolver>(
      () => DmUserProfileResolverImpl(apiClient: serviceLocator<ApiClient>()),
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

Future<void> _stopSessionServices() async {
  final operations = <Future<void>>[];
  if (serviceLocator.isRegistered<NotificationCubit>()) {
    operations.add(serviceLocator<NotificationCubit>().stop());
  }
  if (serviceLocator.isRegistered<DmBadgeCubit>()) {
    operations.add(serviceLocator<DmBadgeCubit>().stop());
  }
  if (serviceLocator.isRegistered<NotificationRealtimeClient>()) {
    operations.add(serviceLocator<NotificationRealtimeClient>().disconnect());
  }
  if (serviceLocator.isRegistered<DmRealtimeClient>()) {
    operations.add(serviceLocator<DmRealtimeClient>().disconnect());
  }
  if (serviceLocator.isRegistered<TableGroupChatRealtimeClient>()) {
    operations.add(serviceLocator<TableGroupChatRealtimeClient>().disconnect());
  }
  await Future.wait(operations);
}
