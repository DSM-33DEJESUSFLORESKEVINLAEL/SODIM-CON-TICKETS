// // // ignore_for_file: unused_field, unnecessary_null_comparison, constant_identifier_names, unnecessary_brace_in_string_interps, control_flow_in_finally

// // import 'dart:async';
// // import 'package:flutter/material.dart';
// // import 'package:sodim/api/api_service.dart';
// // import 'package:sodim/db/mordenes_dao.dart';
// // import 'package:sodim/utils/marbete_utils.dart';

// // class UltimoMarbeteIndicator extends StatefulWidget {
// //   final TextEditingController ordenController;
// //   final int lonOrden; // LON_ORDEN completo (incluye prefijo)
// //   final List<String> prefijos; // catálogo de prefijos (fallback)
// //   final EdgeInsetsGeometry padding;
// //   final bool mostrarSiguiente; // compatibilidad
// //   final String? ordenFija; // consulta directa por orden exacta
// //   final void Function(String sugerido)? onUsarSugerencia;

// //   /// ✅ NUEVO:
// //   /// - autocompletarEnInput: si es false (usar en EDICIÓN), nunca escribe en el input.
// //   /// - soloPrimeraVez: si es true (default), solo autocompleta una vez y ya no vuelve a tocar el campo.
// //   final bool autocompletarEnInput;
// //   final bool soloPrimeraVez;

// //   const UltimoMarbeteIndicator({
// //     super.key,
// //     required this.ordenController,
// //     required this.lonOrden,
// //     required this.prefijos,
// //     this.padding = const EdgeInsets.only(top: 6),
// //     this.mostrarSiguiente = true,
// //     this.ordenFija,
// //     this.onUsarSugerencia,
// //     this.autocompletarEnInput = true, // en creación: true
// //     this.soloPrimeraVez = true,       // sugiere una vez y luego no reescribe
// //   });

// //   @override
// //   State<UltimoMarbeteIndicator> createState() => _UltimoMarbeteIndicatorState();
// // }

// // class _UltimoMarbeteIndicatorState extends State<UltimoMarbeteIndicator> {
// //   static const bool _LOGS = false;

// //   bool _cargando = false;
// //   String? _ultimo;    // último detectado por prefijo (desde datos)
// //   String? _siguiente; // sugerencia (+1)
// //   Timer? _debounce;

// //   // Para controlar que solo se autocomplemente una vez si así se desea
// //   bool _yaAutocompleto = false;

// //   // Guardamos una referencia al listener para poder removerlo correctamente
// //   late final VoidCallback _onTextChanged;

// //   // === Helpers prefijo/dígitos ===
// //   String _prefixFromText(String text) =>
// //       RegExp(r'^[A-Z]+').firstMatch(text.toUpperCase().trim())?.group(0) ?? '';

// //   String _digitsFromText(String text) => text.replaceAll(RegExp(r'[^0-9]'), '');

// //   String _prefijoDeOrden(String orden) =>
// //       RegExp(r'^[A-Z]+').firstMatch(orden.toUpperCase().trim())?.group(0) ?? 'T';

// //   /// Aplica el MISMO aspecto que ves en tu input: "PREF 123 4567"
// //   String _formatearParaInput(String orden) {
// //     final pref = _prefixOf(orden);
// //     final digits = _digitsFromText(orden);
// //     final maxDigits =
// //         (widget.lonOrden > pref.length) ? (widget.lonOrden - pref.length) : digits.length;

// //     final groups = _buildGroups(maxDigits);
// //     final buf = StringBuffer();
// //     if (pref.isNotEmpty) buf..write(pref)..write(' ');

// //     int consumed = 0;
// //     for (var i = 0; i < groups.length; i++) {
// //       if (i > 0) buf.write(' ');
// //       final g = groups[i];
// //       final remain = digits.length - consumed;
// //       final use = remain > 0 ? (remain >= g ? g : remain) : 0;
// //       if (use > 0) {
// //         buf.write(digits.substring(consumed, consumed + use));
// //         consumed += use;
// //       }
// //     }
// //     return buf.toString().trimRight();
// //   }

