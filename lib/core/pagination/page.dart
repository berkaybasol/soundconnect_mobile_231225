class Page<T> {
  final List<T> items;
  final bool hasNext;
  final String? nextCursor;
  final int? totalElements;

  const Page({
    required this.items,
    required this.hasNext,
    this.nextCursor,
    this.totalElements,
  });
}
