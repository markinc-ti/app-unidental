import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../config.dart';
import '../estado.dart';
import 'comunes.dart';

/// Solo el administrador: productos (precios, fotos, videos), pedidos, doctores y ajustes.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool? _activa;

  @override
  void initState() {
    super.initState();
    _revisar();
  }

  Future<void> _revisar() async {
    try {
      await Api.i.get('/api/tienda/admin/config');
      if (mounted) setState(() => _activa = true);
    } catch (e) {
      if (mounted) setState(() => _activa = false);
    }
  }

  Future<void> _activar() async {
    final r = await cargando(context, () => Api.i.post('/api/tienda/admin/activar', {'codigo': Config.tienda, 'nombre': Config.nombre}));
    if (r != null) {
      await _revisar();
      if (mounted) context.read<Estado>().cargarCatalogo();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activa == null) return const Center(child: CircularProgressIndicator());
    if (_activa == false) {
      return SafeArea(
        child: Vacio(Icons.storefront_outlined, 'Esta empresa todavía no tiene la tienda activada.',
            accion: FilledButton(onPressed: _activar, child: const Text('Activar tienda Unidental'))),
      );
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administrar tienda'),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Paleta.lima,
            labelColor: Paleta.lima,
            unselectedLabelColor: Paleta.gris,
            tabs: [Tab(text: 'Productos'), Tab(text: 'Pedidos'), Tab(text: 'Doctores'), Tab(text: 'Ajustes')],
          ),
        ),
        body: const TabBarView(children: [_Productos(), _PedidosAdmin(), _Doctores(), _Ajustes()]),
      ),
    );
  }
}

// ------------------------------------------------------------------ productos

class _Productos extends StatefulWidget {
  const _Productos();

  @override
  State<_Productos> createState() => _ProductosState();
}

class _ProductosState extends State<_Productos> {
  List<Map<String, dynamic>>? _lista;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = lista(await Api.i.get('/api/tienda/admin/productos'));
      if (mounted) setState(() => _lista = r);
    } catch (e) {
      if (mounted) aviso(context, e.toString(), error: true);
    }
  }

  Future<void> _abrir([int? id]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductoFormScreen(productoId: id)));
    _cargar();
    if (mounted) context.read<Estado>().cargarCatalogo();
  }

  @override
  Widget build(BuildContext context) {
    final l = (_lista ?? []).where((p) => _q.isEmpty || '${p['nombre']} ${p['marca']} ${p['modelo']}'.toLowerCase().contains(_q.toLowerCase())).toList();
    return Scaffold(
      body: _lista == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
                TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar producto'),
                    onChanged: (t) => setState(() => _q = t)),
                const SizedBox(height: 10),
                if (l.isEmpty) const Vacio(Icons.inventory_2_outlined, 'Da de alta tu primera unidad con el botón +.'),
                for (final p in l)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: SizedBox(width: 52, height: 52, child: FotoProducto(p['foto_id'], radio: 10)),
                        title: Text(txt(p['nombre']), style: TextStyle(fontWeight: FontWeight.w700,
                            decoration: p['activo'] == true ? null : TextDecoration.lineThrough)),
                        subtitle: Text('${txt(p['marca'])} · ${pesos(p['precio'])} · ${p['fotos']} foto(s) · ${p['videos']} video(s)'
                            '${p['activo'] == true ? '' : ' · oculto'}'),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _abrir(p['id'] as int),
                      ),
                    ),
                  ),
              ]),
            ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _abrir(), icon: const Icon(Icons.add), label: const Text('Nueva unidad')),
    );
  }
}

/// Alta / edición de una unidad: datos, precio, características, fotos y videos.
class ProductoFormScreen extends StatefulWidget {
  final int? productoId;
  const ProductoFormScreen({super.key, this.productoId});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  int? _id;
  bool _cargando = true;
  List<Map<String, dynamic>> _marcas = [];
  int? _marca;
  final _nombre = TextEditingController();
  final _modelo = TextEditingController();
  final _categoria = TextEditingController(text: 'Unidades dentales');
  final _precio = TextEditingController();
  final _anterior = TextEditingController();
  final _msi = TextEditingController();
  final _entrega = TextEditingController();
  final _garantia = TextEditingController();
  final _descripcion = TextEditingController();
  bool _destacado = false;
  bool _activo = true;
  List<Map<String, String>> _caract = [];
  List<int> _fotos = [];
  List<Map<String, dynamic>> _videos = [];

