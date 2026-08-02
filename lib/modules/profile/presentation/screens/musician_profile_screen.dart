import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_service/audio_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/service_locator.dart';
import '../../../artist_venue/domain/artist_venue_connection_repository.dart';
import '../../../artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import '../../../artist_venue/presentation/cubit/artist_venue_connections_state.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_state.dart';
import '../../../follow/presentation/cubit/follow_count_cubit.dart';
import '../../../follow/presentation/cubit/follow_count_state.dart';
import '../../../location/domain/location_repository.dart';
import '../../../setlist/presentation/screens/band_setlist_builder_screen.dart';
import '../../../spotify/domain/entities/spotify_track_preview.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/profile_menu_actions.dart';
import '../../../../shared/widgets/session_logout_action.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/artist_venue_application.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/entities/profile_venue_models.dart';
import '../../domain/entities/profile_media.dart';
import '../../domain/entities/track.dart';
import '../../domain/venue_directory_repository.dart';
import '../../data/models/musician_profile_save_request.dart';
import '../cubit/musician_profile_cubit.dart';
import '../cubit/musician_profile_state.dart';
import '../cubit/profile_media_cubit.dart';
import 'my_bands_screen.dart';
import 'profile_audio_tab_shared.dart';
import 'profile_carousels.dart';
import 'profile_common_widgets.dart';
import 'profile_media_content_shared.dart';
import 'profile_media_tabs.dart';
import 'profile_screen_support.dart';
import 'profile_section_support.dart';
import 'profile_social_support.dart';
import 'profile_route_args.dart';
import 'profile_venue_support.dart';
import 'profile_venue_request_sheet.dart';

part 'musician_profile_screen_audio_cards.dart';
part 'musician_profile_screen_media_content.dart';
part 'musician_profile_screen_audio_tab.dart';
part 'musician_profile_screen_content.dart';
part 'musician_profile_screen_content_overlays.dart';
part 'musician_profile_screen_venue_connections_sheet.dart';
part 'musician_profile_screen_sections.dart';
part 'musician_profile_screen_sections_bio.dart';
part 'musician_profile_screen_sections_venue_carousel.dart';
part 'musician_profile_screen_view.dart';
part 'musician_profile_screen_view_profile_actions.dart';
part 'musician_profile_screen_view_venue_actions.dart';

class MusicianProfileScreenArgs {
  final bool openManagementPanel;
  final bool openIncomingVenueApplications;

  const MusicianProfileScreenArgs({
    this.openManagementPanel = false,
    this.openIncomingVenueApplications = false,
  });
}

class MusicianProfileScreen extends StatelessWidget {
  const MusicianProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              serviceLocator<MusicianProfileCubit>()..loadMyProfile(),
        ),
        BlocProvider(create: (_) => serviceLocator<ProfileMediaCubit>()),
        BlocProvider(create: (_) => serviceLocator<FollowCountCubit>()),
        BlocProvider(create: (_) => serviceLocator<FollowActionCubit>()),
        BlocProvider(
          create: (_) => serviceLocator<ArtistVenueConnectionsCubit>(),
        ),
        BlocProvider(create: (_) => serviceLocator<InteractionStatsCubit>()),
      ],
      child: const _MusicianPublicProfileView(),
    );
  }
}
