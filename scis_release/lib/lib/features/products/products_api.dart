import '../../core/api.dart';

class ProductsApi {
  final ApiClient api;
  ProductsApi(this.api);

  Future<Map<String, dynamic>> list({
    int page = 1,
    int pageSize = 25,
    String? q,
    String? itemId,
    String? barcode,
    bool? active,
  }) async {
    final data = await api.get('/products', query: {
      'page': page,
      'pageSize': pageSize,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (itemId != null && itemId.trim().isNotEmpty) 'itemId': itemId.trim(),
      if (barcode != null && barcode.trim().isNotEmpty) 'barcode': barcode.trim(),
      if (active != null) 'active': active,
    });

    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> create({
    required String itemId,
    required String nameAlias,
    String? barcode,
    bool active = true,
  }) async {
    await api.post('/products', data: {
      'itemId': itemId.trim(),
      'nameAlias': nameAlias.trim(),
      'barcode': (barcode == null || barcode.trim().isEmpty) ? null : barcode.trim(),
      'active': active,
    });
  }
}
