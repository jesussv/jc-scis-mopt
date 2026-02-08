import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/api.dart';
import '../core/models.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  // Solo filtros que querés:
  final TextEditingController _qCtrl = TextEditingController();
  final TextEditingController _barcodeCtrl = TextEditingController();
  bool? _active; // null=todos, true/false

  int _page = 1;
  int _pageSize = 25;

  bool _loading = false;
  String? _err;
  PagedResult? _data;

  // ---------------- Helpers ----------------
  dynamic _pickAny(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k)) return m[k];
    }
    return null;
  }

  String _pickStr(Map<String, dynamic> m, List<String> keys,
      {String fallback = ''}) {
    final v = _pickAny(m, keys);
    return (v ?? fallback).toString();
  }

  // ---------------- Load ----------------
  Map<String, dynamic> _buildQuery({required int page}) {
    final q = <String, dynamic>{
      'page': page,
      'pageSize': _pageSize,
    };

    final search = _qCtrl.text.trim();
    final barcode = _barcodeCtrl.text.trim();

    if (search.isNotEmpty) q['q'] = search;
    if (barcode.isNotEmpty) q['barcode'] = barcode;
    if (_active != null) q['active'] = _active;

    return q;
  }

  Future<void> _load({int? page}) async {
    final targetPage = page ?? _page;

    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final j = await widget.api.getJson<Map<String, dynamic>>(
        '/products',
        auth: true,
        query: _buildQuery(page: targetPage),
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
    _qCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  // ---------------- Barcode Scanner ----------------
  Future<void> _openBarcodeScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
    );

    if (!mounted) return;
    if (code == null || code.trim().isEmpty) return;

    setState(() {
      _barcodeCtrl.text = code.trim();
      _page = 1;
    });
    _load(page: 1);
  }

  void _clearFilters() {
    _qCtrl.clear();
    _barcodeCtrl.clear();
    _active = null;

    setState(() {
      _page = 1;
    });
    _load(page: 1);
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final items = (_data?.items ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final totalPages = _data?.totalPages ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _loading ? null : () => _load(page: _page),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // ----------- Filtros -----------
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filtros',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),

                // Buscar
                TextField(
                  controller: _qCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Buscar (ItemId / Nombre / Barcode)',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) {
                    setState(() => _page = 1);
                    _load(page: 1);
                  },
                ),
                const SizedBox(height: 10),

                // Barcode + botón escáner
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Barcode',
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                        onSubmitted: (_) {
                          setState(() => _page = 1);
                          _load(page: 1);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _loading ? null : _openBarcodeScanner,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Escanear'),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Activo
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

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _loading
                            ? null
                            : () {
                          setState(() => _page = 1);
                          _load(page: 1);
                        },
                        child: const Text('Aplicar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _loading ? null : _clearFilters,
                      child: const Text('Limpiar'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_err != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_err!, style: const TextStyle(color: Colors.red)),
            ),

          if (_loading) const LinearProgressIndicator(minHeight: 2),

          // ----------- Lista -----------
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Sin datos'))
                : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemBuilder: (_, i) {
                final it = items[i];
                final itemId = _pickStr(it, ['itemid', 'ItemId']);
                final name = _pickStr(it, ['namealias', 'NameAlias']);
                final barcode =
                _pickStr(it, ['barcode', 'Barcode'], fallback: '-');

                return Card(
                  elevation: 0,
                  child: ListTile(
                    title: Text(
                      itemId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                      const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${name.isEmpty ? "-" : name}\nBarcode: ${barcode.isEmpty ? "-" : barcode}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          ),

          // ----------- Paginado + PageSize visible -----------
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Página $_page de $totalPages',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Text('Filas: '),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _pageSize,
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 25, child: Text('25')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                        DropdownMenuItem(value: 100, child: Text('100')),
                      ],
                      onChanged: _loading
                          ? null
                          : (v) {
                        if (v == null) return;
                        setState(() {
                          _pageSize = v;
                          _page = 1; //  SIEMPRE reinicia al cambiar tamaño
                        });
                        _load(page: 1);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: (_loading || _page <= 1)
                            ? null
                            : () => _load(page: _page - 1),
                        child: const Text('Anterior'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: (_loading || _page >= totalPages)
                            ? null
                            : () => _load(page: _page + 1),
                        child: const Text('Siguiente'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// Pantalla Scanner (retorna el barcode leído)
// =====================================================
class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  bool _found = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear Barcode')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_found) return;
          final barcodes = capture.barcodes;
          if (barcodes.isEmpty) return;

          final raw = barcodes.first.rawValue ?? '';
          if (raw.trim().isEmpty) return;

          _found = true;
          Navigator.of(context).pop(raw.trim());
        },
      ),
    );
  }
}