  @override
  void initState() {
    super.initState();
    _id = widget.productoId;
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      _marcas = lista(await Api.i.get('/api/tienda/admin/marcas'));
      if (_id != null) {
        final p = Map<String, dynamic>.from(await Api.i.get('/api/tienda/admin/productos/$_id'));
        _marca = p['marca_id'] as int?;
        _nombre.text = txt(p['nombre']);
        _modelo.text = txt(p['modelo']);
        _categoria.text = txt(p['categoria']);
        _precio.text = txt(p['precio']);
        _anterior.text = p['precio_anterior'] == null ? '' : txt(p['precio_anterior']);
        _msi.text = p['meses_sin_intereses'] == null ? '' : txt(p['meses_sin_intereses']);
        _entrega.text = txt(p['entrega']);
        _garantia.text = txt(p['garantia']);
        _descripcion.text = txt(p['descripcion']);
        _destacado = p['destacado'] == true;
        _activo = p['activo'] == true;
        _caract = lista(p['caracteristicas']).map((c) => {'nombre': txt(c['nombre']), 'valor': txt(c['valor'])}).toList();
        _fotos = ((p['fotos'] as List?) ?? []).map((e) => (e as num).toInt()).toList();
        _videos = lista(p['videos']);
      }
    } catch (e) {
      if (mounted) aviso(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Map<String, dynamic> _cuerpo() => {
        'nombre': _nombre.text.trim(),
        'marca_id': _marca,
        'modelo': _modelo.text.trim().isEmpty ? null : _modelo.text.trim(),
        'categoria': _categoria.text.trim().isEmpty ? 'Unidades dentales' : _categoria.text.trim(),
        'descripcion': _descripcion.text.trim().isEmpty ? null : _descripcion.text.trim(),
        'caracteristicas': _caract.where((c) => c['nombre']!.isNotEmpty && c['valor']!.isNotEmpty).toList(),
        'precio': double.tryParse(_precio.text.replaceAll(',', '').trim()) ?? 0,
        'precio_anterior': double.tryParse(_anterior.text.replaceAll(',', '').trim()),
        'meses_sin_intereses': int.tryParse(_msi.text.trim()),
        'entrega': _entrega.text.trim().isEmpty ? null : _entrega.text.trim(),
        'garantia': _garantia.text.trim().isEmpty ? null : _garantia.text.trim(),
        'destacado': _destacado,
        'activo': _activo,
      };

  Future<bool> _guardar({bool salir = true}) async {
    if (_nombre.text.trim().isEmpty || double.tryParse(_precio.text.replaceAll(',', '').trim()) == null) {
      aviso(context, 'Escribe el nombre y el precio.', error: true);
      return false;
    }
    final r = await cargando(context,
        () => _id == null ? Api.i.post('/api/tienda/admin/productos', _cuerpo()) : Api.i.put('/api/tienda/admin/productos/$_id', _cuerpo()));
    if (r == null || !mounted) return false;
    setState(() => _id = (r['id'] as num).toInt());
    if (salir) {
      aviso(context, 'Guardado.');
      Navigator.pop(context);
    }
    return true;
  }

  /// Fotos y videos necesitan que el producto ya exista: si es nuevo se guarda primero.
  Future<bool> _asegurarGuardado() async => _id != null || await _guardar(salir: false);

  Future<void> _nuevaMarca() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Paleta.tarjeta,
        title: const Text('Nueva marca'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre de la marca')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Agregar')),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty || !mounted) return;
    final r = await cargando(context, () => Api.i.post('/api/tienda/admin/marcas', {'nombre': c.text.trim()}));
    if (r != null && mounted) {
      setState(() {
        _marcas.add(Map<String, dynamic>.from(r));
        _marca = (r['id'] as num).toInt();
      });
    }
  }

  Future<void> _agregarFotos() async {
    if (!await _asegurarGuardado() || !mounted) return;
    final xs = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85);
    if (xs.isEmpty || !mounted) return;
    await cargando(context, () async {
      for (final x in xs) {
        final b = await x.readAsBytes();
        final r = await Api.i.post('/api/tienda/admin/productos/$_id/fotos', {'foto_base64': 'data:image/jpeg;base64,${base64Encode(b)}'});
        _fotos.add((r['id'] as num).toInt());
      }
      return true;
    });
    if (mounted) setState(() {});
  }

  Future<void> _fotoAccion(int fid) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Paleta.tarjeta,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.star_outline), title: const Text('Poner de portada'), onTap: () => Navigator.pop(ctx, 'portada')),
          ListTile(leading: const Icon(Icons.delete_outline, color: Paleta.rojo), title: const Text('Borrar foto'), onTap: () => Navigator.pop(ctx, 'borrar')),
        ]),
      ),
    );
    if (v == null || !mounted) return;
    if (v == 'portada') {
      final orden = [fid, ..._fotos.where((f) => f != fid)];
      final r = await cargando(context, () => Api.i.put('/api/tienda/admin/productos/$_id/fotos/orden', {'fotos': orden}));
      if (r != null && mounted) setState(() => _fotos = orden);
    } else {
      final r = await cargando(context, () => Api.i.delete('/api/tienda/admin/fotos/$fid'));
      if (r != null && mounted) setState(() => _fotos.remove(fid));
    }
  }

  Future<void> _agregarVideo() async {
    if (!await _asegurarGuardado() || !mounted) return;
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    final titulo = TextEditingController();
    bool feed = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Paleta.tarjeta,
          title: const Text('Subir video'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titulo, decoration: const InputDecoration(labelText: 'Título (opcional)')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: feed,
              onChanged: (v) => setS(() => feed = v),
              title: const Text('Mostrar en el panel de Videos'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Subir')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    aviso(context, 'Subiendo video… no cierres la app.');
    final r = await cargando(context, () => Api.i.subirArchivo('/api/tienda/admin/productos/$_id/videos', 'archivo', x.path,
        {'titulo': titulo.text.trim(), 'en_feed': feed ? 'true' : 'false'}));
    if (r != null && mounted) setState(() => _videos.add(Map<String, dynamic>.from(r)));
  }

  Future<void> _borrarVideo(Map<String, dynamic> v) async {
    final r = await cargando(context, () => Api.i.delete('/api/tienda/admin/videos/${v['id']}'));
    if (r != null && mounted) setState(() => _videos.remove(v));
  }

  Future<void> _ocultar() async {
    final r = await cargando(context, () => Api.i.delete('/api/tienda/admin/productos/$_id'));
    if (r != null && mounted) Navigator.pop(context);
  }

  Widget _campo(TextEditingController c, String l, {TextInputType? teclado, int lineas = 1, String? prefijo}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: c, keyboardType: teclado, maxLines: lineas, decoration: InputDecoration(labelText: l, prefixText: prefijo)),
      );

  @override
  Widget build(BuildContext context) {
    if (_cargando) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: Text(_id == null ? 'Nueva unidad' : 'Editar unidad'),
        actions: [TextButton(onPressed: _guardar, child: const Text('Guardar', style: TextStyle(color: Paleta.lima, fontWeight: FontWeight.w700)))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        const Seccion('Fotos (la primera es la portada)'),
        SizedBox(
          height: 110,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final f in _fotos)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _fotoAccion(f),
                  child: SizedBox(
                    width: 110,
                    child: Stack(fit: StackFit.expand, children: [
                      FotoProducto(f, radio: 12),
                      if (f == _fotos.first)
                        const Positioned(left: 6, top: 6, child: Icon(Icons.star, color: Paleta.lima)),
                    ]),
                  ),
                ),
              ),
            InkWell(
              onTap: _agregarFotos,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 110,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Paleta.lima, width: 1.5)),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_a_photo_outlined, color: Paleta.lima),
                  SizedBox(height: 4),
                  Text('Agregar', style: TextStyle(color: Paleta.lima)),
                ]),
              ),
            ),
          ]),
        ),
        const Seccion('Datos'),
        _campo(_nombre, 'Nombre *'),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int?>(
              value: _marca,
              isExpanded: true,
              dropdownColor: Paleta.tarjeta,
              decoration: const InputDecoration(labelText: 'Marca'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Sin marca')),
                for (final m in _marcas) DropdownMenuItem<int?>(value: (m['id'] as num).toInt(), child: Text(txt(m['nombre']))),
              ],
              onChanged: (v) => setState(() => _marca = v),
            ),
          ),
          IconButton(onPressed: _nuevaMarca, icon: const Icon(Icons.add_circle_outline, color: Paleta.lima), tooltip: 'Nueva marca'),
        ]),
        const SizedBox(height: 10),
        _campo(_modelo, 'Modelo'),
        _campo(_categoria, 'Categoría (ej. Unidades dentales, Sillones, Compresores)'),
        const Seccion('Precio'),
        Row(children: [
          Expanded(child: _campo(_precio, 'Precio *', teclado: const TextInputType.numberWithOptions(decimal: true), prefijo: '\$ ')),
          const SizedBox(width: 10),
          Expanded(child: _campo(_anterior, 'Precio antes (tachado)', teclado: const TextInputType.numberWithOptions(decimal: true), prefijo: '\$ ')),
        ]),
        Row(children: [
          Expanded(child: _campo(_msi, 'Meses sin intereses', teclado: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _campo(_entrega, 'Entrega (ej. 15 días)')),
        ]),
        _campo(_garantia, 'Garantía (ej. 2 años)'),
        _campo(_descripcion, 'Descripción', lineas: 4),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: _destacado, onChanged: (v) => setState(() => _destacado = v),
            title: const Text('Destacado (sale arriba en Inicio)')),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: _activo, onChanged: (v) => setState(() => _activo = v),
            title: const Text('Visible para los doctores')),
        Row(children: [
          const Expanded(child: Seccion('Características')),
          TextButton.icon(
            onPressed: () => setState(() => _caract.add({'nombre': '', 'valor': ''})),
            icon: const Icon(Icons.add),
            label: const Text('Agregar'),
          ),
        ]),
        for (var i = 0; i < _caract.length; i++)
          Padding(
            key: ObjectKey(_caract[i]),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: _caract[i]['nombre'],
                  decoration: const InputDecoration(labelText: 'Dato (ej. Sillón)'),
                  onChanged: (t) => _caract[i]['nombre'] = t.trim(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: _caract[i]['valor'],
                  decoration: const InputDecoration(labelText: 'Valor (ej. Eléctrico, 3 motores)'),
                  onChanged: (t) => _caract[i]['valor'] = t.trim(),
                ),
              ),
              IconButton(onPressed: () => setState(() => _caract.removeAt(i)), icon: const Icon(Icons.close)),
            ]),
          ),
        Row(children: [
          const Expanded(child: Seccion('Videos')),
          TextButton.icon(onPressed: _agregarVideo, icon: const Icon(Icons.video_call_outlined), label: const Text('Subir video')),
        ]),
        for (final v in _videos)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_circle_outline, color: Paleta.lavanda),
            title: Text(txt(v['titulo']).isEmpty ? 'Video' : txt(v['titulo'])),
            subtitle: Text(v['en_feed'] == true ? 'En el panel de Videos' : 'Solo en la ficha'),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _borrarVideo(v)),
            onTap: () => launchUrl(Uri.parse(txt(v['url'])), mode: LaunchMode.externalApplication),
          ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _guardar, child: const Text('Guardar unidad')),
        if (_id != null && _activo)
          TextButton(onPressed: _ocultar, child: const Text('Ocultar del catálogo', style: TextStyle(color: Paleta.rojo))),
      ]),
    );
  }
}

