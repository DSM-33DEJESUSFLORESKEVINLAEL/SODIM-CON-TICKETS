// // ignore_for_file: avoid_print

// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:http/http.dart' as http;
// import 'package:sodim/api/api_service.dart';

// class UploadService {
//   static const String _base =
//   // 'http://atlastoluca.dyndns.org:12500/datasnap/rest/tservermethods1'; // Toluca
//       'http://atlastoluca.dyndns.org:20000/datasnap/rest/tservermethods1'; // Activa
//   static const String _method =
//       'guardarPdfOrden'; 

//   static Future<String> uploadPdfJson({
//     required Uint8List pdfBytes,
//     required String fileName,
//     required Map<String, dynamic> payload,
//   }) async {
//      final uri = Uri.parse('$_base/$_method');

//     // 🔹 Preparamos el cuerpo JSON
//     final body = {
//       'fileName': fileName,
//       'mime': 'application/pdf',
//       'bytesBase64': base64Encode(pdfBytes),
//       'data': payload,
//     };


//     print('================ ENVIANDO PDF AL BACKEND =================');
//     print('🌐 URL destino: $uri');
//     print('📁 Archivo: $fileName');
//     print('📏 Tamaño PDF (bytes): ${pdfBytes.lengthInBytes}');
//     print('🧾 Payload (data): ${jsonEncode(payload)}');

//     print('📤 JSON COMPLETO ENVIADO AL BACKEND:');
//     print(const JsonEncoder.withIndent('  ').convert(body));
//     print('============================================================');

//     try {
//       final stopwatch = Stopwatch()..start();

//       final resp = await http
//           .post(
//             uri,
//             headers: {'Content-Type': 'application/json'},
//             body: jsonEncode(body),
//           )
//           .timeout(const Duration(seconds: 45));

//       stopwatch.stop();
//       print('⏱️ Tiempo de envío: ${stopwatch.elapsed.inMilliseconds} ms');
//       print('📡 Código HTTP: ${resp.statusCode}');

//       if (resp.statusCode >= 200 && resp.statusCode < 300) {
//         print('✅ Respuesta del servidor: ${resp.body}');

//         try {
//           final data = jsonDecode(resp.body);

//           // Manejo estándar DataSnap
//           if (data is Map &&
//               data['result'] is List &&
//               (data['result'] as List).isNotEmpty) {
//             final first = (data['result'] as List).first;
//             if (first is Map && first['Data'] is String) {
//               print('🟢 Servidor respondió: ${first['Data']}');
//               return first['Data'] as String;
//             }
//           }

//           // Manejo alternativo {"Data": "mensaje"}
//           if (data is Map && data['Data'] is String) {
//             print('🟢 Servidor respondió: ${data['Data']}');
//             return data['Data'] as String;
//           }

//           print('⚠️ Formato de respuesta inesperado: ${resp.body}');
//         } catch (e) {
//           print('❌ Error al decodificar JSON: $e');
//         }

//         return resp.body;
//       } else {
//         print('🚨 Error HTTP ${resp.statusCode}: ${resp.reasonPhrase}');
//         print('🧾 Cuerpo de error: ${resp.body}');
//         throw Exception('HTTP ${resp.statusCode} ${resp.reasonPhrase}');
//       }
//     } on http.ClientException catch (e) {
//       print('❌ Error de cliente HTTP: $e');
//       rethrow;
//     } on FormatException catch (e) {
//       print('❌ Error de formato (JSON o URI): $e');
//       rethrow;
//     } on Exception catch (e) {
//       print('❌ Error inesperado: $e');
//       rethrow;
//     }
//   }
// }


// --------------------------------------------SIN LA FIRMA----------------------------------------------------


// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
// import 'package:sodim/api/api_service.dart';

class UploadService {
  // Sugerencia: si ya tienes ApiService.baseUrl, úsalo:
  // static const String _base = ApiService.baseUrl;  // <-- si lo expones como const
  static const String _base =
      'http://atlastoluca.dyndns.org:12500/datasnap/rest/tservermethods1'; // Toluca
      // 'http://atlastoluca.dyndns.org:20000/datasnap/rest/tservermethods1'; // Activa

  static const String _methodNew = 'guardarPdfOrden';
  static const String _methodOld = 'guardarPdfOrden';

