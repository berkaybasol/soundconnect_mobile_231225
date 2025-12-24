class Page<T> {
  final List<T> items;
  final bool hasNext;
  final String? nextCursor;

  const Page({
    required this.items,
    required this.hasNext,
    this.nextCursor,
  });
}
