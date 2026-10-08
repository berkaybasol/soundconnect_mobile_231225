import 'comment_user_summary.dart';

class LikeUserPage {
  final List<CommentUserSummary> items;
  final String? nextCursor;
  final bool hasMore;

  const LikeUserPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });
}
