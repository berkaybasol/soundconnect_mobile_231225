/// Profile-specific discovery feeds are shelved for the first release.
///
/// Keep the feed engine and its contracts available for a later rollout. This
/// build-time switch controls app entry points and feed initialization together;
/// it is deliberately not a user setting or a remotely toggled preference.
abstract final class ProfileFeedAvailability {
  static const bool enabled = bool.fromEnvironment(
    'SOUNDCONNECT_PROFILE_FEEDS_ENABLED',
    defaultValue: false,
  );
}