// ------------------------------------------------------------------ pedidos

const _estados = {
  'recibido': 'Pedido recibido',
  'confirmado': 'Confirmado por un asesor',
  'pagado': 'Pago completo',
  'en_fabricacion': 'En preparación',
  'en_camino': 'En camino',
  'instalado': 'Instalado',
  'entregado': 'Entregado',
  'cancelado': 'Cancelado',
};

class _PedidosAdmin extends StatefulWidget {
  const _PedidosAdmin();

  @override
  State<_PedidosAdmin> createState() => _PedidosAdminState();
}

class _PedidosAdminState extends State<_PedidosAdmin> {
  List<Map<String, dynamic>>? _l;
  String? _estado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = lista(await Api.i.get('/api/tienda/admin/pedidos', q: _estado == null ? null : {'estado': _estado!}));
      if (mounted) setState(() => _l = r);
    } catch (e) {
      if (mounted) aviso(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: const Text('Todos'), selected: _estado == null, onSelected: (_) {
                setState(() => _estado = null);
                _cargar();
              }),
            ),
            for (final e in _estados.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(e.value), selected: _estado == e.key, onSelected: (_) {
                  setState(() => _estado = e.key);
                  _cargar();
                }),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        if (_l == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        if (_l != null && _l!.isEmpty) const Vacio(Icons.inbox_outlined, 'Sin pedidos.'),
        for (final p in _l ?? <Map<String, dynamic>>[])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                title: Text('${p['folio']} · ${pesos(p['total'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${txt(p['doctor'])}${txt(p['ciudad']).isEmpty ? '' : ' · ${p['ciudad']}'}\n'
                    '${txt(p['estado_nombre'])} · pagado ${pesos(p['pagado'])} · ${fecha(p['creado_en'])}'),
                isThreeLine: true,
                trailing: (p['pagos_por_revisar'] as num? ?? 0) > 0
                    ? Badge(label: Text('${p['pagos_por_revisar']}'), child: const Icon(Icons.receipt_long, color: Paleta.lima))
                    : const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => _PedidoAdminScreen(pedidoId: p['id'] as int)));
                  _cargar();
                },
              ),
            ),
          ),
      ]),
    );
  }
}

