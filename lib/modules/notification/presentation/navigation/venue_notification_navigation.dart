import '../notification_direct_open.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../core/push/push_provider.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../profile/domain/entities/event_performer_request.dart';
import '../../../profile/domain/entities/venue_event_detail.dart';
import '../../../profile/domain/venue_event_repository.dart';
import '../../../profile/domain/band_repository.dart';
import '../../../profile/domain/musician_profile_repository.dart';
import '../../../profile/domain/event_plan_repository.dart';
import '../../../profile/domain/venue_profile_repository.dart';
import '../../../profile/presentation/screens/band_profile_screen.dart';
import '../../../profile/presentation/screens/band_management_panel_screen.dart';
import '../../../profile/presentation/screens/musician_profile_screen.dart';
import '../../../profile/presentation/screens/profile_route_args.dart';
import '../../../profile/presentation/screens/event_invitation_navigation.dart';
import '../../../profile/presentation/screens/event_management_hub.dart';
import '../../../profile/presentation/screens/venue_event_plan_screen.dart';
import '../../../profile/presentation/screens/weekly_event_detail_screen.dart';
import '../../domain/entities/app_notification.dart';
import '../notification_target_read.dart';

/// Shared venue business navigation. Every asynchronous lookup belongs to the
/// recipient, session and origin route that initiated the navigation.
class VenueNotificationNavigation {
  VenueNotificationNavigation(
    this.context,
    this.notification, {
    this.onOpened,
    this.readTicket,
    this.replaceOrigin = false,
  }) : _sessions = serviceLocator<AuthSessionManager>() {
    _expected = _sessions.session;
    _origin = NotificationDirectOpen.routeOf(context);
  }
  final BuildContext context;
  final AppNotification notification;
  final VoidCallback? onOpened;
  final NotificationTargetRead? readTicket;
  final bool replaceOrigin;
  final AuthSessionManager _sessions;
  late final AuthSession _expected;
  late final ModalRoute<dynamic>? _origin;
  bool _didOpen = false;

