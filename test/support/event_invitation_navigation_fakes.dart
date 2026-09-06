import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_calendar_repository_factory.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_calendar.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_performer_request_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_calendar_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';

class InvitationSession extends ChangeNotifier implements AuthSessionManager {
  String? userId = 'owner-1';
  String token = 'token-1';
  @override
  AuthSession get session => userId == null
      ? const AuthSession.guest()
      : AuthSession.authenticated(
          token: token,
          userId: userId,
          username: 'musician',
          accountStatus: 'ACTIVE',
          roles: const ['ROLE_MUSICIAN'],
          permissions: const [],
          expiresAt: DateTime(2100),
          isAdmin: false,
        );
  void switchTo(String? id) {
    userId = id;
    token = 'token-$id';
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const invitationProfile = MusicianProfile(
  id: 'musician-1',
  userId: 'owner-1',
  username: 'musician',
  stageName: null,
  bio: null,
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  spotifyTracks: [],
  instruments: [],
  activeVenues: [],
  bands: [],
);

class InvitationProfileRepository extends Fake
    implements MusicianProfileRepository {
  int reads = 0;
  Future<Result<MusicianProfile>> Function()? read;
  @override
  Future<Result<MusicianProfile>> getMyProfile() async {
    reads++;
    return read == null ? const Result.success(invitationProfile) : read!();
  }
}

BandProfile invitationBand({
  String id = 'band-1',
  String role = 'FOUNDER',
  String status = 'ACTIVE',
}) => BandProfile(
  id: id,
  name: 'Şahbaz',
  description: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundCloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: const [],
  members: [
    BandMemberSummary(
      userId: 'owner-1',
      profileId: 'musician-1',
      username: 'musician',
      profilePictureUrl: null,
      role: role,
      status: status,
    ),
  ],
);

class InvitationBands extends Fake implements BandRepository {
  int reads = 0;
  final ids = <String>[];
  Future<Result<BandProfile>> Function(String id)? read;
  @override
  Future<Result<BandProfile>> getBandById(String id) async {
    reads++;
    ids.add(id);
    return read == null ? Result.success(invitationBand()) : read!(id);
  }
}

class InvitationCalendar extends Fake
    implements MusicianCalendarRepository, MusicianCalendarSettingsReader {
  InvitationCalendar({this.visible = false});
  bool visible;
  int reads = 0;
  int writes = 0;
  bool broadcastReads = false;
  Future<Result<MusicianCalendarSettings>> Function()? read;
  final controller = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => controller.stream;
  @override
  Future<Result<MusicianCalendarSettings>> getSettings() async {
    reads++;
    if (broadcastReads) controller.add(null);
    return read == null
        ? Result.success(MusicianCalendarSettings(visible: visible, version: 0))
        : read!();
  }

  @override
  Future<Result<MusicianCalendarSettings>>
  readSettingsWithoutNotification() async {
    reads++;
    return read == null
        ? Result.success(MusicianCalendarSettings(visible: visible, version: 0))
        : read!();
  }

  @override
  Future<Result<MusicianCalendarSettings>> updateSettings({
    required bool visible,
    required int version,
  }) async {
    writes++;
    this.visible = visible;
    controller.add(null);
    return Result.success(
      MusicianCalendarSettings(visible: visible, version: version + 1),
    );
  }

  @override
  void invalidate() => controller.add(null);
  @override
  Future<void> dispose() => controller.close();
}

class InvitationBandCalendars extends Fake
    implements BandCalendarRepositoryFactory {
  InvitationBandCalendars(this.calendar);
  final InvitationCalendar calendar;
  final acquired = <String>[];
  final released = <String>[];
  @override
  MusicianCalendarRepository acquire(String bandId) {
    acquired.add(bandId);
    return calendar;
  }

  @override
  Future<void> release(String bandId) async {
    released.add(bandId);
  }
}

class InvitationRequests extends Fake
    implements EventPerformerRequestRepository {
  @override
  Future<Result<void>> reconsider(
    String requestId, {
    required bool showOnProfile,
  }) => throw UnimplementedError(
    'Unexpected reconsideration in navigation test.',
  );

  int reads = 0;
  int accepts = 0;
  int rejects = 0;
  EventPerformerTargetType? targetType;
  String? targetId;
  List<EventPerformerRequest> items = [];
  @override
  Future<Result<EventPerformerRequestPage>> listMine({
    EventPerformerRequestStatus status = EventPerformerRequestStatus.pending,
    int page = 0,
    int size = 20,
    EventPerformerTargetType? targetType,
    String? targetId,
  }) async {
    reads++;
    this.targetType = targetType;
    this.targetId = targetId;
    return Result.success(
      EventPerformerRequestPage(
        items: items,
        page: page,
        size: size,
        totalElements: items.length,
        totalPages: items.isEmpty ? 0 : 1,
        hasNext: false,
      ),
    );
  }

  @override
  Future<Result<void>> accept(
    String requestId, {
    bool showOnProfile = false,
  }) async {
    accepts++;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> reject(String requestId) async {
    rejects++;
    return const Result.success(null);
  }
}
