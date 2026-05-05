enum StageMode {
  mainstage,
  backstage,
}

class StageModeResolver {
  static const Set<String> _backstageRoles = {
    'ROLE_OWNER',
    'ROLE_ADMIN',
    'ROLE_VENUE',
    'VENUE',
    'ROLE_MUSICIAN',
    'MUSICIAN',
    'ROLE_STUDIO',
    'STUDIO',
    'ROLE_ORGANIZER',
    'ORGANIZER',
    'ROLE_PRODUCER',
    'PRODUCER',
  };

  static StageMode fromRoles(List<String> roles) {
    final normalized = roles.map((role) => role.trim().toUpperCase()).toSet();
    if (normalized.any(_backstageRoles.contains)) {
      return StageMode.backstage;
    }
    return normalized.contains('ROLE_LISTENER') ||
            normalized.contains('LISTENER')
        ? StageMode.mainstage
        : StageMode.backstage;
  }
}
