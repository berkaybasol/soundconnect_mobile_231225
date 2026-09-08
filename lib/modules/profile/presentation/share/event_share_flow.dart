import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../event_audience/domain/event_audience_repository.dart';
import '../../../event_audience/presentation/event_audience_controller.dart';
import '../../domain/venue_event_repository.dart';
import 'event_share_data.dart';
import 'event_share_service.dart';
import 'event_share_sheet.dart';

final _activeAudienceShares = Expando<bool>('audience-event-share');

@visibleForTesting
EventShareService resolveAudienceShareService([EventShareService? override]) =>
    override ?? _registered<EventShareService>() ?? PlatformEventShareService();

/// Reuses the event's public artwork/export pipeline. A post's author intent
/// must never be supplied here as the viewing user's intent.
/// Invoke after dismissing any action sheet so [context]'s route is current.
Future<void> shareAudienceEvent(
  BuildContext context, {
  required String eventId,
  EventAudienceStatus? status,
  AuthSessionManager? sessions,
  AuthSession? expectedSession,
  VenueEventRepository? repository,
  EventAudienceRepository? audienceRepository,
  EventShareService? shareService,
  String? venueAvatarUrl,
}) async {
  final manager = sessions ?? _registered<AuthSessionManager>();
  final captured = expectedSession ?? manager?.session;
  final personal = status != null && status != EventAudienceStatus.none;
  bool sameSession() =>
      context.mounted &&
      manager != null &&
      captured != null &&
      identical(manager.session, captured) &&
      captured.isAuthenticated &&
      captured.isActive &&
      captured.userId?.trim().isNotEmpty == true &&
      (!personal || canUseEventAudience(captured));
  bool current() => sameSession() && ModalRoute.of(context)?.isCurrent == true;
  if (!current() ||
      eventId.trim().isEmpty ||
      _activeAudienceShares[context] == true) {
    return;
  }
  _activeAudienceShares[context] = true;
  final audience = audienceRepository ?? _registered<EventAudienceRepository>();
  int? validatedAudienceRevision;
  bool exportValid() =>
      sameSession() &&
      (!personal ||
          (audience != null &&
              validatedAudienceRevision == audience.changes.value));
  Future<bool> currentIntent() async {
    if (!personal) return current();
    if (!current() || audience == null) return false;
    final revision = audience.changes.value;
    final reply = await audience.getIntent(
      eventId: eventId.trim(),
      expectedSessionKey: captured!.userId!,
    );
    if (!context.mounted || !current()) return false;
    final state = reply.data;
    if (!reply.isSuccess ||
        state == null ||
        state.eventId != eventId.trim() ||
        state.intent != status ||
        audience.changes.value != revision ||
        !state.eventAvailable ||
        state.eventEnded) {
      _notice(
        context,
        'Etkinlik veya tercihin değişmiş. Yeniden kontrol edebilirsin.',
      );
      return false;
    }
    validatedAudienceRevision = revision;
    return true;
  }

  try {
    if (!await currentIntent()) return;
    final events = repository ?? _registered<VenueEventRepository>();
    // Event detail constructs the platform exporter locally as well. Production
    // does not register EventShareService in DI; tests may still inject one.
    final exporter = resolveAudienceShareService(shareService);
    if (events == null) throw StateError('Share unavailable');
    final reply = await events.getDetail(eventId.trim());
    if (!context.mounted || !current()) return;
    final detail = reply.data;
    if (!reply.isSuccess ||
        detail == null ||
        detail.id.trim() != eventId.trim()) {
      throw StateError('Event unavailable');
    }
    final prepared = await exporter.prepare(
      context,
      EventShareData.fromDetail(
        detail,
        venueAvatarUrl: venueAvatarUrl,
        audienceStatus: personal ? status : null,
      ),
    );
    if (!context.mounted || !current()) return;
    final target = await showEventShareSheet(
      context,
      prepared,
      validityChanges: manager,
      isValid: sameSession,
    );
    if (target == null || !current() || !await currentIntent()) return;
    if (!context.mounted || !current()) return;
    await exporter.share(context, prepared, target, isValid: exportValid);
  } catch (_) {
    if (context.mounted && current()) {
      _notice(
        context,
        'Paylaşım hazırlanamadı. Lütfen tekrar dene.',
        error: true,
      );
    }
  } finally {
    _activeAudienceShares[context] = false;
  }
}

T? _registered<T extends Object>() =>
    serviceLocator.isRegistered<T>() ? serviceLocator<T>() : null;

void _notice(BuildContext context, String text, {bool error = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: error ? AppSnackBarTone.error : AppSnackBarTone.info,
        content: Text(text),
      ),
    );