// //   String _prefixOf(String text) =>
// //       RegExp(r'^[A-Z]+').firstMatch(text.toUpperCase().trim())?.group(0) ?? '';

// //   // Fallback local si no hay datos
// //   String _siguienteFallback({
// //     required String prefijo,
// //     required String typedDigits,
// //   }) {
// //     if (typedDigits.isNotEmpty && int.tryParse(typedDigits) != null) {
// //       final width = typedDigits.length;
// //       final inc = (int.parse(typedDigits) + 1).toString().padLeft(width, '0');
// //       return '$prefijo$inc';
// //     }
// //     final maxDigits =
// //         (widget.lonOrden > prefijo.length) ? (widget.lonOrden - prefijo.length) : 1;
// //     final inc = '1'.padLeft(maxDigits, '0');
// //     return '$prefijo$inc';
// //   }

// //   List<int> _buildGroups(int maxDigits) {
// //     const defaultGroups = [3, 4];
// //     final groups = <int>[];
// //     int remaining = maxDigits;
// //     int gi = 0;
// //     while (remaining > 0) {
// //       final want = gi < defaultGroups.length ? defaultGroups[gi] : defaultGroups.last;
// //       final take = remaining >= want ? want : remaining;
// //       groups.add(take);
// //       remaining -= take;
// //       gi++;
// //     }
// //     return groups;
// //   }

// //   @override
// //   void initState() {
// //     super.initState();

// //     _onTextChanged = () {
// //       _debounce?.cancel();
// //       _debounce = Timer(const Duration(milliseconds: 250), _recalcular);
// //     };

// //     widget.ordenController.addListener(_onTextChanged);
// //     // Primera evaluación
// //     Future.microtask(_recalcular);
// //   }

// //   @override
// //   void didUpdateWidget(covariant UltimoMarbeteIndicator oldWidget) {
// //     super.didUpdateWidget(oldWidget);

// //     if (oldWidget.ordenController != widget.ordenController) {
// //       oldWidget.ordenController.removeListener(_onTextChanged);
// //       widget.ordenController.addListener(_onTextChanged);
// //       _recalcular();
// //     }

// //     if (oldWidget.ordenFija != widget.ordenFija) {
// //       _recalcular();
// //     }

// //     // Si cambian flags, no tocamos _yaAutocompleto para respetar comportamiento actual;
// //     // si quieres reiniciar la autocompletación, podrías exponer un método o reconstruir el widget.
// //   }

// //   @override
// //   void dispose() {
// //     _debounce?.cancel();
// //     widget.ordenController.removeListener(_onTextChanged);
// //     super.dispose();
// //   }

// //   /// mezcla servidor + SQLite y dedup por MARBETE (orden exacta)
// //   Future<List<Map<String, dynamic>>> _cargarMarbetesParaOrdenExacta(
// //     String ordenConsulta,
// //   ) async {
// //     final api = ApiService();

// //     // 1) Servidor
// //     if (_LOGS) debugPrint('🛰️(Widget) getMOrdenes con ORDEN EXACTA: $ordenConsulta');
// //     final marbetesServidorCrudos = await api.getMOrdenes(ordenConsulta);
// //     final marbetesServidor = marbetesServidorCrudos.map((e) {
// //       final map = Map<String, dynamic>.from(e);
// //       map['MARBETE'] = map['MARBETE']?.toString().toUpperCase().trim();
// //       map['_ORIGEN'] = 'SERVIDOR';
// //       return map;
// //     }).toList();

// //     // 2) Local
// //     final marbetesLocalesCrudos = await MOrdenesDAO.obtenerTodosPorOrden(ordenConsulta);
// //     final marbetesLocales = marbetesLocalesCrudos.map((map) {
// //       final nuevo = map.map((k, v) => MapEntry(k.toString().toUpperCase(), v));
// //       nuevo['MARBETE'] = nuevo['MARBETE']?.toString().toUpperCase().trim();
// //       return nuevo;
// //     }).toList();

