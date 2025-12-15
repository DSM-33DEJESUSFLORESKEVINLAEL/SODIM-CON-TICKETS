// ignore_for_file: unused_field, unused_element, use_build_context_synchronously, unnecessary_string_interpolations

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodim/api/api_service.dart';
import 'package:sodim/db/catalogo_dao.dart';
import 'package:sodim/db/mordenes_dao.dart';
import 'package:sodim/models/orden_model.dart';
import 'package:sodim/pages/login_page.dart';
import 'package:sodim/utils/sincronizador_service.dart';

/// Pantalla de captura/edición de marbetes para una orden.
class MarbetesForms extends StatefulWidget {
  final Orden orden;
  final bool soloLectura;

  const MarbetesForms({
    super.key,
    required this.orden,
    this.soloLectura = false,
  });

  @override
  State<MarbetesForms> createState() => _MarbetesFormsState();
}

class _MarbetesFormsState extends State<MarbetesForms> {
  // Controladores cabecera
  final TextEditingController ordenController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController empresaController = TextEditingController();
  final TextEditingController vendedorController = TextEditingController();
  final TextEditingController fCapturaController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController _ordenViewController = TextEditingController();
  int _lonOrden = 0; // largo total (prefijo + dígitos)

  // Estado de formulario / selección
  bool camposObligatoriosIncompletos = false;
  int? selectedIndex;
  bool isEditing = false;
  bool isCreating = false;

  // Mapa de campos vacíos (si quieres remarcar visualmente)
  Map<String, bool> camposVacios = {
    'marbete': false,
    'matricula': false,
    'medida': false,
    'marca': false,
    'trabajo': false,
  };

  // Controladores detalle marbete
  final TextEditingController marbeteController = TextEditingController();
  final TextEditingController matriculaController = TextEditingController();
  final TextEditingController medidaController = TextEditingController();
  final TextEditingController marcaController = TextEditingController();
  final TextEditingController trabajoController = TextEditingController();
  final TextEditingController trabajoAlternoController =
      TextEditingController();
  final TextEditingController codigoTraController = TextEditingController();
  final TextEditingController compuestoController = TextEditingController();
  final TextEditingController trabajoOtrController = TextEditingController();
  final TextEditingController observacionController = TextEditingController();
  final TextEditingController sgController = TextEditingController();
  final TextEditingController busController = TextEditingController();
  final TextEditingController economicoController = TextEditingController();

  // Catálogos en memoria
  final List<String> compuestos = [
    'OTRS',
    'RTC',
    'ARC',
    'TYT',
    'TR',
    'SEM',
    'PQ',
  ];
  final List<String> trabajosOtr = ['FT', 'MO', 'OT'];
  final List<String> sg = ['S', 'N'];

  List<String> marcas = [];
  List<String> medidas = [];
  List<String> terminados = [];
  List<String> trabajos = [];
  List<String> prefijos = [];

  // Lista combinada (servidor + local) de marbetes
  List<Map<String, dynamic>> marbetes = [];

  String? clienteSeleccionado;
  bool loading = true;
  bool mostrarBotonesEdicion = false; // Mostrar/ocultar Guardar/Cancelar
  String get _prefsKeyMarbetes => 'marbetes_${widget.orden.orden}';

