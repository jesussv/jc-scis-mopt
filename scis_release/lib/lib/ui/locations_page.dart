import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/api.dart';
import '../core/models.dart';

class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _q = TextEditingController();
  int _page = 1;
  bool _loading = false;
  String? _err;
  PagedResult? _data;

  // mapa
  LatLng _mapCenter = const LatLng(13.6929, -89.2182);
  bool _gettingGps = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load(page: 1);
    _tryCenterToMyLocation();
  }

  @override
  void dispose() {
    _tab.dispose();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final j = await widget.api.getJson<Map<String, dynamic>>(
        '/inventLocations',
        auth: true,
        query: {'q': _q.text.trim(), 'page': page ?? _page, 'pageSize': 25},
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
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- GPS helpers ----------------

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('Activa el GPS/Ubicación del dispositivo.');
      return false;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      _showSnack('Permiso de ubicación denegado.');
      return false;
    }
    if (perm == LocationPermission.deniedForever) {
      _showSnack(
          'Permiso de ubicación denegado permanentemente. Habilítalo en ajustes.');
      return false;
    }
    return true;
  }

  Future<Position?> _getCurrentPosition() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return null;

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );
  }

  Future<void> _tryCenterToMyLocation() async {
    setState(() => _gettingGps = true);
    try {
      final pos = await _getCurrentPosition();
      if (pos == null) return;
      if (!mounted) return;
      setState(() => _mapCenter = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      // silencioso
    } finally {
      if (!mounted) return;
      setState(() => _gettingGps = false);
    }
  }

  // ---------------- Add Location ----------------

  Future<void> _addLocationDialog() async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    bool saving = false;
    String? msg;

    bool isMobile = false; // ✅ nuevo
    bool active = true;    // ✅ opcional, por defecto true

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setD) {
          Future<void> save() async {
            if (saving) return;

            final id = idCtrl.text.trim();
            final name = nameCtrl.text.trim();

            if (id.isEmpty || name.isEmpty) {
              setD(() => msg = 'InventLocationId y Nombre son obligatorios.');
              return;
            }

            setD(() {
              saving = true;
              msg = null;
            });

            try {
              final pos = await _getCurrentPosition();
              if (pos == null) {
                setD(() {
                  saving = false;
                  msg = 'No se pudo obtener la ubicación.';
                });
                return;
              }

              // ✅ CLAVES EXACTAS como tu backend (C#) espera:
              final body = {
                'InventLocationId': id,
                'Name': name,
                'Active': active,
                'IsMobile': isMobile,
                'Latitude': pos.latitude,
                'Longitude': pos.longitude,
                'AccuracyM': pos.accuracy,
              };

              await widget.api.postJson<Map<String, dynamic>>(
                '/inventLocations',
                body,
                auth: true,
              );

              // cerrar dialog (una sola vez)
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }

              if (!mounted) return;

              await _load(page: 1);

              // centrar mapa y mover al tab mapa
              setState(() => _mapCenter = LatLng(pos.latitude, pos.longitude));
              _tab.animateTo(1);

              _showSnack('✅ Almacén registrado con ubicación actual.');
            } catch (e) {
              setD(() => msg = e.toString());
            } finally {
              if (!mounted) return;
              setD(() => saving = false);
            }
          }

          return AlertDialog(
            title: const Text('Agregar almacén'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idCtrl,
                    decoration:
                    const InputDecoration(labelText: 'InventLocationId'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),

                  const SizedBox(height: 8),

                  // ✅ seleccionar si es móvil
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Es móvil'),
                    value: isMobile,
                    onChanged: saving
                        ? null
                        : (v) => setD(() => isMobile = v),
                  ),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activo'),
                    value: active,
                    onChanged: saving
                        ? null
                        : (v) => setD(() => active = v),
                  ),

                  const SizedBox(height: 10),

                  if (msg != null)
                    Text(msg!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () {
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    idCtrl.dispose();
    nameCtrl.dispose();
  }

  // ---------------- Map markers ----------------

  String _pickStr(Map<String, dynamic> it, String a, String b) {
    final v = it[a] ?? it[b];
    return (v ?? '').toString();
  }

  LatLng? _pickLatLng(Map<String, dynamic> it) {
    dynamic lat = it['lat'] ?? it['Lat'] ?? it['latitude'] ?? it['Latitude'];
    dynamic lng = it['lng'] ?? it['Lng'] ?? it['longitude'] ?? it['Longitude'];

    double? dLat;
    double? dLng;

    if (lat is num) dLat = lat.toDouble();
    if (lng is num) dLng = lng.toDouble();
    dLat ??= double.tryParse(lat?.toString() ?? '');
    dLng ??= double.tryParse(lng?.toString() ?? '');

    if (dLat == null || dLng == null) return null;
    return LatLng(dLat, dLng);
  }

  @override
  Widget build(BuildContext context) {
    final items = (_data?.items ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final totalPages = _data?.totalPages ?? 1;

    final markers = <Marker>[];
    for (final it in items) {
      final p = _pickLatLng(it);
      if (p == null) continue;

      final id = _pickStr(it, 'inventlocationid', 'InventLocationId');
      final name = _pickStr(it, 'name', 'Name');

      markers.add(
        Marker(
          point: p,
          width: 44,
          height: 44,
          child: Tooltip(
            message: '$id - $name',
            child: const Icon(Icons.location_on, size: 34, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bodegas'),
        actions: [
          IconButton(
            tooltip: 'Centrar en mi ubicación',
            onPressed: _gettingGps ? null : _tryCenterToMyLocation,
            icon: _gettingGps
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.my_location),
          ),
          IconButton(
            tooltip: 'Agregar almacén',
            onPressed: _addLocationDialog,
            icon: const Icon(Icons.add_location_alt),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Almacen'),
            Tab(text: 'Ubicaciones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // LISTA
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _q,
                      decoration: const InputDecoration(
                        labelText: 'Buscar (Id / Nombre)',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _load(page: 1),
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
                    final it = items[i];
                    final id =
                    _pickStr(it, 'inventlocationid', 'InventLocationId');
                    final name = _pickStr(it, 'name', 'Name');
                    final hasGps = _pickLatLng(it) != null;

                    return Card(
                      elevation: 0,
                      child: ListTile(
                        title: Text(
                          '$id - $name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          hasGps ? '📍 GPS registrado' : 'Sin GPS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          final p = _pickLatLng(it);
                          if (p != null) {
                            setState(() => _mapCenter = p);
                            _tab.animateTo(1);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              _pager(totalPages),
            ],
          ),

          // MAPA
          FlutterMap(
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.scis_demo',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pager(int totalPages) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        children: [
          Text('Página $_page de $totalPages'),
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
    );
  }
}