// //     // 3) Combinar sin duplicados
// //     final combinados = <Map<String, dynamic>>[];
// //     final unicos = <String>{};
// //     for (final s in marbetesServidor) {
// //       final id = s['MARBETE'];
// //       if (id != null && unicos.add(id)) combinados.add(s);
// //     }
// //     for (final l in marbetesLocales) {
// //       final id = l['MARBETE'];
// //       if (id != null && unicos.add(id)) combinados.add(l);
// //     }

// //     if (_LOGS) {
// //       debugPrint('🌐 Marbetes servidor      : ${marbetesServidor.length}');
// //       debugPrint('📱 Marbetes locales       : ${marbetesLocales.length}');
// //       debugPrint('🧩 Total combinados       : ${combinados.length}');
// //       if (combinados.isNotEmpty) {
// //         debugPrint('🧾 Último (lista combinada): ${combinados.last['MARBETE']}');
// //       }
// //     }

// //     return combinados;
// //   }

// //   Future<void> _recalcular() async {
// //     if (_cargando) return; // evita solapamiento

// //     final typed = widget.ordenController.text;
// //     final prefFromTyped = _prefixFromText(typed);
// //     final digits = _digitsFromText(typed);

// //     // Determinar ORDEN EXACTA que consultaremos (o nada)
// //     String? ordenConsulta;
// //     if (widget.ordenFija != null && widget.ordenFija!.trim().isNotEmpty) {
// //       ordenConsulta = widget.ordenFija!.toUpperCase().trim();
// //     } else if (digits.isNotEmpty) {
// //       ordenConsulta = '${prefFromTyped}${digits}';
// //     } else {
// //       if (!mounted) return;
// //       setState(() {
// //         _cargando = false;
// //         _ultimo = null;
// //         _siguiente = null;
// //       });
// //       if (_LOGS) debugPrint('⏸️(Widget) Sin dígitos y sin ordenFija → no consulto.');
// //       return;
// //     }

// //     if (!mounted) return;
// //     setState(() {
// //       _cargando = true;
// //       _ultimo = null;
// //       _siguiente = null;
// //     });

// //     try {
// //       final combinados = await _cargarMarbetesParaOrdenExacta(ordenConsulta);

// //       // === Elegir **último** por prefijo de la ORDEN (solo si VIENE DE DATOS) ===
// //       final prefijo = _prefijoDeOrden(ordenConsulta);
// //       int maxN = -1;
// //       String? ultimoDetectado;
// //       for (final m in combinados) {
// //         final s = (m['MARBETE'] ?? '').toString();
// //         final n = MarbeteUtils.numeroFinal(s, prefijo);
// //         if (n != null && n > maxN) {
// //           maxN = n;
// //           ultimoDetectado = s; // esto sí viene de datos
// //         }
// //       }

// //       // === Calcular SIGUIENTE ===
// //       String? siguiente;
// //       if (ultimoDetectado != null && ultimoDetectado.isNotEmpty) {
// //         final m = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(ultimoDetectado.trim().toUpperCase());
// //         if (m != null) {
// //           final pref = m.group(1)!;
// //           final numStr = m.group(2)!;
// //           final nextNum = (int.parse(numStr) + 1).toString().padLeft(numStr.length, '0');
// //           siguiente = '$pref$nextNum';
// //         } else {
// //           siguiente = ultimoDetectado;
// //         }
// //       } else {
// //         // SIN DATOS: usar fallback local (NO autocompleta el input)
// //         final typedNow = widget.ordenController.text;
// //         final prefFromTypedNow = _prefixFromText(typedNow);
// //         final digitsFromTyped = _digitsFromText(typedNow);
// //         final pref = (prefFromTypedNow.isNotEmpty)
// //             ? prefFromTypedNow
// //             : _prefijoDeOrden(ordenConsulta);
// //         siguiente = _siguienteFallback(prefijo: pref, typedDigits: digitsFromTyped);
// //       }

// //       // Recortar si excede LON_ORDEN
// //       if (widget.lonOrden > 0 && siguiente != null && siguiente.length > widget.lonOrden) {
// //         siguiente = siguiente.substring(0, widget.lonOrden);
// //       }

