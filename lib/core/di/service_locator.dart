import 'package:get_it/get_it.dart';

import '../../modules/auth/data/auth_repository_impl.dart';
import '../../modules/auth/domain/auth_repository.dart';
import '../../modules/auth/domain/usecases/login_usecase.dart';
import '../../modules/auth/domain/usecases/register_usecase.dart';
import '../../modules/auth/domain/usecases/resend_code_usecase.dart';
import '../../modules/auth/domain/usecases/verify_code_usecase.dart';
import '../../modules/auth/presentation/cubit/auth_cubit.dart';
import '../../modules/artist_venue/data/artist_venue_connection_repository_impl.dart';
import '../../modules/artist_venue/domain/artist_venue_connection_repository.dart';
import '../../modules/artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import '../../modules/follow/data/follow_repository_impl.dart';
import '../../modules/follow/domain/follow_repository.dart';
import '../../modules/follow/presentation/cubit/follow_action_cubit.dart';
import '../../modules/follow/presentation/cubit/follow_count_cubit.dart';
import '../../modules/location/data/location_repository_impl.dart';
import '../../modules/location/domain/location_repository.dart';
import '../../modules/location/presentation/cubit/location_cubit.dart';
import '../../modules/instrument/data/instrument_repository_impl.dart';
import '../../modules/instrument/domain/instrument_repository.dart';
import '../../modules/instrument/presentation/cubit/instrument_cubit.dart';
import '../../modules/profile/data/musician_profile_repository_impl.dart';
import '../../modules/profile/data/profile_media_repository_impl.dart';
import '../../modules/profile/domain/musician_profile_repository.dart';
import '../../modules/profile/domain/profile_media_repository.dart';
import '../../modules/profile/presentation/cubit/musician_profile_cubit.dart';
import '../../modules/profile/presentation/cubit/profile_media_cubit.dart';
import '../../modules/spotify/data/spotify_repository_impl.dart';
import '../../modules/spotify/domain/spotify_repository.dart';
import '../../modules/spotify/presentation/cubit/spotify_preview_cubit.dart';
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
    ..registerLazySingleton<MusicianProfileRepository>(
      () => MusicianProfileRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerFactory<MusicianProfileCubit>(
      () => MusicianProfileCubit(serviceLocator<MusicianProfileRepository>()),
    )
    ..registerLazySingleton<ProfileMediaRepository>(
      () => ProfileMediaRepositoryImpl(serviceLocator<ApiClient>()),
    )
    ..registerFactory<ProfileMediaCubit>(
      () => ProfileMediaCubit(serviceLocator<ProfileMediaRepository>()),
    )
    ..registerLazySingleton<FollowRepository>(
      () => FollowRepositoryImpl(serviceLocator<ApiClient>()),
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
    ..registerFactory<SpotifyPreviewCubit>(
      () => SpotifyPreviewCubit(serviceLocator<SpotifyRepository>()),
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
    );
}
