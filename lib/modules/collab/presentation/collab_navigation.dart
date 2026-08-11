import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import '../../dm/presentation/screens/dm_chat_screen.dart';
import '../../profile/presentation/screens/band_profile_screen.dart';
import '../../profile/presentation/screens/profile_route_args.dart';
import '../domain/collab_types.dart';
import '../domain/entities/collab_actor.dart';

void openCollabActorProfile(BuildContext context, CollabActor actor) {
  switch (actor.profileType) {
    case CollabProfileKind.musician:
      Navigator.of(context).pushNamed(
        AppRoutes.musicianPublicProfile,
        arguments: PublicProfileArgs(profileId: actor.sourceProfileId),
      );
    case CollabProfileKind.band:
      Navigator.of(context).pushNamed(
        AppRoutes.bandPublicProfile,
        arguments: BandProfileScreenArgs(
          bandId: actor.sourceProfileId,
          viewMode: BandProfileViewMode.public,
        ),
      );
    case CollabProfileKind.venue:
      Navigator.of(context).pushNamed(
        AppRoutes.venuePublicProfile,
        arguments: VenuePublicProfileArgs(venueId: actor.sourceProfileId),
      );
    case CollabProfileKind.studio:
      Navigator.of(context).pushNamed(
        AppRoutes.studioPublicProfile,
        arguments: PublicProfileArgs(profileId: actor.sourceProfileId),
      );
  }
}

void openCollabActorConversation(BuildContext context, CollabActor actor) {
  final contactUserId = actor.contactUserId.trim();
  if (contactUserId.isEmpty) return;

  Navigator.of(context).pushNamed(
    AppRoutes.dmChat,
    arguments: DmChatScreenArgs(
      otherUserId: contactUserId,
      otherUsername: actor.displayName,
      otherUserProfilePicture: actor.avatarUrl,
      otherMusicianProfileId: actor.profileType == CollabProfileKind.musician
          ? actor.sourceProfileId
          : null,
    ),
  );
}
