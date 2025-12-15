// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:sodim/db/db_helper.dart';
import 'package:sodim/db/mordenes_dao.dart';
import 'package:sodim/db/ordenes_dao.dart';
import 'package:sodim/api/api_service.dart';

class SincronizadorService {
  static final Set<String> marbetesSincronizados = {};

  static Future<void> sincronizarMarbetes() async {
    final pendientes = await MOrdenesDAO.obtenerPendientes();
    print('🔍 Marbetes pendientes: ${pendientes.length}');

    if (pendientes.isEmpty) {
      print('ℹ️ No hay marbetes pendientes por sincronizar');
      return;
    }

    final api = ApiService();

    for (final marbete in pendientes) {
      final id = marbete['MARBETE'] ?? marbete['marbete'];
      if (id == null || id.toString().trim().isEmpty) {
        print('⚠️ Marbete sin ID. Registro omitido: $marbete');
        continue;
      }

      final camposPermitidos = [
        'ORDEN',
        'MARBETE',
        'MATRICULA',
        'MEDIDA',
        'MARCA',
        'TRABAJO',
        'TRABAJOALTERNO',
        'UBICACION',
        'CODIGO_TRA',
        'COMPUESTO',
        'TRABAJO_OTR',
        'SG',
        'OBS',
        'CLIENTE',
        'RAZONSOCIAL',
        'EMPRESA',
        'VEND',
      ];

      final datosFiltrados = {
        for (final entry in marbete.entries)
          if (camposPermitidos.contains(entry.key.toUpperCase()))
            entry.key.toUpperCase(): entry.value,
      };

      print(
        '📤 Enviando marbete a la BD:\n${const JsonEncoder.withIndent('  ').convert(datosFiltrados)}',
      );

      try {
        final resultado = await api.insertMOrdenes(datosFiltrados);
        if (resultado.toString().contains('NO insertado')) {
          print('⚠️ Servidor rechazó el marbete: $id');
          continue;
        }

        await _marcarMarbeteComoSincronizado(id.toString());
        marbetesSincronizados.add(
          id.toString(),
        ); // ✅ Registrar como sincronizado
        print('✅ Marbete sincronizado: $id');
      } catch (e) {
        print('❌ Error al sincronizar marbete $id: $e');
      }
    }
  }

  static Future<void> sincronizarOrdenes() async {
    final pendientes = await OrdenesDAO.obtenerPendientes();
    // print('🔍 Órdenes pendientes: ${pendientes.length}');

    if (pendientes.isEmpty) {
      // print('ℹ️ No hay órdenes pendientes por sincronizar');
      return;
    }

    final api = ApiService();

    for (final orden in pendientes) {
      final id = orden['ORDEN'] ?? orden['orden'];
      if (id == null || id.toString().trim().isEmpty) {
        print('⚠️ Orden sin ID. Registro omitido: $orden');
        continue;
      }

      try {
        await api.insertOrdenes(orden);
        await _marcarOrdenComoSincronizada(id.toString());
        print('✅ Orden sincronizada: $id');
      } catch (e) {
        print('❌ Error al sincronizar orden $id: $e');
      }
    }
  }

  /// Marca un marbete como sincronizado (LOCAL = 'N')
  static Future<void> _marcarMarbeteComoSincronizado(String marbete) async {
    final db = await DBHelper.initDb();
    await db.update(
      'mordenes',
      {'LOCAL': 'N'},
      where: 'MARBETE = ?',
      whereArgs: [marbete],
    );
  }

  /// Marca una orden como sincronizada (LOCAL = 'N')
  static Future<void> _marcarOrdenComoSincronizada(String orden) async {
    final db = await DBHelper.initDb();
    await db.update(
      'ordenes',
      {'LOCAL': 'N'},
      where: 'ORDEN = ?',
      whereArgs: [orden],
    );
  }
}
