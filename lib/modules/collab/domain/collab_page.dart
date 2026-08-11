class CollabPage<T> {
  const CollabPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  final List<T> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  bool get hasNext => !last;
  int? get nextPage => hasNext ? page + 1 : null;

  CollabPage<R> map<R>(R Function(T item) transform) => CollabPage<R>(
    items: items.map(transform).toList(growable: false),
    page: page,
    size: size,
    totalElements: totalElements,
    totalPages: totalPages,
    first: first,
    last: last,
  );
}
