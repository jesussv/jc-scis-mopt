class PagedResult {
  PagedResult({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.items,
  });

  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final List<dynamic> items;

  factory PagedResult.fromJson(Map<String, dynamic> j) => PagedResult(
    page: (j['page'] ?? 1) as int,
    pageSize: (j['pageSize'] ?? 25) as int,
    total: (j['total'] ?? 0) as int,
    totalPages: (j['totalPages'] ?? 0) as int,
    items: (j['items'] as List<dynamic>? ?? const []),
  );
}