  /// Ciclo de vida: inicializa datos, fecha, SG y sincroniza si hay internet.
  @override
  void initState() {
    super.initState();
    _ordenViewController.text = widget.orden.orden; // <- importante
    cargarDatosIniciales();
    fCapturaController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // ✅ Valor por defecto de SG
    sgController.text = 'S';
    cargarMarbetes();

    Future.delayed(const Duration(seconds: 2), () async {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        await SincronizadorService.sincronizarOrdenes();
        await SincronizadorService.sincronizarMarbetes();

        await cargarMarbetes();
        await _persistirUltimoMarbeteDetectado();

        debugPrint('🔁 Lista de marbetes recargada después de sincronizar');
      }
    });
  }

  /// Carga datos iniciales necesarios para la vista:
  /// - Vendedor desde SharedPreferences
  /// - Catálogos (marcas, medidas, terminados, prefijos, trabajos)
  Future<void> cargarDatosIniciales() async {
    await Future.wait([
      // cargarClientesDesdeSQLite(),
      cargarVendedorDesdePreferencias(),
      // cargarClientes1DesdeSQLite(),
      cargarCatalogosDesdeSQLite(),
    ]);
    setState(() => loading = false);
  }

  /// Obtiene marbetes de servidor y SQLite, normaliza y combina sin duplicados (por MARBETE).
  /// También calcula y loguea el último marbete por prefijo.
  Future<void> cargarMarbetes() async {
    final api = ApiService();

    // 1) Servidor
    final marbetesServidorCrudos = await api.getMOrdenes(widget.orden.orden);

    // Normaliza (asegura uppercase y trim en MARBETE)
    final marbetesServidor =
        marbetesServidorCrudos.map((e) {
          final map = Map<String, dynamic>.from(e);
          map['MARBETE'] = map['MARBETE']?.toString().toUpperCase().trim();
          map['_ORIGEN'] = 'SERVIDOR'; // 👈 etiqueta de origen
          return map;
        }).toList();

    // 2) Local
    final marbetesLocalesCrudos = await MOrdenesDAO.obtenerTodosPorOrden(
      widget.orden.orden,
    );

    final marbetesLocales =
        marbetesLocalesCrudos.map((map) {
          final nuevo = map.map((k, v) => MapEntry(k.toUpperCase(), v));
          nuevo['MARBETE'] = nuevo['MARBETE']?.toString().toUpperCase().trim();
          nuevo['_ORIGEN'] = 'LOCAL'; // 👈 ayuda para depuración
          return nuevo;
        }).toList();

    // 2.5) LocalStorage (SharedPreferences)
    final marbetesLS = await _lsRead();

    // 3) Combinar evitando duplicados por 'MARBETE'
    final combinados = <Map<String, dynamic>>[];
    final marbetesUnicos = <String>{};

    for (final s in marbetesServidor) {
      final id = s['MARBETE'];
      if (id != null && marbetesUnicos.add(id)) combinados.add(s);
    }

    // SQLite
    for (final l in marbetesLocales) {
      final id = l['MARBETE'];
      if (id != null && marbetesUnicos.add(id)) combinados.add(l);
    }
    // LocalStorage
    for (final ls in marbetesLS) {
      final id = ls['MARBETE'];
      if (id != null && marbetesUnicos.add(id)) combinados.add(ls);
    }

    // Ordena y setState (ya lo haces)
    combinados.sort(_compareMarbetesMap);
    setState(() => marbetes = combinados);

    // ⛳️ Mantén el localStorage sincronizado con la lista combinada
    await _lsWrite(combinados);

    // ✅ Ordena aquí (después de combinar)
    combinados.sort(_compareMarbetesMap);

    // 4) Debug
    debugPrint('🌐 Marbetes servidor      : ${marbetesServidor.length}');
    debugPrint('📱 Marbetes locales       : ${marbetesLocales.length}');
    debugPrint('🧩 Total combinados       : ${combinados.length}');
    debugPrint('┌──────── LISTA COMBINADA (${combinados.length}) ────────');
    for (var i = 0; i < combinados.length; i++) {
      final e = combinados[i];
      debugPrint(
        '${i + 1}. '
        'MARBETE=${e['MARBETE'] ?? ''} | '
        'ORIGEN=${e['_ORIGEN'] ?? ''} | '
        'MATRICULA=${e['MATRICULA'] ?? ''} | '
        'MEDIDA=${e['MEDIDA'] ?? ''} | '
        'MARCA=${e['MARCA'] ?? ''} | '
        'TRABAJO=${e['TRABAJO'] ?? ''} | '
        'SG=${e['SG'] ?? ''} | '
        'LOCAL=${e['LOCAL'] ?? ''} | '
        'FECHASYS=${e['FECHASYS'] ?? ''}',
      );
    }
    debugPrint('└────────────────────────────────────────────────────────');

    // a) Último tal cual en la lista combinada
    final String? ultimoEnLista =
        combinados.isNotEmpty ? (combinados.last['MARBETE']?.toString()) : null;
    debugPrint(
      '🧾 Último (lista combinada): ${ultimoEnLista ?? "(sin marbetes)"}',
    );

    // b) Último por prefijo (máximo numérico del prefijo de la orden)
    final String prefijoActual = _extraerPrefijo(widget.orden.orden);
    final List<int> numerosPrefijo =
        combinados
            .map((e) => (e['MARBETE'] ?? '').toString().toUpperCase().trim())
            .where(
              (m) =>
                  m.startsWith(prefijoActual) &&
                  int.tryParse(m.substring(prefijoActual.length)) != null,
            )
            .map((m) => int.parse(m.substring(prefijoActual.length)))
            .toList();

    final String? ultimoPorPrefijo =
        numerosPrefijo.isEmpty
            ? null
            : '$prefijoActual${numerosPrefijo.reduce((a, b) => a > b ? a : b)}';
    debugPrint(
      '🔚 Último por prefijo ($prefijoActual): ${ultimoPorPrefijo ?? "(ninguno)"}',
    );

    if (ultimoPorPrefijo != null) {
      final n = int.parse(ultimoPorPrefijo.substring(prefijoActual.length));
      debugPrint('➡️  Siguiente sugerido: $prefijoActual${n + 1}');
    }

    // 5) Actualiza UI
    if (!mounted) return;
    setState(() {
      marbetes = combinados;
    });

    // Log último marbete por prefijo (tu línea original)
    final prefijo = _extraerPrefijo(widget.orden.orden);
    final ultimo = _ultimoMarbetePorPrefijo(prefijo);
    debugPrint('🔚 Último marbete para prefijo $prefijo: $ultimo ');
  }

  /// Carga catálogos desde SQLite (marcas, medidas, terminados, prefijos, trabajos)
  /// y los asigna a las listas usadas por los TypeAhead.
  Future<void> cargarCatalogosDesdeSQLite() async {
    final datos = await Future.wait([
      CatalogoDAO.obtenerCatalogoSimple(tabla: 'marcas', campo: 'marca'),
      CatalogoDAO.obtenerCatalogoSimple(tabla: 'medidas', campo: 'medida'),
      CatalogoDAO.obtenerCatalogoSimple(
        tabla: 'terminados',
        campo: 'terminado',
      ),
      CatalogoDAO.obtenerCatalogoSimple(tabla: 'prefijos', campo: 'prefijo'),
      CatalogoDAO.obtenerCatalogoSimple(tabla: 'trabajos', campo: 'trabajo'),
    ]);

    setState(() {
    
      marcas = datos[0];
      medidas = datos[1];
      terminados = datos[2];
      prefijos = datos[3]; // ✅ prefijos correcto
      trabajos = datos[4]; // ✅ trabajos correct

      // debugPrint('🏷️ Marcas     : $marcas');
      // debugPrint('📏 Medidas     : $medidas');
      // debugPrint('✅ Terminados  : $terminados');
      // debugPrint('🛠️ Trabajos    : $trabajos');
      debugPrint('🛠️ Prefijos   : $prefijos');
    });
  }

  // -------------------------------------------------------------------------
  /// Lee el vendedor guardado en SharedPreferences y llena empresa/vendedor.
  Future<void> cargarVendedorDesdePreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    final vendedorStr = prefs.getString('vendedor');
    if (vendedorStr != null) {
      final vendedorMap = json.decode(vendedorStr);
      empresaController.text = vendedorMap['EMPRESA'].toString();
      vendedorController.text = vendedorMap['VENDEDOR'].toString();

      _lonOrden =
          int.tryParse(vendedorMap['LON_ORDEN']?.toString() ?? '0') ??
          widget.orden.orden.length; // fallback si no viene
    } else {
      _lonOrden = widget.orden.orden.length;
    }
  }

  // -------------------------------------------------------------------------
  /// Muestra un date picker y escribe la fecha en fCapturaController
  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha != null) {
      fCapturaController.text = DateFormat('yyyy-MM-dd').format(fecha);
    }
  }

  /// Persiste en SharedPreferences el último marbete detectado:

  Future<void> _persistirUltimoMarbeteDetectado() async {
    final prefijo = _extraerPrefijo(widget.orden.orden);
    final ultimo = _ultimoMarbetePorPrefijo(prefijo);

    final prefs = await SharedPreferences.getInstance();

    final keyOrden = 'ultimo_marbete_${widget.orden.orden}';
    if (ultimo != null && ultimo.isNotEmpty) {
      await prefs.setString(keyOrden, ultimo);
    } else {
      await prefs.remove(keyOrden);
    }

    final keyPrefijo = 'ultimo_marbete_prefijo_$prefijo';
    if (ultimo != null && ultimo.isNotEmpty) {
      await prefs.setString(keyPrefijo, ultimo);
    } else {
      await prefs.remove(keyPrefijo);
    }
  }

  Future<List<Map<String, dynamic>>> _lsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKeyMarbetes) ?? [];
    final lista = <Map<String, dynamic>>[];
    for (final s in raw) {
      try {
        final m = Map<String, dynamic>.from(json.decode(s));
        m['MARBETE'] = m['MARBETE']?.toString().toUpperCase().trim();
        m['_ORIGEN'] = m['_ORIGEN'] ?? 'LOCALSTORAGE';
        lista.add(m);
      } catch (_) {
        /* ignora items dañados */
      }
    }
    return lista;
  }

  Future<void> _lsWrite(List<Map<String, dynamic>> lista) async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = lista.map((m) => json.encode(m)).toList();
    await prefs.setStringList(_prefsKeyMarbetes, stringList);
  }

  /// Upsert por MARBETE
  Future<void> _lsUpsert(Map<String, dynamic> m) async {
    final list = await _lsRead();
    final id = (m['MARBETE'] ?? '').toString().toUpperCase().trim();
    final filtered =
        list
            .where(
              (x) => (x['MARBETE'] ?? '').toString().toUpperCase().trim() != id,
            )
            .toList();
    filtered.add({...m, '_ORIGEN': 'LOCALSTORAGE'});
    filtered.sort(_compareMarbetesMap);
    await _lsWrite(filtered);
  }

  /// Remove por MARBETE
  Future<void> _lsRemove(String id) async {
    final list = await _lsRead();
    final filtered =
        list
            .where(
              (x) =>
                  (x['MARBETE'] ?? '').toString().toUpperCase().trim() !=
                  id.toUpperCase().trim(),
            )
            .toList();
    await _lsWrite(filtered);
  }

  // -----------------------------------------------------------------------------------------
  /// Limpia todos los campos del detalle y reinicia SG a 'S'.
  void limpiarCampos() {
    marbeteController.clear();
    matriculaController.clear();
    medidaController.clear();
    marcaController.clear();
    trabajoController.clear();
    trabajoAlternoController.clear();
    codigoTraController.clear();
    compuestoController.clear();
    trabajoOtrController.clear();
    observacionController.clear();

    sgController.text = 'S';
    busController.clear();
    economicoController.clear();
  }

  /// Rellena el detalle con los datos del marbete seleccionado en la tabla.
  void llenarCampos(Map<String, dynamic> data) {
    marbeteController.text = data['MARBETE'] ?? '';
    matriculaController.text = data['MATRICULA'] ?? '';
    medidaController.text = data['MEDIDA'] ?? '';
    marcaController.text = data['MARCA'] ?? '';
    trabajoController.text = data['TRABAJO'] ?? '';
    trabajoAlternoController.text = data['TRABAJOALTERNO'] ?? '';
    codigoTraController.text = data['CODIGO_TRA'] ?? '';
    compuestoController.text = data['COMPUESTO'] ?? '';
    trabajoOtrController.text = data['TRABAJO_OTR'] ?? '';
    sgController.text = data['SG'] ?? '';
    observacionController.text = data['OBSERVACION'] ?? '';

    // Campos adicionales
    busController.text = data['BUS'] ?? '';
    economicoController.text = data['ECONOMICO'] ?? '';
  }

  /// Genera un nuevo MARBETE basado en el prefijo de la orden:
  /// - Si no existe ninguno con ese prefijo y la orden es válida, usa la misma orden
  /// - Si existen, toma el número mayor y le suma 1
  String generarMarbete() {
    final ordenBase = widget.orden.orden;

    // Detectar prefijo (letras al inicio)
    final prefijoMatch = RegExp(r'^[A-Z]+').firstMatch(ordenBase);
    final prefijo = prefijoMatch?.group(0) ?? 'T'; // Por defecto 'T'

    // Números de marbetes con ese prefijo
    final numeros =
        marbetes
            .map((e) => e['MARBETE']?.toString() ?? '')
            .where(
              (m) =>
                  m.startsWith(prefijo) &&
                  int.tryParse(m.substring(prefijo.length)) != null,
            )
            .map((m) => int.parse(m.substring(prefijo.length)))
            .toList();

    if (numeros.isEmpty) {
      if (ordenBase.startsWith(prefijo) &&
          int.tryParse(ordenBase.substring(prefijo.length)) != null) {
        return ordenBase;
      } else {
        return '$prefijo'; // Fallback (solo prefijo)
      }
    }

    // Usa el mayor + 1
    final max = numeros.reduce((a, b) => a > b ? a : b);
    return '$prefijo${(max + 1).toString()}';
  }

  /// Extrae el prefijo alfabético inicial de un valor (por defecto 'T').
  String _extraerPrefijo(String valor) {
    final m = RegExp(r'^[A-Z]+').firstMatch(valor.toUpperCase().trim());
    return m?.group(0) ?? 'T';
  }

  String? _ultimoMarbetePorPrefijo(String prefijo) {
    final numeros =
        marbetes
            .map((e) => (e['MARBETE'] ?? '').toString().toUpperCase().trim())
            .where(
              (m) =>
                  m.startsWith(prefijo) &&
                  int.tryParse(m.substring(prefijo.length)) != null,
            )
            .map((m) => int.parse(m.substring(prefijo.length)))
            .toList();

    if (numeros.isEmpty) return null;
    final max = numeros.reduce((a, b) => a > b ? a : b);
    return '$prefijo$max';
  }

  int _compareMarbeteStr(String a, String b) {
    a = a.toUpperCase().trim();
    b = b.toUpperCase().trim();

    String prefijoA = _extraerPrefijo(a);
    String prefijoB = _extraerPrefijo(b);

    // 1) Ordena por prefijo (A..Z)
    final prefCmp = prefijoA.compareTo(prefijoB);
    if (prefCmp != 0) return prefCmp;

    // 2) Luego por parte numérica (si existe)
    final numA = int.tryParse(a.substring(prefijoA.length));
    final numB = int.tryParse(b.substring(prefijoB.length));

    if (numA != null && numB != null) return numA.compareTo(numB);

    // 3) Fallback: comparación alfabética completa
    return a.compareTo(b);
  }

  int _compareMarbetesMap(Map<String, dynamic> a, Map<String, dynamic> b) {
    final sa = (a['MARBETE'] ?? '').toString();
    final sb = (b['MARBETE'] ?? '').toString();
    return _compareMarbeteStr(sa, sb);
  }

  // Widget _buildDropdownConController(
  //   String label,
  //   TextEditingController controller, {
  //   required String clave,
  //   required List<String> opciones,
  //   String? Function(String?)? validator,
  // }) {
  //   return TypeAheadFormField<String>(
  //     textFieldConfiguration: TextFieldConfiguration(
  //       controller: controller,
  //       enabled: isEditing,
  //       inputFormatters: [UpperCaseTextFormatter()],
  //       decoration: InputDecoration(
  //         labelText: label,
  //         floatingLabelBehavior:
  //             FloatingLabelBehavior.always, // 👈 SIEMPRE visible
  //         labelStyle: const TextStyle(
  //           fontWeight: FontWeight.w600, // 👈 opcional: negritas
  //         ),
  //         border: const OutlineInputBorder(
  //           borderSide: BorderSide(color: Colors.green),
  //         ),
  //         enabledBorder: const OutlineInputBorder(
  //           borderSide: BorderSide(color: Colors.green),
  //         ),
  //         focusedBorder: const OutlineInputBorder(
  //           borderSide: BorderSide(color: Colors.green, width: 2),
  //         ),
  //         contentPadding: const EdgeInsets.symmetric(
  //           horizontal: 12,
  //           vertical: 10,
  //         ),
  //       ),
  //     ),
  //     suggestionsCallback: (pattern) {
  //       return opciones
  //           .where(
  //             (opcion) => opcion.toLowerCase().contains(pattern.toLowerCase()),
  //           )
  //           .toList();
  //     },
  //     itemBuilder:
  //         (context, String suggestion) => ListTile(title: Text(suggestion)),
  //     onSuggestionSelected: (String suggestion) => controller.text = suggestion,
  //     validator: (value) {
  //       if (value == null || value.isEmpty) return '⚠ Requerido';
  //       if (!opciones.contains(value.toUpperCase())) {
  //         return '❌ Seleccione una opción válida';
  //       }
  //       return validator != null ? validator(value) : null;
  //     },
  //     noItemsFoundBuilder:
  //         (context) => const Padding(
  //           padding: EdgeInsets.all(8.0),
  //           child: Text('🔍 Sin coincidencias'),
  //         ),
  //   );
  // }
  Widget _buildDropdownConController(
  String label,
  TextEditingController controller, {
  required String clave,
  required List<String> opciones,
  String? Function(String?)? validator,
}) {
  return TypeAheadField<String>(
    controller: controller,
    suggestionsCallback: (pattern) {
      return opciones
          .where((o) => o.toLowerCase().contains(pattern.toLowerCase()))
          .toList();
    },
    builder: (context, textController, focusNode) {
      return TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: isEditing,
        inputFormatters: [UpperCaseTextFormatter()],
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      );
    },
    itemBuilder: (context, item) {
      return ListTile(title: Text(item));
    },
    onSelected: (item) {
      controller.text = item;
    },
  );
}


  // Widget _buildDropdownConController2(
  //   String label,
  //   TextEditingController controller, {
  //   required String clave,
  //   required List<String> opciones,
  //   String? Function(String?)? validator,
  // }) {
  //   return TypeAheadFormField<String>(
  //     textFieldConfiguration: TextFieldConfiguration(
  //       controller: controller,
  //       enabled: isEditing,
  //       inputFormatters: [UpperCaseTextFormatter()],
  //       decoration: InputDecoration(
  //         labelText: label,
  //         floatingLabelBehavior:
  //             FloatingLabelBehavior.always, // 👈 SIEMPRE visible
  //         labelStyle: const TextStyle(
  //           fontWeight: FontWeight.w600, // 👈 opcional: negritas
  //         ),
  //         border: const OutlineInputBorder(
  //           borderSide: BorderSide(color: Color.fromARGB(255, 255, 137, 3)),
  //         ),
  //         enabledBorder: const OutlineInputBorder(
  //           borderSide: BorderSide(color: Color.fromARGB(255, 255, 137, 3)),
  //         ),
  //         focusedBorder: const OutlineInputBorder(
  //           borderSide: BorderSide(
  //             color: Color.fromARGB(255, 255, 137, 3),
  //             width: 2,
  //           ),
  //         ),
  //         contentPadding: const EdgeInsets.symmetric(
  //           horizontal: 12,
  //           vertical: 10,
  //         ),
  //       ),
  //     ),
  //     suggestionsCallback: (pattern) {
  //       return opciones
  //           .where(
  //             (opcion) => opcion.toLowerCase().contains(pattern.toLowerCase()),
  //           )
  //           .toList();
  //     },
  //     itemBuilder:
  //         (context, String suggestion) => ListTile(title: Text(suggestion)),
  //     onSuggestionSelected: (String suggestion) => controller.text = suggestion,
  //     validator: (value) {
  //       if (value != null &&
  //           value.isNotEmpty &&
  //           !opciones.contains(value.toUpperCase())) {
  //         return '❌ Seleccione una opción válida';
  //       }
  //       return validator != null ? validator(value) : null;
  //     },
  //     noItemsFoundBuilder:
  //         (context) => const Padding(
  //           padding: EdgeInsets.all(8.0),
  //           child: Text('🔍 Sin coincidencias'),
  //         ),
  //   );
  // }

