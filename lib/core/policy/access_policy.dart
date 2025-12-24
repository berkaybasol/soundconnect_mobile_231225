class AccessPolicy {
  static const Set<String> backstageRoles = {
    'ROLE_OWNER',
    'ROLE_ADMIN',
    'ROLE_VENUE',
    'ROLE_MUSICIAN',
    'ROLE_STUDIO',
    'ROLE_ORGANIZER',
    'ROLE_PRODUCER',
  };

  static bool canAccessMainstage(List<String> roles) {
    return roles.isNotEmpty;
  }

  static bool canAccessBackstage(List<String> roles) {
    return roles.any(backstageRoles.contains);
  }
}
