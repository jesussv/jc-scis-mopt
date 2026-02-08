import 'package:flutter/material.dart';
import '../../core/api.dart';
import 'products_api.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late final ProductsApi _svc = ProductsApi(widget.api);

  final _qCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  bool? _active;

  bool _loading = false;
  String? _error;
  List<dynamic> _items = [];
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _itemCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  String _pick(Map x, String a, String b) => (x[a] ?? x[b] ?? '').toString();

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.list(
        page: page,
        pageSize: 25,
        q: _qCtrl.text,
        itemId: _itemCtrl.text,
        barcode: _barcodeCtrl.text,
        active: _active,
      );

      setState(() {
        _page = (data['page'] as int?) ?? page;
        _totalPages = (data['totalPages'] as int?) ?? 1;
        _items = (data['items'] as List?) ?? [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createDialog() async {
    final itemCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final barCtrl = TextEditingController();
    bool active = true;
    bool saving = false;
    String? msg;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          Future<void> save() async {
            if (saving) return;

            final item = itemCtrl.text.trim();
            final name = nameCtrl.text.trim();
            final bar = barCtrl.text.trim();

            if (item.isEmpty || name.isEmpty) {
              setD(() => msg = 'ItemId y NameAlias son obligatorios');
              return;
            }

            setD(() {
              saving = true;
              msg = null;
            });

            try {
              await _svc.create(
                itemId: item,
                nameAlias: name,
                barcode: bar.isEmpty ? null : bar,
                active: active,
              );
              if (!mounted) return;
              Navigator.pop(ctx);
              await _load(1);
            } catch (e) {
              setD(() => msg = e.toString());
            } finally {
              setD(() => saving = false);
            }
          }

          return AlertDialog(
            title: const Text('Nuevo producto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'ItemId')),
                  const SizedBox(height: 8),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'NameAlias')),
                  const SizedBox(height: 8),
                  TextField(controller: barCtrl, decoration: const InputDecoration(labelText: 'Barcode (opcional)')),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activo'),
                    value: active,
                    onChanged: (v) => setD(() => active = v),
                  ),
                  if (msg != null) ...[
                    const SizedBox(height: 8),
                    Text(msg!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    itemCtrl.dispose();
    nameCtrl.dispose();
    barCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Nuevo', onPressed: _createDialog),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refrescar', onPressed: _loading ? null : () => _load(1)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(controller: _qCtrl, decoration: const InputDecoration(labelText: 'Buscar (q)')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _itemCtrl, decoration: const InputDecoration(labelText: 'ItemId'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _barcodeCtrl, decoration: const InputDecoration(labelText: 'Barcode'))),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<bool?>(
                  value: _active,
                  decoration: const InputDecoration(labelText: 'Activo'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    DropdownMenuItem(value: true, child: Text('Sí')),
                    DropdownMenuItem(value: false, child: Text('No')),
                  ],
                  onChanged: (v) => setState(() => _active = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _load(1),
                    child: const Text('Filtrar'),
                  ),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('Sin datos'))
                : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final x = Map<String, dynamic>.from(_items[i] as Map);

                final itemId = _pick(x, 'ItemId', 'itemid');
                final name = _pick(x, 'NameAlias', 'namealias');
                final barcode = _pick(x, 'Barcode', 'barcode');
                final active = _pick(x, 'Active', 'active');
                final created = _pick(x, 'CreatedDateTime', 'createddatetime');

                return ListTile(
                  title: Text('$itemId - $name'),
                  subtitle: Text(
                    'Barcode: ${barcode.isEmpty ? "-" : barcode} | Active: $active\nCreated: ${created.isEmpty ? "-" : created}',
                  ),
                  isThreeLine: true,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_loading || _page <= 1) ? null : () => _load(_page - 1),
                    child: const Text('Anterior'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_loading || _page >= _totalPages) ? null : () => _load(_page + 1),
                    child: const Text('Siguiente'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
