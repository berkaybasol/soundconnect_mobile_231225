part of 'push_coordinator_test.dart';

class _Tokens implements TokenStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessionStore implements AuthSessionStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Provider
    implements
        PushProvider,
        PushRecipientBindingProvider,
        PushDeliveredProvider {
  _Provider(this.operations);
  final List<String> operations;
  int initialized = 0, permissionRequests = 0, tokenReads = 0;
  bool failInitialize = false, failDelete = false;
  String currentToken = 'first';
  Completer<void>? initializeBlock;
  final initializeStarted = Completer<void>();
  Completer<String?>? tokenBlock;
  final tokenStarted = Completer<void>();
  PushPermission allowed = PushPermission.authorized;
  PushTarget? initial;
  String? boundRecipient;
  String bindingEpoch = userB;
  int epochRevision = 0;
  bool failSnapshot = false;
  Completer<void>? snapshotGate, snapshotReached;
  final bindings = <String?>[];
  List<String> deliveredIds = [], dismissedIds = [];
  @override
  Future<PushDeliveredSnapshot?> deliveredSnapshot(String recipientId) async {
    if (snapshotReached?.isCompleted == false) snapshotReached!.complete();
    await snapshotGate?.future;
    if (failSnapshot) throw StateError('native state');
    return boundRecipient == recipientId
        ? PushDeliveredSnapshot(
            recipientId: recipientId,
            bindingEpoch: bindingEpoch,
            notificationIds: List.of(deliveredIds),
          )
        : null;
  }

  @override
  Future<void> dismissDelivered(
    PushDeliveredSnapshot snapshot,
    List<String> notificationIds,
  ) async {
    if (snapshot.recipientId != boundRecipient ||
        snapshot.bindingEpoch != bindingEpoch) {
      return;
    }
    dismissedIds = notificationIds;
    deliveredIds.removeWhere(notificationIds.contains);
  }

  @override
  Future<void> bindRecipient(String? recipientId) async {
    bindings.add(recipientId);
    if (recipientId == null || boundRecipient != recipientId) {
      deliveredIds.clear();
      bindingEpoch =
          '30000000-0000-4000-8000-${(++epochRevision).toString().padLeft(12, '0')}';
    }
    boundRecipient = recipientId;
  }

  final refresh = StreamController<String>.broadcast();
  final opens = StreamController<PushTarget>.broadcast();
  final messages = StreamController<PushTarget>.broadcast();
  @override
  bool get supported => true;
  String currentPlatform = 'ANDROID';
  @override
  String get platform => currentPlatform;
  @override
  Future<void> initialize() async {
    initialized++;
    if (!initializeStarted.isCompleted) initializeStarted.complete();
    await initializeBlock?.future;
    if (failInitialize) throw StateError('configuration');
  }

  @override
  Future<PushPermission> permission({bool request = false}) async {
    if (request) permissionRequests++;
    return allowed;
  }

  @override
  Future<String?> token() async {
    tokenReads++;
    if (!tokenStarted.isCompleted) tokenStarted.complete();
    if (tokenBlock != null) return tokenBlock!.future;
    return currentToken;
  }

  @override
  Future<void> deleteToken() async {
    operations.add('deleteToken');
    boundRecipient = null;
    if (failDelete) throw StateError('offline');
  }

  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Stream<PushTarget> get opened => opens.stream;
  @override
  Stream<PushTarget> get foreground => messages.stream;
  @override
  Future<PushTarget?> initialMessage() async => initial;
  Future<void> close() async {
    await refresh.close();
    await opens.close();
    await messages.close();
  }
}

class _Api implements PushDeviceApi {
  _Api(this.operations);
  final List<String> operations;
  final registrations = <String>[], installations = <String>[];
  final revisions = <int>[];
  final started = Completer<void>();
  Completer<void>? block;
  bool failRevoke = false;
  @override
  Future<void> register({
    required AuthSession session,
    required String installationId,
    required int clientRevision,
    required String token,
    required String platform,
    required PushPermission permission,
  }) async {
    if (!started.isCompleted) started.complete();
    await block?.future;
    registrations.add('${session.userId}:$token');
    installations.add(installationId);
    revisions.add(clientRevision);
    operations.add('register:${session.userId}');
  }

