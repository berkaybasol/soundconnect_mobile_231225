class DmBadgeState {
  final int unreadCount;
  final bool initialized;

  const DmBadgeState({required this.unreadCount, required this.initialized});

  const DmBadgeState.initial() : unreadCount = 0, initialized = false;

  DmBadgeState copyWith({int? unreadCount, bool? initialized}) {
    return DmBadgeState(
      unreadCount: unreadCount ?? this.unreadCount,
      initialized: initialized ?? this.initialized,
    );
  }
}