// //       // ¿El último detectado provino realmente de datos?
// //       final bool ultimoEnDatos = (ultimoDetectado != null) &&
// //           combinados.any((e) =>
// //               (e['MARBETE'] ?? '').toString().toUpperCase().trim() ==
// //               ultimoDetectado!.toUpperCase().trim());

// //       if (!mounted) return;
// //       setState(() {
// //         _ultimo = ultimoDetectado;
// //         _siguiente = siguiente;

// //         // === Autocompletar dentro del input SOLO si:
// //         // - Vino de datos (ultimoEnDatos),
// //         // - Está habilitado (autocompletarEnInput),
// //         // - Y (no es soloPrimeraVez) o (si es soloPrimeraVez y aún no hemos autocompletado).
// //         final puedeAutocompletar =
// //             ultimoEnDatos &&
// //             widget.autocompletarEnInput &&
// //             (!widget.soloPrimeraVez || !_yaAutocompleto);

// //         if (puedeAutocompletar && _siguiente != null && _siguiente!.isNotEmpty) {
// //           final actualDigits = _digitsFromText(widget.ordenController.text);
// //           final ultimoDigits = _ultimo != null ? _digitsFromText(_ultimo!) : '';
// //           final userEscribioAlgoPropio =
// //               actualDigits.isNotEmpty && actualDigits != ultimoDigits;

// //           if (!userEscribioAlgoPropio) {
// //             final masked = _formatearParaInput(_siguiente!);
// //             if (masked != widget.ordenController.text) {
// //               widget.ordenController.text = masked;
// //               widget.ordenController.selection =
// //                   TextSelection.collapsed(offset: masked.length);
// //               _yaAutocompleto = true; // ✅ marcamos que ya se autocompletó
// //               // Callback opcional
// //               widget.onUsarSugerencia?.call(_siguiente!);
// //             }
// //           }
// //         }
// //       });
// //     } catch (e) {
// //       if (!mounted) return;
// //       setState(() {
// //         _ultimo = null;
// //         _siguiente = null;
// //       });
// //       if (_LOGS) debugPrint('❌(Widget) Error consultando último/siguiente: $e');
// //     } finally {
// //       if (!mounted) return;
// //       setState(() => _cargando = false);
// //     }
// //   }

// //   // 👇 Widget “headless”: no muestra nada en pantalla
// //   @override
// //   Widget build(BuildContext context) => const SizedBox.shrink();
// // }


// // ignore_for_file: unused_field, unnecessary_null_comparison, constant_identifier_names,
// // unnecessary_brace_in_string_interps, control_flow_in_finally

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:sodim/api/api_service.dart';
// import 'package:sodim/db/mordenes_dao.dart';
// import 'package:sodim/utils/marbete_utils.dart';

// class UltimoMarbeteIndicator extends StatefulWidget {
//   final TextEditingController ordenController;
//   final int lonOrden;                 // LON_ORDEN completo (incluye prefijo)
//   final List<String> prefijos;        // catálogo de prefijos (fallback)
//   final EdgeInsetsGeometry padding;
//   final bool mostrarSiguiente;        // compatibilidad
//   final String? ordenFija;            // consulta directa por orden exacta
//   final void Function(String sugerido)? onUsarSugerencia;

//   /// ✅ NUEVO:
//   /// - autocompletarEnInput: si es false (usar en EDICIÓN), nunca escribe en el input.
//   /// - soloPrimeraVez: si es true (default), solo autocompleta una vez y ya no reescribe.
//   final bool autocompletarEnInput;
//   final bool soloPrimeraVez;

//   const UltimoMarbeteIndicator({
//     super.key,
//     required this.ordenController,
//     required this.lonOrden,
//     required this.prefijos,
//     this.padding = const EdgeInsets.only(top: 6),
//     this.mostrarSiguiente = true,
//     this.ordenFija,
//     this.onUsarSugerencia,
//     this.autocompletarEnInput = true, // en creación: true
//     this.soloPrimeraVez = true,       // sugiere una vez y luego no reescribe
//   });

