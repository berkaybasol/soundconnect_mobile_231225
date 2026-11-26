import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/error/app_error.dart';
import '../../auth/domain/entities/user_status.dart';
import 'admin_panel_access.dart';
import 'pending_application.dart';

bool canReadAdminUsers(AuthSession session) =>
    hasAdminPanelPermission(session, 'READ_USERS');

const adminUsersAccessError = AppError(
  code: 'admin_users_access_changed',
  message: 'Kullanıcıları görüntüleme yetkin veya oturumun değişti.',
);

bool isAdminUsersAccessError(AppError? error) =>
    isAdminPanelAccessError(error) ||
    error?.code.toLowerCase() == adminUsersAccessError.code;

enum AdminUserProfileType {
  listener('Dinleyici'),
  musician('Müzisyen'),
  venue('Mekân'),
  studio('Stüdyo');

  const AdminUserProfileType(this.label);
  final String label;
  String get wire => name.toUpperCase();

  static AdminUserProfileType parse(Object? value) =>
      values.firstWhere((type) => type.wire == value);
}

typedef AdminUserStatus = UserStatus;

class MemberPreferenceCounts {
  const MemberPreferenceCounts({
    required this.granted,
    required this.denied,
    required this.undecided,
    required this.asOf,
  });

  final int granted;
  final int denied;
  final int undecided;
  final DateTime asOf;

  factory MemberPreferenceCounts.fromJson(Object? value) {
    final json = value as Map;
    int count(String field) {
      final value = json[field];
      if (value is int && value >= 0) return value;
      throw FormatException('Invalid preference count: $field');
    }

    return MemberPreferenceCounts(
      granted: count('granted'),
      denied: count('denied'),
      undecided: count('undecided'),
      asOf: DateTime.parse(json['asOf'] as String),
    );
  }
}

extension AdminUserStatusLabel on UserStatus {
  String get wire => apiValue;
  String get label => switch (this) {
    UserStatus.active => 'Aktif',
    UserStatus.inactive => 'Pasif',
    UserStatus.pendingVenueRequest => 'Mekân adayı',
    UserStatus.pendingStudioRequest => 'Stüdyo adayı',
    UserStatus.rejectedStudioRequest => 'Stüdyo başvurusu reddedilmiş',
  };
}

String _uuid(Object? value) {
  if (value is! String || !Uuid.isValidUUID(fromString: value)) {
    throw const FormatException('Invalid account directory identity');
  }
  return value;
}

class AdminUserAccount {
  const AdminUserAccount({
    required this.userId,
    required this.username,
    required this.profileType,
    required this.status,
    this.suspended = false,
  });

  final String userId;
  final String username;
  final AdminUserProfileType profileType;
  final AdminUserStatus status;
  final bool suspended;

  factory AdminUserAccount.fromJson(Object? value) {
    final json = value as Map;
    final username = json['username'] as String;
    if (username.trim().isEmpty) {
      throw const FormatException('Missing username');
    }
    return AdminUserAccount(
      userId: _uuid(json['userId']),
      username: username,
      profileType: AdminUserProfileType.parse(json['profileType']),
      suspended: json['suspended'] as bool? ?? false,
      status: UserStatus.values.firstWhere(
        (status) => status.apiValue == json['status'],
      ),
    );
  }
}

class AdminUserDetail {
  const AdminUserDetail({
    required this.account,
    this.createdAt,
    required this.emailVerified,
    required this.publicCode,
    this.lastApplicationStatus,
    this.profileId,
    this.accessRevision,
    this.canManageAccess = false,
    this.lastAccessDecision,
  });

  final AdminUserAccount account;
  final String publicCode;
  final DateTime? createdAt;
  final bool emailVerified;
  final ApplicationReviewStatus? lastApplicationStatus;
  final String? profileId;
  final int? accessRevision;
  final bool canManageAccess;
  final AdminAccountDecision? lastAccessDecision;

  factory AdminUserDetail.fromJson(Object? value, {bool allowChanges = true}) {
    final json = value as Map;
    final account = AdminUserAccount.fromJson(json);
    final target = json['profileTarget'] as Map?;
    if (target != null && target['type'] != account.profileType.wire) {
      throw const FormatException('Unexpected account profile type');
    }
    final application = json['lastApplicationStatus'];
    final createdAt = json['createdAt'] as String?;
    final publicCode = json['publicCode'] as String;
    if (publicCode.trim().isEmpty) {
      throw const FormatException('Missing account public code');
    }
    final revision = json['accessRevision'] as int?;
    final decision = json['lastAccessDecision'] == null
        ? null
        : AdminAccountDecision.fromJson(json['lastAccessDecision'] as Map);
    if (revision != null &&
        (revision < 0 ||
            json['suspended'] is! bool ||
            json['canManageAccess'] is! bool ||
            (revision == 0 && (account.suspended || decision != null)) ||
            (revision > 0 &&
                (decision == null ||
                    decision.suspended != account.suspended)))) {
      throw const FormatException('Inconsistent account access decision');
    }
    return AdminUserDetail(
      account: account,
      createdAt: createdAt == null ? null : DateTime.parse(createdAt),
      emailVerified: json['emailVerified'] as bool,
      publicCode: publicCode,
      lastApplicationStatus: application == null
          ? null
          : ApplicationReviewStatus.parse(application),
      profileId: target == null ? null : _uuid(target['profileId']),
      accessRevision: revision,
      canManageAccess:
          revision != null && allowChanges && json['canManageAccess'] == true,
      lastAccessDecision: decision,
    );
  }
}

class AdminAccountDecision {
  const AdminAccountDecision(
    this.suspended,
    this.reason,
    this.actorUsername,
    this.decidedAt,
  );

  final bool suspended;
  final String reason;
  final String actorUsername;
  final DateTime decidedAt;

  factory AdminAccountDecision.fromJson(Map json) => AdminAccountDecision(
    json['suspended'] as bool,
    json['reason'] as String,
    json['actorUsername'] as String,
    DateTime.parse(json['decidedAt'] as String),
  );
}
