import 'package:flutter/material.dart';
import 'package:sodim/models/vendedor_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  // 🔼 Aumenta versión a 2 para asegurar creación de bitácora en upgrades
  static const _dbName = 'sodim.db';
  static const _dbVersion = 2;

  static Future<Database> initDb() async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createAllTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Maneja upgrades sin pérdida de datos
        if (oldVersion < 2) {
          // v1 -> v2: asegurar tabla bitácora e índices
          await _ensureBitacora(db);
        }
      },
    );

    return _db!;
  }

  /// Crea todas las tablas e índices para instalaciones nuevas
  static Future<void> _createAllTables(Database db) async {
    // Puedes usar un batch si prefieres
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vendedores(
        id TEXT PRIMARY KEY,
        clave_cel TEXT,
        nombre TEXT,
        mail TEXT,
        empresa INTEGER,
        lon_orden INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ordenes(
        orden TEXT PRIMARY KEY,
        fecha TEXT,
        cliente TEXT,
        razonsocial TEXT,
        fcierre TEXT,
        fcaptura TEXT,
        empresa INTEGER,
        vend INTEGER,
        ruta TEXT,
        enviada INTEGER,
        diasentrega INTEGER,
        clietipo TEXT,
        ucaptura TEXT,
        local TEXT DEFAULT 'N',
        pdf_generado INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mordenes(
        orden TEXT,
        marbete TEXT,
        economico TEXT,
        matricula TEXT,
        medida TEXT,
        marca TEXT,
        trabajo TEXT,
        terminado TEXT,
        banda TEXT,
        pr TEXT,
        nup TEXT,
        oriren TEXT,
        falla TEXT,
        ajuste TEXT,
        docajuste TEXT,
        faj TEXT,
        oaj TEXT,
        reprocesos TEXT,
        status TEXT,
        reparaciones TEXT,
        frev TEXT,
        orev TEXT,
        farm TEXT,
        oarm TEXT,
        fcal TEXT,
        ocal TEXT,
        ubicacion TEXT,
        documento TEXT,
        env_suc TEXT,
        fsalida TEXT,
        docsalida TEXT,
        fentrada TEXT,
        docentrada TEXT,
        control TEXT,
        oras TEXT,
        ocar TEXT,
        opre TEXT,
        orep TEXT,
        oenc TEXT,
        ores TEXT,
        ovul TEXT,
        fdocumento TEXT,
        fras TEXT,
        frep TEXT,
        fvul TEXT,
        fcar TEXT,
        sg TEXT,
        bus TEXT,
        trabajoalterno TEXT,
        observacion1 TEXT,
        observacion2 TEXT,
        refac TEXT,
        mesdoc TEXT,
        aniodoc TEXT,
        ter_anterior TEXT,
        nrenovado TEXT,
        ajusteimporte TEXT,
        marbete_ant TEXT,
        autoclave TEXT,
        rev_xerografia TEXT,
        obs TEXT,
        codigo_tra TEXT,
        compuesto TEXT,
        trabajo_otr TEXT,
        anio_calidad TEXT,
        mes_calidad TEXT,
        fentcascosren TEXT,
        dentcascosren TEXT,
        uentcascosren TEXT,
        cte_distribuidor TEXT,
        datoextra1 TEXT,
        falla_armado TEXT,
        fincidencia_armado TEXT,
        perdido TEXT,
        fperdido TEXT,
        clie_tipo TEXT,
        causa_atrazo TEXT,
        fabricante TEXT,
        articulo_pronostico TEXT,
        sobre TEXT,
        nc_docto TEXT,
        nc_fecha TEXT,
        nc_usuario TEXT,
        tipo_cardeado TEXT,
        marbete_ic TEXT,
        terminado_cte_ic TEXT,
        ic TEXT,
        articulo_pt TEXT,
        tarima TEXT,
        reg_tarima TEXT,
        opar TEXT,
        fpar TEXT,
        rep_parches TEXT,
        ogur0tr TEXT,
        fgur0tr TEXT,
        olavotr TEXT,
        flavotr TEXT,
        oencotr TEXT,
        fencotr TEXT,
        oresotr TEXT,
        fresotr TEXT,
        occeotr TEXT,
        fcceotr TEXT,
        otr_kilos_arm TEXT,
        otr_kilos_car TEXT,
        articulo_revisado TEXT,
        opulotr TEXT,
        fpulotr TEXT,
        lote_tira TEXT,
        sumacalidad TEXT,
        dias_entrega TEXT,
        cliente TEXT,
        razonsocial TEXT,
        empresa TEXT,
        vend TEXT,
        local TEXT,
        fechasys TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS clientes(
        clave TEXT PRIMARY KEY,
        nombre TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS prefijos(
        prefijo TEXT PRIMARY KEY
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS marcas(
        marca TEXT PRIMARY KEY
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS medidas(
        medida TEXT PRIMARY KEY
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS terminados(
        terminado TEXT PRIMARY KEY
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS trabajos(
        trabajo TEXT PRIMARY KEY
      )
    ''');

    await db.execute(''' 
    CREATE TABLE IF NOT EXISTS pending_uploads (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       file_name TEXT NOT NULL,
       empresa TEXT NOT NULL,
       bytes_b64 TEXT NOT NULL,
       created_at TEXT NOT NULL,
       attempts INTEGER NOT NULL DEFAULT 0,
       last_error TEXT
      )
    ''');

    // bitácora + índice
    await _ensureBitacora(db);
  }

  /// Asegura la existencia de la tabla de bitácora e índice (para onCreate y onUpgrade)
  static Future<void> _ensureBitacora(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bitacora_ordenes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orden TEXT NOT NULL,
        campo TEXT NOT NULL,                 -- p.ej. 'pdf_generado'
        valor_anterior INTEGER,
        valor_nuevo INTEGER,
        fecha TEXT DEFAULT (datetime('now')) -- ISO8601 UTC
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_bitacora_ordenes_orden
      ON bitacora_ordenes(orden)
    ''');
  }

  // ==== Utilidades ====

  static Future<void> insertVendedor(Vendedor vendedor) async {
    final db = await initDb();
    await db.insert(
      'vendedores',
      vendedor.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Future<void> resetDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await deleteDatabase(path);
    debugPrint('🗑 Base de datos eliminada correctamente.');
  }

  static Future<void> limpiarBaseDatos() async {
    final db = await initDb();
    await db.delete('ordenes');
    await db.delete('mordenes');
    await db.delete('clientes');
    await db.delete('prefijos');
    // Agrega más tablas si es necesario limpiar otras
  }
}
