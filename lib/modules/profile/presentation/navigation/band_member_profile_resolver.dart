import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../dm/domain/dm_user_profile_resolver.dart';
import '../../../dm/domain/entities/dm_profile_target.dart';
import '../../domain/entities/band_member_summary.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/musician_profile_repository.dart';
import '../screens/profile_route_args.dart';

/// Keeps the roster's user identity distinct from the musician profile ID.
/// Names and search ordering are never evidence that a profile is this member.
class BandMemberProfileResolver {
  BandMemberProfileResolver({
    MusicianProfileRepository? repository,
    DmUserProfileResolver? userProfileResolver,
    AuthSessionManager? sessionManager,
  }) : _repository = repository,
       _userProfileResolver = userProfileResolver,
       _sessionManager = sessionManager;

  final MusicianProfileRepository? _repository;
  final DmUserProfileResolver? _userProfileResolver;
  final AuthSessionManager? _sessionManager;
  final Map<(String, String, AuthSession?), Future<MusicianProfile?>>
  _inFlight = {};
  bool _opening = false;

  AuthSessionManager? get _manager =>
      _sessionManager ??
      (serviceLocator.isRegistered<AuthSessionManager>()
          ? serviceLocator<AuthSessionManager>()
          : null);

  Future<MusicianProfile?> resolve(BandMemberSummary member) {
    final userId = member.userId.trim();
    final profileId = member.profileId?.trim() ?? '';
    if (userId.isEmpty) return Future.value();
    final manager = _manager;
    final session = manager?.session;
    final key = (userId, profileId, session);
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final operation = _resolve(
      userId: userId,
      profileId: profileId,
      isCurrent: () => identical(manager?.session, session),
    );
    _inFlight[key] = operation;
    operation.then((_) {
      if (identical(_inFlight[key], operation)) _inFlight.remove(key);
    });
    return operation;
  }

  Future<MusicianProfile?> _resolve({
    required String userId,
    required String profileId,
    required bool Function() isCurrent,
  }) async {
    try {
      final repository =
          _repository ?? serviceLocator<MusicianProfileRepository>();

      Future<MusicianProfile?> verifiedProfile(String candidate) async {
        final result = await repository.getPublicProfileByProfileId(candidate);
        if (!isCurrent() || !result.isSuccess) return null;
        final profile = result.data;
        if (profile == null ||
            profile.id.trim() != candidate ||
            profile.userId.trim() != userId) {
          return null;
        }
        return profile;
      }

      if (profileId.isNotEmpty) {
        final direct = await verifiedProfile(profileId);
        if (!isCurrent() || direct != null) return direct;
      }
      final resolver =
          _userProfileResolver ??
          (serviceLocator.isRegistered<DmUserProfileResolver>()
              ? serviceLocator<DmUserProfileResolver>()
              : null);
      if (resolver == null || !isCurrent()) return null;

      final targets = await resolver.resolveByUserId(userId: userId);
      if (!isCurrent()) return null;
      final musicianIds = targets
          .where((target) => target.type == DmProfileTargetType.musician)
          .map((target) => target.id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      // A user has one musician profile. Ambiguous responses fail closed.
      if (musicianIds.length != 1) return null;
      final canonicalId = musicianIds.single;
      if (canonicalId == profileId) return null;
      return await verifiedProfile(canonicalId);
    } catch (_) {
      return null;
    }
  }

  Future<void> open(
    BuildContext context,
    BandMemberSummary member, {
    bool Function()? isMemberCurrent,
  }) async {
    if (_opening || !context.mounted) return;
    final sourceRoute = ModalRoute.of(context);
    if (sourceRoute?.isCurrent != true) return;
    final manager = _manager;
    final session = manager?.session;
    bool canNavigate() =>
        context.mounted &&
        sourceRoute?.isCurrent == true &&
        identical(manager?.session, session) &&
        (isMemberCurrent?.call() ?? true);

    _opening = true;
    try {
      final profile = await resolve(member);
      if (!context.mounted || !canNavigate()) return;
      if (profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.warning,
            content: const Text(
              'Bu üyenin profili açılamadı. Lütfen tekrar dene.',
            ),
          ),
        );
        return;
      }
      await Navigator.of(context).pushNamed(
        AppRoutes.musicianPublicProfile,
        arguments: PublicProfileArgs(profileId: profile.id.trim()),
      );
    } finally {
      _opening = false;
    }
  }
}
