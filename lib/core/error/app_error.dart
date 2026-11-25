class AppError {
  static const accountSuspended = '1119';
  final String code;
  final String message;
  final List<String> details;

  bool get isInteractionUnavailable =>
      code == '1120' || code == 'USER_INTERACTION_UNAVAILABLE';

  bool get isProfileUnavailable =>
      code == '1301' ||
      code == 'PROFILE_NOT_FOUND' ||
      code == '404' ||
      code == '403';

  /// Optional server cooldown, bounded by the transport before exposure.
  final Duration? retryAfter;

  const AppError({
    required this.code,
    required this.message,
    this.details = const [],
    this.retryAfter,
  });
}
