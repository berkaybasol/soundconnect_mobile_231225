class CommentLikeState {
  const CommentLikeState({required this.likeCount, required this.likedByMe});

  final int likeCount;
  final bool likedByMe;

  factory CommentLikeState.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid comment like state');
    }
    final count = raw['likeCount'];
    final liked = raw['likedByMe'];
    if (count is! int ||
        count < 0 ||
        count > 9007199254740991 ||
        liked is! bool ||
        (liked && count == 0)) {
      throw const FormatException('Invalid comment like state');
    }
    return CommentLikeState(likeCount: count, likedByMe: liked);
  }
}
