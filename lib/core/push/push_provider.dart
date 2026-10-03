enum PushPermission { authorized, provisional, denied, notDetermined }

extension PushPermissionApi on PushPermission {
  String get apiValue => switch (this) {
    PushPermission.authorized => 'AUTHORIZED',
    PushPermission.provisional => 'PROVISIONAL',
    PushPermission.denied => 'DENIED',
    PushPermission.notDetermined => 'NOT_DETERMINED',
  };
  bool get canDeliver =>
      this == PushPermission.authorized || this == PushPermission.provisional;
}

/// Contains identifiers only. Visible text and sender identity are never trusted
/// for navigation; the authenticated API supplies current conversation details.
class PushTarget {
  const PushTarget({
    required this.notificationId,
    required this.recipientId,
    required this.type,
    this.conversationId,
  });
  final String notificationId;
  final String recipientId;
  final String type;
  final String? conversationId;
  static const venueTypes = <String>{
    'ARTIST_VENUE_LINK_APPLICATION_REQUEST',
    'ARTIST_VENUE_LINK_APPLICATION_ACCEPT',
    'ARTIST_VENUE_LINK_APPLICATION_REJECT',
    'EVENT_PERFORMER_APPROVAL_REQUESTED',
    'EVENT_PERFORMER_APPROVED',
    'EVENT_PERFORMER_REJECTED',
  };
  static const venueApplicationTypes = <String>{
    'VENUE_APPLICATION_APPROVED',
    'VENUE_APPLICATION_REJECTED',
  };
  static const studioTypes = <String>{
    'STUDIO_RESERVATION_CREATED',
    'STUDIO_RESERVATION_CONFLICTING_REQUESTS',
    'STUDIO_RESERVATION_APPROVED',
    'STUDIO_RESERVATION_REJECTED',
    'STUDIO_RESERVATION_CANCELLED_BY_CUSTOMER',
    'STUDIO_RESERVATION_CANCELLED_BY_STUDIO',
  };
  static const followTypes = <String>{
    'SOCIAL_NEW_FOLLOWER',
    'SOCIAL_NEW_BAND_FOLLOWER',
  };
  static const mediaTypes = <String>{'SOCIAL_LIKE', 'SOCIAL_COMMENT'};
  static const bandTypes = <String>{
    'BAND_INVITE_RECEIVED', 'BAND_INVITE_ACCEPTED', 'BAND_INVITE_REJECTED',
    'BAND_MEMBER_REMOVED', 'BAND_MEMBER_LEFT',
  };
  static const tableTypes = <String>{
    'TABLE_JOIN_REQUEST_RECEIVED', 'TABLE_JOIN_REQUEST_APPROVED',
    'TABLE_JOIN_REQUEST_REJECTED', 'TABLE_PARTICIPANT_LEFT',
    'TABLE_REMOVED', 'TABLE_CANCELLED', 'TABLE_EXPIRED',
  };
  static const collabTypes = <String>{
    'COLLAB_APPLICATION_RECEIVED',
    'COLLAB_APPLICATION_ACCEPTED',
    'COLLAB_APPLICATION_REJECTED',
    'COLLAB_APPLICATION_WITHDRAWN',
    'COLLAB_APPLICATION_INVALIDATED',
    'COLLAB_LISTING_EXPIRED',
    'COLLAB_JOB_COMPLETION_REQUESTED',
    'COLLAB_JOB_COMPLETED',
    'COLLAB_REVIEW_RECEIVED',
    'COLLAB_LISTING_REMOVED',
    'COLLAB_REPORT_RESOLVED',
  };
  bool get isCollab => collabTypes.contains(type);
  static const overthinkingTypes = <String>{
    'OVERTHINKING_REVEAL_REQUEST_RECEIVED',
    'OVERTHINKING_REVEAL_REQUEST_APPROVED',
    'OVERTHINKING_REVEAL_REQUEST_REJECTED',
  };
  bool get isOverthinking => overthinkingTypes.contains(type);
  bool get isTable => tableTypes.contains(type);
  bool get isBand => bandTypes.contains(type);
  bool get isMedia => mediaTypes.contains(type);
  bool get isFollow => followTypes.contains(type);
  bool get isStudio => studioTypes.contains(type);
  bool get isVenue => venueTypes.contains(type);
  bool get isVenueApplication => venueApplicationTypes.contains(type);

