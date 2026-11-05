import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../config.dart';
import '../estado.dart';
import 'comunes.dart';

/// Cuenta: entrar/registrarse, mis datos, cerrar sesión y borrar la cuenta.
class CuentaScreen extends StatelessWidget {
  const CuentaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final e = context.watch<Estado>();
    if (!e.conSesion) {
      return SafeArea(
        child: Vacio(Icons.person_outline, 'Regístrate gratis para comprar, guardar tu carrito y seguir tus pedidos.',
            accion: FilledButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AccesoScreen())),
              child: const Text('Entrar o registrarme'),
            )),
      );
    }
    return const _Perfil();
  }
}

class _Perfil extends StatefulWidget {
  const _Perfil();

  @override
  State<_Perfil> createState() => _PerfilState();
}

class _PerfilState extends State<_Perfil> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final u = context.read<Estado>().usuario ?? {};
    _c = {for (final k in ['nombre', 'telefono', 'consultorio', 'especialidad', 'ciudad', 'estado', 'direccion', 'rfc']) k: TextEditingController(text: txt(u[k]))};
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final r = await cargando(context, () => Api.i.put('/api/tienda/yo', {for (final e in _c.entries) e.key: e.value.text.trim()}));
    if (r == null || !mounted) return;
    final e = context.read<Estado>();
    e.usuario = {...?e.usuario, ...Map<String, dynamic>.from(r)};
    aviso(context, 'Datos guardados.');
  }

  Future<void> _borrar() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Paleta.tarjeta,
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text('Se borran tus datos personales y tu carrito. Tus pedidos se conservan sin tus datos de contacto '
            'porque la ley fiscal pide guardarlos. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Paleta.rojo, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    final r = await cargando(context, () => Api.i.delete('/api/tienda/yo'));
    if (r != null && mounted) {
      await context.read<Estado>().salir();
      if (mounted) aviso(context, 'Tu cuenta se eliminó.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<Estado>();
    final doctor = e.esDoctor;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Text(txt(e.usuario?['nombre']), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        Text(txt(e.usuario?['email']), style: const TextStyle(color: Paleta.gris)),
        if (e.esAdmin)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Administrador de la tienda: usa la pestaña Admin.', style: TextStyle(color: Paleta.lima)),
          ),
        if (doctor) ...[
          const Seccion('Mis datos'),
          for (final (k, l) in [
            ('nombre', 'Nombre completo'),
            ('telefono', 'Teléfono / WhatsApp'),
            ('consultorio', 'Consultorio o clínica'),
            ('especialidad', 'Especialidad'),
            ('ciudad', 'Ciudad'),
            ('estado', 'Estado'),
            ('direccion', 'Dirección de entrega'),
            ('rfc', 'RFC (para factura)'),
          ])
            Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: _c[k], decoration: InputDecoration(labelText: l))),
          FilledButton(onPressed: _guardar, child: const Text('Guardar mis datos')),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(onPressed: () => e.salir(), icon: const Icon(Icons.logout), label: const Text('Cerrar sesión')),
        TextButton(
          onPressed: () => launchUrl(Uri.parse('${Config.baseUrl}/privacidad'), mode: LaunchMode.externalApplication),
          child: const Text('Aviso de privacidad'),
        ),
        if (doctor) TextButton(onPressed: _borrar, child: const Text('Eliminar mi cuenta', style: TextStyle(color: Paleta.rojo))),
      ]),
    );
  }
}

/// Entrar o crear cuenta (obligatorio para comprar).
class AccesoScreen extends StatefulWidget {
  const AccesoScreen({super.key});

  @override
  State<AccesoScreen> createState() => _AccesoScreenState();
}

class _AccesoScreenState extends State<AccesoScreen> {
  bool _registro = true;
  bool _ver = false;
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _tel = TextEditingController();
  final _pass = TextEditingController();
  final _consultorio = TextEditingController();
  final _ciudad = TextEditingController();
  bool _acepto = false;

  @override
  void dispose() {
    for (final c in [_nombre, _email, _tel, _pass, _consultorio, _ciudad]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _email.text.trim();
    // Al entrar se acepta también el usuario del administrador (no siempre es un correo).
    if ((_registro && !email.contains('@')) || email.isEmpty || _pass.text.length < (_registro ? 8 : 1)) {
      aviso(context, _registro ? 'Escribe tu correo y una contraseña de al menos 8 caracteres.' : 'Escribe tu correo y contraseña.', error: true);
      return;
    }
    if (_registro) {
      if (_nombre.text.trim().length < 3 || _tel.text.trim().length < 8) {
        aviso(context, 'Escribe tu nombre y teléfono.', error: true);
        return;
      }
      if (!_acepto) {
        aviso(context, 'Acepta el aviso de privacidad para continuar.', error: true);
        return;
      }
    }
    final r = await cargando(
      context,
      () => _registro
          ? Api.i.post('${Api.i.t}/registro', {
              'nombre': _nombre.text.trim(),
              'email': email,
              'telefono': _tel.text.trim(),
              'password': _pass.text,
              if (_consultorio.text.trim().isNotEmpty) 'consultorio': _consultorio.text.trim(),
              if (_ciudad.text.trim().isNotEmpty) 'ciudad': _ciudad.text.trim(),
            })
          : Api.i.post('${Api.i.t}/login', {'email': email, 'password': _pass.text}),
    );
    if (r == null || !mounted) return;
    await context.read<Estado>().entrar(Map<String, dynamic>.from(r));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_registro ? 'Crear cuenta' : 'Entrar')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Center(child: LogoUnidental(tam: 72)),
        const SizedBox(height: 20),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Soy nuevo')),
            ButtonSegment(value: false, label: Text('Ya tengo cuenta')),
          ],
          selected: {_registro},
          onSelectionChanged: (s) => setState(() => _registro = s.first),
        ),
        const SizedBox(height: 20),
        if (_registro) ...[
          TextField(controller: _nombre, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombre completo *')),
          const SizedBox(height: 12),
          TextField(controller: _tel, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono / WhatsApp *')),
          const SizedBox(height: 12),
        ],
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false,
            decoration: const InputDecoration(labelText: 'Correo electrónico *')),
        const SizedBox(height: 12),
        TextField(
          controller: _pass,
          obscureText: !_ver,
          decoration: InputDecoration(
            labelText: _registro ? 'Contraseña (mínimo 8) *' : 'Contraseña',
            suffixIcon: IconButton(icon: Icon(_ver ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ver = !_ver)),
          ),
        ),
        if (_registro) ...[
          const SizedBox(height: 12),
          TextField(controller: _consultorio, decoration: const InputDecoration(labelText: 'Consultorio o clínica')),
          const SizedBox(height: 12),
          TextField(controller: _ciudad, decoration: const InputDecoration(labelText: 'Ciudad')),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acepto,
            activeColor: Paleta.lima,
            checkColor: Paleta.limaOscura,
            onChanged: (v) => setState(() => _acepto = v ?? false),
            title: const Text('Acepto el aviso de privacidad'),
            secondary: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => launchUrl(Uri.parse('${Config.baseUrl}/privacidad'), mode: LaunchMode.externalApplication),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _enviar, child: Text(_registro ? 'Crear mi cuenta' : 'Entrar')),
      ]),
    );
  }
}
