import 'comment_item.dart';

class CommentPage {
  final List<CommentItem> items;
  final int totalElements;

  const CommentPage({
    required this.items,
    required this.totalElements,
  });
}