  bool _current() =>
      context.mounted &&
      identical(_sessions.session, _expected) &&
      _expected.isAuthenticated &&
      _expected.isActive &&
      !_expected.requiresListenerProfileChoice &&
      _expected.userId?.toLowerCase() ==
          notification.recipientId.toLowerCase() &&
      !_expected.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']) &&
      (readTicket?.isCurrent ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      _origin?.isCurrent != false;

  void _opened() {
    if (_didOpen) return;
    _didOpen = true;
    onOpened?.call();
  }

  Future<void> _pushNamed(String name, {Object? arguments}) async {
    if (!context.mounted || !_current()) return;
    final navigator = Navigator.of(context);
    final targetArguments = readTicket != null && !notification.read
        ? readTicket!.argumentsFor(name, arguments: arguments)
        : arguments;
    if (replaceOrigin) {
      unawaited(
        NotificationDirectOpen.pushNamed<void>(
          context,
          name,
          arguments: targetArguments,
        ),
      );
    } else {
      unawaited(navigator.pushNamed<void>(name, arguments: targetArguments));
    }
    _opened();
  }

  Future<void> _push(Route<void> route) async {
    if (!context.mounted || !_current()) return;
    readTicket?.attach(route);
    final navigator = Navigator.of(context);
    if (replaceOrigin) {
      unawaited(NotificationDirectOpen.push<void>(context, route));
    } else {
      unawaited(navigator.push<void>(route));
    }
    _opened();
  }

  Future<bool> open() async {
    if (!_current()) return false;
    final module = notification.payload['module'];
    if (module == 'ARTIST_VENUE' ||
        notification.type.startsWith('ARTIST_VENUE')) {
      await _openArtistVenueTarget(context, notification.payload);
    } else {
      await _openEventPerformerTarget(context, notification);
    }
    return _didOpen;
  }

  String? _cleanNullable(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _openEventPerformerTarget(
    BuildContext context,
    AppNotification notification,
  ) async {
    if (notification.payload['module']?.toString().trim().toUpperCase() ==
        'EVENT_PLAN') {
      await _openEventPlanTarget(context, notification);
      return;
    }
    final type = notification.type.trim().toUpperCase();
    final action =
        notification.payload['action']?.toString().trim().toUpperCase() ?? '';
    if (type == 'EVENT_PERFORMER_APPROVAL_REQUESTED' ||
        action == 'APPROVAL_REQUESTED') {
      final target = _performerInvitationTarget(notification);
      if (target == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.error,
            content: const Text('Davetin ait olduğu profil doğrulanamadı.'),
          ),
        );
        return;
      }
      await openEventInvitations(
        context,
        readTicket: readTicket,
        onOpened: _opened,
        replaceOrigin: false,
        notificationDirect: replaceOrigin,
        targetType: target.type,
        targetId: target.id,
      );
      return;
    }

    final eventId = notification.payload['eventId']?.toString().trim() ?? '';
    if (eventId.isEmpty) {
      final target = _performerInvitationTarget(notification);
      if (target == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context,
            tone: AppSnackBarTone.error,
            content: const Text('Davetin ait olduğu profil doğrulanamadı.'),
          ),
        );
        return;
      }
      await openEventInvitations(
        context,
        readTicket: readTicket,
        onOpened: _opened,
        replaceOrigin: false,
        notificationDirect: replaceOrigin,
        targetType: target.type,
        targetId: target.id,
      );
      return;
    }

    Result<VenueEventDetail> result;
    try {
      result = await serviceLocator<VenueEventRepository>().getDetail(eventId);
    } catch (_) {
      if (!context.mounted || !_current()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: const Text('Etkinlik ayrıntıları açılamadı.'),
        ),
      );
      return;
    }
    if (!context.mounted || !_current()) return;
    final detail = result.data;
    if (!result.isSuccess || detail == null || detail.id != eventId) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text(
            result.error?.message ?? 'Etkinlik ayrıntıları açılamadı.',
          ),
        ),
      );
      return;
    }

    // The event detail is the current authorization source of truth. Never
    // revive a performer link from a potentially stale notification payload.
    final performerIdentity = detail.performerIdentity;
    final musicianId = performerIdentity.musicianProfileId;
    final bandId = performerIdentity.bandId;

    await _push(
      MaterialPageRoute<void>(
        builder: (_) => WeeklyEventDetailScreen(
          event: WeeklyCalendarEvent(
            id: eventId,
            title:
                _firstNonBlank(detail.title, notification.title) ?? 'Etkinlik',
            artistName:
                _firstNonBlank(
                  detail.performerName,
                  notification.payload['performerName']?.toString(),
                ) ??
                'Sanatçı',
            artistProfileId: musicianId,
            bandProfileId: bandId,
            performerType: performerIdentity.performerType,
            venueName:
                _firstNonBlank(
                  detail.venueName,
                  notification.payload['venueName']?.toString(),
                ) ??
                'Mekan',
            // Only live event data may authorize a venue link; an old
            // notification can still contain a pending or rejected target.
            venueId: _cleanNullable(detail.venueId),
            city: detail.venueCity ?? '-',
            district: detail.venueDistrict ?? '-',
            neighborhood: detail.venueNeighborhood ?? '-',
            eventDate: _notificationEventDate(detail.eventDate),
            startTime: _shortEventTime(detail.startTime) ?? '-',
            endTime: _shortEventTime(detail.endTime) ?? '-',
            imageAssetPath: detail.posterImage,
            description: detail.description?.trim() ?? '',
          ),
        ),
      ),
    );
  }

  Future<void> _openEventPlanTarget(
    BuildContext context,
    AppNotification notification,
  ) async {
    final sessions = serviceLocator<AuthSessionManager>();
    final expected = sessions.session;
    final route = NotificationDirectOpen.routeOf(context);
    bool current() =>
        context.mounted &&
        identical(sessions.session, expected) &&
        expected.isAuthenticated &&
        expected.isActive &&
        route?.isCurrent != false &&
        _current();
    final id = notification.payload['planId']?.toString().trim() ?? '';
    if (!current() || id.isEmpty) return;
    try {
      if (expected.hasAnyRole(const ['VENUE', 'ROLE_VENUE'])) {
        final result = await serviceLocator<EventPlanRepository>().getOwner(id);
        if (!current()) return;
        final plan = result.data;
        if (!result.isSuccess || plan == null || plan.id != id) {
          throw StateError('Plan unavailable');
        }
        final owner = await serviceLocator<VenueProfileRepository>()
            .getMyVenueProfileDetail(venueId: plan.definition.venueId);
        if (!current()) return;
        final profile = owner.data;
        if (!owner.isSuccess ||
            profile == null ||
            profile.venueId != plan.definition.venueId ||
            profile.ownerUserId != expected.userId) {
          throw StateError('Owner changed');
        }
        if (!context.mounted || !_current()) return;
        await _push(
          MaterialPageRoute(
            builder: (_) =>
                VenueEventPlanScreen(planId: id, ownerProfile: profile),
          ),
        );
      } else {
        final result = await serviceLocator<EventPlanRepository>().getPerformer(
          id,
        );
        if (!current()) return;
        final plan = result.data;
        if (!result.isSuccess || plan == null || plan.id != id) {
          throw StateError('Plan unavailable');
        }
        final template = plan.definition.template;
        final target = template.bandId ?? template.musicianProfileId;
        if (target == null) throw StateError('Missing performer');
        if (!context.mounted || !_current()) return;
        await openEventInvitations(
          context,
          readTicket: readTicket,
          onOpened: _opened,
          replaceOrigin: false,
          notificationDirect: replaceOrigin,
          targetType: template.bandId == null
              ? EventPerformerTargetType.musician
              : EventPerformerTargetType.band,
          targetId: target,
          destination: EventManagementDestination.plans,
        );
      }
    } catch (_) {
      if (!context.mounted || !current()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: const Text(
            'Planın güncel bilgileri açılamadı. Davetlerden veya etkinlik yönetiminden tekrar dene.',
          ),
        ),
      );
    }
  }

  ({EventPerformerTargetType? type, String? id})? _performerInvitationTarget(
    AppNotification notification,
  ) {
    final payload = notification.payload;
    const identityFields = [
      'performerType',
      'targetType',
      'musicianProfileId',
      'bandId',
      'targetId',
    ];
    // Truly legacy notifications resolve to the authenticated musician's own
    // profile in the shared navigation guard, never to an aggregate band inbox.
    if (identityFields.every((field) => payload[field] == null)) {
      return (type: null, id: null);
    }
    if (identityFields.any(
      (field) => payload[field] != null && payload[field] is! String,
    )) {
      return null;
    }
    final declared = _cleanNullable(
      payload['performerType'] as String?,
    )?.toUpperCase();
    final alternate = _cleanNullable(
      payload['targetType'] as String?,
    )?.toUpperCase();
    if (declared != null && alternate != null && declared != alternate) {
      return null;
    }
    final type = declared ?? alternate;
    final musicianId = _cleanNullable(payload['musicianProfileId'] as String?);
    final bandId = _cleanNullable(payload['bandId'] as String?);
    final targetId = _cleanNullable(payload['targetId'] as String?);
    if (type == 'MUSICIAN' &&
        musicianId != null &&
        bandId == null &&
        (targetId == null || targetId == musicianId)) {
      return (type: EventPerformerTargetType.musician, id: musicianId);
    }
    if (type == 'BAND' &&
        bandId != null &&
        musicianId == null &&
        (targetId == null || targetId == bandId)) {
      return (type: EventPerformerTargetType.band, id: bandId);
    }
    return null;
  }

  String? _firstNonBlank(String? first, String? second) {
    final normalizedFirst = first?.trim() ?? '';
    if (normalizedFirst.isNotEmpty) return normalizedFirst;
    final normalizedSecond = second?.trim() ?? '';
    return normalizedSecond.isEmpty ? null : normalizedSecond;
  }

  String _notificationEventDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String? _shortEventTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final pieces = value.split(':');
    if (pieces.length < 2) return value;
    return '${pieces[0].padLeft(2, '0')}:${pieces[1].padLeft(2, '0')}';
  }

  Future<void> _openArtistVenueTarget(
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    final requestByType = payload['requestByType']?.toString().trim() ?? '';
    final action = payload['action']?.toString().trim() ?? '';
    final bandId = payload['bandId']?.toString().trim() ?? '';
    final venueId = payload['venueId']?.toString().trim() ?? '';
    final musicianId = payload['musicianProfileId']?.toString().trim() ?? '';
    if (!const {'VENUE', 'ARTIST', 'BAND'}.contains(requestByType) ||
        !const {
          'REQUEST_CREATED',
          'REQUEST_ACCEPTED',
          'REQUEST_REJECTED',
        }.contains(action)) {
      return;
    }
    final ownerSide = action == 'REQUEST_CREATED'
        ? requestByType != 'VENUE'
        : requestByType == 'VENUE';
    try {
      if (ownerSide) {
        if (!_expected.hasAnyRole(const ['VENUE', 'ROLE_VENUE']) ||
            venueId.isEmpty) {
          return;
        }
        final result = await serviceLocator<VenueProfileRepository>()
            .getMyVenueProfileDetail(venueId: venueId);
        if (!context.mounted || !_current()) return;
        if (!result.isSuccess ||
            result.data?.venueId != venueId ||
            result.data?.ownerUserId != _expected.userId) {
          return;
        }
      } else if (bandId.isNotEmpty) {
        final result = await serviceLocator<BandRepository>().getBandById(
          bandId,
        );
        if (!context.mounted || !_current()) return;
        if (!result.isSuccess ||
            result.data?.id != bandId ||
            result.data?.members.any(
                  (member) =>
                      member.userId == _expected.userId &&
                      member.status == 'ACTIVE',
                ) !=
                true) {
          return;
        }
        if (requestByType == 'VENUE' && action == 'REQUEST_CREATED') {
          final profile = result.data!;
          if (notification.type != 'ARTIST_VENUE_LINK_APPLICATION_REQUEST' ||
              !PushTarget.isUuid(payload['requestId']) ||
              !_expected.hasAnyRole(const ['MUSICIAN', 'ROLE_MUSICIAN']) ||
              !profile.members.any(
                (member) =>
                    member.userId == _expected.userId &&
                    member.status == 'ACTIVE' &&
                    member.isFounder,
              )) {
            return;
          }
          await _push(
            MaterialPageRoute<void>(
              builder: (_) => BandManagementPanelScreen(
                profile: profile,
                openIncomingVenueApplications: true,
              ),
            ),
          );
          return;
        }
      } else {
        if (!_expected.hasAnyRole(const ['MUSICIAN', 'ROLE_MUSICIAN']) ||
            musicianId.isEmpty) {
          return;
        }
        final result = await serviceLocator<MusicianProfileRepository>()
            .getMyProfile();
        if (!context.mounted || !_current()) return;
        if (!result.isSuccess ||
            result.data?.id != musicianId ||
            result.data?.userId != _expected.userId) {
          return;
        }
      }
    } catch (_) {
      return;
    }

    final opensBand =
        bandId.isNotEmpty &&
        requestByType == 'BAND' &&
        action != 'REQUEST_CREATED';
    if (opensBand) {
      await _pushNamed(
        AppRoutes.bandPublicProfile,
        arguments: BandProfileScreenArgs(
          bandId: bandId,
          viewMode: BandProfileViewMode.public,
        ),
      );
      return;
    }

    if (action == 'REQUEST_CREATED' &&
        (requestByType == 'ARTIST' || requestByType == 'BAND')) {
      await _pushNamed(
        AppRoutes.venueProfile,
        arguments: VenueProfileArgs(
          venueId: venueId,
          openIncomingApplications: true,
        ),
      );
      return;
    }

    if (requestByType == 'VENUE') {
      await _pushNamed(
        action == 'REQUEST_CREATED'
            ? AppRoutes.musicianProfile
            : AppRoutes.venueProfile,
        arguments: action == 'REQUEST_CREATED'
            ? const MusicianProfileScreenArgs(
                openIncomingVenueApplications: true,
              )
            : VenueProfileArgs(venueId: venueId),
      );
      return;
    }

    await _pushNamed(
      action == 'REQUEST_CREATED'
          ? AppRoutes.venueProfile
          : AppRoutes.musicianProfile,
    );
  }
}
