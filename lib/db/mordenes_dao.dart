import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/morden_model.dart';
import 'db_helper.dart';

class MOrdenesDAO {
  static const String tableName = 'mordenes';

  /// Inserta o reemplaza un registro de MORDEN en la base de datos local
  static Future<void> insertMOrden(MOrden morden) async {
    final db = await DBHelper.initDb();
    await db.insert(
      tableName,
      morden.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,

      // conflictAlgorithm: ConflictAlgorithm.ignore
    );
  }

  /// Obtiene todas las MORDENES locales
  static Future<List<MOrden>> getMOrdenes() async {
    final db = await DBHelper.initDb();
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    return maps.map((map) => MOrden.fromMap(map)).toList();
  }

  /// Borra todas las MORDENES locales
  static Future<void> clearMOrdenes() async {
    final db = await DBHelper.initDb();
    await db.delete(tableName);
  }

  /// Filtrar por una orden específica (opcional)
  static Future<List<MOrden>> getByOrden(String orden) async {
    final db = await DBHelper.initDb();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'orden = ?',
      whereArgs: [orden],
    );
    return maps.map((map) => MOrden.fromMap(map)).toList();
  }

  static Future<List<Map<String, dynamic>>> obtenerPendientes() async {
    final db = await DBHelper.initDb();
    return await db.query('mordenes', where: 'LOCAL = ?', whereArgs: ['S']);
  }

  static Future<void> insertarMOrden(Map<String, dynamic> data) async {
    final db = await DBHelper.initDb();
    await db.insert(
      'mordenes',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> obtenerTodosPorOrden(
    String orden,
  ) async {
    final db = await DBHelper.initDb();
    return await db.query('mordenes', where: 'ORDEN = ?', whereArgs: [orden]);
  }

  // static Future<void> eliminarPorOrden(String orden) async {
  //   try {
  //     final db = await DBHelper.initDb();
  //     final filas = await db.delete(
  //       tableName,
  //       where: 'orden = ?',
  //       whereArgs: [orden],
  //     );

  //     debugPrint(
  //       '🗑️ Marbetes eliminados para la orden $orden: $filas fila(s)',
  //     );
  //   } catch (e) {
  //     debugPrint('❌ Error al eliminar marbetes de la orden $orden: $e');
  //   }
  // }
  // MOrdenesDAO.dart
static Future<int> eliminarPorOrdenYMarbete(String orden, String marbete) async {
  final db = await DBHelper.initDb(); // tu método para abrir la DB
  return await db.delete(
    'mordenes',
    where: 'ORDEN = ? AND MARBETE = ?',
    whereArgs: [orden, marbete],
  );
}

static Future<int> eliminarPorOrden(String orden) async {
  try {
    final db = await DBHelper.initDb();

    // Normaliza el valor que llega
    final value = orden.trim().toUpperCase();

    final filas = await db.rawDelete(
      '''
      DELETE FROM $tableName
      WHERE UPPER(TRIM(ORDEN)) = ?
      ''',
      [value],
    );

    debugPrint('🗑️ MORDENES: eliminados $filas para ORDEN=$value');
    return filas;
  } catch (e) {
    debugPrint('❌ Error al eliminar marbetes de la orden $orden: $e');
    return 0;
  }
}

 /// Elimina el caché de marbetes en SharedPreferences para una orden
 static Future<void> eliminarCacheLocalStorage(String orden) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'marbetes_$orden';

  final eliminado = await prefs.remove(key);

  if (eliminado) {
    debugPrint('🧹 Caché de marbetes eliminado correctamente: $key');
  } else {
    debugPrint('⚠️ No existía caché para eliminar: $key');
  }
}

}
