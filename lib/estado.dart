import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api.dart';

/// Estado global: sesión, catálogo y carrito.
class Estado extends ChangeNotifier {
  Map<String, dynamic>? usuario; // {id, nombre, rol, ...}
  Map<String, dynamic> tienda = {};
  List<Map<String, dynamic>> productos = [];
  List<Map<String, dynamic>> marcas = [];
  List<String> categorias = [];
  Map<String, dynamic> carrito = {'items': [], 'total': 0, 'piezas': 0};
  bool cargandoCatalogo = false;
  String? errorCatalogo;

  bool get conSesion => usuario != null;
  bool get esAdmin => usuario?['rol'] == 'admin';
  bool get esDoctor => usuario?['rol'] == 'doctor';
  int get piezas => (carrito['piezas'] as num? ?? 0).toInt();
  List<String> get formasPago => ((tienda['formas_pago'] as List?) ?? ['asesor']).map((e) => e.toString()).toList();

  Future<void> iniciar() async {
    Api.i.alExpirar = () {
      usuario = null;
      carrito = {'items': [], 'total': 0, 'piezas': 0};
      notifyListeners();
    };
    await Api.i.cargarToken();
    if (Api.i.token != null) {
      try {
        usuario = Map<String, dynamic>.from(await Api.i.get('/api/tienda/yo'));
      } catch (_) {
        await Api.i.guardarToken(null);
      }
    }
    await Future.wait([cargarCatalogo(), if (esDoctor) cargarCarrito()]);
  }

  Future<void> cargarCatalogo() async {
    cargandoCatalogo = productos.isEmpty;
    errorCatalogo = null;
    notifyListeners();
    try {
      final r = Map<String, dynamic>.from(await Api.i.get('${Api.i.t}/catalogo'));
      tienda = Map<String, dynamic>.from(r['tienda'] ?? {});
      productos = lista(r['productos']);
      marcas = lista(r['marcas']);
      categorias = ((r['categorias'] as List?) ?? []).map((e) => e.toString()).toList();
    } catch (e) {
      errorCatalogo = e.toString();
    } finally {
      cargandoCatalogo = false;
      notifyListeners();
    }
  }

  Future<void> cargarCarrito() async {
    if (!esDoctor) return;
    try {
      carrito = Map<String, dynamic>.from(await Api.i.get('/api/tienda/carrito'));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> ponerEnCarrito(int productoId, int cantidad) async {
    carrito = Map<String, dynamic>.from(await Api.i.put('/api/tienda/carrito', {'producto_id': productoId, 'cantidad': cantidad}));
    notifyListeners();
  }

  int cantidadEnCarrito(int productoId) {
    for (final i in lista(carrito['items'])) {
      if (i['producto_id'] == productoId) return (i['cantidad'] as num).toInt();
    }
    return 0;
  }

  Future<void> entrar(Map<String, dynamic> respuesta) async {
    await Api.i.guardarToken(respuesta['token'] as String);
    usuario = Map<String, dynamic>.from(await Api.i.get('/api/tienda/yo'));
    notifyListeners();
    await cargarCarrito();
  }

  Future<void> salir() async {
    await Api.i.guardarToken(null);
    usuario = null;
    carrito = {'items': [], 'total': 0, 'piezas': 0};
    notifyListeners();
  }
}

List<Map<String, dynamic>> lista(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

String txt(dynamic v) => v == null ? '' : v.toString();

final _pesos = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);
String pesos(dynamic v) => _pesos.format((v is num) ? v : num.tryParse(txt(v)) ?? 0);

String fecha(dynamic iso) {
  final d = DateTime.tryParse(txt(iso));
  if (d == null) return txt(iso);
  return DateFormat('d MMM yyyy, HH:mm', 'es_MX').format(d.toLocal());
}

void aviso(BuildContext context, String texto, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(texto),
    backgroundColor: error ? const Color(0xFFB3261E) : const Color(0xFF2E3A52),
  ));
}

/// Corre una acción con indicador y muestra el error si falla.
Future<T?> cargando<T>(BuildContext context, Future<T> Function() fn) async {
  showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  try {
    final r = await fn();
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return r;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      aviso(context, e.toString(), error: true);
    }
    return null;
  }
}
