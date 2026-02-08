import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/token_store.dart';
import 'login_page.dart';
import 'products_page.dart';
import 'locations_page.dart';
import 'inventory_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.api});
  final ApiClient api;

  Future<void> _logout(BuildContext context) async {
    await TokenStore().clearAll();
    if (!context.mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage(api: api)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCIS'),
        actions: [
          IconButton(onPressed: () => _logout(context), icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(context, 'Productos', 'Listado con filtro y paginado', Icons.inventory_2,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsPage(api: api)))),
          const SizedBox(height: 12),
          _tile(context, 'Bodegas', 'Listado con filtro y paginado', Icons.warehouse,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => LocationsPage(api: api)))),
          const SizedBox(height: 12),
          _tile(context, 'Inventario', 'Stock + Movimientos + Historial', Icons.swap_horiz,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryPage(api: api)))),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String title, String sub, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
