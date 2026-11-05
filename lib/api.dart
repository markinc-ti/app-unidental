import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

class ApiError implements Exception {
  final String mensaje;
  final int? status;
  ApiError(this.mensaje, {this.status});
  @override
  String toString() => mensaje;
}

/// Cliente del servidor. El token del doctor (o del admin) se guarda en el teléfono.
class Api {
  Api._();
  static final Api i = Api._();

  String? _token;
  String? get token => _token;
  void Function()? alExpirar;

  Future<void> cargarToken() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('token');
  }

  Future<void> guardarToken(String? t) async {
    _token = t;
    final p = await SharedPreferences.getInstance();
    if (t == null) {
      await p.remove('token');
    } else {
      await p.setString('token', t);
    }
  }

  Uri uri(String ruta, [Map<String, String>? q]) => Uri.parse('${Config.baseUrl}$ruta').replace(queryParameters: q);
  String foto(dynamic id) => '${Config.baseUrl}/api/tienda/foto/$id';
  String get t => '/api/tienda/${Config.tienda}';

  Map<String, String> headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> get(String ruta, {Map<String, String>? q}) => _enviar(() => http.get(uri(ruta, q), headers: headers()));
  Future<dynamic> post(String ruta, [Object? cuerpo]) =>
      _enviar(() => http.post(uri(ruta), headers: headers(), body: jsonEncode(cuerpo ?? {})));
  Future<dynamic> put(String ruta, Object cuerpo) => _enviar(() => http.put(uri(ruta), headers: headers(), body: jsonEncode(cuerpo)));
  Future<dynamic> delete(String ruta) => _enviar(() => http.delete(uri(ruta), headers: headers()));

  Future<Uint8List> bytes(String ruta) async {
    final r = await http.get(uri(ruta), headers: headers(json: false)).timeout(const Duration(seconds: 60));
    if (r.statusCode >= 300) throw ApiError(_mensaje(r), status: r.statusCode);
    return r.bodyBytes;
  }

  /// Subida de archivo grande (video) con campos de formulario.
  Future<dynamic> subirArchivo(String ruta, String campo, String rutaArchivo, Map<String, String> campos) {
    return _enviar(() async {
      final req = http.MultipartRequest('POST', uri(ruta));
      req.headers.addAll(headers(json: false));
      req.fields.addAll(campos);
      req.files.add(await http.MultipartFile.fromPath(campo, rutaArchivo));
      return http.Response.fromStream(await req.send());
    }, timeout: const Duration(minutes: 10));
  }

  Future<dynamic> _enviar(Future<http.Response> Function() fn, {Duration timeout = const Duration(seconds: 40)}) async {
    final http.Response r;
    try {
      r = await fn().timeout(timeout);
    } on TimeoutException {
      throw ApiError('El servidor tardó demasiado. Intenta de nuevo.');
    } on SocketException {
      throw ApiError('Sin conexión a internet.');
    }
    if (r.statusCode == 401 && _token != null) {
      await guardarToken(null);
      alExpirar?.call();
    }
    if (r.statusCode < 200 || r.statusCode >= 300) throw ApiError(_mensaje(r), status: r.statusCode);
    if (r.body.isEmpty) return null;
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  String _mensaje(http.Response r) {
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      final det = d is Map ? d['detail'] : null;
      if (det is String) return det;
      if (det is List && det.isNotEmpty) return 'Revisa los datos: ${det.first['msg'] ?? det.first}';
    } catch (_) {}
    return 'Error del servidor (${r.statusCode}).';
  }
}
