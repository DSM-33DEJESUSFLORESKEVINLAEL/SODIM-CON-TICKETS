// ignore_for_file: unused_local_variable, avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodim/db/catalogo_dao.dart';
import 'package:sodim/utils/conexion.dart';
import '../db/ordenes_dao.dart';
import '../db/mordenes_dao.dart';
import '../models/orden_model.dart';
import '../models/morden_model.dart';

class ApiService {
  
  // static const String baseUrl = 'http://atlastoluca.dyndns.org:20000/datasnap/rest/tservermethods1';
  static const String baseUrl = 'http://atlastoluca.dyndns.org:12500/datasnap/rest/tservermethods1';// toluca

  Future<void> mostrarVendedorGuardado() async {
    final prefs = await SharedPreferences.getInstance();

    final vendedorStr = prefs.getString('vendedor');

    if (vendedorStr == null) {
      // debugPrint('❌ No hay vendedor guardado en SharedPreferences.');
      return;
    }

    final vendedorMap = json.decode(vendedorStr);
    debugPrint('✅ Vendedor cargado desde SharedPreferences:');
    debugPrint('🧑 NOMBRE      : ${vendedorMap['NOMBRE']}');
    debugPrint('🏢 EMPRESA     : ${vendedorMap['EMPRESA']}');
    // debugPrint('🆔 VENDEDOR ID : ${vendedorMap['VENDEDOR']}');
    debugPrint('🆔 VENDEDOR ID : ${vendedorMap['VENDEDOR'].toString()}'); // ✅ Forzado a string
    debugPrint('📱 CLAVE_CEL   : ${vendedorMap['CLAVE_CEL']}');
    debugPrint('📧 MAIL        : ${vendedorMap['MAIL']}');
    debugPrint('📧 LON_ORDEN   : ${vendedorMap['LON_ORDEN']}');

  }


Future<Map<String, dynamic>?> login(String clave) async {
  final response = await http.get(Uri.parse('$baseUrl/vendedor/$clave'));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final List<dynamic> lista = data['DATA'];
    if (lista.isNotEmpty) {
      final raw = lista.first;

      // 🔐 Forzar a conservar tal cual venga del backend (con ceros si aplica)
      final vendedorOriginal = raw['VENDEDOR'].toString();
      final vendedorData = Map<String, dynamic>.from(raw);
      vendedorData['VENDEDOR'] = vendedorOriginal;

      debugPrint('🔍 Datos recibidos del vendedor:');
      vendedorData.forEach((key, value) {
        debugPrint('$key: $value');
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vendedor', json.encode(vendedorData));
      debugPrint('✅ Guardado exitoso del vendedor');
      return vendedorData;
    } else {
      debugPrint('⚠️ Lista de vendedores vacía');
    }
  } else {
    debugPrint('❌ Error HTTP ${response.statusCode}: ${response.body}');
  }
  return null;
}


Future<void> sincronizarDatos(String claveVendedor) async {
  final conectado = await tieneInternet();
  if (!conectado) {
    debugPrint('📴 se omite sincronización.');
    return;
  }
  try {
    final prefs = await SharedPreferences.getInstance();

    // ✅ Obtener vendedor guardado
    final vendedorStr = prefs.getString('vendedor');
    if (vendedorStr == null) return;
    
    final vendedorMap = json.decode(vendedorStr);
    final claveCel = vendedorMap['CLAVE_CEL'];
    final empresa = vendedorMap['EMPRESA'].toString();

    // ✅ Sincronizar ÓRDENES
    final ordenesResp = await http.get(Uri.parse('$baseUrl/ordenes/$claveVendedor'));
    if (ordenesResp.statusCode == 200) {
      final data = json.decode(ordenesResp.body);
      final List<dynamic> ordenes = data['DATA'] ?? [];

      debugPrint('📦 Recibidas ${ordenes.length} órdenes del backend');
      if (ordenes.isNotEmpty) {
        await prefs.setString('ordenes_$claveCel', json.encode(ordenes));
        debugPrint('✅ ordenes_$claveCel guardadas correctamente');
      } else {
        debugPrint('⚠️ No se recibieron órdenes');
      }

      int insertadas = 0;
      for (var item in ordenes) {
        try {
          final orden = Orden.fromJson(item);

          // Validación defensiva
          if (orden.orden.isEmpty || orden.fcaptura.isEmpty) {
            debugPrint('⚠️ Orden con campos vacíos ignorada: ${orden.toJson()}');
            continue;
            
          }

          await OrdenesDAO.insertOrden(orden);
          insertadas++;
        } catch (e) {
          debugPrint('❌ Error al convertir/insertar orden:\n$item\nError: $e');
        }
      }

      // debugPrint('✅ Órdenes insertadas en SQLite: $insertadas');

      // ✅ Verificación después de insertar
      final ordenesSQLite = await OrdenesDAO.getOrdenes();
      debugPrint('🧪 Prueba: hay ${ordenesSQLite.length} órdenes en SQLite luego de insertar');
    }

    // ✅ Sincronizar MORDENES
    final mordenesResp = await http.get(Uri.parse('$baseUrl/mordenes/$claveVendedor'));
    if (mordenesResp.statusCode == 200) {
      final data = json.decode(mordenesResp.body);
      final List<dynamic> mordenes = data['DATA'] ?? [];

      await prefs.setString('mordenes_$claveCel', json.encode(mordenes));
      debugPrint('✅ mordenes_$claveCel guardadas correctamente');

      for (var item in mordenes) {
        try {
          await MOrdenesDAO.insertMOrden(MOrden.fromJson(item));
        } catch (e) {
          debugPrint('❌ Error al insertar morden: $e');
        }
      }
    }

    // ✅ Sincronizar CATÁLOGOS
    await getYGuardarClientes(empresa);
    await getYGuardarPrefijos(empresa);
    await getYGuardarMarcas();
    await getYGuardarMedidas();
    await getYGuardarTerminados();
    await getYGuardarTrabajos();
    debugPrint('✅ Catálogos sincronizados correctamente');
  } catch (e) {
    debugPrint('❌ Error en sincronizarDatos: $e');
    rethrow;
  }
}

  //==================== ORDENES ====================

Future<void> cargarOrdenesDesdePrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final vendedorStr = prefs.getString('vendedor');

  if (vendedorStr != null) {
    final Map<String, dynamic> vendedorMap =
        Map<String, dynamic>.from(json.decode(vendedorStr));

    final empresa = vendedorMap['EMPRESA'].toString();

    // 👇 Mantiene el valor original exacto, incluso "09"
    final vendedor = vendedorMap['VENDEDOR'].toString();

    debugPrint('🧾 VENDEDOR original desde prefs: "$vendedor"'); // Muestra con comillas
    final ordenes = await getOrdenes(empresa, vendedor);

    debugPrint('📋 Órdenes cargadas: ${ordenes.length}');
  } else {
    debugPrint('⚠️ No se encontró vendedor en SharedPreferences.');
  }
}

Future<List<Map<String, dynamic>>> getOrdenes(String empresa, String vend) async {
  final conectado = await tieneInternet();

  // 🔐 Reforzamos: evitar conversión implícita a int
  final vendedorFinal = vend.toString();

  if (conectado) {
    // debugPrint('🧾 VENDEDOR original: "$vendedorFinal"');
    final url = Uri.parse('$baseUrl/listaOrdenes/$empresa/$vendedorFinal');
    // debugPrint('🌐 URL construida: $url');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final ordenes = List<Map<String, dynamic>>.from(data['DATA'] ?? []);
      // debugPrint('📥 Total de datos obtenidos (API): ${ordenes.length}');
      return ordenes;
    } else {
      debugPrint('❌ Error HTTP ${response.statusCode}: ${response.body}');
    }
  }

