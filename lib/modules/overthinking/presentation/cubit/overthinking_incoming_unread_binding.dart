import 'dart:async';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../notification/data/notification_realtime_client.dart';
import '../../domain/overthinking_repository.dart';
import 'overthinking_incoming_unread_scope.dart';

/// Profiles without an Overthinking repository (including isolated previews)
/// simply have no unread signal. Production DI owns this singleton's lifetime.
OverthinkingIncomingUnreadScope? findOverthinkingIncomingUnreadScope() {
  if (!serviceLocator.isRegistered<OverthinkingIncomingUnreadScope>()) {
    if (!serviceLocator.isRegistered<OverthinkingRepository>()) return null;
    serviceLocator.registerLazySingleton<OverthinkingIncomingUnreadScope>(
      _createScope,
      dispose: (scope) => scope.close(),
    );
  }
  final scope = serviceLocator<OverthinkingIncomingUnreadScope>();
  unawaited(scope.ensureStarted());
  return scope;
}

OverthinkingIncomingUnreadScope requireOverthinkingIncomingUnreadScope() =>
    findOverthinkingIncomingUnreadScope() ??
    (throw StateError('OverthinkingRepository is not registered'));

OverthinkingIncomingUnreadScope _createScope() {
  final realtime = serviceLocator.isRegistered<NotificationRealtimeClient>()
      ? serviceLocator<NotificationRealtimeClient>()
      : null;
  return OverthinkingIncomingUnreadScope(
    serviceLocator<OverthinkingRepository>(),
    sessions: serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null,
    notifications: realtime?.notificationStream,
    reconnections: realtime?.connectionStream,
    // Cancellation changes the notification badge without creating a new
    // notification. Its value is only a refresh signal, never an inbox count.
    invalidations: realtime?.badgeStream.map<void>((_) {}),
  );
}