  /// Only for metadata returned by the Android delivery channel after native
  /// wire, expiry and binding validation. Never use for RemoteMessage.data.
  static PushTarget? parseNativeMetadata(Map<String, dynamic> data) {
    if (overthinkingTypes.contains(data['type'])) {
      const identity = {'notificationId', 'recipientId', 'type'};
      if (data.length != identity.length ||
          !data.keys.toSet().containsAll(identity) ||
          !isUuid(data['notificationId']) || !isUuid(data['recipientId'])) {
        return null;
      }
      return PushTarget(
        notificationId: data['notificationId'] as String,
        recipientId: data['recipientId'] as String,
        type: data['type'] as String,
      );
    }
    return parse(data);
  }

  /// Untrusted Firebase wire data. The Overthinking family always requires its
  /// complete closed version/time envelope, including foreground and cold open.
  static PushTarget? parse(Map<String, dynamic> data, {int? nowMillis}) {
    final notification = data['notificationId'];
    final recipient = data['recipientId'];
    final type = data['type'];
    final conversation = data['conversationId'];
    if (!isUuid(notification) ||
        !isUuid(recipient) ||
        type is! String ||
        !RegExp(r'^[A-Z_]{1,100}$').hasMatch(type)) {
      return null;
    }
    if (type.startsWith('OVERTHINKING_') ||
        (data['presentationVersion'] is String &&
            (data['presentationVersion'] as String).startsWith('ANDROID_OVERTHINKING_'))) {
      if (!overthinkingTypes.contains(type) || conversation != null) return null;
      const identity = {'notificationId', 'recipientId', 'type'};
      const wire = {...identity, 'presentationVersion', 'sentAt', 'expiresAt'};
      final keys = data.keys.toSet();
      if (keys.length != wire.length || !keys.containsAll(wire) ||
          data['presentationVersion'] != 'ANDROID_OVERTHINKING_V1') {
        return null;
      }
      final sent = _positiveDecimalTimestamp(data['sentAt']);
      final expiry = _positiveDecimalTimestamp(data['expiresAt']);
      final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
      const ttl = Duration(days: 28);
      if (sent == null || expiry == null || now < 0 || sent - now > 5000 ||
          expiry <= now || expiry <= sent || expiry - sent > ttl.inMilliseconds ||
          expiry - now > ttl.inMilliseconds) {
        return null;
      }
      return PushTarget(notificationId: notification as String,
          recipientId: recipient as String, type: type);
    }
    if ((type.startsWith('COLLAB_') ||
            data['presentationVersion'] is String &&
                (data['presentationVersion'] as String).startsWith('ANDROID_COLLAB_')) &&
        !collabTypes.contains(type)) {
      return null;
    }
    if ((type.startsWith('TABLE_') ||
            data['presentationVersion'] is String &&
                (data['presentationVersion'] as String).startsWith('ANDROID_TABLE_')) &&
        !tableTypes.contains(type)) {
      return null;
    }
    if ((type.startsWith('BAND_') ||
            data['presentationVersion'] is String &&
                (data['presentationVersion'] as String).startsWith('ANDROID_BAND_')) &&
        !bandTypes.contains(type)) {
      return null;
    }
    if (conversation != null &&
        (venueTypes.contains(type) ||
            venueApplicationTypes.contains(type) ||
            studioTypes.contains(type) ||
            followTypes.contains(type) ||
            mediaTypes.contains(type) ||
            bandTypes.contains(type) ||
            tableTypes.contains(type) ||
            collabTypes.contains(type) ||
            !isUuid(conversation))) {
      return null;
    }
    if (followTypes.contains(type) || mediaTypes.contains(type) || bandTypes.contains(type) || tableTypes.contains(type) || collabTypes.contains(type)) {
      const identityFields = {'notificationId', 'recipientId', 'type'};
      const wireFields = {
        'presentationVersion',
        'displayVariant',
        'sentAt',
        'expiresAt',
      };
      if (data.keys.any(
        (key) => !identityFields.contains(key) && !wireFields.contains(key),
      )) {
        return null;
      }
      if (wireFields.any(data.containsKey)) {
        if ((bandTypes.contains(type) || tableTypes.contains(type) || collabTypes.contains(type)) &&
            wireFields.any((key) => data[key] is! String)) {
          return null;
        }
        if (!wireFields.every(data.containsKey) ||
            data['presentationVersion'] !=
                (collabTypes.contains(type)
                    ? 'ANDROID_COLLAB_V1'
                    : tableTypes.contains(type)
                    ? 'ANDROID_TABLE_V1'
                    : bandTypes.contains(type)
                    ? 'ANDROID_BAND_V1'
                    : mediaTypes.contains(type)
                    ? 'ANDROID_MEDIA_V1'
                    : 'ANDROID_FOLLOW_V1') ||
            (type == 'COLLAB_REPORT_RESOLVED'
                ? !const {'REMOVE_LISTING', 'DISMISS'}.contains(data['displayVariant'])
                : type == 'TABLE_CANCELLED'
                ? !const {'OWNER_CANCELLED', 'OWNER_JOINED_ANOTHER_TABLE'}.contains(data['displayVariant'])
                : data['displayVariant'] != 'DEFAULT')) {
          return null;
        }
        final followOrMedia = followTypes.contains(type) || mediaTypes.contains(type) || tableTypes.contains(type) || collabTypes.contains(type);
        final sent = followOrMedia
            ? _positiveDecimalTimestamp(data['sentAt'])
            : int.tryParse(data['sentAt'].toString());
        final expiry = followOrMedia
            ? _positiveDecimalTimestamp(data['expiresAt'])
            : int.tryParse(data['expiresAt'].toString());
        final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
        const maxTtl = Duration(days: 28);
        // Match native FOLLOW/MEDIA: bounded skew, unextended expiry, and both
        // remaining lifetime and actual wire lifetime. BAND keeps its contract.
        if (sent == null ||
            expiry == null ||
            sent <= 0 ||
            (followOrMedia && now < 0) ||
            sent - now > 5000 ||
            expiry <= now ||
            expiry <= sent ||
            expiry - sent > maxTtl.inMilliseconds ||
            (followOrMedia && expiry - now > maxTtl.inMilliseconds)) {
          return null;
        }
      }
    }
    return PushTarget(
      notificationId: notification as String,
      recipientId: recipient as String,
      type: type,
      conversationId: conversation as String?,
    );
  }

