// ignore_for_file: use_build_context_synchronously, unused_local_variable

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodim/api/api_service.dart';
import 'package:sodim/db/mordenes_dao.dart';
import 'package:sodim/db/ordenes_dao.dart';
import 'package:sodim/db/db_helper.dart'; // <- leer pdf_generado
import 'package:sodim/models/orden_model.dart';
import 'package:sodim/pages/impresora_page.dart';
import 'package:sodim/pages/select_printer_page.dart';
import 'package:sodim/services/dispositivo_service.dart';
import 'package:sodim/services/upload_queue_service.dart';
import 'package:sodim/services/upload_service.dart';
import 'package:sodim/utils/sincronizador_service.dart';
import 'package:sodim/widgets/firma_dialog.dart';
import 'package:onboarding_overlay/onboarding_overlay.dart';
import 'package:flutter/services.dart';

class PdfOtForms extends StatefulWidget {
  final Orden orden;
  final bool soloLectura;

  const PdfOtForms({super.key, required this.orden, this.soloLectura = false});

  @override
  State<PdfOtForms> createState() => _PdfOtFormsState();
}

class _PdfOtFormsState extends State<PdfOtForms> {
  // ===== Utilitario: quitar acentos/Unicode para PDF (Helvetica sin Unicode) =====
  String _t(Object? v) {
    final s = (v ?? '').toString();
    const src =
        'áàäâãÁÀÄÂÃéèëêÉÈËÊíìïîÍÌÏÎóòöôõÓÒÖÔÕúùüûÚÙÜÛñÑçÇ¡¿’´`^~¨–—•“”„°…·•’';
    const dst =
        'aaaaaAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUnNcC!!\'\'^^^^--*"",...**\'';
    final map = {for (int i = 0; i < src.length; i++) src[i]: dst[i]};
    final sb = StringBuffer();
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      sb.write(map[c] ?? c);
    }
    // elimina cualquier no-ASCII remanente (emojis, etc.)
    return sb.toString().replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  }

  // ===== Datos =====
  List<Map<String, dynamic>> marbetes = [];
  bool cargando = true;

  // Estado del PDF en SQLite
  bool _pdfYaGenerado = false;

  // Firmas
  Uint8List? _firmaChoferBytes;
  Uint8List? _firmaClienteBytes;

  final TextEditingController empresaController = TextEditingController();
  final TextEditingController vendedorController = TextEditingController();

  // Onboarding
  final GlobalKey<OnboardingState> _onboardingKey =
      GlobalKey<OnboardingState>();
  late final FocusNode _fnBtnFirma;
  late final FocusNode _fnMenuFirmas;
  late final FocusNode _fnPreview;
  late final FocusNode _fnGuardar;

  @override
  void initState() {
    super.initState();

    _fnBtnFirma = FocusNode(debugLabel: 'Firma');
    _fnMenuFirmas = FocusNode(debugLabel: 'MenuFirmas');
    _fnPreview = FocusNode(debugLabel: 'Preview');
    _fnGuardar = FocusNode(debugLabel: 'GuardarPDF');

    _cargarEstadoPdf();
    cargarMarbetes();
    cargarVendedorDesdePreferencias();
    _cargarFirmasDePrefs();

    // Sincroniza si hay internet y recarga
    Future.delayed(const Duration(seconds: 2), () async {
      final conn = await Connectivity().checkConnectivity();
      if (conn != ConnectivityResult.none) {
        await SincronizadorService.sincronizarOrdenes();
        await SincronizadorService.sincronizarMarbetes();
        await cargarMarbetes();
      }
    });
  }

  @override
  void dispose() {
    _fnBtnFirma.dispose();
    _fnMenuFirmas.dispose();
    _fnPreview.dispose();
    _fnGuardar.dispose();
    super.dispose();
  }

  // ===============================================================================================
  // ===============================================================================================
  // ====================================TICKET ====================================================
  // ===============================================================================================
  // ===============================================================================================

  String generarTicketTexto() {
    final o = widget.orden;
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    const String init = "\x1B\x40";
    const String cut = "\x1B\x64\x02";

    final sb = StringBuffer();

    // ===========================================================
    // 1️⃣ DEFINIR COLUMNAS EN EL ORDEN QUE QUIERES
    // ===========================================================
    final columnas = [
      {"key": "MARBETE", "titulo": "MARBETE"},
      {"key": "MEDIDA", "titulo": "MEDIDA"},
      {"key": "MARCA", "titulo": "MARCA"},
      {"key": "TRABAJO", "titulo": "TRABAJO"},
      {"key": "MATRICULA", "titulo": "MATRICULA"}, // 👉 AL FINAL
    ];

    // ===========================================================
    // 2️⃣ CALCULAR ANCHO AUTOMÁTICO DE CADA COLUMNA
    // ===========================================================
    final Map<String, int> widths = {};

    for (var col in columnas) {
      final key = col["key"]!;
      final titulo = col["titulo"]!;

      int maxLen = titulo.length;

      for (final m in marbetes) {
        final v = (m[key] ?? "").toString().trim();
        if (v.length > maxLen) maxLen = v.length;
      }

      widths[key] = maxLen + 1; // +1 espacio separador
    }

    // Auxiliar para ajustar valores
    String fix(String key, dynamic value) {
      final w = widths[key]!;
      final v = (value ?? "").toString().trim();
      return v.padRight(w).substring(0, w);
    }

    // ===========================================================
    // 3️⃣ CONSTRUIR TICKET
    // ===========================================================

    sb.write(init);

    sb.writeln("          LLANTERA ATLAS S.A. DE C.V.");
    sb.writeln("         PLANTA RENOVADORA DE LLANTAS");
    sb.writeln("----------------------------------------------");
    sb.writeln("ORDEN: ${o.orden}");
    sb.writeln("CLIENTE: ${o.cliente} - ${o.razonsocial}");
    sb.writeln(
      "EMPRESA: ${empresaController.text}   VENDEDOR: ${vendedorController.text} ",
    );
    // sb.writeln("VENDEDOR: ${vendedorController.text}");
    sb.writeln("FECHA: $fecha");
    sb.writeln("----------------------------------------------");

    // ---------------- TÍTULOS AUTOMÁTICOS ----------------
    String header = "";
    for (var col in columnas) {
      header += col["titulo"]!.padRight(widths[col["key"]]!);
    }
    // sb.writeln(header);
    // sb.writeln(header.trimLeft());
    sb.writeln(header.trim());
    sb.writeln("----------------------------------------------");

    // ---------------- FILAS AUTOMÁTICAS ------------------
    for (final m in marbetes) {
      String row = "";
      for (var col in columnas) {
        final key = col["key"]!;
        row += fix(key, m[key]);
      }
      sb.writeln(row);
    }

    sb.writeln("----------------------------------------------");
    sb.writeln("TOTAL MARBETES: ${marbetes.length}");
    sb.writeln("----------------------------------------------");

    // ===========================================================
    // 4️⃣ APARTADO PROFESIONAL DE FIRMAS
    // ===========================================================
    sb.writeln("");
    sb.writeln("");
    sb.writeln("");
    sb.writeln("   ________________        _________________");
    sb.writeln("   FIRMA DEL CHOFER        FIRMA DEL CLIENTE");
    // sb.writeln("");
    sb.writeln("----------------------------------------------");
    sb.writeln("DESPUES DE 30 DIAS NO RESPONDEMOS POR NINGUN TRABAJO");
    sb.writeln("----------------------------------------------");

    // Alimentación + corte
    sb.writeln("\n");
    sb.write(cut);

    return sb.toString();
  }

  Future<String?> _getImpresoraGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("printer_mac"); // ← CORREGIDO
  }

  Future<void> seleccionarImpresora(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final macGuardada = prefs.getString("printer_mac"); // ← CORRECTO

    // =====================================================
    // 1️⃣ SI YA HAY UNA IMPRESORA GUARDADA → IMPRIMIR DIRECTO
    // =====================================================
    if (macGuardada != null && macGuardada.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🖨️ Usando impresora guardada: $macGuardada")),
      );

      await imprimirTicketGuardado();
      return;
    }

    // =====================================================
    // 2️⃣ NO HAY IMPRESORA GUARDADA → ESCANEAR
    // =====================================================
    const platform = MethodChannel("star_bt_channel");
    final resultado = await platform.invokeMethod("scan");

    final lista = List<Map<String, String>>.from(
      resultado.map((e) => Map<String, String>.from(e)),
    );

    // =====================================================
    // 3️⃣ SI SOLO HAY UNA IMPRESORA → GUARDARLA + IMPRIMIR
    // =====================================================
    if (lista.length == 1) {
      final unico = lista.first;
      final mac = unico["mac"]!;
      final nombre = unico["name"] ?? "Impresora";

      await prefs.setString("printer_mac", mac);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "🖨️ Impresora detectada automáticamente: $nombre ($mac)",
          ),
        ),
      );

      await imprimirTicketGuardado();
      return;
    }

    // =====================================================
    // 4️⃣ SI NO HAY NINGUNA → ERROR
    // =====================================================
    if (lista.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ No se detectaron impresoras")));
      return;
    }

    // =====================================================
    // 5️⃣ SI HAY VARIAS → SELECCIONAR MANUALMENTE
    // =====================================================
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SelectPrinterPage(devices: lista)),
    );
  }

  Future<void> imprimirTicketGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    // final mac = prefs.getString("impresora_mac");
    final mac = prefs.getString("printer_mac");

    if (mac == null || mac.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("⚠️ No hay impresora guardada")));
      return;
    }

    final texto = generarTicketTexto();

    const platform = MethodChannel("star_bt_channel");

    try {
      final ok = await platform.invokeMethod("printStarBluetooth", {
        "text": texto,
        "mac": mac,
      });

      if (ok == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🖨️ Ticket impreso correctamente")),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error al imprimir")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    }
  }
  // ===============================================================================================
  // ===============================================================================================
  // ====================================TICKET ====================================================
  // ===============================================================================================
  // ===============================================================================================

  // ===== Estado PDF (SQLite) =====
  Future<void> _cargarEstadoPdf() async {
    final db = await DBHelper.initDb();
    final r = await db.query(
      'ordenes',
      columns: ['pdf_generado'],
      where: 'orden = ?',
      whereArgs: [widget.orden.orden],
      limit: 1,
    );
    if (!mounted) return;
    setState(() {
      _pdfYaGenerado =
          r.isNotEmpty && (r.first['pdf_generado'] as int? ?? 0) == 1;
    });
  }

  Future<void> _marcarPdfYRefrescar() async {
    try {
      final res = await OrdenesDAO.marcarPdfGenerado(widget.orden.orden);
      await _cargarEstadoPdf();
      if (!mounted) return;
      setState(() => _pdfYaGenerado = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('No se pudo marcar PDF generado: $e'))),
      );
    }
  }

  // ===== Data =====
  Future<void> cargarVendedorDesdePreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    print("MAC GUARDADA: ${prefs.getString("printer_mac")}");

    final vendedorStr = prefs.getString('vendedor');
    if (vendedorStr != null) {
      final m = json.decode(vendedorStr);
      empresaController.text = (m['EMPRESA'] ?? '').toString();
      vendedorController.text = (m['VENDEDOR'] ?? '').toString();
      if (!mounted) return;
      setState(() {}); // por si hay que repintar
    }
  }

  void guardarImpresora(String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("printer_mac", mac);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("🖨️ Impresora guardada: $mac")));
  }

  Future<void> cargarMarbetes() async {
    final api = ApiService();

    final srv = await api.getMOrdenes(widget.orden.orden);
    final srvNorm =
        srv.map((e) {
          final mapa = Map<String, dynamic>.from(e);
          mapa['MARBETE'] = mapa['MARBETE']?.toString().toUpperCase().trim();
          return mapa;
        }).toList();

    final locRaw = await MOrdenesDAO.obtenerTodosPorOrden(widget.orden.orden);
    final loc =
        locRaw.map((m) {
          final nuevo = m.map((k, v) => MapEntry(k.toUpperCase(), v));
          nuevo['MARBETE'] = nuevo['MARBETE']?.toString().toUpperCase().trim();
          return nuevo;
        }).toList();

    final combinados = <Map<String, dynamic>>[];
    final unicos = <String>{};
    for (final s in srvNorm) {
      final id = s['MARBETE'];
      if (id != null && unicos.add(id)) combinados.add(s);
    }
    for (final l in loc) {
      final id = l['MARBETE'];
      if (id != null && unicos.add(id)) combinados.add(l);
    }

    combinados.sort((a, b) {
      final numA =
          int.tryParse(RegExp(r'\d+').stringMatch(a['MARBETE'] ?? '') ?? '0') ??
          0;
      final numB =
          int.tryParse(RegExp(r'\d+').stringMatch(b['MARBETE'] ?? '') ?? '0') ??
          0;
      return numA.compareTo(numB);
    });

    if (!mounted) return;
    setState(() {
      marbetes = combinados;
      cargando = false;
    });
  }

  // ===== Firmas =====
  Future<void> _cargarFirmasDePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final b64Chofer = prefs.getString('firma_chofer_png');
    final b64Cliente = prefs.getString('firma_cliente_png');
    if (!mounted) return;
    setState(() {
      _firmaChoferBytes =
          (b64Chofer != null && b64Chofer.isNotEmpty)
              ? base64Decode(b64Chofer)
              : null;
      _firmaClienteBytes =
          (b64Cliente != null && b64Cliente.isNotEmpty)
              ? base64Decode(b64Cliente)
              : null;
    });
  }

  Future<void> _guardarFirmaEnPrefs({
    required String tipo, // Chofer | Cliente
    required Uint8List bytes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        (tipo.toLowerCase() == 'chofer')
            ? 'firma_chofer_png'
            : 'firma_cliente_png';
    await prefs.setString(key, base64Encode(bytes));
    if (!mounted) return;
    setState(() {
      if (tipo.toLowerCase() == 'chofer') {
        _firmaChoferBytes = bytes;
      } else {
        _firmaClienteBytes = bytes;
      }
    });
  }

  Future<void> _borrarFirma(String cual) async {
    final prefs = await SharedPreferences.getInstance();
    if (cual == 'Chofer' || cual == 'Ambas') {
      await prefs.remove('firma_chofer_png');
      _firmaChoferBytes = null;
    }
    if (cual == 'Cliente' || cual == 'Ambas') {
      await prefs.remove('firma_cliente_png');
      _firmaClienteBytes = null;
    }
    if (!mounted) return;
    setState(() {});
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Onboarding(
      key: _onboardingKey,
      steps: [
        OnboardingStep(
          focusNode: _fnBtnFirma,
          titleText: 'Firma',
          bodyText: 'Captura firma de Chofer o Cliente.',
          hasLabelBox: true,
          titleTextStyle: const TextStyle(fontSize: 15),
          bodyTextStyle: const TextStyle(fontSize: 10, height: 1.1),
          margin: const EdgeInsets.only(bottom: 180),
          overlayBehavior: HitTestBehavior.deferToChild,
        ),
        OnboardingStep(
          focusNode: _fnMenuFirmas,
          titleText: 'Opciones',
          bodyText: 'Borra una o ambas firmas.',
          hasLabelBox: true,
          titleTextStyle: const TextStyle(fontSize: 15),
          bodyTextStyle: const TextStyle(fontSize: 10, height: 1.1),
          margin: const EdgeInsets.only(bottom: 180),
          overlayBehavior: HitTestBehavior.deferToChild,
        ),
        OnboardingStep(
          focusNode: _fnGuardar,
          titleText: 'Guardar',
          bodyText: 'Genera el PDF en Documentos.',
          hasLabelBox: true,
          titleTextStyle: const TextStyle(fontSize: 15),
          bodyTextStyle: const TextStyle(fontSize: 10, height: 1.1),
          margin: const EdgeInsets.only(bottom: 200),
          overlayBehavior: HitTestBehavior.deferToChild,
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/SODIM1.png', height: 32),
              const SizedBox(width: 8),
              if (_pdfYaGenerado)
                const Chip(
                  label: Text(
                    'PDF generado',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.green,
                ),
            ],
          ),
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
          actions: [
            FutureBuilder<String?>(
              future: _getImpresoraGuardada(),
              builder: (context, snapshot) {
                final mac = snapshot.data ?? "Ninguna";

                return IconButton(
                  tooltip: "Impresora: $mac",
                  icon: const Icon(Icons.print, color: Colors.white),
                  onPressed: () async {
                    if (mac != null && mac.isNotEmpty && mac != "Ninguna") {
                      // 🔥 IMPRIME DIRECTO SI HAY IMPRESORA GUARDADA
                      await imprimirTicketGuardado();
                    } else {
                      // ❌ NO HAY IMPRESORA → MOSTRAR MENSAJE Y ABRIR CONFIGURACIÓN
                      showDialog(
                        context: context,
                        builder:
                            (_) => AlertDialog(
                              title: const Text("Sin impresora"),
                              content: const Text(
                                "No hay una impresora guardada. Seleccione una.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ImpresoraPage(),
                                      ),
                                    );
                                  },
                                  child: const Text("Configurar"),
                                ),
                              ],
                            ),
                      );
                    }
                  },
                );
              },
            ),

            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Mostrar tutorial',
              onPressed: () => _onboardingKey.currentState?.show(),
              onLongPress: () => _onboardingKey.currentState?.hide(),
            ),

            // Capturar/actualizar firma (bloqueado si PDF ya generado)
            Opacity(
              opacity: _pdfYaGenerado ? 0.4 : 1.0,
              child: IgnorePointer(
                ignoring: _pdfYaGenerado,
                child: Focus(
                  focusNode: _fnBtnFirma,
                  child: IconButton(
                    tooltip:
                        _pdfYaGenerado
                            ? 'PDF ya generado — no se puede modificar firmas'
                            : 'Capturar/Actualizar firma (Chofer/Cliente)',
                    icon: const Icon(Icons.gesture),
                    onPressed: () async {
                      final resultado = await showDialog<Map<String, dynamic>?>(
                        context: context,
                        builder: (_) => const FirmaDialog(),
                      );
                      if (resultado != null) {
                        final tipo =
                            (resultado['tipo'] as String?)?.trim() ?? 'Chofer';
                        final bytes = resultado['firma'] as Uint8List;
                        await _guardarFirmaEnPrefs(tipo: tipo, bytes: bytes);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_t('Firma $tipo guardada.'))),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),

            // Menú de firmas (bloqueado si PDF ya generado)
            Opacity(
              opacity: _pdfYaGenerado ? 0.4 : 1.0,
              child: IgnorePointer(
                ignoring: _pdfYaGenerado,
                child: Focus(
                  focusNode: _fnMenuFirmas,
                  child: PopupMenuButton<String>(
                    tooltip:
                        _pdfYaGenerado
                            ? 'PDF ya generado — no se puede modificar firmas'
                            : 'Opciones de firmas',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (op) async {
                      switch (op) {
                        case 'borrar_chofer':
                          await _borrarFirma('Chofer');
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_t('Firma Chofer eliminada.')),
                            ),
                          );
                          break;
                        case 'borrar_cliente':
                          await _borrarFirma('Cliente');
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_t('Firma Cliente eliminada.')),
                            ),
                          );
                          break;
                        case 'borrar_ambas':
                          await _borrarFirma('Ambas');
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_t('Ambas firmas eliminadas.')),
                            ),
                          );
                          break;
                      }
                    },
                    itemBuilder:
                        (context) => const [
                          PopupMenuItem(
                            value: 'borrar_chofer',
                            child: Text('Borrar firma Chofer'),
                          ),
                          PopupMenuItem(
                            value: 'borrar_cliente',
                            child: Text('Borrar firma Cliente'),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'borrar_ambas',
                            child: Text('Borrar ambas firmas'),
                          ),
                        ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // FAB Guardar (bloqueado si PDF ya generado)
        floatingActionButton:
            cargando
                ? null
                : Padding(
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: Focus(
                    focusNode: _fnGuardar,
                    child: FloatingActionButton.extended(
                      icon: Icon(
                        _pdfYaGenerado ? Icons.check_circle : Icons.download,
                      ),
                      label: Text(
                        _pdfYaGenerado ? 'PDF ya generado' : 'Guardar PDF',
                      ),
                      backgroundColor:
                          _pdfYaGenerado ? Colors.grey : Colors.orange,
                      foregroundColor: Colors.white,

                      onPressed:
                          _pdfYaGenerado
                              ? null
                              : () async {
                                // 0) Generar PDF
                                final pdfData = await _buildPdf(
                                  PdfPageFormat.a4,
                                );

                                // 1) Nombres de archivo
                                final localFileName =
                                    'ORDEN_${widget.orden.orden}.pdf';
                                final now = DateTime.now();
                                final stamp = DateFormat(
                                  'ddMMyy_HHmmss',
                                ).format(now);

                                final serverFileName =
                                    '${widget.orden.orden}_$stamp.pdf';

                                // 2) Guardar local
                                await guardarPDFEnDescargas(
                                  context,
                                  pdfData,
                                  localFileName,
                                );

                                // 3) Construir payload para el backend
                                final dispositivoNombre =
                                    await DispositivoService.obtenerNombreDispositivo();
                                final dispositivoSerial =
                                    await DispositivoService.obtenerSerial();

                                final payload = <String, dynamic>{
                                  'orden': widget.orden.orden,
                                  'cliente': widget.orden.cliente,
                                  'razonSocial': widget.orden.razonsocial,
                                  'empresa': empresaController.text,
                                  'vendedor': vendedorController.text,
                                  'fechaImpresion':
                                      DateTime.now().toIso8601String(),
                                  'firmas': {
                                    'chofer': _firmaChoferBytes != null,
                                    'cliente': _firmaClienteBytes != null,
                                  },
                                  'marbetes':
                                      marbetes
                                          .map(
                                            (e) => {
                                              'MARBETE': e['MARBETE'],
                                              'MATRICULA': e['MATRICULA'],
                                              'MEDIDA': e['MEDIDA'],
                                              'MARCA': e['MARCA'],
                                              'TRABAJO': e['TRABAJO'],
                                              'ALT': e['TRABAJOALTERNO'],
                                              'BUS': e['BUS'],
                                              'ECONOMICO': e['ECONOMICO'],
                                              'COMPUESTO': e['COMPUESTO'],
                                              'OTRO': e['TRABAJO_OTR'],
                                            },
                                          )
                                          .toList(),
                                  'dispositivo': {
                                    'nombre': dispositivoNombre,
                                    'serial': dispositivoSerial,
                                  },
                                };

                                // 4) Enviar al servidor o encolar si no hay internet
                                try {
                                  final conn =
                                      await Connectivity().checkConnectivity();
                                  final tieneNet =
                                      conn != ConnectivityResult.none;

                                  if (tieneNet) {
                                    final t0 = DateTime.now();

                                    // final resultado =
                                    //     await UploadService.uploadPdfJson(
                                    //       pdfBytes: pdfData,
                                    //       fileName: serverFileName,
                                    //       payload: payload,
                                    //     );

                                    final resultado =
                                        await UploadService.uploadPdfJson(
                                          pdfBytes: pdfData,
                                          fileName: serverFileName,
                                          orden: widget.orden.orden,
                                          payload: payload,
                                        );

                                    final ms =
                                        DateTime.now()
                                            .difference(t0)
                                            .inMilliseconds;

                                    if (!mounted) return;
                                    // debugPrint('⏱️ Tiempo de envío: ${ms} ms');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '📤 PDF enviado: $resultado',
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Encolar (si implementaste tu cola)
                                    await UploadQueueService.enqueue(
                                      bytes: pdfData,
                                      fileName: serverFileName,
                                      payload: payload,
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '⏳ Sin internet: PDF encolado para envío',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  // Si falla el POST, encola como respaldo
                                  await UploadQueueService.enqueue(
                                    bytes: pdfData,
                                    fileName: serverFileName,
                                    payload: payload,
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '❌ Error al subir. Encolado para reintento: $e',
                                      ),
                                    ),
                                  );
                                }

                                // 5) Actualizar estado local
                                await _marcarPdfYRefrescar();
                                if (!mounted) return;
                                Navigator.pop(context, widget.orden.orden);
                              },
                    ),
                  ),
                ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

        body:
            cargando
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 96.0),
                    child: Focus(
                      focusNode: _fnPreview,
                      child: PdfPreview(
                        build: (format) => _buildPdf(format),
                        // ⛔ Desactivar acciones
                        allowPrinting: false,
                        allowSharing: false,

                        canChangePageFormat: false,
                        canChangeOrientation: false,

                        pdfFileName: 'ORDEN_${widget.orden.orden}.pdf',
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  // ===== PDF =====
  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final orden = widget.orden;
    final DateTime fecha =
        DateTime.tryParse(orden.fechaCaptura.toString()) ?? DateTime.now();
    final String fechaFormateada =
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

    final pdf = pw.Document();
    final logoImage = await imageFromAssetBundle('assets/images/logo.png');

    final String fcaptura = DateFormat(
      'dd/MM/yyyy HH:mm:ss',
    ).format(DateTime.now());

    final fechaCaptura = DateTime.tryParse(orden.fcaptura.toString());
    final String fechaCapturaFormateada =
        (fechaCaptura != null)
            ? DateFormat('dd/MM/yyyy HH:mm').format(fechaCaptura)
            : orden.fcaptura.toString();

    // --- Dispositivo (para mostrar en el footer)
    final String deviceName =
        await DispositivoService.obtenerNombreDispositivo();
    // Si tienes el método obtenerSerial() que puede devolver null:
    final String? serialRaw = await DispositivoService.obtenerSerial();
    final String serialShort =
        (serialRaw == null || serialRaw.isEmpty)
            ? 'N/D'
            : (serialRaw.length > 6
                ? '…${serialRaw.substring(serialRaw.length - 6)}'
                : serialRaw);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(margin: const pw.EdgeInsets.all(32)),
        footer:
            (context) => pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          if (_firmaChoferBytes != null) ...[
                            pw.Image(
                              pw.MemoryImage(_firmaChoferBytes!),
                              width: 90,
                              height: 40,
                              fit: pw.BoxFit.contain,
                            ),
                            pw.SizedBox(height: 4),
                          ] else
                            pw.SizedBox(height: 44),
                          pw.Container(
                            width: 200,
                            child: pw.Divider(
                              thickness: 1,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            _t('Firma Chofer'),
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          if (_firmaClienteBytes != null) ...[
                            pw.Image(
                              pw.MemoryImage(_firmaClienteBytes!),
                              width: 90,
                              height: 40,
                              fit: pw.BoxFit.contain,
                            ),
                            pw.SizedBox(height: 4),
                          ] else
                            pw.SizedBox(height: 44),
                          pw.Container(
                            width: 200,
                            child: pw.Divider(
                              thickness: 1,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            _t('Firma Cliente'),
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 0.5, color: PdfColors.grey),
                pw.SizedBox(height: 4),
                pw.Text(
                  _t('DESPUES DE 30 DIAS NO RESPONDEMOS POR NINGUN TRABAJO'),
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.black,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),

                pw.Text(
                  _t(
                    'SODIM || Impreso: $fcaptura || Equipo: $deviceName  || Pagina ${context.pageNumber} de ${context.pagesCount}',
                  ),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                  textAlign: pw.TextAlign.right,
                ),
              ],
            ),
        build:
            (context) => [
              // Encabezado
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(logoImage, width: 100),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        _t('LLANTERA ATLAS, S.A. DE C.V.'),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _t('ORDEN DE TRABAJO'),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 10),

              // Datos de la orden
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          flex: 1,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: _t('Orden: '),
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                                pw.TextSpan(
                                  text: _t(widget.orden.orden),
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          flex: 2,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: _t('Cliente: '),
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                                pw.TextSpan(
                                  text: _t(
                                    '${widget.orden.cliente} - ${widget.orden.razonsocial}',
                                  ),
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: _t('Fecha: '),
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                                pw.TextSpan(
                                  text: _t(fechaFormateada),
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: _t('Empresa: '),
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                                pw.TextSpan(
                                  text: _t(empresaController.text),
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: _t('Vendedor: '),
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                                pw.TextSpan(
                                  text: _t(vendedorController.text),
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: _t('Fecha captura: '),
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                                pw.TextSpan(
                                  text: _t(fechaCapturaFormateada),
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Text(
                _t('Detalle de Marbetes'),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),

              pw.TableHelper.fromTextArray(
                headers: [
                  _t('MARBETE'),
                  _t('MATRICULA'),
                  _t('MEDIDA'),
                  _t('MARCA'),
                  _t('TRABAJO'),
                  _t('ALT.'),
                  _t('BUS'),
                  _t('ECONOMICO'),
                  _t('COMP.'),
                  _t('OTRO'),
                ],
                data:
                    marbetes
                        .map(
                          (e) => [
                            _t(e['MARBETE']),
                            _t(e['MATRICULA']),
                            _t(e['MEDIDA']),
                            _t(e['MARCA']),
                            _t(e['TRABAJO']),
                            _t(e['TRABAJOALTERNO']),
                            _t(e['BUS']),
                            _t(e['ECONOMICO']),
                            _t(e['COMPUESTO']),
                            _t(e['TRABAJO_OTR']),
                          ],
                        )
                        .toList(),
                cellStyle: const pw.TextStyle(fontSize: 12),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF7B234),
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 2,
                ),
              ),

              pw.SizedBox(height: 10),

              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  _t('Total de marbetes: ${marbetes.length}'),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 60),
            ],
      ),
    );

    return pdf.save();
  }
}

// ===== Guardar PDF en Documents/ORDENES_SODIM =====
Future<void> guardarPDFEnDescargas(
  BuildContext context,
  Uint8List pdfData,
  String nombreArchivo,
) async {
  final status = await Permission.manageExternalStorage.request();

  if (!status.isGranted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ Permiso de almacenamiento denegado')),
    );
    return;
  }

  final dir = Directory('/storage/emulated/0/Documents/ORDENES_SODIM');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final file = File('${dir.path}/$nombreArchivo');

  try {
    await file.writeAsBytes(pdfData);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('✅ PDF guardado: ${file.path}')));
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('❌ Error al guardar: $e')));
  }
}