class _PedidoAdminScreen extends StatefulWidget {
  final int pedidoId;
  const _PedidoAdminScreen({required this.pedidoId});

  @override
  State<_PedidoAdminScreen> createState() => _PedidoAdminScreenState();
}

class _PedidoAdminScreenState extends State<_PedidoAdminScreen> {
  Map<String, dynamic>? _p;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = Map<String, dynamic>.from(await Api.i.get('/api/tienda/admin/pedidos/${widget.pedidoId}'));
      if (mounted) setState(() => _p = r);
    } catch (e) {
      if (mounted) aviso(context, e.toString(), error: true);
    }
  }

  Future<void> _cambiarEstado() async {
    String estado = txt(_p!['estado']);
    final nota = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Paleta.tarjeta,
          title: const Text('Cambiar estado'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: estado,
              dropdownColor: Paleta.tarjeta,
              isExpanded: true,
              items: [for (final e in _estados.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setS(() => estado = v ?? estado),
            ),
            const SizedBox(height: 10),
            TextField(controller: nota, maxLines: 2, decoration: const InputDecoration(labelText: 'Mensaje para el doctor (opcional)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar y avisar')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final r = await cargando(context, () => Api.i.post('/api/tienda/admin/pedidos/${widget.pedidoId}/estado', {
          'estado': estado,
          if (nota.text.trim().isNotEmpty) 'nota': nota.text.trim(),
        }));
    if (r != null && mounted) setState(() => _p = Map<String, dynamic>.from(r));
  }

  Future<void> _revisarPago(Map<String, dynamic> g) async {
    final monto = TextEditingController(text: txt(g['monto']));
    final nota = TextEditingController();
    final bytes = g['tiene_comprobante'] == true ? await cargando(context, () => Api.i.bytes('/api/tienda/admin/pagos/${g['id']}/comprobante')) : null;
    if (!mounted) return;
    final aprobar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Paleta.tarjeta,
        title: const Text('Revisar pago'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (bytes != null) InteractiveViewer(child: Image.memory(bytes, height: 280, errorBuilder: (_, __, ___) => const Text('No es imagen'))),
            const SizedBox(height: 10),
            TextField(controller: monto, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto que se confirma', prefixText: '\$ ')),
            const SizedBox(height: 8),
            TextField(controller: nota, decoration: const InputDecoration(labelText: 'Nota (si lo rechazas, por qué)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Rechazar', style: TextStyle(color: Paleta.rojo))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar pago')),
        ],
      ),
    );
    if (aprobar == null || !mounted) return;
    final r = await cargando(context, () => Api.i.post('/api/tienda/admin/pagos/${g['id']}/revisar', {
          'aprobar': aprobar,
          if (double.tryParse(monto.text) != null) 'monto': double.parse(monto.text),
          if (nota.text.trim().isNotEmpty) 'nota': nota.text.trim(),
        }));
    if (r != null && mounted) setState(() => _p = Map<String, dynamic>.from(r));
  }

  Future<void> _whatsapp() async {
    final tel = txt(_p?['telefono']).replaceAll(RegExp(r'\D'), '');
    if (tel.isEmpty) return;
    await launchUrl(Uri.parse('https://wa.me/${tel.length == 10 ? '52$tel' : tel}'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    if (p == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text('Pedido ${p['folio']}')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          Card(
            child: ListTile(
              title: Text(txt(p['doctor']), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([txt(p['consultorio']), txt(p['ciudad']), txt(p['telefono']), txt(p['email'])].where((t) => t.isNotEmpty).join('\n')),
              trailing: IconButton(icon: const Icon(Icons.chat_outlined, color: Paleta.lima), onPressed: _whatsapp),
            ),
          ),
          const SizedBox(height: 10),
          Text('${txt(p['estado_nombre'])} · ${nombresPago[p['forma_pago']] ?? p['forma_pago']}', style: const TextStyle(color: Paleta.lima)),
          Text('Total ${pesos(p['total'])} · Pagado ${pesos(p['pagado'])} · Saldo ${pesos(p['saldo'])}'),
          if (txt(p['direccion_entrega']).isNotEmpty) Text('Entrega: ${p['direccion_entrega']}'),
          if (txt(p['notas']).isNotEmpty) Text('Notas: ${p['notas']}'),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _cambiarEstado, icon: const Icon(Icons.local_shipping_outlined), label: const Text('Cambiar estado y avisar')),
          const Seccion('Productos'),
          for (final it in lista(p['items']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(width: 48, height: 48, child: FotoProducto(it['foto_id'], radio: 8)),
              title: Text('${it['cantidad']} × ${txt(it['nombre'])}'),
              subtitle: Text('${txt(it['marca'])} ${txt(it['modelo'])}'),
              trailing: Text(pesos(it['precio'])),
            ),
          const Seccion('Pagos'),
          if (lista(p['pagos']).isEmpty) const Text('Sin pagos todavía.', style: TextStyle(color: Paleta.gris)),
          for (final g in lista(p['pagos']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(g['tipo'] == 'linea' ? Icons.credit_card : Icons.receipt_long, color: Paleta.lavanda),
              title: Text('${pesos(g['monto'])} · ${g['estado']}'),
              subtitle: Text(fecha(g['creado_en'])),
              trailing: g['estado'] == 'pendiente' ? FilledButton(onPressed: () => _revisarPago(g), child: const Text('Revisar')) : null,
            ),
          const Seccion('Seguimiento'),
          for (final ev in lista(p['eventos']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.circle, size: 12, color: colorEstado(txt(ev['estado']))),
              title: Text(txt(ev['nombre'])),
              subtitle: Text('${txt(ev['nota'])}${txt(ev['nota']).isEmpty ? '' : '\n'}${fecha(ev['creado_en'])}'),
            ),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ doctores

class _Doctores extends StatefulWidget {
  const _Doctores();

  @override
  State<_Doctores> createState() => _DoctoresState();
}

class _DoctoresState extends State<_Doctores> {
  List<Map<String, dynamic>>? _l;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = lista(await Api.i.get('/api/tienda/admin/doctores'));
      if (mounted) setState(() => _l = r);
    } catch (e) {
      if (mounted) aviso(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    if (l == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Text('${l.length} doctor(es) registrados', style: const TextStyle(color: Paleta.gris)),
        const SizedBox(height: 8),
        for (final d in l)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                title: Text(txt(d['nombre']), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([txt(d['consultorio']), txt(d['ciudad']), txt(d['telefono']), txt(d['email'])].where((t) => t.isNotEmpty).join(' · ')),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${d['pedidos']} pedido(s)'),
                  Text(pesos(d['comprado']), style: const TextStyle(color: Paleta.lima, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ ajustes

class _Ajustes extends StatefulWidget {
  const _Ajustes();

  @override
  State<_Ajustes> createState() => _AjustesState();
}

class _AjustesState extends State<_Ajustes> {
  Map<String, dynamic>? _c;
  final _whatsapp = TextEditingController();
  final _datos = TextEditingController();
  final _pct = TextEditingController();
  final _mp = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = Map<String, dynamic>.from(await Api.i.get('/api/tienda/admin/config'));
      _whatsapp.text = txt(r['whatsapp']);
      _datos.text = txt(r['datos_pago']);
      _pct.text = txt(r['anticipo_pct']);
      if (mounted) setState(() => _c = r);
    } catch (e) {
      if (mounted) aviso(context, e.toString(), error: true);
    }
  }

  Future<void> _guardar() async {
    final r = await cargando(context, () => Api.i.put('/api/tienda/admin/config', {
          'whatsapp': _whatsapp.text.trim(),
          'datos_pago': _datos.text.trim(),
          'anticipo_pct': double.tryParse(_pct.text.trim()) ?? 20,
          'pago_asesor': _c!['pago_asesor'],
          'pago_linea': _c!['pago_linea'],
          'pago_anticipo': _c!['pago_anticipo'],
          if (_mp.text.trim().isNotEmpty) 'mp_access_token': _mp.text.trim(),
        }));
    if (r != null && mounted) {
      _mp.clear();
      setState(() => _c = Map<String, dynamic>.from(r));
      context.read<Estado>().cargarCatalogo();
      aviso(context, 'Ajustes guardados.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      const Seccion('Formas de pago'),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: c['pago_asesor'] == true, onChanged: (v) => setState(() => c['pago_asesor'] = v),
          title: const Text('Con asesor (transferencia / financiamiento)')),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: c['pago_linea'] == true, onChanged: (v) => setState(() => c['pago_linea'] = v),
          title: const Text('Pago completo en línea')),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: c['pago_anticipo'] == true, onChanged: (v) => setState(() => c['pago_anticipo'] = v),
          title: const Text('Anticipo en línea')),
      TextField(controller: _pct, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '% de anticipo', suffixText: '%')),
      const SizedBox(height: 10),
      Text(c['mp_configurado'] == true ? '✅ Mercado Pago conectado' : '⚠️ Mercado Pago sin conectar: el pago en línea no se muestra a los doctores.',
          style: TextStyle(color: c['mp_configurado'] == true ? Paleta.verde : Paleta.lima)),
      const SizedBox(height: 8),
      TextField(controller: _mp, obscureText: true,
          decoration: const InputDecoration(labelText: 'Access token de Mercado Pago (producción)', helperText: 'Déjalo vacío para no cambiarlo')),
      const Seccion('Contacto y datos de pago'),
      TextField(controller: _whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp de asesores (10 dígitos)')),
      const SizedBox(height: 10),
      TextField(controller: _datos, maxLines: 4, decoration: const InputDecoration(labelText: 'Datos para transferencia (banco, CLABE, titular)')),
      const SizedBox(height: 20),
      FilledButton(onPressed: _guardar, child: const Text('Guardar ajustes')),
    ]);
  }
}
