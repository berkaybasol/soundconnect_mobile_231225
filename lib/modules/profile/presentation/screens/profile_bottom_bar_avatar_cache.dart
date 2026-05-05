class ProfileBottomBarAvatarCache {
  static String? _lastProfileImageUrl;

  static String? get lastProfileImageUrl => _lastProfileImageUrl;

  static void remember(String? imageUrl) {
    final trimmed = imageUrl?.trim() ?? '';
    if (trimmed.isEmpty) return;
    _lastProfileImageUrl = trimmed;
  }
}
