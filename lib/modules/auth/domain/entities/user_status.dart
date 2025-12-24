enum UserStatus {
  inactive,
  active,
  pendingVenueRequest,
}

extension UserStatusParser on UserStatus {
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
