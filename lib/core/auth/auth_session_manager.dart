import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_session.dart';
import 'auth_session_store.dart';
import 'jwt_claims.dart';
import 'token_store.dart';

typedef SessionEndedCallback = Future<void> Function();
typedef SessionAccessProbe =
    Future<void> Function(AuthSession session, int revision);
typedef SessionExpiryTimerFactory =
    Timer Function(Duration duration, void Function() callback);

class AuthSessionManager extends ChangeNotifier {
  final TokenStore _tokenStore;
  final AuthSessionStore _sessionStore;
  final SessionEndedCallback? _onSessionEnded;
  final DateTime Function() _clock;
  final Duration _expirySafetyWindow;
  final SessionExpiryTimerFactory _expiryTimerFactory;
  final SessionAccessProbe? verifyAccess;

  AuthSessionManager({
    required TokenStore tokenStore,
    required AuthSessionStore sessionStore,
    SessionEndedCallback? onSessionEnded,
    this.verifyAccess,
    DateTime Function()? clock,
    Duration expirySafetyWindow = const Duration(seconds: 30),
    SessionExpiryTimerFactory? expiryTimerFactory,
  }) : assert(!expirySafetyWindow.isNegative),
       _tokenStore = tokenStore,
       _sessionStore = sessionStore,
       _onSessionEnded = onSessionEnded,
       _clock = clock ?? DateTime.now,
       _expirySafetyWindow = expirySafetyWindow,
       _expiryTimerFactory = expiryTimerFactory ?? Timer.new;

  AuthSession _session = const AuthSession.guest();
  AuthSession get session => _session;

  Future<void>? _terminationInFlight;
  Timer? _expiryTimer;
  int _credentialIntent = 0;
  _TokenRotation? _rotation;

  /// True during the notification that installs a new bearer for the same login.
  bool get isRotatingCurrentLogin => _rotation?.installing == true;

  /// Changes before login/logout credential work, including guest-to-guest logout.
  int get credentialRevision => _credentialIntent;
  Future<void> _credentialWrites = Future<void>.value();