//   @override
//   State<UltimoMarbeteIndicator> createState() => _UltimoMarbeteIndicatorState();
// }

// class _UltimoMarbeteIndicatorState extends State<UltimoMarbeteIndicator> {
//   static const bool _LOGS = false;

//   bool _cargando = false;
//   String? _ultimo;       // último detectado por RECENCIA (desde datos)
//   String? _siguiente;    // sugerencia (+1)
//   Timer? _debounce;

//   // Control para autocompletar una sola vez si así se configura
//   bool _yaAutocompleto = false;

//   // Guardar referencia del listener para removerlo correctamente
//   late final VoidCallback _onTextChanged;

//   // === Helpers prefijo/dígitos ===
//   String _prefixFromText(String text) =>
//       RegExp(r'^[A-Z]+').firstMatch(text.toUpperCase().trim())?.group(0) ?? '';

//   String _digitsFromText(String text) =>
//       text.replaceAll(RegExp(r'[^0-9]'), '');

//   String _prefijoDeOrden(String orden) =>
//       RegExp(r'^[A-Z]+').firstMatch(orden.toUpperCase().trim())?.group(0) ?? 'T';

//   String _prefixOf(String text) =>
//       RegExp(r'^[A-Z]+').firstMatch(text.toUpperCase().trim())?.group(0) ?? '';

//   /// Aplica el MISMO aspecto que ves en tu input: "PREF 123 4567"
//   String _formatearParaInput(String orden) {
//     final pref = _prefixOf(orden);
//     final digits = _digitsFromText(orden);
//     final maxDigits = (widget.lonOrden > pref.length)
//         ? (widget.lonOrden - pref.length)
//         : digits.length;

//     final groups = _buildGroups(maxDigits);
//     final buf = StringBuffer();
//     if (pref.isNotEmpty) buf..write(pref)..write(' ');

//     int consumed = 0;
//     for (var i = 0; i < groups.length; i++) {
//       if (i > 0) buf.write(' ');
//       final g = groups[i];
//       final remain = digits.length - consumed;
//       final use = remain > 0 ? (remain >= g ? g : remain) : 0;
//       if (use > 0) {
//         buf.write(digits.substring(consumed, consumed + use));
//         consumed += use;
//       }
//     }
//     return buf.toString().trimRight();
//   }

//   // Fallback local si no hay datos con fecha
//   String _siguienteFallback({
//     required String prefijo,
//     required String typedDigits,
//   }) {
//     if (typedDigits.isNotEmpty && int.tryParse(typedDigits) != null) {
//       final width = typedDigits.length;
//       final inc =
//           (int.parse(typedDigits) + 1).toString().padLeft(width, '0');
//       return '$prefijo$inc';
//     }
//     final maxDigits = (widget.lonOrden > prefijo.length)
//         ? (widget.lonOrden - prefijo.length)
//         : 1;
//     final inc = '1'.padLeft(maxDigits, '0');
//     return '$prefijo$inc';
//   }

//   List<int> _buildGroups(int maxDigits) {
//     const defaultGroups = [3, 4];
//     final groups = <int>[];
//     int remaining = maxDigits;
//     int gi = 0;
//     while (remaining > 0) {
//       final want = gi < defaultGroups.length
//           ? defaultGroups[gi]
//           : defaultGroups.last;
//       final take = remaining >= want ? want : remaining;
//       groups.add(take);
//       remaining -= take;
//       gi++;
//     }
//     return groups;
//   }

//   @override
//   void initState() {
//     super.initState();

//     _onTextChanged = () {
//       _debounce?.cancel();
//       _debounce = Timer(const Duration(milliseconds: 250), _recalcular);
//     };

//     widget.ordenController.addListener(_onTextChanged);
//     // Primera evaluación
//     Future.microtask(_recalcular);
//   }

//   @override
//   void didUpdateWidget(covariant UltimoMarbeteIndicator oldWidget) {
//     super.didUpdateWidget(oldWidget);