  /// Sube un PDF como JSON al backend Delphi.
  /// Devuelve el mejor mensaje posible desde la respuesta del servidor.
static Future<String> uploadPdfJson({
  required Uint8List pdfBytes,
  required String fileName,
  required String orden,                 // 👈 agregar aquí
  required Map<String, dynamic> payload,
}) async {
  // la inserto dentro del payload
  payload['orden'] = orden;

  final body = {
    'fileName': fileName,
    'mime': 'application/pdf',
    'bytesBase64': base64Encode(pdfBytes),
    'data': payload, // ahora contiene orden también
  };


    print('================ ENVIANDO PDF AL BACKEND =================');
    print('📁 Archivo: $fileName');
    print('📏 Tamaño PDF (bytes): ${pdfBytes.lengthInBytes}');
    print('🧾 Payload (data): ${jsonEncode(payload)}');
    print('📤 JSON COMPLETO ENVIADO AL BACKEND:');
    print(const JsonEncoder.withIndent('  ').convert(body));
    print('============================================================');

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // 1) Intentar el endpoint nuevo
    final uriNew = Uri.parse('$_base/$_methodNew');
    final sw = Stopwatch()..start();
    http.Response resp;

    try {
      resp = await http
          .post(uriNew, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 45));

      sw.stop();
      print('⏱️ Tiempo de envío: ${sw.elapsed.inMilliseconds} ms');
      print('📡 Código HTTP: ${resp.statusCode}');
      if (_isSuccess(resp.statusCode)) {
        print('✅ Respuesta del servidor (new): ${resp.body}');
        return _parseBestMessage(resp.body);
      } else if (resp.statusCode == 404) {
        // 2) Fallback al endpoint viejo si el nuevo no existe
        print('ℹ️ Endpoint "$_methodNew" no encontrado (404). Probando "$_methodOld"...');
        return await _fallbackOld(body, headers);
      } else {
        _logHttpError(resp);
        throw HttpException('HTTP ${resp.statusCode} ${resp.reasonPhrase}');
      }
    } on SocketException catch (e) {
      print('❌ Error de red (SocketException): $e');
      rethrow;
    } on http.ClientException catch (e) {
      print('❌ Error de cliente HTTP: $e');
      rethrow;
    } on FormatException catch (e) {
      print('❌ Error de formato (JSON o URI): $e');
      rethrow;
    } on HttpException {
      rethrow;
    } catch (e) {
      print('❌ Error inesperado: $e');
      rethrow;
    }
  }

  static bool _isSuccess(int code) => code >= 200 && code < 300;

  static Future<String> _fallbackOld(
    Map<String, dynamic> body,
    Map<String, String> headers,
  ) async {
    final uriOld = Uri.parse('$_base/$_methodOld');
    final sw = Stopwatch()..start();
    final resp = await http
        .post(uriOld, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 45));

    sw.stop();
    print('⏱️ Tiempo de envío (fallback): ${sw.elapsed.inMilliseconds} ms');
    print('📡 Código HTTP (fallback): ${resp.statusCode}');

    if (_isSuccess(resp.statusCode)) {
      print('✅ Respuesta del servidor (old): ${resp.body}');
      return _parseBestMessage(resp.body);
    } else {
      _logHttpError(resp);
      throw HttpException('HTTP ${resp.statusCode} ${resp.reasonPhrase}');
    }
  }

  /// Extrae el mejor mensaje posible de distintos formatos de respuesta.
  static String _parseBestMessage(String raw) {
    try {
      final data = jsonDecode(raw);

      // A) DataSnap clásico: { "result": [ { ... } ] }
      if (data is Map && data['result'] is List && (data['result'] as List).isNotEmpty) {
        final first = (data['result'] as List).first;
        if (first is Map) {
          // Nuevo backend: {ok, mensaje, ruta, archivo, ...}
          if (first['ok'] is bool && first['mensaje'] is String) {
            final ok = first['ok'] as bool;
            final msg = (first['mensaje'] as String).trim();
            final ruta = first['ruta'];
            final extra = ruta is String && ruta.isNotEmpty ? ' Ruta: $ruta' : '';
            return (ok ? 'OK: ' : 'ERROR: ') + msg + extra;
          }
          // Viejo: { Data: "..." }
          if (first['Data'] is String) {
            return (first['Data'] as String).trim();
          }
        }
      }

      // B) Respuesta directa (no DataSnap): { ok, mensaje, ... }
      if (data is Map) {
        if (data['ok'] is bool && data['mensaje'] is String) {
          final ok = data['ok'] as bool;
          final msg = (data['mensaje'] as String).trim();
          final ruta = data['ruta'];
          final extra = ruta is String && ruta.isNotEmpty ? ' Ruta: $ruta' : '';
          return (ok ? 'OK: ' : 'ERROR: ') + msg + extra;
        }
        if (data['Data'] is String) {
          return (data['Data'] as String).trim();
        }
      }

      // C) Si no coincide ningún formato esperado
      print('⚠️ Formato de respuesta inesperado: $raw');
      return raw;
    } catch (e) {
      print('❌ Error al decodificar JSON: $e');
      return raw; // devolvemos el cuerpo tal cual por si es texto plano
    }
  }

  static void _logHttpError(http.Response resp) {
    print('🚨 Error HTTP ${resp.statusCode}: ${resp.reasonPhrase}');
    if ((resp.body).isNotEmpty) {
      print('🧾 Cuerpo de error: ${resp.body}');
    }
  }
}

