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
    return roles.map(_normalizeRole).any(backstageRoles.contains);
  }

  static String _normalizeRole(String role) {
    final normalized = role.trim().toUpperCase();
    if (normalized.isEmpty || normalized.startsWith('ROLE_')) {
      return normalized;
    }
    return 'ROLE_$normalized';
  }
}
