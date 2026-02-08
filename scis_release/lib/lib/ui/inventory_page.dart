import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/models.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Stock'),
            Tab(text: 'Movimiento'),
            Tab(text: 'Transacciones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _StockTab(api: widget.api),
          _MovementTab(api: widget.api),
          _TransTab(api: widget.api),
        ],
      ),
    );
  }
}

/// Helpers para leer keys en minúscula/mayúscula (Dapper puede variar)
dynamic _pickAny(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    if (m.containsKey(k)) return m[k];
  }
  return null;
}

String _pickStr(Map<String, dynamic> m, List<String> keys, {String fallback = ''}) {
  final v = _pickAny(m, keys);
  if (v == null) return fallback;
  return v.toString();
}

double _pickNum(Map<String, dynamic> m, List<String> keys, {double fallback = 0}) {
  final v = _pickAny(m, keys);
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

// -------------------- STOCK TAB --------------------

class _StockTab extends StatefulWidget {
  const _StockTab({required this.api});
  final ApiClient api;

  @override
  State<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<_StockTab> {
  final _item = TextEditingController();
  final _loc = TextEditingController();
  int _page = 1;
  PagedResult? _data;
  bool _loading = false;
  String? _err;

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final j = await widget.api.getJson<Map<String, dynamic>>(
        '/inventory/stock',
        auth: true,
        query: {
          'itemId': _item.text.trim(),
          'inventLocationId': _loc.text.trim(),
          'page': page ?? _page,
          'pageSize': 50,
        },
      );
      final pr = PagedResult.fromJson(j);
      if (!mounted) return;
      setState(() {
        _data = pr;
        _page = pr.page;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load(page: 1);
  }

  @override
  void dispose() {
    _item.dispose();
    _loc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _data?.items ?? const [];
    final totalPages = _data?.totalPages ?? 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [

              TextField(controller: _item, decoration: const InputDecoration(labelText: 'Producto')),
              const SizedBox(height: 8),
              TextField(controller: _loc, decoration: const InputDecoration(labelText: 'Bodega Id')),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : () => _load(page: 1),
                  child: const Text('Aplicar filtros'),
                ),
              ),
            ],
          ),
        ),
        if (_err != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_err!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: _loading && _data == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemBuilder: (_, i) {
              final it = Map<String, dynamic>.from(items[i] as Map);
              final itemId = _pickStr(it, ['itemid', 'ItemId']);
              final name = _pickStr(it, ['namealias', 'NameAlias']);
              final locId = _pickStr(it, ['inventlocationid', 'InventLocationId']);
              final locName = _pickStr(it, ['inventlocationname', 'InventLocationName'], fallback: '-');
              final qty = _pickNum(it, ['availphysical', 'AvailPhysical'], fallback: 0);

              return Card(
                elevation: 0,
                child: ListTile(
                  title: Text(
                    '$itemId - $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Bodega: $locId ($locName)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    qty.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Column(
            children: [
              Text('Página $_page de $totalPages'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (_loading || _page <= 1) ? null : () => _load(page: _page - 1),
                      child: const Text('Anterior'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (_loading || _page >= totalPages) ? null : () => _load(page: _page + 1),
                      child: const Text('Siguiente'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------- MOVEMENT TAB (Dropdowns + Disponible) --------------------

class _MovementTab extends StatefulWidget {
  const _MovementTab({required this.api});
  final ApiClient api;

  @override
  State<_MovementTab> createState() => _MovementTabState();
}

class _MovementTabState extends State<_MovementTab> {
  bool _loadingLists = true;
  String? _listsErr;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _locations = [];

  String? _selectedItemId;
  String? _selectedLocId;

  bool _loadingAvail = false;
  double? _availableQty;

  final _qty = TextEditingController(text: '');
  final _reason = TextEditingController();
  final _voucher = TextEditingController();
  String _type = 'IN';

  bool _posting = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _loadDropdownLists();
  }

  @override
  void dispose() {
    _qty.dispose();
    _reason.dispose();
    _voucher.dispose();
    super.dispose();
  }

  Future<void> _loadDropdownLists() async {
    setState(() {
      _loadingLists = true;
      _listsErr = null;
    });

    try {
      final prod = await widget.api.getJson<Map<String, dynamic>>(
        '/products',
        auth: true,
        query: {'page': 1, 'pageSize': 200, 'active': true},
      );
      final locs = await widget.api.getJson<Map<String, dynamic>>(
        '/inventLocations',
        auth: true,
        query: {'page': 1, 'pageSize': 200, 'active': true},
      );

      final prodItems = (prod['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final locItems = (locs['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      String? defaultItem;
      String? defaultLoc;

      if (prodItems.isNotEmpty) {
        defaultItem = _pickStr(prodItems.first, ['itemid', 'ItemId'], fallback: '');
      }
      if (locItems.isNotEmpty) {
        defaultLoc = _pickStr(locItems.first, ['inventlocationid', 'InventLocationId'], fallback: '');
      }

      if (!mounted) return;
      setState(() {
        _products = prodItems;
        _locations = locItems;
        _selectedItemId = (defaultItem == null || defaultItem!.isEmpty) ? null : defaultItem;
        _selectedLocId = (defaultLoc == null || defaultLoc!.isEmpty) ? null : defaultLoc;
        _loadingLists = false;
      });

      await _refreshAvailable();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listsErr = e.toString();
        _loadingLists = false;
      });
    }
  }

  Future<void> _refreshAvailable() async {
    final itemId = _selectedItemId;
    final locId = _selectedLocId;
    if (itemId == null || itemId.isEmpty || locId == null || locId.isEmpty) {
      setState(() => _availableQty = null);
      return;
    }

    setState(() {
      _loadingAvail = true;
      _availableQty = null;
    });

    try {
      final j = await widget.api.getJson<Map<String, dynamic>>(
        '/inventory/stock',
        auth: true,
        query: {
          'itemId': itemId,
          'inventLocationId': locId,
          'page': 1,
          'pageSize': 1,
        },
      );

      final items = (j['items'] as List? ?? const []);
      double qty = 0;
      if (items.isNotEmpty) {
        final row = Map<String, dynamic>.from(items.first as Map);
        qty = _pickNum(row, ['availphysical', 'AvailPhysical'], fallback: 0);
      }

      if (!mounted) return;
      setState(() => _availableQty = qty);
    } catch (_) {
      if (!mounted) return;
      setState(() => _availableQty = 0);
    } finally {
      if (!mounted) return;
      setState(() => _loadingAvail = false);
    }
  }

  Future<void> _postMovement() async {
    setState(() {
      _posting = true;
      _msg = null;
    });

    try {
      final itemId = _selectedItemId;
      final locId = _selectedLocId;

      if (itemId == null || itemId.isEmpty) throw Exception('Selecciona un producto');
      if (locId == null || locId.isEmpty) throw Exception('Selecciona una bodega');

      final qty = double.tryParse(_qty.text.trim()) ?? 0;
      if (qty <= 0) throw Exception('Qty debe ser > 0');

      final body = {
        'itemId': itemId,
        'inventLocationId': locId,
        'qty': qty,
        'movementType': _type,
        'reason': _reason.text.trim().isEmpty ? null : _reason.text.trim(),
        'voucher': _voucher.text.trim().isEmpty ? null : _voucher.text.trim(),
      };

      await widget.api.postJson<Map<String, dynamic>>('/inventory/movement', body, auth: true);

      if (!mounted) return;

      // limpiar campos para registrar otro rápido
      _qty.clear();
      _reason.clear();
      _voucher.clear();

      // ✅ opcional: volver tipo a IN
      setState(() {
        _type = 'IN';
        _msg = 'Movimiento registrado';
      });

      // refrescar disponible luego de registrar
      await _refreshAvailable();
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = '❌ $e');
    } finally {
      if (!mounted) return;
      setState(() => _posting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_loadingLists) return const Center(child: CircularProgressIndicator());

    if (_listsErr != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_listsErr!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadDropdownLists, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedItemId,
                  decoration: const InputDecoration(labelText: 'Producto (ItemId)'),
                  items: _products.map((p) {
                    final id = _pickStr(p, ['itemid', 'ItemId']);
                    final name = _pickStr(p, ['namealias', 'NameAlias'], fallback: '');
                    return DropdownMenuItem(
                      value: id,
                      child: Text(name.isEmpty ? id : '$id - $name', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) async {
                    setState(() => _selectedItemId = v);
                    await _refreshAvailable();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedLocId,
                  decoration: const InputDecoration(labelText: 'Bodega (InventLocationId)'),
                  items: _locations.map((l) {
                    final id = _pickStr(l, ['inventlocationid', 'InventLocationId']);
                    final name = _pickStr(l, ['name', 'Name'], fallback: '');
                    return DropdownMenuItem(
                      value: id,
                      child: Text(name.isEmpty ? id : '$id - $name', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) async {
                    setState(() => _selectedLocId = v);
                    await _refreshAvailable();
                  },
                ),
                const SizedBox(height: 12),

                // Disponible (simple y legible)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_outlined),
                      const SizedBox(width: 10),
                      const Text('Disponible:', style: TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (_loadingAvail)
                        const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Text(
                          (_availableQty ?? 0).toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ✅ básico: en columna para evitar overflow
                DropdownButtonFormField<String>(
                  value: _type,
                  items: const [
                    DropdownMenuItem(value: 'IN', child: Text('IN (Entrada)')),
                    DropdownMenuItem(value: 'OUT', child: Text('OUT (Salida)')),
                    DropdownMenuItem(value: 'ADJUST', child: Text('ADJUST (Ajuste +)')),
                    DropdownMenuItem(value: 'TRANSFER', child: Text('TRANSFER (Suma)')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'IN'),
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),

                const SizedBox(height: 10),
                TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Descripción')),
                const SizedBox(height: 10),
                TextField(controller: _voucher, decoration: const InputDecoration(labelText: 'Documento #')),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _posting ? null : _postMovement,
                    child: _posting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Registrar movimiento'),
                  ),
                ),

                if (_msg != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_msg!)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------- TRANSACTIONS TAB --------------------

class _TransTab extends StatefulWidget {
  const _TransTab({required this.api});
  final ApiClient api;

  @override
  State<_TransTab> createState() => _TransTabState();
}

class _TransTabState extends State<_TransTab> {
  final _item = TextEditingController();
  final _loc = TextEditingController();
  String? _type;
  int _page = 1;
  PagedResult? _data;
  bool _loading = false;
  String? _err;

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final j = await widget.api.getJson<Map<String, dynamic>>(
        '/inventory/transactions',
        auth: true,
        query: {
          'itemId': _item.text.trim(),
          'inventLocationId': _loc.text.trim(),
          'movementType': _type,
          'page': page ?? _page,
          'pageSize': 50,
        },
      );
      final pr = PagedResult.fromJson(j);
      if (!mounted) return;
      setState(() {
        _data = pr;
        _page = pr.page;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load(page: 1);
  }

  @override
  void dispose() {
    _item.dispose();
    _loc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _data?.items ?? const [];
    final totalPages = _data?.totalPages ?? 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // ✅ básico: columna para evitar overflow
                  TextField(controller: _item, decoration: const InputDecoration(labelText: 'Producto')),
                  const SizedBox(height: 8),
                  TextField(controller: _loc, decoration: const InputDecoration(labelText: 'Bodega Id')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: _type,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Todos')),
                      DropdownMenuItem(value: 'IN', child: Text('IN')),
                      DropdownMenuItem(value: 'OUT', child: Text('OUT')),
                      DropdownMenuItem(value: 'ADJUST', child: Text('ADJUST')),
                      DropdownMenuItem(value: 'TRANSFER', child: Text('TRANSFER')),
                    ],
                    onChanged: (v) => setState(() => _type = v),
                    decoration: const InputDecoration(labelText: 'Tipo'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : () => _load(page: 1),
                      child: const Text('Filtrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_err != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_err!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: _loading && _data == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemBuilder: (_, i) {
              final it = Map<String, dynamic>.from(items[i] as Map);
              final itemId = _pickStr(it, ['itemid', 'ItemId']);
              final name = _pickStr(it, ['namealias', 'NameAlias'], fallback: '');
              final locId = _pickStr(it, ['inventlocationid', 'InventLocationId']);
              final locName = _pickStr(it, ['inventlocationname', 'InventLocationName'], fallback: '');
              final mt = _pickStr(it, ['movementtype', 'MovementType']);
              final qty = _pickNum(it, ['qty', 'Qty'], fallback: 0);
              final voucher = _pickStr(it, ['voucher', 'Voucher'], fallback: '-');
              final created = _pickStr(it, ['createdat', 'CreatedAt', 'createddatetime', 'CreatedDateTime'], fallback: '');


              final title = name.isNotEmpty
                  ? '$itemId - $name'
                  : (locName.isNotEmpty ? '$itemId - $locId ($locName)' : '$itemId - $locId');

              return Card(
                elevation: 0,
                child: ListTile(
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Tipo: $mt | Voucher: ${voucher.isEmpty ? "-" : voucher}\n$created',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    qty.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Column(
            children: [
              Text('Página $_page de $totalPages'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (_loading || _page <= 1) ? null : () => _load(page: _page - 1),
                      child: const Text('Anterior'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (_loading || _page >= totalPages) ? null : () => _load(page: _page + 1),
                      child: const Text('Siguiente'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