  @override
  Future<void> revoke({
    required AuthSession session,
    required String installationId,
    required int clientRevision,
  }) async {
    revisions.add(clientRevision);
    operations.add('revoke:${session.userId}');
    if (failRevoke) throw StateError('offline');
  }

  @override
  Future<PushPreferences> preferences(AuthSession session) async =>
      const PushPreferences(enabled: true);
  @override
  Future<void> savePreferences(
    AuthSession session,
    PushPreferences preferences,
  ) async {}
}

class _DeliveredApi implements PushDeliveryApi {
  Set<String>? selected;
  @override
  Future<Set<String>> dismissedIds(
    AuthSession session,
    List<String> notificationIds,
  ) async => selected ?? notificationIds.toSet();
}

class _Store implements PushInstallationStore, PushBindingContextStore {
  String? context;
  Completer<void>? contextGate, contextReached;
  @override
  Future<String?> bindingContext() async => context;
  @override
  Future<void> setBindingContext(String value) async {
    if (contextReached?.isCompleted == false) contextReached!.complete();
    await contextGate?.future;
    context = value;
  }

  String? owner;
  bool reset = false;
  bool failResetWrite = false, failMutation = false;
  bool failOwnerRead = false, failResetRead = false;
  Completer<void>? ownerReadGate,
      ownerReadReached,
      resetReadGate,
      resetReadReached;
  int revision = 0;
  @override
  Future<PushInstallationMutation> nextMutation() async {
    if (failMutation) throw StateError('storage');
    return PushInstallationMutation('installation', ++revision);
  }

  @override
  Future<String> installationId() async => 'installation';
  @override
  Future<String?> ownerId() async {
    if (ownerReadReached?.isCompleted == false) ownerReadReached!.complete();
    await ownerReadGate?.future;
    if (failOwnerRead) throw StateError('owner storage');
    return owner;
  }

  @override
  Future<void> setOwnerId(String? value) async {
    owner = value;
  }

  @override
  Future<bool> resetRequired() async {
    if (resetReadReached?.isCompleted == false) resetReadReached!.complete();
    await resetReadGate?.future;
    if (failResetRead) throw StateError('reset storage');
    return reset;
  }

  @override
  Future<void> setResetRequired(bool value) async {
    if (failResetWrite) throw StateError('storage');
    reset = value;
  }
}

// Fault-injection fake intentionally exposes mutable state for storage failures.
// ignore: must_be_immutable
class _Preferences extends Fake implements SharedPreferencesAsync {
  String? owner;
  bool reset = false, failResetWrite = false;
  @override
  Future<String?> getString(String key) async => owner;
  @override
  Future<void> setString(String key, String value) async {
    owner = value;
  }

  @override
  Future<void> remove(String key) async {
    owner = null;
  }

  @override
  Future<bool?> getBool(String key) async => reset;
  @override
  Future<void> setBool(String key, bool value) async {
    if (failResetWrite) throw StateError('storage');
    reset = value;
  }
}

String _jwt(String user, {bool expired = false, bool listener = false}) {
  final expiration = DateTime.now().toUtc().add(
    Duration(days: expired ? -1 : 1),
  );
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': user,
            'exp': expiration.millisecondsSinceEpoch ~/ 1000,
            'roles': [listener ? 'ROLE_LISTENER' : 'ROLE_MUSICIAN'],
          }),
        ),
      )
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

class _RestoringTokens implements TokenStore {
  _RestoringTokens(this.value);
  final Future<String?> value;
  @override
  Future<String?> readToken() => value;
  @override
  Future<void> writeToken(String token) async {}
  @override
  Future<void> clear() async {}
}

class _RestoringMetadata implements AuthSessionStore {
  _RestoringMetadata({
    this.metadata = const AuthSessionMetadata(accountStatus: 'ACTIVE'),
  });
  final AuthSessionMetadata metadata;
  @override
  Future<AuthSessionMetadata?> read() async => metadata;
  @override
  Future<void> write(AuthSessionMetadata metadata) async {}
  @override
  Future<void> clear() async {}
}
