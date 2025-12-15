// lib/services/upload_queue_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class UploadQueueService {
  static const String _key = 'upload_queue';

  /// Guarda un PDF pendiente de subir
  static Future<void> enqueue({
    required Uint8List bytes,
    required String fileName,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final item = {
      'fileName': fileName,
      'bytesBase64': base64Encode(bytes),
      'payload': payload,
      'fecha': DateTime.now().toIso8601String(),
    };

    final listaRaw = prefs.getStringList(_key) ?? [];
    listaRaw.add(jsonEncode(item));
    await prefs.setStringList(_key, listaRaw);

    // print('📥 Encolado PDF pendiente: $fileName (${listaRaw.length} total)');
  }

  /// Devuelve todos los pendientes
  static Future<List<Map<String, dynamic>>> getPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final listaRaw = prefs.getStringList(_key) ?? [];
    return listaRaw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  /// Limpia la cola
  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    // print('🧹 Cola de uploads limpiada');
  }
}
