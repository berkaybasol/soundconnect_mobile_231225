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

  /// Collab publishes and applies through the first-production profile types:
  /// musician (including owned bands), venue, and studio. Backstage roles that
  /// do not own one of those profiles must not discover the module.
  static const Set<String> collabRoles = {
    'ROLE_MUSICIAN',
    'ROLE_VENUE',
    'ROLE_STUDIO',
  };

  /// Table groups always act as the authenticated person. Venue and studio
  /// accounts must not create or apply to tables, including mixed-role
  /// sessions that contain either business role.
  static const Set<String> tableGroupMutationDeniedRoles = {
    'ROLE_VENUE',
    'ROLE_STUDIO',
  };

  static bool canAccessMainstage(List<String> roles) {
    return roles.isNotEmpty;
  }

  static bool canAccessBackstage(List<String> roles) {
    return roles.map(_normalizeRole).any(backstageRoles.contains);
  }

  static bool canAccessCollab(List<String> roles) {
    final normalized = roles.map(_normalizeRole).toSet();
    return !normalized.contains('ROLE_LISTENER') &&
        normalized.any(collabRoles.contains);
  }

  /// Each market participant acts through one current professional identity.
  /// Administrative authorities do not grant consumer access on their own.
  static bool canAccessMarketplace(List<String> roles) {
    final normalized = roles.map(_normalizeRole).toSet();
    final personalRoles = normalized.intersection(const {
      'ROLE_MUSICIAN',
      'ROLE_VENUE',
      'ROLE_STUDIO',
      'ROLE_LISTENER',
      'ROLE_ORGANIZER',
      'ROLE_PRODUCER',
    });
    return personalRoles.length == 1 &&
        collabRoles.contains(personalRoles.single);
  }

  static bool canCreateOrJoinTableGroups(List<String> roles) {
    return !roles
        .map(_normalizeRole)
        .any(tableGroupMutationDeniedRoles.contains);
  }

  static String _normalizeRole(String role) {
    final normalized = role.trim().toUpperCase();
    if (normalized.isEmpty || normalized.startsWith('ROLE_')) {
      return normalized;
    }
    return 'ROLE_$normalized';
  }
}