  Future<T> _serializeCredentials<T>(Future<T> Function() action) {
    final result = _credentialWrites.then((_) => action());
    _credentialWrites = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<AuthSession> restore({Future<String?>? tokenOverride}) async {
    final revision = _credentialIntent;
    final isPreview = tokenOverride != null;
    String? token;
    AuthSessionMetadata? metadata;
    try {
      token = isPreview
          ? await tokenOverride.timeout(
              const Duration(seconds: 2),
              onTimeout: () => null,
            )
          : await _tokenStore.readToken();
    } catch (_) {
      token = null;
    }
    if (!isPreview) {
      try {
        metadata = await _sessionStore.read();
      } catch (_) {
        token = null;
      }
    }

    if (_credentialIntent != revision) return _session;
    final restored = !isPreview && metadata?.accountStatus == 'SUSPENDED'
        ? const AuthSession.suspended()
        : _sessionFromToken(
            token,
            metadata: metadata,
            requireListenerChoiceWhenMetadataMissing: !isPreview,
          );
    _setSession(restored);
    if (!restored.isAuthenticated && !isPreview) {
      await _serializeCredentials(() async {
        if (_credentialIntent != revision) return;
        if (!restored.isSuspendedNotice) {
          await _clearCredentialsBestEffort();
        } else if (token != null) {
          await _clearTokenBestEffort();
        }
      });
    }
    return restored;
  }

  Future<void> startSession({
    required String token,
    required String? username,
    required String accountStatus,
    bool requiresListenerProfileChoice = false,
  }) async {
    final intent = ++_credentialIntent;
    // Credential stores belong to the terminating session until its cleanup
    // completes. Otherwise a late clear could erase a newly committed login.
    final termination = _terminationInFlight;
    if (termination != null) await termination;

    final metadata = AuthSessionMetadata(
      username: username,
      accountStatus: accountStatus,
      requiresListenerProfileChoice: requiresListenerProfileChoice,
    );
    final next = _sessionFromToken(token, metadata: metadata);
    if (!next.isAuthenticated) {
      await _clearCredentialsBestEffort();
      throw const FormatException('Invalid or expired access token');
    }

    await _serializeCredentials(() async {
      if (intent != _credentialIntent) throw StateError('Session superseded');
      // Metadata is written first; the token is the commit marker for restore.
      await _sessionStore.write(metadata);
      if (intent != _credentialIntent) throw StateError('Session superseded');
      try {
        await _tokenStore.writeToken(token.trim());
      } catch (_) {
        await _clearCredentialsBestEffort();
        rethrow;
      }
      if (intent != _credentialIntent) throw StateError('Session superseded');
      _setSession(next);
    });
  }

  /// Exchanges the current bearer without reviving a logout or a newer login.
  /// A parallel request may receive a 401 for the old bearer after the server
  /// commits and before its replacement arrives on this device.
  Future<bool> rotateAccessToken({
    required AuthSession expected,
    required int revision,
    required Future<String> Function() requestToken,
  }) async {
    bool current() =>
        _credentialIntent == revision &&
        _session.token == expected.token &&
        _session.userId == expected.userId;
    if (!expected.isAuthenticated || !current() || _rotation != null) {
      return false;
    }
    final rotation = _TokenRotation(expected.token!, revision);
    _rotation = rotation;
    var serverChanged = false;
    try {
      final token = await requestToken().timeout(const Duration(seconds: 45));
      serverChanged = true;
      return await _serializeCredentials(() async {
        if (!current()) return false;
        AuthSession renewed() {
          final next = _sessionFromToken(
            token,
            metadata: AuthSessionMetadata(
              username: _session.username,
              accountStatus: _session.accountStatus,
              requiresListenerProfileChoice:
                  _session.requiresListenerProfileChoice,
            ),
          );
          if (!next.isAuthenticated ||
              next.token == expected.token ||
              next.userId != expected.userId ||
              next.sessionScope != expected.sessionScope ||
              next.applicationId != expected.applicationId) {
            throw const FormatException('Invalid renewed session');
          }
          return next;
        }

        final prior = _session;
        final next = renewed();
        await _tokenStore.writeToken(next.token!);
        if (!current()) return false;
        final committed = identical(prior, _session) ? next : renewed();
        _credentialIntent++;
        rotation.installing =
            setEquals(committed.normalizedRoles, _session.normalizedRoles) &&
            setEquals(
              committed.permissions.toSet(),
              _session.permissions.toSet(),
            );
        _setSession(committed);
        rotation.installing = false;
        return true;
      });
    } finally {
      _rotation = null;
      if (current() && (serverChanged || rotation.rejected)) {
        await _terminateSession();
      }
    }
  }

  /// Only an authoritative approved application exchange may replace a limited
  /// bearer. The queue prevents a delayed secure write from overwriting logout
  /// or another login; identity checks prevent in-memory resurrection.
  Future<bool> promoteVenueApplication({
    required AuthSession expected,
    required String token,
    required String? username,
  }) => _serializeCredentials(() async {
    final intent = _credentialIntent;
    if (!identical(_session, expected) || !expected.isVenueApplicationSession) {
      return false;
    }
    final metadata = AuthSessionMetadata(
      username: username,
      accountStatus: 'ACTIVE',
    );
    final next = _sessionFromToken(token, metadata: metadata);
    if (!next.isAuthenticated ||
        !next.isActive ||
        next.sessionScope != null ||
        next.userId != expected.userId ||
        !next.hasAnyRole(const ['ROLE_VENUE']) ||
        next.requiresListenerProfileChoice) {
      throw const FormatException('Invalid approved application session');
    }
    await _sessionStore.write(metadata);
    if (!identical(_session, expected) || intent != _credentialIntent) {
      return false;
    }
    try {
      await _tokenStore.writeToken(token.trim());
    } catch (_) {
      // Restore the still-current restricted credential if commit failed.
      if (identical(_session, expected)) {
        await _tokenStore.writeToken(expected.token!);
        await _restoreCurrentSessionMetadata();
      }
      rethrow;
    }
    if (!identical(_session, expected) || intent != _credentialIntent) {
      return false;
    }
    _setSession(next);
    return true;
  });

  Future<bool> updateUsername(
    String username, {
    String? expectedUserId,
    String? expectedToken,
  }) async {
    if (username.isEmpty) {
      throw const FormatException('Username cannot be blank');
    }

    final current = _session;
    final currentToken = current.token?.trim();
    final expiresAt = current.expiresAt;
    if (!current.isAuthenticated ||
        currentToken == null ||
        currentToken.isEmpty ||
        expiresAt == null) {
      throw StateError('An authenticated session is required');
    }
    final currentUserId = current.userId?.trim();
    final requestedUserId = expectedUserId?.trim();
    final requestedToken = expectedToken?.trim();
    if ((requestedUserId != null &&
            requestedUserId.isNotEmpty &&
            requestedUserId != currentUserId) ||
        (requestedToken != null &&
            requestedToken.isNotEmpty &&
            requestedToken != currentToken)) {
      return false;
    }

    final metadata = AuthSessionMetadata(
      username: username,
      accountStatus: current.accountStatus,
      requiresListenerProfileChoice: current.requiresListenerProfileChoice,
    );
    await _sessionStore.write(metadata);

    // A logout or a different login may complete while secure storage is
    // writing. Never revive or mutate a session that is no longer current.
    if (_session.token?.trim() != currentToken ||
        _session.userId?.trim() != currentUserId) {
      await _serializeCredentials(_restoreCurrentSessionMetadata);
      return false;
    }

    _setSession(
      AuthSession.authenticated(
        token: currentToken,
        userId: current.userId,
        username: username,
        accountStatus: current.accountStatus,
        roles: current.roles,
        permissions: current.permissions,
        expiresAt: expiresAt,
        isAdmin: current.isAdmin,
        sessionScope: current.sessionScope,
        applicationId: current.applicationId,
        requiresListenerProfileChoice: current.requiresListenerProfileChoice,
      ),
    );
    return true;
  }

  /// Commits the local half of the server-authoritative listener onboarding
  /// transition. Identity checks prevent a late response from mutating a newer
  /// login that replaced the session while secure storage was writing.
  Future<bool> completeListenerProfileChoice({
    String? expectedUserId,
    String? expectedToken,
  }) async {
    final current = _session;
    final currentToken = current.token?.trim();
    final currentUserId = current.userId?.trim();
    if (!current.isAuthenticated ||
        currentToken == null ||
        currentToken.isEmpty ||
        !current.hasAnyRole(const <String>['ROLE_LISTENER', 'LISTENER'])) {
      throw StateError('An authenticated listener session is required');
    }

    final requestedUserId = expectedUserId?.trim();
    final requestedToken = expectedToken?.trim();
    if ((requestedUserId != null &&
            requestedUserId.isNotEmpty &&
            requestedUserId != currentUserId) ||
        (requestedToken != null &&
            requestedToken.isNotEmpty &&
            requestedToken != currentToken)) {
      return false;
    }
    if (!current.requiresListenerProfileChoice) return true;

    await _sessionStore.write(
      AuthSessionMetadata(
        username: current.username,
        accountStatus: current.accountStatus,
        requiresListenerProfileChoice: false,
      ),
    );

    if (_session.token?.trim() != currentToken ||
        _session.userId?.trim() != currentUserId) {
      await _serializeCredentials(_restoreCurrentSessionMetadata);
      return false;
    }

    _setSession(
      AuthSession.authenticated(
        token: currentToken,
        userId: current.userId,
        username: current.username,
        accountStatus: current.accountStatus,
        roles: current.roles,
        permissions: current.permissions,
        expiresAt: current.expiresAt!,
        isAdmin: current.isAdmin,
        sessionScope: current.sessionScope,
        applicationId: current.applicationId,
        requiresListenerProfileChoice: false,
      ),
    );
    return true;
  }

  /// Repairs stale or missing local onboarding metadata after the listener
  /// owner projection reports that no visibility choice has been completed.
  /// The server remains authoritative; the identity fence prevents a delayed
  /// storage write from changing a newer login.
  Future<bool> requireListenerProfileChoice({
    String? expectedUserId,
    String? expectedToken,
  }) async {
    final current = _session;
    final currentToken = current.token?.trim();
    final currentUserId = current.userId?.trim();
    if (!current.isAuthenticated ||
        currentToken == null ||
        currentToken.isEmpty ||
        !current.hasAnyRole(const <String>['ROLE_LISTENER', 'LISTENER'])) {
      throw StateError('An authenticated listener session is required');
    }

    final requestedUserId = expectedUserId?.trim();
    final requestedToken = expectedToken?.trim();
    if ((requestedUserId != null &&
            requestedUserId.isNotEmpty &&
            requestedUserId != currentUserId) ||
        (requestedToken != null &&
            requestedToken.isNotEmpty &&
            requestedToken != currentToken)) {
      return false;
    }
    if (current.requiresListenerProfileChoice) return true;

    await _sessionStore.write(
      AuthSessionMetadata(
        username: current.username,
        accountStatus: current.accountStatus,
        requiresListenerProfileChoice: true,
      ),
    );

    if (_session.token?.trim() != currentToken ||
        _session.userId?.trim() != currentUserId) {
      await _serializeCredentials(_restoreCurrentSessionMetadata);
      return false;
    }

    _setSession(
      AuthSession.authenticated(
        token: currentToken,
        userId: current.userId,
        username: current.username,
        accountStatus: current.accountStatus,
        roles: current.roles,
        permissions: current.permissions,
        expiresAt: current.expiresAt!,
        isAdmin: current.isAdmin,
        sessionScope: current.sessionScope,
        applicationId: current.applicationId,
        requiresListenerProfileChoice: true,
      ),
    );
    return true;
  }

  Future<void> _restoreCurrentSessionMetadata() async {
    final current = _session;
    if (current.isSuspendedNotice) {
      await _sessionStore.write(
        const AuthSessionMetadata(accountStatus: 'SUSPENDED'),
      );
      return;
    }
    if (!current.isAuthenticated) {
      await _sessionStore.clear();
      return;
    }
    await _sessionStore.write(
      AuthSessionMetadata(
        username: current.username,
        accountStatus: current.accountStatus,
        requiresListenerProfileChoice: current.requiresListenerProfileChoice,
      ),
    );
  }

  Future<void> logout() => _session.isSuspendedNotice
      ? _terminationInFlight ?? Future<void>.value()
      : _terminateSession();

  Future<void> suspendAccount({
    required int revision,
    required String? requestToken,
  }) {
    if (revision != _credentialIntent ||
        _session.token != requestToken ||
        _session.isSuspendedNotice) {
      return Future<void>.value();
    }
    return _terminateSession(suspended: true);
  }

  Future<void> dismissSuspension() async {
    if (!_session.isSuspendedNotice) return;
    // Keep the notice in place until its durable marker has finished writing.
    await _terminationInFlight;
    if (_session.isSuspendedNotice) await _terminateSession();
  }

  Future<void> rejectUnauthorizedToken(String? rejectedToken) async {
    if (_session.isSuspendedNotice) return;
    final revision = _credentialIntent;
    final rejected = rejectedToken?.trim() ?? '';
    if (rejected.isEmpty) return;
    final rotation = _rotation;
    if (rotation != null &&
        rotation.token == rejected &&
        rotation.revision == revision) {
      rotation.rejected = true;
      return;
    }
    String? current = _session.token?.trim();
    if (current == null || current.isEmpty) {
      try {
        current = await _tokenStore.readToken();
      } catch (_) {
        if (_credentialIntent == revision) await _terminateSession();
        return;
      }
    }
    if (_credentialIntent != revision || current?.trim() != rejected) return;
    await _terminateSession();
  }

  Future<void> _terminateSession({bool suspended = false}) {
    final inFlight = _terminationInFlight;
    if (inFlight != null) return inFlight;

    final operation = _terminateSessionInternal(suspended);
    _terminationInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_terminationInFlight, operation)) {
        _terminationInFlight = null;
      }
    });
  }

  Future<void> _terminateSessionInternal(bool suspended) async {
    _credentialIntent++;
    _setSession(
      suspended ? const AuthSession.suspended() : const AuthSession.guest(),
    );
    await _serializeCredentials(() async {
      if (!suspended) {
        await _clearCredentialsBestEffort();
        return;
      }
      // Write the marker first: a crash before token removal must still restore
      // the suspension screen. Neither operation depends on the other succeeding.
      try {
        await _sessionStore.write(
          const AuthSessionMetadata(accountStatus: 'SUSPENDED'),
        );
      } catch (_) {
        // Continue revocation if platform metadata storage is unavailable.
      }
      await _clearTokenBestEffort();
    });
    try {
      await _onSessionEnded?.call();
    } catch (_) {
      // Credentials are already gone; cleanup failures must not revive a session.
    }
  }

  Future<void> _clearTokenBestEffort() async {
    try {
      await _tokenStore.clear();
    } catch (_) {
      // In-memory logout must not depend on platform storage availability.
    }
  }

  Future<void> _clearCredentialsBestEffort() async {
    await _clearTokenBestEffort();
    try {
      await _sessionStore.clear();
    } catch (_) {
      // Both stores are attempted independently so one failure cannot block the other.
    }
  }

  AuthSession _sessionFromToken(
    String? token, {
    AuthSessionMetadata? metadata,
    bool requireListenerChoiceWhenMetadataMissing = true,
  }) {
    final raw = token?.trim() ?? '';
    final claims = JwtClaims.tryParse(
      raw,
      now: _clock(),
      clockSkew: _expirySafetyWindow,
    );
    if (claims == null) return const AuthSession.guest();

    // Identity and authorization always come from the signed JWT. Persisted
    // metadata is only for UX fields that the token does not carry.
    final roles = claims.roles;
    final permissions = claims.permissions;
    if (roles.isEmpty &&
        metadata?.accountStatus == null &&
        claims.sessionScope == null) {
      return const AuthSession.guest();
    }
    final normalizedRoles = roles.map((role) => role.toUpperCase()).toSet();
    final normalizedPermissions = permissions
        .map((permission) => permission.toUpperCase())
        .toSet();
    final inferredAdmin =
        normalizedRoles.contains('ROLE_OWNER') ||
        normalizedRoles.contains('ROLE_ADMIN') ||
        normalizedPermissions.contains('ADMIN_PANEL_ACCESS') ||
        normalizedPermissions.any(
          (permission) => permission.startsWith('MANAGE_'),
        );
    final isListener =
        normalizedRoles.contains('ROLE_LISTENER') ||
        normalizedRoles.contains('LISTENER');
    final requiresListenerProfileChoice =
        isListener &&
        ((metadata == null || !metadata.hasListenerProfileChoiceMarker)
            ? requireListenerChoiceWhenMetadataMissing
            : metadata.requiresListenerProfileChoice);

    return AuthSession.authenticated(
      token: raw,
      userId: claims.subject,
      username: metadata?.username,
      accountStatus: claims.sessionScope == 'VENUE_APPLICATION'
          ? 'PENDING_VENUE_REQUEST'
          : metadata?.accountStatus ?? 'ACTIVE',
      sessionScope: claims.sessionScope,
      applicationId: claims.applicationId,
      roles: roles,
      permissions: permissions,
      expiresAt: claims.expiresAt,
      isAdmin: inferredAdmin,
      requiresListenerProfileChoice: requiresListenerProfileChoice,
    );
  }

  void _setSession(AuthSession value) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _session = value;
    _scheduleExpiry(value);
    notifyListeners();
  }

  void _scheduleExpiry(AuthSession value) {
    final token = value.token?.trim();
    final expiresAt = value.expiresAt;
    if (!value.isAuthenticated || token == null || expiresAt == null) return;

    final deadline = expiresAt.toUtc().subtract(_expirySafetyWindow);
    final delay = deadline.difference(_clock().toUtc());
    if (delay <= Duration.zero) {
      scheduleMicrotask(() => _expireSessionIfCurrent(token));
      return;
    }
    _expiryTimer = _expiryTimerFactory(
      delay,
      () => _expireSessionIfCurrent(token),
    );
  }

  void _expireSessionIfCurrent(String expectedToken) {
    if (_session.token?.trim() != expectedToken) return;
    unawaited(rejectUnauthorizedToken(expectedToken));
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    super.dispose();
  }
}

class _TokenRotation {
  _TokenRotation(this.token, this.revision);

  final String token;
  final int revision;
  bool rejected = false;
  bool installing = false;
}