//     if (oldWidget.ordenController != widget.ordenController) {
//       oldWidget.ordenController.removeListener(_onTextChanged);
//       widget.ordenController.addListener(_onTextChanged);
//       _recalcular();
//     }

//     if (oldWidget.ordenFija != widget.ordenFija) {
//       _recalcular();
//     }
//   }

//   @override
//   void dispose() {
//     _debounce?.cancel();
//     widget.ordenController.removeListener(_onTextChanged);
//     super.dispose();
//   }

//   /// Mezcla servidor + SQLite y dedup por MARBETE.
//   /// **OJO**: puede regresar marbetes de otras órdenes si el origen no filtra bien,
//   /// por eso abajo reforzamos con filtro por ORDEN exacta.
//   Future<List<Map<String, dynamic>>> _cargarMarbetesParaOrdenExacta(
//     String ordenConsulta,
//   ) async {
//     final api = ApiService();

//     // 1) Servidor
//     if (_LOGS) {
//       debugPrint('🛰️(Widget) getMOrdenes con ORDEN EXACTA: $ordenConsulta');
//     }
//     final marbetesServidorCrudos = await api.getMOrdenes(ordenConsulta);
//     final marbetesServidor = marbetesServidorCrudos.map((e) {
//       final map = Map<String, dynamic>.from(e);
//       map['MARBETE'] = map['MARBETE']?.toString().toUpperCase().trim();
//       map['ORDEN'] = map['ORDEN']?.toString().toUpperCase().trim();
//       map['_ORIGEN'] = 'SERVIDOR';
//       return map;
//     }).toList();

//     // 2) Local
//     final marbetesLocalesCrudos =
//         await MOrdenesDAO.obtenerTodosPorOrden(ordenConsulta);
//     final marbetesLocales = marbetesLocalesCrudos.map((map) {
//       final nuevo =
//           map.map((k, v) => MapEntry(k.toString().toUpperCase(), v));
//       nuevo['MARBETE'] =
//           nuevo['MARBETE']?.toString().toUpperCase().trim();
//       nuevo['ORDEN'] = nuevo['ORDEN']?.toString().toUpperCase().trim();
//       return nuevo;
//     }).toList();

//     // 3) Combinar sin duplicados por MARBETE
//     final combinados = <Map<String, dynamic>>[];
//     final unicos = <String>{};
//     for (final s in marbetesServidor) {
//       final id = s['MARBETE'];
//       if (id != null && unicos.add(id)) combinados.add(s);
//     }
//     for (final l in marbetesLocales) {
//       final id = l['MARBETE'];
//       if (id != null && unicos.add(id)) combinados.add(l);
//     }

//     if (_LOGS) {
//       debugPrint('🌐 Marbetes servidor      : ${marbetesServidor.length}');
//       debugPrint('📱 Marbetes locales       : ${marbetesLocales.length}');
//       debugPrint('🧩 Total combinados       : ${combinados.length}');
//       if (combinados.isNotEmpty) {
//         debugPrint(
//           '🧾 Último (lista combinada): ${combinados.last['MARBETE']}',
//         );
//       }
//     }

//     return combinados;
//   }

//   /// Intenta parsear fecha desde varios campos comunes
//   DateTime? _parseFecha(Map<String, dynamic> m) {
//     final candidatos = [
//       m['FECHASYS'],
//       m['FCAPTURA'],
//       m['FECHA'],
//       m['FECHA_ALTA'],
//       m['CREATED_AT'],
//       m['FREGISTRO'],
//       m['UPDATED_AT'],
//     ]
//         .where((v) => v != null && v.toString().trim().isNotEmpty)
//         .map((v) => v.toString());

//     DateTime? best;
//     for (final raw in candidatos) {
//       final s = raw.trim();

//       // ISO
//       DateTime? dt;
//       try {
//         dt = DateTime.parse(s);
//       } catch (_) {}

//       // Formatos comunes
//       dt ??= _tryParseMany(s, const [
//         'yyyy-MM-dd HH:mm:ss',
//         'yyyy/MM/dd HH:mm:ss',
//         'dd/MM/yyyy HH:mm:ss',
//         'yyyy-MM-dd',
//         'dd/MM/yyyy',
//       ]);

