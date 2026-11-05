import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../config.dart';
import '../estado.dart';
import 'catalogo.dart';
import 'comunes.dart';

/// Panel de videos (clips verticales): desliza para ver el siguiente; cada video
/// lleva a su unidad para comprarla.
class VideosScreen extends StatefulWidget {
  final bool activa;
  const VideosScreen({super.key, required this.activa});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  List<Map<String, dynamic>> _videos = [];
  bool _cargando = true;
  String? _error;
  int _actual = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = lista(await Api.i.get('${Api.i.t}/videos'));
      if (mounted) setState(() => _videos = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Vacio(Icons.wifi_off, _error!, accion: OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')));
    }
    if (_videos.isEmpty) {
      return Vacio(Icons.video_library_outlined, 'Pronto verás aquí videos de las unidades.',
          accion: OutlinedButton(onPressed: _cargar, child: const Text('Actualizar')));
    }
    return Container(
      color: Colors.black,
      child: RefreshIndicator(
        onRefresh: _cargar,
        child: PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: _videos.length,
          onPageChanged: (i) => setState(() => _actual = i),
          itemBuilder: (_, i) => _Clip(_videos[i], reproducir: widget.activa && i == _actual),
        ),
      ),
    );
  }
}

class _Clip extends StatefulWidget {
  final Map<String, dynamic> v;
  final bool reproducir;
  const _Clip(this.v, {required this.reproducir});

  @override
  State<_Clip> createState() => _ClipState();
}

class _ClipState extends State<_Clip> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(Uri.parse(txt(widget.v['url'])));
  bool _listo = false;
  bool _pausado = false;

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      if (!mounted) return;
      _c.setLooping(true);
      setState(() => _listo = true);
      _aplicar();
    });
  }

  @override
  void didUpdateWidget(covariant _Clip old) {
    super.didUpdateWidget(old);
    _aplicar();
  }

  void _aplicar() {
    if (!_listo) return;
    if (widget.reproducir && !_pausado) {
      _c.play();
    } else {
      _c.pause();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    return GestureDetector(
      onTap: () {
        setState(() => _pausado = !_pausado);
        _aplicar();
      },
      child: Stack(fit: StackFit.expand, children: [
        if (_listo)
          FittedBox(fit: BoxFit.cover, child: SizedBox(width: _c.value.size.width, height: _c.value.size.height, child: VideoPlayer(_c)))
        else
          const Center(child: CircularProgressIndicator()),
        if (_pausado) const Center(child: Icon(Icons.play_arrow_rounded, size: 90, color: Colors.white70)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xDD000000)], stops: [0.55, 1]),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: SafeArea(
            top: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (txt(v['titulo']).isNotEmpty)
                Text(txt(v['titulo']), style: const TextStyle(fontSize: 15, color: Colors.white70)),
              Text(txt(v['marca']).toUpperCase(),
                  style: const TextStyle(color: Paleta.lavanda, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1)),
              Text(txt(v['nombre']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(children: [
                Text(pesos(v['precio']), style: const TextStyle(fontSize: 22, color: Paleta.lima, fontWeight: FontWeight.w800)),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    _c.pause();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductoScreen(productoId: v['producto_id'] as int)));
                  },
                  child: const Text('Ver unidad'),
                ),
              ]),
              if (_listo)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: VideoProgressIndicator(_c, allowScrubbing: true,
                      colors: const VideoProgressColors(playedColor: Paleta.lima, backgroundColor: Colors.white24)),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
