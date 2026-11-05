import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../config.dart';
import '../estado.dart';
import 'comunes.dart';
import 'pedidos.dart';

/// Carrito: cantidades, forma de pago, dirección y "Hacer pedido".
class CarritoScreen extends StatefulWidget {
  final VoidCallback alPedir;
  const CarritoScreen({super.key, required this.alPedir});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  String? _forma;
  final _direccion = TextEditingController();
  final _notas = TextEditingController();

  @override
  void dispose() {
    _direccion.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _cantidad(int productoId, int n) async {
    await cargando(context, () async {
      await context.read<Estado>().ponerEnCarrito(productoId, n);
      return true;
    });
  }

  Future<void> _pedir() async {
    final e = context.read<Estado>();
    final forma = _forma ?? e.formasPago.first;
    final r = await cargando(context, () => Api.i.post('${Api.i.t}/pedidos', {
          'forma_pago': forma,
          if (_direccion.text.trim().isNotEmpty) 'direccion_entrega': _direccion.text.trim(),
          if (_notas.text.trim().isNotEmpty) 'notas': _notas.text.trim(),
        }));
    if (r == null || !mounted) return;
    await e.cargarCarrito();
    final pedido = Map<String, dynamic>.from(r['pedido']);
    final url = r['pago_url'];
    _notas.clear();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Paleta.tarjeta,
        title: Text('¡Pedido ${pedido['folio']} recibido!'),
        content: Text(url != null
            ? 'Te llevamos a Mercado Pago para pagar ${pesos(forma == 'anticipo' ? pedido['anticipo'] : pedido['total'])}. '
                'Al terminar, regresa a la app: verás tu pago en Pedidos.'
            : forma == 'asesor'
                ? 'Un asesor te contactará para confirmar y acordar el pago. Puedes subir tu comprobante desde Pedidos.'
                : 'Tu pedido quedó registrado. Desde Pedidos puedes pagar o subir tu comprobante.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(url != null ? 'Ir a pagar' : 'Ver mi pedido'))],
      ),
    );
    if (url != null) await launchUrl(Uri.parse(url.toString()), mode: LaunchMode.externalApplication);
    if (!mounted) return;
    widget.alPedir();
    Navigator.push(context, MaterialPageRoute(builder: (_) => PedidoScreen(pedidoId: pedido['id'] as int)));
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<Estado>();
    if (!e.esDoctor) {
      return SafeArea(
        child: Vacio(Icons.shopping_cart_outlined, 'Crea tu cuenta o inicia sesión para guardar productos en tu carrito y comprar.',
            accion: FilledButton(onPressed: () => exigirSesion(context), child: const Text('Entrar o registrarme'))),
      );
    }
    final items = lista(e.carrito['items']);
    if (items.isEmpty) {
      return const SafeArea(child: Vacio(Icons.remove_shopping_cart_outlined, 'Tu carrito está vacío.\nAgrega unidades desde Inicio o Videos.'));
    }
    final formas = e.formasPago;
    final forma = formas.contains(_forma) ? _forma! : formas.first;
    final total = (e.carrito['total'] as num?) ?? 0;
    final pct = (e.tienda['anticipo_pct'] as num?) ?? 0;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        const Text('Mi carrito', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  SizedBox(width: 84, height: 84, child: FotoProducto(i['foto_id'], radio: 12)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(txt(i['marca']).toUpperCase(), style: const TextStyle(fontSize: 11, color: Paleta.lavanda, fontWeight: FontWeight.w700)),
                      Text(txt(i['nombre']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(pesos(i['precio']), style: const TextStyle(color: Paleta.lima, fontWeight: FontWeight.w700)),
                      Row(children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _cantidad(i['producto_id'] as int, (i['cantidad'] as num).toInt() - 1),
                          icon: Icon((i['cantidad'] as num) <= 1 ? Icons.delete_outline : Icons.remove),
                        ),
                        Text('${i['cantidad']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _cantidad(i['producto_id'] as int, (i['cantidad'] as num).toInt() + 1),
                          icon: const Icon(Icons.add),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        const Seccion('¿Cómo quieres pagar?'),
        for (final f in formas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: RadioListTile<String>(
                value: f,
                groupValue: forma,
                activeColor: Paleta.lima,
                onChanged: (v) => setState(() => _forma = v),
                title: Text(nombresPago[f] ?? f),
                subtitle: f == 'anticipo'
                    ? Text('Pagas hoy ${pesos(total * pct / 100)} ($pct%) y el resto con tu asesor.')
                    : f == 'linea'
                        ? const Text('Tarjeta, meses sin intereses u otros medios con Mercado Pago.')
                        : const Text('Te contactamos para confirmar y te damos los datos de pago.'),
              ),
            ),
          ),
        const Seccion('Entrega'),
        TextField(
          controller: _direccion,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Dirección del consultorio (opcional)'),
        ),
        const SizedBox(height: 10),
        TextField(controller: _notas, maxLines: 2, decoration: const InputDecoration(labelText: 'Notas para tu asesor (opcional)')),
        const SizedBox(height: 20),
        Row(children: [
          const Text('Total', style: TextStyle(fontSize: 18, color: Paleta.gris)),
          const Spacer(),
          Text(pesos(total), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _pedir, icon: const Icon(Icons.check_circle_outline), label: const Text('Hacer pedido')),
      ]),
    );
  }
}