//       if (dt != null && (best == null || dt.isAfter(best))) best = dt;
//     }
//     return best;
//   }

//   DateTime? _tryParseMany(String s, List<String> formats) {
//     for (final f in formats) {
//       try {
//         return DateFormat(f).parseStrict(s);
//       } catch (_) {}
//     }
//     return null;
//   }

//   Future<void> _recalcular() async {
//     if (_cargando) return; // evita solapamiento

//     final typed = widget.ordenController.text;
//     final prefFromTyped = _prefixFromText(typed);
//     final digits = _digitsFromText(typed);

//     // Determinar ORDEN EXACTA que consultaremos (o nada)
//     String? ordenConsulta;
//     if (widget.ordenFija != null && widget.ordenFija!.trim().isNotEmpty) {
//       ordenConsulta = widget.ordenFija!.toUpperCase().trim();
//     } else if (digits.isNotEmpty) {
//       ordenConsulta = '${prefFromTyped}${digits}';
//     } else {
//       if (!mounted) return;
//       setState(() {
//         _cargando = false;
//         _ultimo = null;
//         _siguiente = null;
//       });
//       if (_LOGS) {
//         debugPrint('⏸️(Widget) Sin dígitos y sin ordenFija → no consulto.');
//       }
//       return;
//     }

//     if (!mounted) return;
//     setState(() {
//       _cargando = true;
//       _ultimo = null;
//       _siguiente = null;
//     });

//     try {
//       final combinados =
//           await _cargarMarbetesParaOrdenExacta(ordenConsulta);

//       // 🔒 Blindaje: QUEDARSE SOLO con la ORDEN exacta
//       final exactos = combinados.where((m) {
//         final o = (m['ORDEN'] ?? '').toString().toUpperCase().trim();
//         return o == ordenConsulta!.toUpperCase().trim();
//       }).toList();

//       // (Log opcional para detectar "colados")
//       assert(() {
//         final otros = combinados
//             .where((m) {
//               final o =
//                   (m['ORDEN'] ?? '').toString().toUpperCase().trim();
//               return o != ordenConsulta!.toUpperCase().trim();
//             })
//             .map((m) => (m['ORDEN'] ?? '').toString())
//             .toSet();
//         if (otros.isNotEmpty) {
//           debugPrint('⚠️ Marbetes de otras ORDENES detectados: $otros');
//         }
//         return true;
//       }());

//       // === Elegir **último** por ORDEN y prefijo, usando FECHA (recencia) ===
//       final prefijo = _prefijoDeOrden(ordenConsulta);
//       final candidatosPrefijo = exactos.where((m) {
//         final marb =
//             (m['MARBETE'] ?? '').toString().toUpperCase().trim();
//         return RegExp('^${RegExp.escape(prefijo)}\\d+\$').hasMatch(marb);
//       }).toList();

//       Map<String, dynamic>? elegido;
//       DateTime? bestDate;

//       // 1) Priorizar el que tenga FECHA más reciente
//       for (final m in candidatosPrefijo) {
//         final dt = _parseFecha(m);
//         if (dt != null && (bestDate == null || dt.isAfter(bestDate))) {
//           bestDate = dt;
//           elegido = m;
//         }
//       }

//       // 2) Si NADIE tiene fecha → fallback por número más alto
//       if (elegido == null) {
//         int maxN = -1;
//         for (final m in candidatosPrefijo) {
//           final s = (m['MARBETE'] ?? '').toString();
//           final n = MarbeteUtils.numeroFinal(s, prefijo); // prefijo estricto
//           if (n != null && n > maxN) {
//             maxN = n;
//             elegido = m;
//           }
//         }
//       }

//       String? ultimoDetectado =
//           (elegido?['MARBETE'] ?? '').toString().trim().toUpperCase();

