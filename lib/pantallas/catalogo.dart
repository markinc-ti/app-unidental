import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../config.dart';
import '../estado.dart';
import 'comunes.dart';

/// Inicio: buscador, categorías, marcas, destacados y todas las unidades.
class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  String _q = '';
  String? _categoria;
  int? _marca;
  String _orden = 'relevancia';

  void _abrir(Map<String, dynamic> p) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProductoScreen(productoId: p['id'] as int)));

  @override
  Widget build(BuildContext context) {
    final e = context.watch<Estado>();
    final q = _q.toLowerCase();
    var lista = e.productos.where((p) {
      if (_categoria != null && p['categoria'] != _categoria) return false;
      if (_marca != null && p['marca_id'] != _marca) return false;
      return q.isEmpty || '${p['nombre']} ${p['modelo']} ${p['marca']} ${p['categoria']}'.toLowerCase().contains(q);
    }).toList();
    if (_orden == 'menor') lista.sort((a, b) => (a['precio'] as num).compareTo(b['precio'] as num));
    if (_orden == 'mayor') lista.sort((a, b) => (b['precio'] as num).compareTo(a['precio'] as num));
    final destacados = e.productos.where((p) => p['destacado'] == true).toList();
    final filtrando = q.isNotEmpty || _categoria != null || _marca != null;
    final ancho = MediaQuery.of(context).size.width;
    final columnas = ancho > 900 ? 4 : (ancho > 600 ? 3 : 2);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: e.cargarCatalogo,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                const _Logo(),
                const SizedBox(width: 10),
                const Text('unidental', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -1)),
                const Spacer(),
                if (e.conSesion)
                  Text('Hola, ${txt(e.usuario?['nombre']).split(' ').first}', style: const TextStyle(color: Paleta.gris)),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar unidad, marca o modelo'),
                onChanged: (t) => setState(() => _q = t),
              ),
            ),
          ),
          if (e.categorias.length > 1 || e.marcas.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 46,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                  for (final c in e.categorias)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: _categoria == c,
                        onSelected: (s) => setState(() => _categoria = s ? c : null),
                      ),
                    ),
                  for (final m in e.marcas)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: const Icon(Icons.verified_outlined, size: 16),
                        label: Text(txt(m['nombre'])),
                        selected: _marca == m['id'],
                        onSelected: (s) => setState(() => _marca = s ? m['id'] as int : null),
                      ),
                    ),
                ]),
              ),
            ),
          if (!filtrando && destacados.isNotEmpty) ...[
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Seccion('Destacados'))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 230,
                child: PageView.builder(
                  controller: PageController(viewportFraction: 0.88),
                  itemCount: destacados.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _Banner(destacados[i], onTap: () => _abrir(destacados[i])),
                  ),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(children: [
                Expanded(child: Seccion(filtrando ? '${lista.length} resultado(s)' : 'Todas las unidades')),
                DropdownButton<String>(
                  value: _orden,
                  underline: const SizedBox(),
                  dropdownColor: Paleta.tarjeta,
                  items: const [
                    DropdownMenuItem(value: 'relevancia', child: Text('Relevancia')),
                    DropdownMenuItem(value: 'menor', child: Text('Menor precio')),
                    DropdownMenuItem(value: 'mayor', child: Text('Mayor precio')),
                  ],
                  onChanged: (v) => setState(() => _orden = v ?? 'relevancia'),
                ),
              ]),
            ),
          ),
          if (e.cargandoCatalogo)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (e.errorCatalogo != null && e.productos.isEmpty)
            SliverFillRemaining(
              child: Vacio(Icons.wifi_off, e.errorCatalogo!,
                  accion: OutlinedButton(onPressed: e.cargarCatalogo, child: const Text('Reintentar'))),
            )
          else if (lista.isEmpty)
            const SliverFillRemaining(child: Vacio(Icons.search_off, 'No encontramos unidades con ese filtro.'))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnas, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.58),
                delegate: SliverChildBuilderDelegate((_, i) => TarjetaProducto(lista[i], onTap: () => _abrir(lista[i])),
                    childCount: lista.length),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => const LogoUnidental();
}