Widget _buildDropdownConController2(
  String label,
  TextEditingController controller, {
  required String clave,
  required List<String> opciones,
  String? Function(String?)? validator,
}) {
  return TypeAheadField<String>(
    controller: controller,
    suggestionsCallback: (pattern) {
      return opciones
          .where((o) => o.toLowerCase().contains(pattern.toLowerCase()))
          .toList();
    },
    builder: (context, textController, focusNode) {
      return TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: isEditing,
        validator: validator,
        inputFormatters: [UpperCaseTextFormatter()],
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.orange),
          ),
        ),
      );
    },
    itemBuilder: (context, item) => ListTile(title: Text(item)),
    onSelected: (item) => controller.text = item,
  );
}

  // Widget _buildDropdownConController3(
  //   String label,
  //   TextEditingController controller, {
  //   required String clave,
  //   required List<String> opciones,
  //   String? Function(String?)? validator,
  // }) {
  //   return TypeAheadFormField<String>(
  //     textFieldConfiguration: TextFieldConfiguration(
  //       controller: controller,
  //       enabled: isEditing,
  //       inputFormatters: [UpperCaseTextFormatter()],
  //       decoration: const InputDecoration().copyWith(
  //         labelText: label,
  //         floatingLabelBehavior: FloatingLabelBehavior.always,
  //         border: const OutlineInputBorder(),
  //         contentPadding: const EdgeInsets.symmetric(
  //           horizontal: 12,
  //           vertical: 10,
  //         ),
  //       ),
  //     ),
  //     suggestionsCallback:
  //         (pattern) =>
  //             opciones
  //                 .where((o) => o.toLowerCase().contains(pattern.toLowerCase()))
  //                 .toList(),
  //     itemBuilder: (context, String s) => ListTile(title: Text(s)),
  //     onSuggestionSelected: (String s) => controller.text = s,
  //     validator: (value) {
  //       if (value != null &&
  //           value.isNotEmpty &&
  //           !opciones.contains(value.toUpperCase())) {
  //         return '❌ Seleccione una opción válida';
  //       }
  //       return validator != null ? validator(value) : null;
  //     },
  //     noItemsFoundBuilder:
  //         (context) => const Padding(
  //           padding: EdgeInsets.all(8.0),
  //           child: Text('🔍 Sin coincidencias'),
  //         ),
  //   );
  // }

