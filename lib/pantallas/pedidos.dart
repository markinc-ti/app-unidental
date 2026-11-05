import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../config.dart';
import '../estado.dart';
import 'comunes.dart';

/// Mis pedidos (doctor).
class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  List<Map<String, dynamic>>? _pedidos;
  String? _error;
  bool? _eraDoctor;

  Future<void> _cargar() async {
    try {
      final r = lista(await Api.i.get('/api/tienda/mis-pedidos'));
      if (mounted) setState(() => _pedidos = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<Estado>();
    if (_eraDoctor != e.esDoctor) {
      _eraDoctor = e.esDoctor;
      _pedidos = null;
      if (e.esDoctor) _cargar();
    }
    if (!e.esDoctor) {
      return SafeArea(
        child: Vacio(Icons.local_shipping_outlined, 'Inicia sesión para ver tus pedidos y su seguimiento.',
            accion: FilledButton(onPressed: () => exigirSesion(context), child: const Text('Entrar o registrarme'))),
      );
    }
    final ps = _pedidos;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          const Text('Mis pedidos', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (ps == null && _error == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          if (_error != null && ps == null) Vacio(Icons.error_outline, _error!),
          if (ps != null && ps.isEmpty) const Vacio(Icons.inventory_2_outlined, 'Todavía no tienes pedidos.'),
          for (final p in ps ?? <Map<String, dynamic>>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: SizedBox(width: 56, height: 56, child: FotoProducto(p['foto_id'], radio: 10)),
                  title: Text('${p['folio']} · ${pesos(p['total'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(fecha(p['creado_en']), style: const TextStyle(color: Paleta.gris, fontSize: 12)),
                    const SizedBox(height: 4),
                    _EstadoChip(txt(p['estado']), txt(p['estado_nombre'])),
                  ]),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => PedidoScreen(pedidoId: p['id'] as int)));
                    _cargar();
                  },
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String estado;
  final String nombre;
  const _EstadoChip(this.estado, this.nombre);

  @override
  Widget build(BuildContext context) {
    final c = colorEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: c)),
      child: Text(nombre, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// Seguimiento del pedido: línea de tiempo, productos, pagos y acciones.
class PedidoScreen extends StatefulWidget {
  final int pedidoId;
  const PedidoScreen({super.key, required this.pedidoId});

  @override
  State<PedidoScreen> createState() => _PedidoScreenState();
}

class _PedidoScreenState extends State<PedidoScreen> {
  Map<String, dynamic>? _p;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = Map<String, dynamic>.from(await Api.i.get('/api/tienda/mis-pedidos/${widget.pedidoId}'));
      if (mounted) setState(() => _p = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _pagarEnLinea() async {
    final r = await cargando(context, () => Api.i.post('${Api.i.t}/pedidos/${widget.pedidoId}/pagar'));
    final url = r?['pago_url'];
    if (url == null) {
      if (mounted && r != null) aviso(context, 'El pago en línea no está disponible ahora. Habla con tu asesor.', error: true);
      return;
    }
    await launchUrl(Uri.parse(url.toString()), mode: LaunchMode.externalApplication);
  }

  Future<void> _comprobante() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 85);
    if (x == null || !mounted) return;
    final b = await x.readAsBytes();
    if (!mounted) return;
    final saldo = (_p?['saldo'] as num?) ?? 0;
    final monto = TextEditingController(text: saldo > 0 ? saldo.toStringAsFixed(2) : '');
    final ref = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Paleta.tarjeta,
        title: const Text('Comprobante de pago'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(b, height: 160)),
          const SizedBox(height: 12),
          TextField(controller: monto, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto pagado', prefixText: '\$ ')),
          const SizedBox(height: 8),
          TextField(controller: ref, decoration: const InputDecoration(labelText: 'Referencia / folio (opcional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
        ],
      ),
    );
    final cantidad = double.tryParse(monto.text.replaceAll(',', '').trim());
    if (ok != true || !mounted) return;
    if (cantidad == null || cantidad <= 0) {
      aviso(context, 'Escribe el monto que pagaste.', error: true);
      return;
    }
    final r = await cargando(context, () => Api.i.post('/api/tienda/mis-pedidos/${widget.pedidoId}/comprobante', {
          'monto': cantidad,
          'archivo_base64': 'data:image/jpeg;base64,${base64Encode(b)}',
          if (ref.text.trim().isNotEmpty) 'referencia': ref.text.trim(),
        }));
    if (r != null && mounted) {
      setState(() => _p = Map<String, dynamic>.from(r));
      aviso(context, 'Comprobante enviado. Te avisamos cuando lo confirmemos.');
    }
  }

  Future<void> _cancelar() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Paleta.tarjeta,
        title: const Text('¿Cancelar este pedido?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (si != true || !mounted) return;
    final r = await cargando(context, () => Api.i.post('/api/tienda/mis-pedidos/${widget.pedidoId}/cancelar'));
    if (r != null && mounted) setState(() => _p = Map<String, dynamic>.from(r));
  }

  Future<void> _whatsapp() async {
    final tel = txt(context.read<Estado>().tienda['whatsapp']).replaceAll(RegExp(r'\D'), '');
    if (tel.isEmpty) return;
    final texto = Uri.encodeComponent('Hola, tengo una duda sobre mi pedido ${_p?['folio']} de Unidental.');
    await launchUrl(Uri.parse('https://wa.me/52$tel?text=$texto'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    if (p == null) {
      return Scaffold(appBar: AppBar(), body: _error != null ? Vacio(Icons.error_outline, _error!) : const Center(child: CircularProgressIndicator()));
    }
    final e = context.watch<Estado>();
    final saldo = (p['saldo'] as num?) ?? 0;
    final cancelado = p['estado'] == 'cancelado';
    final enLinea = e.formasPago.contains('linea') || e.formasPago.contains('anticipo');
    return Scaffold(
      appBar: AppBar(title: Text('Pedido ${p['folio']}')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          _EstadoChip(txt(p['estado']), txt(p['estado_nombre'])),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _Fila('Total', pesos(p['total']), fuerte: true),
                _Fila('Pagado', pesos(p['pagado'])),
                if (!cancelado) _Fila('Por pagar', pesos(saldo), color: saldo > 0 ? Paleta.lima : Paleta.verde),
                _Fila('Forma de pago', nombresPago[p['forma_pago']] ?? txt(p['forma_pago'])),
              ]),
            ),
          ),
          if (!cancelado && saldo > 0) ...[
            const SizedBox(height: 12),
            if (enLinea) FilledButton.icon(onPressed: _pagarEnLinea, icon: const Icon(Icons.credit_card), label: const Text('Pagar en línea')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _comprobante, icon: const Icon(Icons.receipt_long), label: const Text('Subir comprobante de pago')),
            if (txt(e.tienda['datos_pago']).isNotEmpty) ...[
              const Seccion('Datos para transferencia'),
              SelectableText(txt(e.tienda['datos_pago']), style: const TextStyle(height: 1.5)),
            ],
          ],
          const Seccion('Seguimiento'),
          for (final (i, ev) in lista(p['eventos']).indexed)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: colorEstado(txt(ev['estado']))),
                ),
                if (i < lista(p['eventos']).length - 1) Container(width: 2, height: 46, color: Paleta.borde),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(txt(ev['nombre']), style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (txt(ev['nota']).isNotEmpty) Text(txt(ev['nota'])),
                    Text(fecha(ev['creado_en']), style: const TextStyle(color: Paleta.gris, fontSize: 12)),
                  ]),
                ),
              ),
            ]),
          const Seccion('Productos'),
          for (final it in lista(p['items']))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 56, height: 56, child: FotoProducto(it['foto_id'], radio: 10)),
                const SizedBox(width: 10),
                Expanded(child: Text('${it['cantidad']} × ${txt(it['nombre'])}${txt(it['modelo']).isEmpty ? '' : ' (${it['modelo']})'}')),
                Text(pesos(((it['precio'] as num?) ?? 0) * ((it['cantidad'] as num?) ?? 1))),
              ]),
            ),
          if (lista(p['pagos']).isNotEmpty) ...[
            const Seccion('Pagos'),
            for (final g in lista(p['pagos']))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(g['tipo'] == 'linea' ? Icons.credit_card : Icons.receipt_long, color: Paleta.lavanda),
                title: Text(pesos(g['monto'])),
                subtitle: Text('${fecha(g['creado_en'])} · ${g['estado'] == 'aprobado' ? 'Confirmado' : g['estado'] == 'rechazado' ? 'No confirmado' : 'En revisión'}'),
              ),
          ],
          const SizedBox(height: 16),
          if (txt(e.tienda['whatsapp']).isNotEmpty)
            OutlinedButton.icon(onPressed: _whatsapp, icon: const Icon(Icons.chat_outlined), label: const Text('Escribir a mi asesor por WhatsApp')),
          if (p['estado'] == 'recibido' && ((p['pagado'] as num?) ?? 0) <= 0) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: _cancelar, child: const Text('Cancelar pedido', style: TextStyle(color: Paleta.rojo))),
          ],
        ]),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final String a;
  final String b;
  final bool fuerte;
  final Color? color;
  const _Fila(this.a, this.b, {this.fuerte = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(a, style: const TextStyle(color: Paleta.gris))),
          Flexible(
            child: Text(b,
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: fuerte ? FontWeight.w800 : FontWeight.w600, fontSize: fuerte ? 20 : 15, color: color)),
          ),
        ]),
      );
}