  // Long.toString emits this form. Requiring the string representation also
  // rejects whitespace, hex, signs, leading zeros, non-string values and overflow.
  static int? _positiveDecimalTimestamp(Object? value) {
    if (value is! String) return null;
    final parsed = int.tryParse(value);
    return parsed != null && parsed > 0 && parsed.toString() == value
        ? parsed
        : null;
  }

  static bool isUuid(Object? value) =>
      value is String &&
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value);
}

/// Native notification rendering must follow the active authenticated owner.
abstract interface class PushRecipientBindingProvider {
  Future<void> bindRecipient(String? recipientId);
}

class PushDeliveredSnapshot {
  const PushDeliveredSnapshot({
    required this.recipientId,
    required this.bindingEpoch,
    required this.notificationIds,
  });
  final String recipientId;
  final String bindingEpoch;
  final List<String> notificationIds;
}

/// An epoch fences a delayed response even across logout/login to the same user.
abstract interface class PushDeliveredProvider {
  Future<PushDeliveredSnapshot?> deliveredSnapshot(String recipientId);
  Future<void> dismissDelivered(
    PushDeliveredSnapshot snapshot,
    List<String> notificationIds,
  );
}

abstract interface class PushProvider {
  bool get supported;
  String get platform;
  Future<void> initialize();
  Future<PushPermission> permission({bool request = false});
  Future<String?> token();
  Future<void> deleteToken();
  Stream<String> get tokenRefresh;
  Stream<PushTarget> get opened;
  Stream<PushTarget> get foreground;
  Future<PushTarget?> initialMessage();
}
