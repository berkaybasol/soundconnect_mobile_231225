import 'comment_item.dart';

class CommentPage {
  final List<CommentItem> items;
  final int totalElements;
  final int page;
  final int size;

  const CommentPage({
    required this.items,
    required this.totalElements,
    this.page = 0,
    this.size = 20,
  });

  bool get hasMore => page < 1000 && (page + 1) * size < totalElements;
}
