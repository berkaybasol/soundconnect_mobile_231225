enum UserStatus { inactive, active, pendingVenueRequest }

extension UserStatusParser on UserStatus {
  String get apiValue => switch (this) {
    UserStatus.inactive => 'INACTIVE',
    UserStatus.active => 'ACTIVE',
    UserStatus.pendingVenueRequest => 'PENDING_VENUE_REQUEST',
  };

  static UserStatus fromApi(String? value) {
    switch (value) {
      case 'ACTIVE':
        return UserStatus.active;
      case 'PENDING_VENUE_REQUEST':
        return UserStatus.pendingVenueRequest;
      case 'INACTIVE':
      default:
        return UserStatus.inactive;
    }
  }
}