class _Banner extends StatelessWidget {
  final Map<String, dynamic> p;
  final VoidCallback onTap;
  const _Banner(this.p, {required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Stack(fit: StackFit.expand, children: [
          FotoProducto(p['foto_id'], radio: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xEE121826)], stops: [0.35, 1]),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(txt(p['marca']).toUpperCase(), style: const TextStyle(color: Paleta.lavanda, fontSize: 11, fontWeight: FontWeight.w700)),
              Text(txt(p['nombre']), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text(pesos(p['precio']), style: const TextStyle(color: Paleta.lima, fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      );
}

/// Ficha del producto: galería, videos, precio, características y "Agregar al carrito".
class ProductoScreen extends StatefulWidget {
  final int productoId;
  const ProductoScreen({super.key, required this.productoId});

  @override
  State<ProductoScreen> createState() => _ProductoScreenState();
}

class _ProductoScreenState extends State<ProductoScreen> {
  Map<String, dynamic>? _p;
  String? _error;
  int _foto = 0;
  int _cantidad = 1;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = Map<String, dynamic>.from(await Api.i.get('${Api.i.t}/producto/${widget.productoId}'));
      if (mounted) setState(() => _p = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _agregar() async {
    if (!await exigirSesion(context) || !mounted) return;
    final e = context.read<Estado>();
    final ya = e.cantidadEnCarrito(widget.productoId);
    final ok = await cargando(context, () async {
      await e.ponerEnCarrito(widget.productoId, (ya + _cantidad).clamp(1, 99));
      return true;
    });
    if (ok == true && mounted) aviso(context, 'Agregado al carrito. Ábrelo en la pestaña Carrito para hacer tu pedido.');
  }

  void _verFoto(List fotos, int i) => Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.black),
            body: PageView.builder(
              controller: PageController(initialPage: i),
              itemCount: fotos.length,
              itemBuilder: (_, j) => InteractiveViewer(maxScale: 5, child: Center(child: FotoProducto(fotos[j], fit: BoxFit.contain))),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = _p;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null ? Vacio(Icons.error_outline, _error!) : const Center(child: CircularProgressIndicator()),
      );
    }
    final fotos = (p['fotos'] as List?) ?? [];
    final videos = lista(p['videos']);
    final caracteristicas = lista(p['caracteristicas']);
    final anterior = (p['precio_anterior'] as num?) ?? 0;
    final precio = (p['precio'] as num?) ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(txt(p['marca']))),
      body: ListView(padding: const EdgeInsets.only(bottom: 120), children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(children: [
            PageView.builder(
              itemCount: fotos.isEmpty ? 1 : fotos.length,
              onPageChanged: (i) => setState(() => _foto = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: fotos.isEmpty ? null : () => _verFoto(fotos, i),
                child: FotoProducto(fotos.isEmpty ? null : fotos[i]),
              ),
            ),
            if (fotos.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < fotos.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _foto ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(color: i == _foto ? Paleta.lima : Colors.white54, borderRadius: BorderRadius.circular(4)),
                    ),
                ]),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(txt(p['categoria']).toUpperCase(), style: const TextStyle(color: Paleta.lavanda, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(txt(p['nombre']), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.15)),
            if (txt(p['modelo']).isNotEmpty) Text('Modelo ${p['modelo']}', style: const TextStyle(color: Paleta.gris)),
            const SizedBox(height: 14),
            if (anterior > precio)
              Text(pesos(anterior), style: const TextStyle(color: Paleta.gris, decoration: TextDecoration.lineThrough)),
            Text(pesos(precio), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Paleta.lima)),
            if ((p['meses_sin_intereses'] as num? ?? 0) > 0)
              Text('Hasta ${p['meses_sin_intereses']} meses sin intereses', style: const TextStyle(color: Paleta.texto)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (txt(p['entrega']).isNotEmpty) _Pastilla(Icons.local_shipping_outlined, txt(p['entrega'])),
              if (txt(p['garantia']).isNotEmpty) _Pastilla(Icons.verified_user_outlined, txt(p['garantia'])),
            ]),
            if (videos.isNotEmpty) ...[
              const Seccion('Videos'),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: videos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _MiniVideo(videos[i]),
                ),
              ),
            ],
            if (caracteristicas.isNotEmpty) ...[
              const Seccion('Características'),
              Card(
                child: Column(children: [
                  for (var i = 0; i < caracteristicas.length; i++)
                    Container(
                      color: i.isEven ? Colors.transparent : Paleta.tarjeta2.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 2, child: Text(txt(caracteristicas[i]['nombre']), style: const TextStyle(color: Paleta.gris))),
                        Expanded(flex: 3, child: Text(txt(caracteristicas[i]['valor']), style: const TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                    ),
                ]),
              ),
            ],
            if (txt(p['descripcion']).isNotEmpty) ...[
              const Seccion('Descripción'),
              Text(txt(p['descripcion']), style: const TextStyle(height: 1.5)),
            ],
          ]),
        ),
      ]),
      bottomSheet: Container(
        color: Paleta.tarjeta,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: Row(children: [
          Container(
            decoration: BoxDecoration(border: Border.all(color: Paleta.borde), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              IconButton(onPressed: _cantidad > 1 ? () => setState(() => _cantidad--) : null, icon: const Icon(Icons.remove)),
              Text('$_cantidad', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              IconButton(onPressed: _cantidad < 99 ? () => setState(() => _cantidad++) : null, icon: const Icon(Icons.add)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _agregar(),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Agregar al carrito'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Pastilla(this.icono, this.texto);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Paleta.tarjeta, borderRadius: BorderRadius.circular(20), border: Border.all(color: Paleta.borde)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 16, color: Paleta.lima),
          const SizedBox(width: 6),
          Text(texto, style: const TextStyle(fontSize: 13)),
        ]),
      );
}

/// Video corto dentro de la ficha: se reproduce al tocarlo.
class _MiniVideo extends StatefulWidget {
  final Map<String, dynamic> v;
  const _MiniVideo(this.v);

  @override
  State<_MiniVideo> createState() => _MiniVideoState();
}

class _MiniVideoState extends State<_MiniVideo> {
  VideoPlayerController? _c;

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _tocar() async {
    if (_c == null) {
      final c = VideoPlayerController.networkUrl(Uri.parse(txt(widget.v['url'])));
      setState(() => _c = c);
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (mounted) setState(() {});
      return;
    }
    _c!.value.isPlaying ? await _c!.pause() : await _c!.play();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return GestureDetector(
      onTap: _tocar,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 140,
          color: Paleta.tarjeta2,
          child: Stack(fit: StackFit.expand, children: [
            if (c != null && c.value.isInitialized)
              FittedBox(fit: BoxFit.cover, child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c))),
            if (c == null || !c.value.isPlaying) const Center(child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white)),
            if (txt(widget.v['titulo']).isNotEmpty)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(txt(widget.v['titulo']), maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 6)])),
              ),
          ]),
        ),
      ),
    );
  }
}
