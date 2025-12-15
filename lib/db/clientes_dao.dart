import 'package:sqflite/sqflite.dart';
import '../models/cliente_model.dart';
import 'db_helper.dart';

class ClientesDAO {
  static Future<void> insertClientes(List<Cliente> clientes) async {
    final db = await DBHelper.initDb();
    final batch = db.batch();

    for (var cliente in clientes) {
      batch.insert(
        'clientes',
        cliente.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
        // conflictAlgorithm: ConflictAlgorithm.ignore

      );
    }

    await batch.commit(noResult: true);
  }

  static Future<List<Cliente>> getClientes() async {
    final db = await DBHelper.initDb();
    final maps = await db.query('clientes');
    return maps
        .map((e) => Cliente(
              clave: e['clave'] as String,
              nombre: e['NOMBRE'] as String,
            ))
        .toList();
  }
}
