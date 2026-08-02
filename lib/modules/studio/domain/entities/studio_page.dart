class StudioPage<T> {
  final List<T> items;
  final int pageIndex;
  final int pageSize;
  final int totalItems;
  final int totalPages;
  final bool isFirst;
  final bool isLast;

  const StudioPage({
    required this.items,
    required this.pageIndex,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
    required this.isFirst,
    required this.isLast,
  });

  bool get hasNext => !isLast && pageIndex + 1 < totalPages;
  bool get hasPrevious => !isFirst && pageIndex > 0;
}
