import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'estado.dart';
import 'pantallas/admin.dart';
import 'pantallas/carrito.dart';
import 'pantallas/catalogo.dart';
import 'pantallas/cuenta.dart';
import 'pantallas/pedidos.dart';
import 'pantallas/videos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final estado = Estado();
  runApp(ChangeNotifierProvider.value(value: estado, child: const UnidentalApp()));
  estado.iniciar();
}

class UnidentalApp extends StatelessWidget {
  const UnidentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Config.nombre,
      debugShowCheckedModeBanner: false,
      theme: temaUnidental(),
      home: const Principal(),
    );
  }
}

/// Pestañas de abajo: Inicio, Videos, Carrito, Pedidos, Cuenta (y Admin para el administrador).
class Principal extends StatefulWidget {
  const Principal({super.key});

  @override
  State<Principal> createState() => _PrincipalState();
}

class _PrincipalState extends State<Principal> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final e = context.watch<Estado>();
    final paginas = <Widget>[
      const CatalogoScreen(),
      VideosScreen(activa: _i == 1),
      CarritoScreen(alPedir: () => setState(() => _i = 3)),
      const PedidosScreen(),
      const CuentaScreen(),
      if (e.esAdmin) const AdminScreen(),
    ];
    if (_i >= paginas.length) _i = 0;
    return Scaffold(
      body: IndexedStack(index: _i, children: paginas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) {
          setState(() => _i = v);
          if (v == 2) e.cargarCarrito();
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Inicio'),
          const NavigationDestination(icon: Icon(Icons.play_circle_outline), selectedIcon: Icon(Icons.play_circle), label: 'Videos'),
          NavigationDestination(
            icon: Badge(isLabelVisible: e.piezas > 0, label: Text('${e.piezas}'), child: const Icon(Icons.shopping_cart_outlined)),
            selectedIcon: Badge(isLabelVisible: e.piezas > 0, label: Text('${e.piezas}'), child: const Icon(Icons.shopping_cart)),
            label: 'Carrito',
          ),
          const NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'Pedidos'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cuenta'),
          if (e.esAdmin)
            const NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Admin'),
        ],
      ),
    );
  }
}