  final ordenesLocales = await OrdenesDAO.getOrdenes();
  // debugPrint('📦 Total de datos obtenidos (SQLite): ${ordenesLocales.length}');
  return ordenesLocales.map((e) => e.toMap()).toList();
}



  Future<String> insertOrdenes(Map<String, dynamic> datos) async {
    final response = await http.post(
      Uri.parse('$baseUrl/Ordenes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(datos),
    );
    return jsonDecode(response.body)['Data'];
  }
  Future<String> updateOrdenes(Map<String, dynamic> datos) async {
    final response = await http.put(
      Uri.parse('$baseUrl/Ordenes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(datos),
    );
    return jsonDecode(response.body)['Data'];
  }



Future<String> deleteOrdenes(String orden) async {
  final url = '$baseUrl/Ordenes/$orden';
  final response = await http.delete(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    // 👀 Log completo de lo que respondió el servidor
    print('📩 Respuesta backend: $data');

    // Extrae mensaje estilo DataSnap: {"result":[{"Data":"..."}]}
    if (data is Map && data['result'] is List && (data['result'] as List).isNotEmpty) {
      final first = (data['result'] as List).first;
      if (first is Map && first['Data'] is String) {
        return first['Data'] as String;
      }
    }

    // O si tu backend ya devuelve {"Data":"..."}
    if (data is Map && data['Data'] is String) {
      return data['Data'] as String;
    }

    return 'Orden eliminada'; // Fallback
  } else {
    throw Exception('❌ Error al eliminar orden (${response.statusCode})');
  }
}



  //==================== MORDENES ====================
Future<List<Map<String, dynamic>>> getMOrdenes(String orden) async {
  final conectado = await tieneInternet();

  if (conectado) {
    final response = await http.get(Uri.parse('$baseUrl/MOrdenes/$orden'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['DATA'] ?? []);
    } else {
      debugPrint('❌ Error al obtener MOrdenes desde API');
      return [];
    }
  } else {
    final locales = await MOrdenesDAO.getByOrden(orden);
    return locales.map((e) => e.toMap()).toList(); // Asegúrate que MOrden tenga .toMap()
  }
}

  Future<String> insertMOrdenes(Map<String, dynamic> datos) async {
    final response = await http.post(
      Uri.parse('$baseUrl/MOrdenes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(datos),
    );
    return jsonDecode(response.body)['Data'];
  }

  Future<String> updateMOrdenes(Map<String, dynamic> datos) async {
    final response = await http.put(
      Uri.parse('$baseUrl/MOrdenes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(datos),
    );
    return jsonDecode(response.body)['Data'];
  }

  

Future<String> deleteMOrdenes(String marbete) async {
  final url = '$baseUrl/MOrdenes/$marbete';
  final response = await http.delete(Uri.parse(url));

  if (response.statusCode == 200) {
    // 👀 ver exactamente qué regresó el servidor
    try {
      final data = jsonDecode(response.body);
      print('📩 Respuesta backend (MOrdenes): $data');

      // Formato típico DataSnap: {"result":[{"Data":"..."}]}
      if (data is Map && data['result'] is List && (data['result'] as List).isNotEmpty) {
        final first = (data['result'] as List).first;
        if (first is Map && first['Data'] is String) {
          return first['Data'] as String;
        }
      }

      // Si devuelve {"Data":"..."}
      if (data is Map && data['Data'] is String) {
        return data['Data'] as String;
      }

      // Fallback si el body es JSON pero no trae Data
      return 'Marbete eliminado';
    } catch (_) {
      // Si el body NO es JSON (texto plano)
      final body = response.body.trim();
      return body.isNotEmpty ? body : 'Marbete eliminado';
    }
  } else {
    throw Exception('❌ Error al eliminar marbete (${response.statusCode})');
  }
}

  // //==================== CATÁLOGOS ====================
 
  Future<List<String>> getYGuardarClientes(String empresa) async {
  final conectado = await tieneInternet();

  if (conectado) {
    final response = await http.get(Uri.parse('$baseUrl/clientes/$empresa'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final lista = data['DATA'] ?? [];
      final valores = List<String>.from(lista.map((e) => '${e['CLIENTE']} - ${e['NOMBRE']}'));

      await CatalogoDAO.guardarCatalogoSimple(
        tabla: 'clientes',
        campo: 'nombre',
        valores: valores,
      );
      return valores;
    }
  }
  return await CatalogoDAO.obtenerCatalogoSimple(tabla: 'clientes', campo: 'nombre');
}

Future<List<String>> getYGuardarPrefijos(String empresa) async {
  final conectado = await tieneInternet();

  if (conectado) {
    final response = await http.get(Uri.parse('$baseUrl/prefijoOrden/$empresa'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final lista = data['DATA'] ?? [];
              // debugPrint('🧪 Lista cruda de PREFIJO: $lista'); // 👈 Agrega esto


      final valores = lista
          .map((e) => e['PREORDEN'])
          .where((e) => e != null)
          .cast<String>()
          .toList();

      await CatalogoDAO.guardarCatalogoSimple(
        tabla: 'prefijos',
        campo: 'prefijo',
        valores: valores,
      );
      return valores;
    }
  }
  return await CatalogoDAO.obtenerCatalogoSimple(tabla: 'prefijos', campo: 'prefijo');
}

Future<List<String>> getYGuardarMarcas() async {
  final conectado = await tieneInternet();

  if (conectado) {
    final response = await http.get(Uri.parse('$baseUrl/marcas'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final lista = data['DATA'] ?? [];
      final valores = List<String>.from(lista.map((e) => e['MARCA']));

      await CatalogoDAO.guardarCatalogoSimple(
        tabla: 'marcas',
        campo: 'marca',
        valores: valores,
      );
      return valores;
    }
  }
  return await CatalogoDAO.obtenerCatalogoSimple(tabla: 'marcas', campo: 'marca');
}

  Future<List<String>> getYGuardarMedidas() async {
  final conectado = await tieneInternet();

  if (conectado) {
    final response = await http.get(Uri.parse('$baseUrl/medidas'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final lista = data['DATA'] ?? [];
      final valores = List<String>.from(lista.map((e) => e['MEDIDA']));

      await CatalogoDAO.guardarCatalogoSimple(
        tabla: 'medidas',
        campo: 'medida',
        valores: valores,
      );
      return valores;
    }
  }
  return await CatalogoDAO.obtenerCatalogoSimple(tabla: 'medidas', campo: 'medida');
}


  Future<List<String>> getYGuardarTerminados() async {
  final conectado = await tieneInternet();

  if (conectado) {
    final response = await http.get(Uri.parse('$baseUrl/terminados'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final lista = data['DATA'] ?? [];
      final valores = List<String>.from(lista.map((e) => e['TERMINADO']));

      await CatalogoDAO.guardarCatalogoSimple(
        tabla: 'terminados',
        campo: 'terminado',
        valores: valores,
      );
      return valores;
    }
  }
  return await CatalogoDAO.obtenerCatalogoSimple(tabla: 'terminados', campo: 'terminado');
}

Future<List<String>> getYGuardarTrabajos() async {
  final conectado = await tieneInternet();

  if (conectado) {
    final response = await http.get(Uri.parse('$baseUrl/tra'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final lista = data['DATA'] ?? [];
        // debugPrint('🧪 Lista cruda de trabajos: $lista'); // 👈 Agrega esto


      final valores = lista
          .map((e) => e['TRA'])
          .where((e) => e != null)
          .cast<String>()
          .toList();

      await CatalogoDAO.guardarCatalogoSimple(
        tabla: 'trabajos',
        campo: 'trabajo',
        valores: valores,
      );
      return valores;
    }
  }
  return await CatalogoDAO.obtenerCatalogoSimple(tabla: 'trabajos', campo: 'trabajo');
}


  Future<String> insertBitacorasOt(Map<String, dynamic> datos) async {
    final response = await http.post(
      Uri.parse('$baseUrl/BitacoraOt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(datos),
    );  
    return jsonDecode(response.body)['Data'];
  }

  Future<String> updateBitacorasOt(Map<String, dynamic> datos) async {
    final response = await http.put(
      Uri.parse('$baseUrl/BitacoraOt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(datos),
    );  
    return jsonDecode(response.body)['Data'];
  }
  // -----------------------------------------------------

Future<List<Map<String, dynamic>>> getMarbetesPorCliente(String cliente) async {
  final url = Uri.parse('$baseUrl/obtenerMarbetesPorCliente/$cliente');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['DATA'] ?? []);
  } else {
    debugPrint('❌ Error al obtener marbetes por cliente: ${response.statusCode}');
    return []; 
  }
}

Future<List<Map<String, dynamic>>> getMarbetesPorOrden(String orden) async {
  final url = Uri.parse('$baseUrl/obtenerMarbetesPorOrden/$orden');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['DATA'] ?? []);
  } else {
    debugPrint('❌ Error al obtener marbetes por orden: ${response.statusCode}');
    return [];
  }
}

Future<List<Map<String, dynamic>>> getMarbetesPorGrupo(String grupo) async {
  final url = Uri.parse('$baseUrl/obtenerMarbetesPorGrupo/$grupo');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['DATA'] ?? []);
  } else {
    debugPrint('❌ Error al obtener marbetes por grupo: ${response.statusCode}');
    return [];
  }
}

  // ----------------------------------------------------------

}