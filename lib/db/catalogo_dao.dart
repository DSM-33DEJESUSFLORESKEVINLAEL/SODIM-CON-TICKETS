import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class CatalogoDAO {
  static Future<void> guardarCatalogoSimple({
    required String tabla,
    required String campo,
    required List<String> valores,
  }) async {
    final db = await DBHelper.initDb();
    final batch = db.batch();

    for (final valor in valores) {
      batch.insert(
        tabla,
        {campo: valor},
        conflictAlgorithm: ConflictAlgorithm.replace,
        // conflictAlgorithm: ConflictAlgorithm.ignore

      );
    }

    await batch.commit(noResult: true);
  }

  static Future<List<String>> obtenerCatalogoSimple({
  required String tabla,
  required String campo,
}) async {
  final db = await DBHelper.initDb();
  final result = await db.query(tabla);

  return result
      .map((e) => e[campo])
      .where((e) => e != null)
      .cast<String>()
      .toList();
}


  static Future<void> limpiarTabla(String tabla) async {
    final db = await DBHelper.initDb();
    await db.delete(tabla);
  }
}
