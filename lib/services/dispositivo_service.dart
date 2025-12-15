import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';

class DispositivoService {
  static const _channel = MethodChannel('com.example.atlastime/serial');
  static const _kSerialKey = 'serial_autorizado';
  static const _kSerialHashKey = 'serial_autorizado_sha256';

  // --- Helpers privados ---

  static String _normalize(String s) => s.trim().toUpperCase();

  static String _sha256(String s) {
    final bytes = utf8.encode(s);
    return sha256.convert(bytes).toString();
  }

  static Future<String?> _serialRaw() async {
    try {
      if (Platform.isAndroid) {
        // ANDROID_ID desde canal nativo (Settings.Secure.ANDROID_ID)
        final serial = await _channel.invokeMethod<String>('getSerial');
        if (serial == null || serial.isEmpty) return null;
        if (serial.startsWith('ERROR')) return null; // no propagues errores como serial
        if (serial == 'ANDROID_ID_UNAVAILABLE') return null;
        return serial;
      } else if (Platform.isIOS) {
        final info = DeviceInfoPlugin();
        final ios = await info.iosInfo;
        // identifierForVendor: estable por app+vendor, cambia si reinstala TODAS las apps del vendor
        final idfv = ios.identifierForVendor;
        if (idfv == null || idfv.isEmpty) return null;
        return idfv;
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  // --- API pública ---

  /// Obtiene el identificador de dispositivo "serial" normalizado (o null si no disponible).
  static Future<String?> obtenerSerial() async {
    final raw = await _serialRaw();
    if (raw == null) return null;
    return _normalize(raw);
  }

  /// Valida si el dispositivo está autorizado (first-run enroll + comparación).
  ///
  /// - Primer uso: guarda **hash** del serial.
  /// - Usos posteriores: compara contra el hash guardado.
  /// - Nunca autoriza si no hay serial válido.
  static Future<bool> validarDispositivo() async {
    final prefs = await SharedPreferences.getInstance();
    final serial = await obtenerSerial();
    if (serial == null || serial.isEmpty) {
      return false; // sin serial válido => no autorizar
    }

    final savedHash = prefs.getString(_kSerialHashKey);
    final currentHash = _sha256(serial);

    if (savedHash == null) {
      // Migración: si antiguamente guardaste el serial en claro, intenta leerlo y convertirlo
      final oldPlain = prefs.getString(_kSerialKey);
      if (oldPlain != null && oldPlain.isNotEmpty) {
        final oldHash = _sha256(_normalize(oldPlain));
        await prefs.setString(_kSerialHashKey, oldHash);
        await prefs.remove(_kSerialKey); // limpia el viejo
        return oldHash == currentHash;
      }

      // Primer registro (enrollment)
      await prefs.setString(_kSerialHashKey, currentHash);
      return true;
    }

    return savedHash == currentHash;
  }

  /// Nombre de dispositivo para fines **informativos** (no seguridad).
  /// Evita PII en iOS (p.ej., "iPhone de Juan"): solo marca + modelo.
  static Future<String> obtenerNombreDispositivo() async {
    final info = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      final m = (android.manufacturer).trim();
      final model = (android.model).trim();
      final brand = (android.brand).trim();
      // Prefiere brand+model; algunos fabricantes devuelven 'unknown' en manufacturer
      final left = brand.isNotEmpty ? brand : m;
      return [left, model].where((x) => x.isNotEmpty).join(' ');
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      // Evita usar ios.name (puede tener nombre del usuario)
      final model = (ios.utsname.machine).trim();
      // Convierte, p.ej., "iPhone13,2" lo puedes mapear si quieres, pero al menos no expones PII
      return "Apple $model";
    } else {
      return "DISPOSITIVO_DESCONOCIDO";
    }
  }
}