//       // === Calcular SIGUIENTE ===
//       String? siguiente;
//       if (ultimoDetectado != null && ultimoDetectado.isNotEmpty) {
//         final m = RegExp(r'^([A-Z]+)(\d+)$')
//             .firstMatch(ultimoDetectado.toUpperCase());
//         if (m != null) {
//           final pref = m.group(1)!;
//           final numStr = m.group(2)!;
//           final nextNum = (int.parse(numStr) + 1)
//               .toString()
//               .padLeft(numStr.length, '0');
//           siguiente = '$pref$nextNum';
//         } else {
//           siguiente = ultimoDetectado;
//         }
//       } else {
//         // SIN DATOS: usar fallback local (NO autocompleta el input)
//         final typedNow = widget.ordenController.text;
//         final prefFromTypedNow = _prefixFromText(typedNow);
//         final digitsFromTyped = _digitsFromText(typedNow);
//         final pref = (prefFromTypedNow.isNotEmpty)
//             ? prefFromTypedNow
//             : _prefijoDeOrden(ordenConsulta);
//         siguiente = _siguienteFallback(
//           prefijo: pref,
//           typedDigits: digitsFromTyped,
//         );
//       }

//       // Recortar si excede LON_ORDEN
//       if (widget.lonOrden > 0 &&
//           siguiente != null &&
//           siguiente.length > widget.lonOrden) {
//         siguiente = siguiente.substring(0, widget.lonOrden);
//       }

//       // ¿El último detectado provino realmente de datos?
//       final bool ultimoEnDatos = (ultimoDetectado != null) &&
//           exactos.any((e) =>
//               (e['MARBETE'] ?? '').toString().toUpperCase().trim() ==
//               ultimoDetectado!.toUpperCase().trim());

//       if (!mounted) return;
//       setState(() {
//         _ultimo = ultimoDetectado;
//         _siguiente = siguiente;

//         // === Autocompletar dentro del input SOLO si:
//         // - Vino de datos (ultimoEnDatos),
//         // - Está habilitado (autocompletarEnInput),
//         // - Y (no es soloPrimeraVez) o (si es soloPrimeraVez y aún no hemos autocompletado).
//         final puedeAutocompletar = ultimoEnDatos &&
//             widget.autocompletarEnInput &&
//             (!widget.soloPrimeraVez || !_yaAutocompleto);

//         if (puedeAutocompletar && _siguiente != null && _siguiente!.isNotEmpty) {
//           final actualDigits =
//               _digitsFromText(widget.ordenController.text);
//           final ultimoDigits =
//               _ultimo != null ? _digitsFromText(_ultimo!) : '';
//           final userEscribioAlgoPropio =
//               actualDigits.isNotEmpty && actualDigits != ultimoDigits;

//           if (!userEscribioAlgoPropio) {
//             final masked = _formatearParaInput(_siguiente!);
//             if (masked != widget.ordenController.text) {
//               widget.ordenController.text = masked;
//               widget.ordenController.selection =
//                   TextSelection.collapsed(offset: masked.length);
//               _yaAutocompleto = true; // ✅ marcamos que ya se autocompletó
//               // Callback opcional
//               widget.onUsarSugerencia?.call(_siguiente!);
//             }
//           }
//         }

//         // Log útil
//         assert(() {
//           if (elegido != null) {
//             final f = elegido!['FECHASYS'] ??
//                 elegido!['FCAPTURA'] ??
//                 elegido!['FECHA'] ??
//                 elegido!['FECHA_ALTA'] ??
//                 elegido!['CREATED_AT'] ??
//                 elegido!['FREGISTRO'] ??
//                 elegido!['UPDATED_AT'];
//             debugPrint('🕒 Último por recencia: $_ultimo | FECHA=$f');
//           } else {
//             debugPrint('🕒 Sin fechas válidas: se usó fallback numérico.');
//           }
//           return true;
//         }());
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _ultimo = null;
//         _siguiente = null;
//       });
//       if (_LOGS) debugPrint('❌(Widget) Error consultando último/siguiente: $e');
//     } finally {
//       if (!mounted) return;
//       setState(() => _cargando = false);
//     }
//   }

//   // Headless (no dibuja UI)
//   @override
//   Widget build(BuildContext context) => const SizedBox.shrink();
// }