Widget _buildDropdownConController3(
  String label,
  TextEditingController controller, {
  required String clave,
  required List<String> opciones,
  String? Function(String?)? validator,
}) {
  return TypeAheadField<String>(
    controller: controller,
    suggestionsCallback: (pattern) {
      return opciones
          .where((o) => o.toLowerCase().contains(pattern.toLowerCase()))
          .toList();
    },
    builder: (context, textController, focusNode) {
      return TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: isEditing,
        validator: validator,
        inputFormatters: [UpperCaseTextFormatter()],
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: const OutlineInputBorder(),
        ),
      );
    },
    itemBuilder: (context, item) => ListTile(title: Text(item)),
    onSelected: (item) => controller.text = item,
  );
}

  Widget _buildCampoConController(
    String label,
    TextEditingController controller, {
    required String clave,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: 350,
      child: TextFormField(
        controller: controller,
        enabled: isEditing,
        inputFormatters: [
          UpperCaseTextFormatter(),
          LengthLimitingTextInputFormatter(14), // 👈 LIMITE A 14 CARACTERES
        ],
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior:
              FloatingLabelBehavior.always, // 👈 SIEMPRE visible
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600, // 👈 opcional: negritas
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: const OutlineInputBorder(), // 👈 si quieres borde consistente
        ),
      ),
    );
  }

  /// Campo simple (mayúsculas) sin límites especiales (puedes agregar si deseas).
  Widget _buildCampoConController3(
    String label,
    TextEditingController controller, {
    required String clave,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: 350,
      child: TextFormField(
        controller: controller,
        enabled: isEditing,
        inputFormatters: [UpperCaseTextFormatter()],
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildCampoConController2(
    String label,
    TextEditingController controller, {
    required String clave,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: 350,
      child: TextFormField(
        controller: controller,
        enabled: isEditing,
        inputFormatters: [UpperCaseTextFormatter()],
        validator: validator,
        decoration: const InputDecoration().copyWith(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildCampoConController9(
  String label,
  TextEditingController controller, {
  required String clave,
  String? Function(String?)? validator,

  int maxLen = 10, // 👈 valor por defecto (antes era 14 fijo)
}) {
  return SizedBox(
    width: 350,
    child: TextFormField(
      controller: controller,
      enabled: isEditing,
      inputFormatters: [
        UpperCaseTextFormatter(),
        LengthLimitingTextInputFormatter(maxLen), // 👈 usa el parámetro
      ],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: const OutlineInputBorder(),
      ),
    ),
  );
}


  /// Construye toda la UI
  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final screenWidth = MediaQuery.of(context).size.width;

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Image.asset('assets/images/SODIM1.png', height: 48),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFA500), Color(0xFFF7B234)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment, color: Color(0xFFF7B234)),
                    const SizedBox(width: 8),
                    Text(
                      '📌Orden: ${widget.orden.orden}',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                /// Barra de acciones principales
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),

                      /// NUEVO
                      _iconAction(
                        icon: Icons.add_box,
                        label: 'Nuevo',
                        onTap:
                            (!widget.soloLectura && !isCreating && !isEditing)
                                ? () {
                                  limpiarCampos();
                                  marbeteController.text = generarMarbete();
                                  isCreating = true;
                                  isEditing = true;
                                  mostrarBotonesEdicion = true;
                                  selectedIndex = null;
                                  setState(() {});
                                }
                                : null,
                      ),

                      const SizedBox(width: 24),

                      /// MODIFICAR
                      _iconAction(
                        icon: Icons.edit,
                        label: 'Modificar',
                        onTap:
                            (!widget.soloLectura &&
                                    !mostrarBotonesEdicion &&
                                    selectedIndex != null &&
                                    !isCreating)
                                ? () {
                                  final seleccionado = marbetes[selectedIndex!];
                                  llenarCampos(seleccionado);
                                  isCreating = false;
                                  isEditing = true;
                                  mostrarBotonesEdicion = true;
                                  setState(() {});
                                }
                                : null,
                      ),

                      const SizedBox(width: 24),

                      /// GUARDAR
                      _iconAction(
                        icon: Icons.save,
                        label: 'Guardar',
                        onTap:
                            (mostrarBotonesEdicion)
                                ? () async {
                                  // ✅ Validación global
                                  if (!formKey.currentState!.validate()) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '⚠️ Faltan Campos por llenar',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  // Construye payload
                                  final ordenActual = widget.orden.orden;
                                  final marbeteActual =
                                      marbeteController.text.trim();

                                  final datosActualizar = {
                                    'ORDEN': ordenActual,
                                    'MARBETE': marbeteActual,
                                    'MATRICULA': matriculaController.text,
                                    'MEDIDA': medidaController.text,
                                    'MARCA': marcaController.text,
                                    'TRABAJO': trabajoController.text,
                                    'TRABAJOALTERNO':
                                        trabajoAlternoController.text,
                                    'UBICACION': null,
                                    'CODIGO_TRA': codigoTraController.text,
                                    'COMPUESTO': compuestoController.text,
                                    'TRABAJO_OTR': trabajoOtrController.text,
                                    'SG': sgController.text,
                                    'OBS': observacionController.text,
                                    'BUS': busController.text,
                                    'ECONOMICO': economicoController.text,
                                  };

                                  final datosInsertar = {
                                    ...datosActualizar,
                                    'CLIENTE': widget.orden.cliente,
                                    'RAZONSOCIAL': widget.orden.razonsocial,
                                    'EMPRESA': empresaController.text,
                                    'VEND': vendedorController.text,
                                  };

                                  final jsonFinal =
                                      isCreating
                                          ? datosInsertar
                                          : datosActualizar;
                                  debugPrint(
                                    '📤 Enviando JSON: ${jsonEncode(jsonFinal)}',
                                  );

                                  try {
                                    final api = ApiService();
                                    final result =
                                        isCreating
                                            ? await api.insertMOrdenes(
                                              jsonFinal,
                                            )
                                            : await api.updateMOrdenes(
                                              jsonFinal,
                                            );

                                    // Guarda también en SQLite como LOCAL="N"
                                    final datosLocal = {
                                      ...jsonFinal,
                                      'LOCAL': 'N',
                                      'FECHASYS': DateFormat(
                                        'yyyy-MM-dd HH:mm:ss',
                                      ).format(DateTime.now()),
                                    };
                                    await MOrdenesDAO.insertarMOrden(
                                      datosLocal,
                                    );
                                    debugPrint(
                                      '📥 Guardado en SQLite con LOCAL=N',
                                    );

                                    // Bitácora de cambios si fue update
                                    if (!isCreating && selectedIndex != null) {
                                      final anterior = marbetes[selectedIndex!];
                                      final cambios = <String>[];

                                      for (final campo
                                          in datosActualizar.keys) {
                                        final nuevo =
                                            datosActualizar[campo]
                                                ?.toString() ??
                                            '';
                                        final viejo =
                                            anterior[campo]?.toString() ?? '';
                                        if (nuevo != viejo) {
                                          cambios.add(
                                            '$campo: "$viejo" → "$nuevo"',
                                          );
                                        }
                                      }

                                      if (cambios.isNotEmpty) {
                                        final observacion =
                                            'Se actualizó el marbete $marbeteActual. Cambios:\n${cambios.join('\n')}';

                                        final bitacoraData = {
                                          'REG': 1,
                                          'ORDEN': ordenActual,
                                          'MARBETE': marbeteActual,
                                          'OBSERVACION': observacion,
                                          'FECHASYS': DateFormat(
                                            'yyyy-MM-dd HH:mm:ss',
                                          ).format(DateTime.now()),
                                          'USUARIO':
                                              vendedorController.text.trim(),
                                        };

                                        try {
                                          await api.insertBitacorasOt(
                                            bitacoraData,
                                          );
                                          debugPrint('📝 Bitácora insertada');
                                        } catch (_) {
                                          try {
                                            await api.updateBitacorasOt(
                                              bitacoraData,
                                            );
                                            debugPrint(
                                              '📝 Bitácora actualizada',
                                            );
                                          } catch (e2) {
                                            debugPrint(
                                              '❌ No se pudo actualizar bitácora: $e2',
                                            );
                                          }
                                        }
                                      }
                                    }

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '✅ ${isCreating ? "Insertado" : "Actualizado"}: $result',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );

                                    // Refleja cambios en memoria/UI
                                    if (isCreating) {
                                      marbetes.add({
                                        ...datosInsertar,
                                        '_ORIGEN': 'SERVIDOR',
                                      });
                                    } else if (selectedIndex != null) {
                                      marbetes[selectedIndex!] = {
                                        ...datosActualizar,
                                        '_ORIGEN': 'SERVIDOR',
                                      };
                                    }

                                    // ✅ Re-ordenar SIEMPRE después de tocar la lista
                                    marbetes.sort(_compareMarbetesMap);

                                    limpiarCampos();
                                    isCreating = false;
                                    isEditing = false;
                                    mostrarBotonesEdicion = false;
                                    selectedIndex = null;
                                    setState(() {});
                                  } catch (e) {
                                    // Modo offline / error: persiste LOCAL="S"
                                    debugPrint('❌ Error: $e');

                                    final datosLocal = {
                                      ...jsonFinal,
                                      'LOCAL': 'S',
                                      'FECHASYS': DateFormat(
                                        'yyyy-MM-dd HH:mm:ss',
                                      ).format(DateTime.now()),
                                    };

                                    await MOrdenesDAO.insertarMOrden(
                                      datosLocal,
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '📴 Marbete guardado localmente en SQLite',
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );

                                    debugPrint(
                                      '📦 JSON guardado en SQLite:\n${const JsonEncoder.withIndent('  ').convert(datosLocal)}',
                                    );

                                    if (isCreating) {
                                      marbetes.add({
                                        ...datosLocal,
                                        '_ORIGEN': 'LOCAL',
                                      });
                                    } else if (selectedIndex != null) {
                                      marbetes[selectedIndex!] = {
                                        ...datosLocal,
                                        '_ORIGEN': 'LOCAL',
                                      };
                                    }

                                    // ✅ Re-ordenar también en offline/error
                                    marbetes.sort(_compareMarbetesMap);

                                    limpiarCampos();
                                    isCreating = false;
                                    isEditing = false;
                                    mostrarBotonesEdicion = false;
                                    selectedIndex = null;
                                    setState(() {});
                                  }
                                }
                                : null,
                      ),

                      const SizedBox(width: 24),

                      /// CANCELAR
                      _iconAction(
                        icon: Icons.cancel,
                        label: 'Cancelar',
                        onTap:
                            (mostrarBotonesEdicion)
                                ? () {
                                  limpiarCampos();
                                  isEditing = false;
                                  isCreating = false;
                                  mostrarBotonesEdicion = false;
                                  selectedIndex = null;
                                  setState(() {});
                                }
                                : null,
                      ),

                      const SizedBox(width: 24),

                      /// ELIMINAR
                      _iconAction(
                        icon: Icons.delete_forever,
                        label: 'Elimina Marbete',
                        onTap:
                            (!widget.soloLectura &&
                                    !mostrarBotonesEdicion &&
                                    selectedIndex != null)
                                ? () async {
                                  final seleccionado = marbetes[selectedIndex!];
                                  final String marbeteId =
                                      (seleccionado['MARBETE'] ?? '')
                                          .toString();
                                  final String ubicacion =
                                      (seleccionado['UBICACION'] ?? '')
                                          .toString();
                                  final String ordenActual = widget.orden.orden;

                                  if (ubicacion.isNotEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '❌ No se puede eliminar un marbete con ubicación asignada.',
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }

                                  final confirmado = await showDialog<bool>(
                                    context: context,
                                    builder:
                                        (ctx) => AlertDialog(
                                          title: const Text('Confirmación'),
                                          content: Text(
                                            '¿Deseas eliminar el marbete $marbeteId?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.pop(ctx, false),
                                              child: const Text('No'),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.pop(ctx, true),
                                              child: const Text('Sí'),
                                            ),
                                          ],
                                        ),
                                  );

                                  if (!(confirmado ?? false)) return;

                                  String serverMsg = '';
                                  bool borroServidor = false;

                                  try {
                                    final api = ApiService();
                                    serverMsg = await api.deleteMOrdenes(
                                      marbeteId,
                                    );
                                    borroServidor = true;
                                    debugPrint(
                                      '✅ Eliminado del servidor: ${serverMsg.isNotEmpty ? serverMsg : "(sin mensaje)"}',
                                    );
                                  } catch (e) {
                                    // No detenemos la limpieza local: queremos que desaparezca del dispositivo.
                                    debugPrint(
                                      '⚠️ No se pudo eliminar en servidor ($marbeteId): $e',
                                    );
                                  }

                                  // 🔽 Limpieza local SIEMPRE
                                  try {
                                    // 1) SQLite
                                    final filas =
                                        await MOrdenesDAO.eliminarPorOrdenYMarbete(
                                          ordenActual,
                                          marbeteId,
                                        );
                                    debugPrint(
                                      '🧹 SQLite: filas eliminadas=$filas para $ordenActual/$marbeteId',
                                    );

                                    // 2) SharedPreferences (lista cacheada)
                                    await _lsRemove(marbeteId);
                                    debugPrint(
                                      '🧹 SharedPrefs: removido $marbeteId',
                                    );

                                    // 3) Memoria/UI
                                    marbetes.removeAt(selectedIndex!);
                                    selectedIndex = null;
                                    setState(() {});
                                  } catch (e) {
                                    debugPrint(
                                      '❌ Error limpiando local $marbeteId: $e',
                                    );
                                  }

                                  // 4) Mensaje final
                                  Future.delayed(
                                    const Duration(milliseconds: 100),
                                    () {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            borroServidor
                                                ? (serverMsg.isNotEmpty
                                                    ? '✅ $serverMsg'
                                                    : '✅ Marbete eliminado: $marbeteId')
                                                : '🗑️ Eliminado localmente: $marbeteId (no se pudo borrar en servidor)',
                                          ),
                                          backgroundColor:
                                              borroServidor
                                                  ? Colors.green
                                                  : Colors.orange,
                                        ),
                                      );
                                    },
                                  );
                                }
                                : null,
                      ),

                      const SizedBox(width: 24),

                      /// CERRAR
                      _iconAction(
                        icon: Icons.close,
                        label: 'Cerrar',
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),
                const Text(
                  '📌 Detalles del Marbete',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                /// Formulario de detalle (con validaciones)
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildCampoConController3(
                              'Marbete',
                              marbeteController,
                              clave: 'marbete',
                              validator:
                                  (value) =>
                                      (value == null || value.isEmpty)
                                          ? 'Campo requerido'
                                          : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCampoConController2(
                              'Matrícula',
                              matriculaController,
                              clave: 'matricula',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '⚠ Matrícula requerida';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownConController(
                              'Medida',
                              medidaController,
                              clave: 'medida',
                              opciones: medidas,
                              validator:
                                  (value) =>
                                      (value == null || value.isEmpty)
                                          ? 'Seleccione una medida'
                                          : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownConController(
                              'Marca',
                              marcaController,
                              clave: 'marca',
                              opciones: marcas,
                              validator:
                                  (value) =>
                                      (value == null || value.isEmpty)
                                          ? 'Seleccione una marca'
                                          : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownConController(
                              'Trabajo',
                              trabajoController,
                              clave: 'trabajo',
                              opciones: terminados,
                              validator:
                                  (value) =>
                                      (value == null || value.isEmpty)
                                          ? 'Seleccione un trabajo'
                                          : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdownConController3(
                              'Trabajo alterno',
                              trabajoAlternoController,
                              clave: 'trabajoAlterno',
                              opciones: terminados,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      /// NUEVOS CAMPOS INTEGRADOS: BUS y ECONOMICO
                      Row(
                        children: [
                          Expanded(
                            child: _buildCampoConController9(
                              'Bus',
                              busController,
                              clave: 'bus',
                              validator: (value) => null,
                              maxLen: 10, // 👈 solo Bus a 10
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCampoConController9(
                              'Economico',
                              economicoController,
                              clave: 'economico',
                              validator: (value) => null,
                              maxLen: 10, // 👈 solo Bus a 10
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownConController2(
                              'Código TRA',
                              codigoTraController,
                              clave: 'codigoTra',
                              opciones: trabajos,
                              validator: (value) {
                                final codigoLleno =
                                    value != null && value.trim().isNotEmpty;
                                final compuestoLleno =
                                    compuestoController.text.trim().isNotEmpty;
                                final trabajoOtrLleno =
                                    trabajoOtrController.text.trim().isNotEmpty;

                                // Reglas de dependencia: si hay Código TRA, exige Compuesto y Trabajo OTR
                                if (codigoLleno &&
                                    (!compuestoLleno || !trabajoOtrLleno)) {
                                  return 'Completa Compuesto y Trabajo OTR';
                                }
                                if (value != null &&
                                    value.isNotEmpty &&
                                    !trabajos.contains(value.toUpperCase())) {
                                  return '❌ Seleccione una opción válida';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdownConController2(
                              'Compuesto',
                              compuestoController,
                              clave: 'compuesto',
                              opciones: compuestos,
                              validator: (value) {
                                final codigoLleno =
                                    codigoTraController.text.trim().isNotEmpty;
                                if (codigoLleno &&
                                    (value == null || value.trim().isEmpty)) {
                                  return '⚠ Requerido si Código TRA tiene valor';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownConController2(
                              'Trabajo OTR',
                              trabajoOtrController,
                              clave: 'trabajoOtr',
                              opciones: trabajosOtr,
                              validator: (value) {
                                final codigoLleno =
                                    codigoTraController.text.trim().isNotEmpty;
                                if (codigoLleno &&
                                    (value == null || value.trim().isEmpty)) {
                                  return '⚠ Requerido si Código TRA tiene valor';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdownConController3(
                              'Garantía',
                              sgController,
                              clave: 'sg',
                              opciones: sg,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildCampoConController(
                              'Observación',
                              observacionController,
                              clave: 'observacion',
                              validator: (value) => null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),
                const Text(
                  '📄 Lista de Marbetes Registrados',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                /// Tabla de marbetes (selección para editar/modificar)
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        headingRowColor: WidgetStateProperty.resolveWith(
                          (states) => Colors.deepPurple.shade50,
                        ),
                        dataRowMinHeight: 30,
                        dataRowMaxHeight: 40,
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Marbete',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Matrícula',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Medida',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Marca',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Trabajo',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Trabajo alterno',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'BUS',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Económico',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'SG',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ],
                        rows: List.generate(marbetes.length, (index) {
                          final e = marbetes[index];
                          final bool isSelected = selectedIndex == index;

                          return DataRow(
                            color: WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) =>
                                  isSelected ? Colors.blue.shade100 : null,
                            ),
                            cells: [
                              DataCell(
                                Text(
                                  e['MARBETE'] ?? '',
                                  style: const TextStyle(color: Colors.black),
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(
                                  e['MATRICULA'] ?? '',
                                  style: const TextStyle(color: Colors.black),
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(
                                  e['MEDIDA'] ?? '',
                                  style: const TextStyle(color: Colors.black),
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(
                                  e['MARCA'] ?? '',
                                  style: const TextStyle(color: Colors.black),
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(
                                  e['TRABAJO'] ?? '',
                                  style: const TextStyle(color: Colors.black),
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(
                                  e['TRABAJOALTERNO'] ?? '',
                                  style: const TextStyle(color: Colors.black),
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(
                                  e['BUS'] ?? '',
                                  style: const TextStyle(color: Colors.black),
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(
                                  e['ECONOMICO'] ?? '',
                                  style: const TextStyle(color: Colors.black),
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                              DataCell(
                                Text(
                                  e['SG'] ?? '',
                                  style: const TextStyle(color: Colors.black),
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedIndex = isSelected ? null : index;
                                    if (!isSelected) llenarCampos(e);
                                  });
                                },
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// TextField label + controller genérico
  Widget buildLabelField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      enabled: enabled,
      decoration: const InputDecoration(
        labelText: null,
        border: OutlineInputBorder(),
      ),
    );
  }

  /// Campo genérico pequeño con label (no ligado a controlador).
  Widget buildCampo(String label) {
    return SizedBox(
      width: 180,
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  /// Botón circular de acción con etiqueta.
  Widget _iconAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: onTap == null ? Colors.grey : const Color(0xFFF7B234),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  /// Dropdown "dummy" (placeholder) sin items; útil si luego lo llenas dinámicamente.
  Widget buildDropdown(String label) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 250),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        items: const [],
        onChanged: (value) {},
      ),
    );
  }
}
