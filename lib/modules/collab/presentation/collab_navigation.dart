import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import '../../dm/domain/dm_user_profile_resolver.dart';
import '../../dm/presentation/band_representative_conversation.dart';
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

Future<void> openCollabActorConversation(
  BuildContext context,
  CollabActor actor, {
  DmUserProfileResolver? profileResolver,
}) async {
  final contactUserId = actor.contactUserId.trim();
  if (contactUserId.isEmpty) return;

  if (actor.profileType == CollabProfileKind.band) {
    await openBandRepresentativeConversation(
      context,
      bandName: actor.displayName,
      contactUserId: contactUserId,
      contactUsername: actor.contactUsername,
      profileResolver: profileResolver,
    );
    return;
  }

  _pushActorConversation(
    context,
    contactUserId: contactUserId,
    username: actor.displayName,
    avatarUrl: actor.avatarUrl,
    musicianProfileId: actor.profileType == CollabProfileKind.musician
        ? actor.sourceProfileId
        : null,
  );
}

void _pushActorConversation(
  BuildContext context, {
  required String contactUserId,
  required String username,
  required String? avatarUrl,
  required String? musicianProfileId,
}) {
  Navigator.of(context).pushNamed(
    AppRoutes.dmChat,
    arguments: DmChatScreenArgs(
      otherUserId: contactUserId,
      otherUsername: username,
      otherUserProfilePicture: avatarUrl,
      otherMusicianProfileId: musicianProfileId,
    ),
  );
}
