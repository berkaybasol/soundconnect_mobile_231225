enum UserStatus {
  inactive,
  active,
  pendingVenueRequest,
  pendingStudioRequest,
  rejectedStudioRequest,
}

extension UserStatusParser on UserStatus {
  String get apiValue => switch (this) {
    UserStatus.inactive => 'INACTIVE',
    UserStatus.active => 'ACTIVE',
    UserStatus.pendingVenueRequest => 'PENDING_VENUE_REQUEST',
    UserStatus.pendingStudioRequest => 'PENDING_STUDIO_REQUEST',
    UserStatus.rejectedStudioRequest => 'REJECTED_STUDIO_REQUEST',
  };

  static UserStatus fromApi(String? value) {
    switch (value) {
      case 'ACTIVE':
        return UserStatus.active;
      case 'PENDING_VENUE_REQUEST':
        return UserStatus.pendingVenueRequest;
      case 'PENDING_STUDIO_REQUEST':
        return UserStatus.pendingStudioRequest;
      case 'REJECTED_STUDIO_REQUEST':
        return UserStatus.rejectedStudioRequest;
      case 'INACTIVE':
      default:
        return UserStatus.inactive;
    }
  }
}
