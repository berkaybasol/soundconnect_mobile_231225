import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_session.dart';
import 'auth_session_store.dart';
import 'jwt_claims.dart';
import 'token_store.dart';

typedef SessionEndedCallback = Future<void> Function();
typedef SessionExpiryTimerFactory =
    Timer Function(Duration duration, void Function() callback);

class AuthSessionManager extends ChangeNotifier {
  final TokenStore _tokenStore;
  final AuthSessionStore _sessionStore;
  final SessionEndedCallback? _onSessionEnded;
  final DateTime Function() _clock;
  final Duration _expirySafetyWindow;
  final SessionExpiryTimerFactory _expiryTimerFactory;

  AuthSessionManager({
    required TokenStore tokenStore,
    required AuthSessionStore sessionStore,
    SessionEndedCallback? onSessionEnded,
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

  Future<AuthSession> restore({Future<String?>? tokenOverride}) async {
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
      if (!isPreview) metadata = await _sessionStore.read();
    } catch (_) {
      token = null;
    }

    final restored = _sessionFromToken(
      token,
      metadata: metadata,
      requireListenerChoiceWhenMetadataMissing: !isPreview,
    );
    _setSession(restored);
    if (!restored.isAuthenticated && !isPreview) {
      await _clearCredentialsBestEffort();
    }
    return restored;
  }

  Future<void> startSession({
    required String token,
    required String? username,
    required String accountStatus,
    bool requiresListenerProfileChoice = false,
  }) async {
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

    // Metadata is written first; the token is the commit marker for restore.
    await _sessionStore.write(metadata);
    try {
      await _tokenStore.writeToken(token.trim());
    } catch (_) {
      // A failed commit must not leave an older token paired with new metadata.
      await _clearCredentialsBestEffort();
      rethrow;
    }
    _setSession(next);
  }

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
      await _restoreCurrentSessionMetadata();
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
      await _restoreCurrentSessionMetadata();
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
      await _restoreCurrentSessionMetadata();
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
        requiresListenerProfileChoice: true,
      ),
    );
    return true;
  }

  Future<void> _restoreCurrentSessionMetadata() async {
    final current = _session;
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

  Future<void> logout() => _terminateSession();

  Future<void> rejectUnauthorizedToken(String? rejectedToken) async {
    final rejected = rejectedToken?.trim() ?? '';
    if (rejected.isEmpty) return;
    String? current = _session.token?.trim();
    if (current == null || current.isEmpty) {
      try {
        current = await _tokenStore.readToken();
      } catch (_) {
        await _terminateSession();
        return;
      }
    }
    if (current?.trim() != rejected) return;
    await _terminateSession();
  }

  Future<void> _terminateSession() {
    final inFlight = _terminationInFlight;
    if (inFlight != null) return inFlight;

    final operation = _terminateSessionInternal();
    _terminationInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_terminationInFlight, operation)) {
        _terminationInFlight = null;
      }
    });
  }

  Future<void> _terminateSessionInternal() async {
    _setSession(const AuthSession.guest());
    await _clearCredentialsBestEffort();
    try {
      await _onSessionEnded?.call();
    } catch (_) {
      // Credentials are already gone; cleanup failures must not revive a session.
    }
  }

  Future<void> _clearCredentialsBestEffort() async {
    try {
      await _tokenStore.clear();
    } catch (_) {
      // In-memory logout must not depend on platform storage availability.
    }
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
    if (roles.isEmpty && metadata?.accountStatus == null) {
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
      accountStatus: metadata?.accountStatus ?? 'ACTIVE',
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
    unawaited(_terminateSession());
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    super.dispose();
  }
}
