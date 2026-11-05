import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../config.dart';
import '../estado.dart';
import 'cuenta.dart';

/// Foto del producto desde el servidor (con fondo mientras carga).
class FotoProducto extends StatelessWidget {
  final dynamic fotoId;
  final BoxFit fit;
  final double radio;
  const FotoProducto(this.fotoId, {super.key, this.fit = BoxFit.cover, this.radio = 0});

  @override
  Widget build(BuildContext context) {
    final vacio = Container(
      color: Paleta.tarjeta2,
      alignment: Alignment.center,
      child: const Icon(Icons.chair_alt_outlined, color: Paleta.gris, size: 40),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: fotoId == null
          ? vacio
          : Image.network(
              Api.i.foto(fotoId),
              fit: fit,
              errorBuilder: (_, __, ___) => vacio,
              loadingBuilder: (c, w, p) => p == null ? w : Container(color: Paleta.tarjeta2),
            ),
    );
  }
}

/// Tarjeta de producto del catálogo (foto grande, marca, nombre, precio).
class TarjetaProducto extends StatelessWidget {
  final Map<String, dynamic> p;
  final VoidCallback onTap;
  const TarjetaProducto(this.p, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final anterior = (p['precio_anterior'] as num?) ?? 0;
    final precio = (p['precio'] as num?) ?? 0;
    final descuento = anterior > precio && anterior > 0 ? ((1 - precio / anterior) * 100).round() : 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(fit: StackFit.expand, children: [
              FotoProducto(p['foto_id']),
              if (p['destacado'] == true)
                const Positioned(left: 8, top: 8, child: _Etiqueta('DESTACADO', Paleta.lima, Paleta.limaOscura)),
              if (descuento > 0) Positioned(right: 8, top: 8, child: _Etiqueta('-$descuento%', Paleta.lavanda, const Color(0xFF0E1340))),
              if ((p['videos'] as num? ?? 0) > 0)
                const Positioned(right: 8, bottom: 8, child: Icon(Icons.play_circle_fill, color: Colors.white, size: 26)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(txt(p['marca']).toUpperCase(),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, letterSpacing: 1, color: Paleta.lavanda, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(txt(p['nombre']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (anterior > precio)
                Text(pesos(anterior), style: const TextStyle(fontSize: 12, color: Paleta.gris, decoration: TextDecoration.lineThrough)),
              Text(pesos(precio), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              if ((p['meses_sin_intereses'] as num? ?? 0) > 0)
                Text('Hasta ${p['meses_sin_intereses']} MSI', style: const TextStyle(fontSize: 12, color: Paleta.lima)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color fondo;
  final Color color;
  const _Etiqueta(this.texto, this.fondo, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(6)),
        child: Text(texto, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
      );
}

/// Pide iniciar sesión (o registrarse) antes de comprar. Regresa true si ya tiene sesión.
Future<bool> exigirSesion(BuildContext context) async {
  final e = context.read<Estado>();
  if (e.esDoctor) return true;
  if (e.esAdmin) {
    aviso(context, 'Estás como administrador: para comprar entra con una cuenta de doctor.');
    return false;
  }
  await Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AccesoScreen()));
  return context.mounted && context.read<Estado>().esDoctor;
}

class Vacio extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Widget? accion;
  const Vacio(this.icono, this.texto, {super.key, this.accion});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icono, size: 56, color: Paleta.gris),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Paleta.gris)),
            if (accion != null) ...[const SizedBox(height: 16), accion!],
          ]),
        ),
      );
}

class Seccion extends StatelessWidget {
  final String texto;
  const Seccion(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(texto.toUpperCase(),
            style: const TextStyle(fontSize: 12, letterSpacing: 1.2, color: Paleta.gris, fontWeight: FontWeight.w700)),
      );
}

const nombresPago = {
  'asesor': 'Con un asesor (transferencia o financiamiento)',
  'linea': 'Pagar todo en línea',
  'anticipo': 'Apartar con anticipo en línea',
};

Color colorEstado(String e) {
  switch (e) {
    case 'cancelado':
      return Paleta.rojo;
    case 'entregado':
    case 'instalado':
    case 'pagado':
      return Paleta.verde;
    case 'recibido':
      return Paleta.lavanda;
    default:
      return Paleta.lima;
  }
}
