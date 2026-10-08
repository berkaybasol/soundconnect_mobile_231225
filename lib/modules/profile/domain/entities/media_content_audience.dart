abstract final class MediaContentAudience {
  static const mainstage = 'MAINSTAGE';
  static const backstage = 'BACKSTAGE';

  static bool isValid(String value) => value == mainstage || value == backstage;

  static bool canChoose(String ownerType) => const {
    'MUSICIAN_PROFILE',
    'VENUE_PROFILE',
    'BAND',
  }.contains(ownerType.trim().toUpperCase());

  static String forOwner(String ownerType, String requested) =>
      switch (ownerType.trim().toUpperCase()) {
        'STUDIO_PROFILE' => backstage,
        'LISTENER_PROFILE' => mainstage,
        _ => requested,
      };

  static String label(String value) =>
      value == backstage ? 'Yalnız sektör içi' : 'Dinleyiciler dahil herkes';
}
