// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_service/audio_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/service_locator.dart';
import '../../../artist_venue/domain/artist_venue_connection_repository.dart';
import '../../../artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_state.dart';
import '../../../follow/presentation/cubit/follow_count_cubit.dart';
import '../../../follow/presentation/cubit/follow_count_state.dart';
import '../../../location/domain/location_repository.dart';
import '../../../spotify/domain/entities/spotify_track_preview.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/entities/profile_venue_models.dart';
import '../../domain/entities/profile_media.dart';
import '../../domain/entities/track.dart';
import '../../domain/entities/venue_active_musician.dart';
import '../../domain/entities/venue_owner_profile.dart';
import '../../domain/musician_search_repository.dart';
import '../../domain/profile_media_management_repository.dart';
import '../../domain/venue_directory_repository.dart';
import '../../domain/venue_event_repository.dart';
import '../../../../app/router/app_routes.dart';
import '../../data/models/venue_profile_save_request.dart';
import '../cubit/profile_media_cubit.dart';
import '../cubit/venue_profile_cubit.dart';
import '../cubit/venue_profile_state.dart';
import 'profile_audio_tab_shared.dart';
import 'profile_carousels.dart';
import 'profile_common_widgets.dart';
import 'profile_media_content_shared.dart';
import 'profile_media_tabs.dart';
import 'profile_photo_gallery_tab.dart';
import 'venue_management_panel_screen.dart';
import 'profile_venue_support.dart';
import 'profile_screen_support.dart';
import 'profile_section_support.dart';
import 'profile_social_support.dart';
import 'profile_route_args.dart';
import 'profile_venue_request_sheet.dart';
import 'venue_weekly_calendar_editor_screen.dart';
import 'venue_event_support.dart';
import 'weekly_event_carousel.dart';
import 'weekly_event_detail_screen.dart';

part 'venue_profile_screen_audio_cards.dart';
part 'venue_profile_screen_media_content.dart';
part 'venue_profile_screen_audio_tab.dart';
part 'venue_profile_screen_content.dart';
part 'venue_profile_screen_content_actions.dart';
part 'venue_profile_screen_sections.dart';
part 'venue_profile_screen_sections_bio.dart';
part 'venue_profile_screen_sections_activity.dart';
part 'venue_profile_screen_sections_activity_calendar.dart';
part 'venue_profile_screen_view.dart';
part 'venue_profile_screen_view_profile_actions.dart';
part 'venue_profile_screen_view_connected_artist_actions.dart';
part 'venue_profile_screen_connected_artist_request_sheet.dart';
part 'venue_profile_screen_connected_artist_request_sheet_methods.dart';
part 'venue_profile_screen_view_venue_actions.dart';
part 'venue_profile_screen_view_formatters.dart';

class VenueProfileScreen extends StatelessWidget {
  const VenueProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => serviceLocator<VenueProfileCubit>()),
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
