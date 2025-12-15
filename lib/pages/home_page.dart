// ignore_for_file: use_build_context_synchronously, deprecated_member_use, curly_braces_in_flow_control_structures, unused_field

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sodim/api/api_service.dart';
import 'package:sodim/db/db_helper.dart'; // leer estado por orden
import 'package:sodim/db/mordenes_dao.dart';
import 'package:sodim/db/ordenes_dao.dart';
import 'package:sodim/models/orden_model.dart';
import 'package:sodim/models/vendedor_model.dart';
import 'package:sodim/pages/buscar_orden_page.dart';
import 'package:sodim/pages/marbetes_forms.dart';
import 'package:sodim/pages/nueva_orden.dart';
import 'package:sodim/pages/pdf_ot.dart';
import 'package:sodim/utils/conexion_helper.dart';
import 'package:sodim/utils/sincronizador_service.dart';
import 'package:sodim/widgets/custom_drawer.dart';

// Onboarding
import 'package:onboarding_overlay/onboarding_overlay.dart';

class HomePage extends StatefulWidget {
  final Vendedor vendedor;

  const HomePage({super.key, required this.vendedor});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ===== Estado principal =====
  List<Orden> ordenesRecientes = [];
  Orden? ordenSeleccionada;

  String? _prefijoUM;
  String? _ultimoUM;

  // Fuente de verdad: SQLite (ordenes.pdf_generado=1)
  Set<String> _ordenesBloqueadas = {};
  bool _ordenTienePdf = false; // para la seleccionada
  bool _avisadoAlIniciar = false; // <- arriba en tu State
  Timer? _holdTimer;
  bool _holding = false;

  // UI auxiliar (solo color verde histórico opcional)
  Set<String> pdfGenerados = {};
  final Set<String> marbetesSincronizados =
      SincronizadorService.marbetesSincronizados;

  late final StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _yaSincronizado = false;

  /// Los botones se deshabilitan si no hay orden seleccionada o si está bloqueada en SQLite
  bool get deshabilitarAcciones =>
      (ordenSeleccionada == null) ||
      _ordenesBloqueadas.contains(ordenSeleccionada!.orden);

  // ===== Onboarding =====
  final GlobalKey<OnboardingState> _onboardingKey =
      GlobalKey<OnboardingState>();
  late final FocusNode _fnSync;
  late final FocusNode _fnNuevaOrden;
  late final FocusNode _fnMarbetes;
  late final FocusNode _fnConsultaSoloLectura;
  late final FocusNode _fnEliminar;
  late final FocusNode _fnConsultaOrden;
  late final FocusNode _fnPDF;
  late final FocusNode _fnLista;
  final ScrollController _actionsScroll = ScrollController();

  @override
  void initState() {
    super.initState();

    // FocusNodes...
    _fnSync = FocusNode(debugLabel: 'Sync');
    _fnNuevaOrden = FocusNode(debugLabel: 'NuevaOrden');
    _fnMarbetes = FocusNode(debugLabel: 'Marbetes');
    _fnConsultaSoloLectura = FocusNode(debugLabel: 'Consulta');
    _fnEliminar = FocusNode(debugLabel: 'Eliminar');
    _fnConsultaOrden = FocusNode(debugLabel: 'ConsultaOrden');
    _fnPDF = FocusNode(debugLabel: 'PDF');
    _fnLista = FocusNode(debugLabel: 'Lista');

    // 🔁 Carga primero las órdenes, luego lee bloqueadas y avisa.
    _cargarOrdenes().then((_) async {
      await _cargarBloqueadas();
      if (!mounted) return;
      _avisarBloqueadasEnUI(); // ⬅️ aquí avisamos
      await _actualizarPrefijosYUM();
    });

    ApiService().cargarOrdenesDesdePrefs();

    // Conectividad
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      _,
    ) async {
      final conectado = await ConexionHelper.hayInternet();
      if (conectado && !_yaSincronizado) {
        _yaSincronizado = true;
        await _sincronizarYActualizar();
        // tras sincronizar, vuelve a avisar si cambió algo
        if (!mounted) return;
        _avisarBloqueadasEnUI();
      }
    });

    // Revisa conexión al iniciar
    Future.microtask(() async {
      final conectado = await ConexionHelper.hayInternet();
      if (conectado && !_yaSincronizado) {
        _yaSincronizado = true;
        await _sincronizarYActualizar();
        if (!mounted) return;
        _avisarBloqueadasEnUI();
      }
    });
  }

  void _avisarBloqueadasEnUI() {
    if (_avisadoAlIniciar) return; // evita repetidos
    _avisadoAlIniciar = true;

    if (_ordenesBloqueadas.isEmpty) {
      debugPrint('🟢 No hay órdenes bloqueadas en SQLite.');
      return;
    }

    // final preview = _ordenesBloqueadas.take(2).join(', ');
    // final mas = _ordenesBloqueadas.length > 2 ? '…' : '';
    // final msg =
    //     '🔒 ${_ordenesBloqueadas.length} orden(es) bloqueada(s): $preview$mas';

    // debugPrint('🟡 Al iniciar: $msg');

    // muestra SnackBar y preselecciona una bloqueada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      // Preselecciona la primera bloqueada
      for (final o in ordenesRecientes) {
        if (_ordenesBloqueadas.contains(o.orden)) {
          setState(() => ordenSeleccionada = o);
          break;
        }
      }
    });
  }

  // ===== Auto-scroll cuando cambia el paso del tour =====
  void _scrollToStep(int stepIndex) {
    if (!_actionsScroll.hasClients) return;
    if (stepIndex <= 0 || stepIndex >= 7) return;

    const itemWidth = 160.0;
    const spacing = 24.0;
    final target = ((stepIndex - 1) * (itemWidth + spacing)).clamp(
      0.0,
      _actionsScroll.position.maxScrollExtent,
    );

    _actionsScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 10),
      curve: Curves.easeOut,
    );
  }

  // ===== Sincronización / Datos =====
  Future<void> _sincronizarYActualizar() async {
    final conectado = await ConexionHelper.hayInternet();
    if (conectado) {
      await SincronizadorService.sincronizarOrdenes();
      await SincronizadorService.sincronizarMarbetes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Sincronización completada')),
      );
    }
    await _cargarOrdenes();
    await _actualizarPrefijosYUM();
  }

  Future<void> _cargarBloqueadas() async {
    try {
      final db = await DBHelper.initDb();
      final res = await db.query(
        'ordenes',
        columns: ['orden'],
        where: 'pdf_generado=?',
        whereArgs: [1],
      );

      final bloqueadas =
          res
              .map((m) => (m['orden'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toSet();

      debugPrint(
        '🔒 [_cargarBloqueadas] ${bloqueadas.length} orden(es) bloqueada(s): $bloqueadas',
      );

      if (!mounted) return;
      setState(() {
        _ordenesBloqueadas = bloqueadas;
        _ordenTienePdf =
            ordenSeleccionada != null &&
            _ordenesBloqueadas.contains(ordenSeleccionada!.orden);
      });
    } catch (e) {
      debugPrint('❌ [_cargarBloqueadas] Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No pude leer estado PDF: $e')));
    }
  }

  Future<void> _cargarOrdenes() async {
    final api = ApiService();
    final conectado = await ConexionHelper.hayInternet();

    final ordenesLocales = await OrdenesDAO.getOrdenes();
    final pdfLocales =
        ordenesLocales
            .where((o) => o.pdfGenerado == true)
            .map((o) => o.orden)
            .toSet();
    final localesLocales =
        ordenesLocales.where((o) => o.local == 'S').map((o) => o.orden).toSet();

    List<Orden> ordenesValidas = [];

    if (conectado) {
      final data = await api.getOrdenes(
        widget.vendedor.empresa.toString(),
        widget.vendedor.id.toString(),
      );
      for (final item in data) {
        try {
          final o = Orden.fromJson(item);
          if (pdfLocales.contains(o.orden)) o.pdfGenerado = true;
          if (localesLocales.contains(o.orden)) o.local = 'S';
          ordenesValidas.add(o);
        } catch (_) {}
      }
      if (ordenesValidas.isNotEmpty) {
        await OrdenesDAO.insertarListaOrdenes(ordenesValidas);
      }
    } else {
      ordenesValidas = ordenesLocales;
    }

    // 🔴 Antes de pintar, refresca el set desde SQLite
    await _cargarBloqueadas();

    if (!mounted) return;
    setState(() {
      ordenesRecientes = ordenesValidas;
      // (opcional) solo para colorear “histórico” verde, no afecta bloqueo real
      pdfGenerados = _ordenesBloqueadas;
    });

    await _actualizarPrefijosYUM();
  }

  Future<bool> _estaBloqueadaEnDb(String ordenId) async {
    final db = await DBHelper.initDb();
    final r = await db.query(
      'ordenes',
      columns: ['pdf_generado'],
      where: 'orden = ?',
      whereArgs: [ordenId],
      limit: 1,
    );
    final bloqueada =
        r.isNotEmpty && (r.first['pdf_generado'] as int? ?? 0) == 1;
    return bloqueada;
  }

  void _startHoldToUnlock(String ordenId) {
    if (!_ordenesBloqueadas.contains(ordenId)) return;

    _holding = true;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 1), () async {
      if (!_holding) return;

      final ok = await showDialog<bool>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Desbloquear PDF'),
              content: Text('¿Quitar bloqueo de la orden $ordenId ?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Desbloquear'),
                ),
              ],
            ),
      );

      // ya no seguimos “sosteniendo”
      _holding = false;
      _holdTimer?.cancel();

      if (ok == true) {
        final r = await OrdenesDAO.desmarcarPdfGenerado(ordenId);
        debugPrint(
          '🔓 Desbloqueada $ordenId: ${r.valorAnterior}→${r.valorNuevo} filas=${r.filasActualizadas}',
        );

        // 1) Refleja cambio inmediatamente en memoria (UI instantánea)
        if (mounted) {
          setState(() => _ordenesBloqueadas.remove(ordenId));
        }

        // 2) Refuerza consistencia leyendo de SQLite
        await _cargarBloqueadas();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🔓 Orden $ordenId desbloqueada')),
        );
      }
    });
  }

  void _cancelHoldToUnlock() {
    _holding = false;
    _holdTimer?.cancel();
  }

  // ===== Helpers de prefijo / última orden =====
  String _prefixOf(String text) =>
      RegExp(r'^[A-Z]+').firstMatch(text.toUpperCase().trim())?.group(0) ?? '';

  String _prefijoHeuristico() {
    if (ordenesRecientes.isNotEmpty) {
      final p = _prefixOf(ordenesRecientes.first.orden);
      if (p.isNotEmpty) return p;
    }
    return 'T';
  }

  String? _sugerirOrdenInicial() {
    final pref = _prefijoUM ?? _prefijoHeuristico();
    final ultima = _ultimaPorPrefijo(ordenesRecientes, pref);
    return ultima?.orden;
  }

  int? _tailNumber(String orden, {String? forcedPrefix}) {
    final up = orden.toUpperCase().trim();
    final pref = forcedPrefix ?? _prefixOf(up);
    if (pref.isEmpty) return null;
    final tail = up.substring(pref.length).replaceAll(RegExp(r'[^0-9]'), '');
    if (tail.isEmpty) return null;
    return int.tryParse(tail);
  }

  Orden? _ultimaPorPrefijo(List<Orden> src, String prefijo) {
    final p = prefijo.toUpperCase();
    Orden? best;
    var maxN = -1;
    for (final o in src) {
      final up = o.orden.toUpperCase().trim();
      if (!up.startsWith(p)) continue;
      final n = _tailNumber(up, forcedPrefix: p);
      if (n != null && n > maxN) {
        maxN = n;
        best = o;
      }
    }
    return best;
  }

  List<String> _calcularPrefijosDesdeOrdenes() {
    final set = <String>{};
    for (final o in ordenesRecientes) {
      final p = _prefixOf(o.orden);
      if (p.isNotEmpty) set.add(p);
    }
    final list = set.toList()..sort();
    return list.isEmpty ? ['T'] : list;
  }

  Future<void> _refrescarUltimoUMHome([String? prefOverride]) async {
    final pref = prefOverride ?? _prefijoUM ?? _prefijoHeuristico();
    final prefs = await SharedPreferences.getInstance();
    final um = prefs.getString('ultimo_marbete_prefijo_${pref.toUpperCase()}');
    if (!mounted) return;
    setState(() {
      _prefijoUM = pref;
      _ultimoUM = um; // (puede ser null)
    });
  }

  Future<void> _actualizarPrefijosYUM() async {
    final nuevos = _calcularPrefijosDesdeOrdenes();
    final pref =
        (_prefijoUM != null && nuevos.contains(_prefijoUM))
            ? _prefijoUM!
            : (nuevos.isNotEmpty ? nuevos.first : _prefijoHeuristico());
    if (!mounted) return;
    await _refrescarUltimoUMHome(pref);
  }

  // ===== Estado (pintado) =====
  bool _estaGenerado(Orden o) {
    // Pintamos según SQLite (verdad absoluta)
    return _ordenesBloqueadas.contains(o.orden);
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Onboarding(
      key: _onboardingKey,
      onChanged: _scrollToStep,
      steps: <OnboardingStep>[
        OnboardingStep(
          focusNode: _fnSync,
          titleText: 'Sincronizar',
          bodyText: 'Pulsa para sincronizar con el servidor.',
          hasLabelBox: true,
          overlayBehavior: HitTestBehavior.deferToChild,
        ),
        OnboardingStep(
          focusNode: _fnNuevaOrden,
          titleText: 'Crear nueva orden',
          bodyText: 'Usaremos la última por prefijo como sugerencia.',
          hasLabelBox: true,
          overlayBehavior: HitTestBehavior.deferToChild,
        ),
        OnboardingStep(
          focusNode: _fnMarbetes,
          titleText: 'Marbetes',
          bodyText: 'Gestiona marbetes de la orden seleccionada.',
          hasLabelBox: true,
          overlayBehavior: HitTestBehavior.deferToChild,
        ),
        OnboardingStep(
          focusNode: _fnConsultaSoloLectura,
          titleText: 'Consulta',
          bodyText: 'Abre la orden en modo solo lectura.',
          hasLabelBox: true,
          overlayBehavior: HitTestBehavior.deferToChild,
        ),
        OnboardingStep(
          focusNode: _fnEliminar,
          titleText: 'Eliminar',
          bodyText: 'Elimina la orden seleccionada.',
          hasLabelBox: true,
          overlayBehavior: HitTestBehavior.deferToChild,
        ),
        OnboardingStep(
          focusNode: _fnConsultaOrden,
          titleText: 'Consulta Orden',
          bodyText: 'Busca una orden por cliente y orden.',
          hasLabelBox: true,
          overlayBehavior: HitTestBehavior.deferToChild,
        ),
        OnboardingStep(
          focusNode: _fnPDF,
          titleText: 'PDF',
          bodyText: 'Genera o abre el PDF de la orden.',
          hasLabelBox: true,
          overlayBehavior: HitTestBehavior.deferToChild,
        ),
        OnboardingStep(
          focusNode: _fnLista,
          titleText: 'Órdenes recientes',
          bodyText: 'Toca una fila para seleccionarla.',
          hasLabelBox: true,
          overlayBehavior: HitTestBehavior.deferToChild,
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFE5E5E5),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Image.asset('assets/images/SODIM1.png', height: 48),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Mostrar tutorial',
              onPressed: () => _onboardingKey.currentState?.show(),
              onLongPress: () => _onboardingKey.currentState?.hide(),
            ),
            Focus(
              focusNode: _fnSync,
              child: IconButton(
                icon: const Icon(Icons.sync),
                tooltip: 'Sincronizar',
                onPressed: () async {
                  final conectado = await ConexionHelper.hayInternet();
                  if (conectado) {
                    await _sincronizarYActualizar();
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ No hay conexión a internet'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
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
        drawer: CustomDrawer(vendedor: widget.vendedor),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📋 Sistema de Ordenes ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD2691E),
                  ),
                ),
                const Divider(thickness: 1),
                const SizedBox(height: 14),
                _infoTile('🏢 Empresa', widget.vendedor.empresa.toString()),
                const SizedBox(height: 10),
                _infoTile(
                  '👨‍🔧 Vendedor',
                  '${widget.vendedor.id} - ${widget.vendedor.nombre}',
                ),
                const SizedBox(height: 20),

                // ===== Acciones con scroll horizontal =====
                SingleChildScrollView(
                  controller: _actionsScroll,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),

                      // Nueva Orden
                      Focus(
                        focusNode: _fnNuevaOrden,
                        child: IconActionButton(
                          icon: Icons.add_box,
                          label: 'Nueva Orden',
                          color: Colors.black,
                          onTap: () async {
                            final sugerida = _sugerirOrdenInicial();
                            final res = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        NuevaOrden(ordenInicial: sugerida),
                              ),
                            );
                            if (!mounted) return;
                            if (res is Orden) {
                              setState(() => ordenesRecientes.insert(0, res));
                              await _refrescarUltimoUMHome();
                              await _cargarBloqueadas(); // por si la nueva viene ya bloqueada
                            }
                          },
                        ),
                      ),

                      const SizedBox(width: 24),

                      // Marbetes
                      Focus(
                        focusNode: _fnMarbetes,
                        child: IconActionButton(
                          icon: Icons.local_offer,
                          label: 'Marbetes',
                          enabled: !deshabilitarAcciones, // bloquea por SQLite
                          onTap: () {
                            if (ordenSeleccionada == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '⚠️ Selecciona una orden para continuar.',
                                  ),
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => MarbetesForms(
                                      orden: ordenSeleccionada!,
                                    ),
                              ),
                            ).then((_) async {
                              if (!mounted) return;
                              await _cargarBloqueadas(); // refresca estado
                              await _refrescarUltimoUMHome();
                            });
                          },
                        ),
                      ),

                      const SizedBox(width: 24),

                      // Consulta
                      Focus(
                        focusNode: _fnConsultaSoloLectura,
                        child: IconActionButton(
                          icon: Icons.remove_red_eye,
                          label: 'Consulta',
                          onTap: () {
                            if (ordenSeleccionada == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '⚠️ Selecciona una orden para consultar.',
                                  ),
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => MarbetesForms(
                                      orden: ordenSeleccionada!,
                                      soloLectura: true,
                                    ),
                              ),
                            ).then((_) async {
                              if (!mounted) return;
                              await _cargarBloqueadas();
                              await _refrescarUltimoUMHome();
                            });
                          },
                        ),
                      ),

                      const SizedBox(width: 24),

                      // Eliminar
                      Focus(
                        focusNode: _fnEliminar,
                        child: IconActionButton(
                          icon: Icons.delete,
                          label: 'Eliminar',
                          enabled: !deshabilitarAcciones, // bloquea por SQLite
                          onTap: () async {
                            if (ordenSeleccionada == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '⚠️ Selecciona una orden para eliminar.',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            final confirmar = await showDialog<bool>(
                              context: context,
                              builder:
                                  (_) => AlertDialog(
                                    title: const Text('Eliminar orden'),
                                    content: Text(
                                      '¿Estás seguro de eliminar la orden ${ordenSeleccionada!.orden}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                            );

                            if (confirmar == true) {
                              final ordenId = ordenSeleccionada!.orden;
                              final conectado =
                                  await ConexionHelper.hayInternet();
                              try {
                                if (conectado) {
                                  await ApiService().deleteOrdenes(ordenId);
                                }

                                await OrdenesDAO.eliminarPorOrden(ordenId);
                                await MOrdenesDAO.eliminarPorOrden(ordenId);

                                // 🔥 limpia también el caché de marbetes por orden
                                await MOrdenesDAO.eliminarCacheLocalStorage(
                                  ordenId,
                                );

                                if (!mounted) return;
                                setState(() {
                                  ordenesRecientes.remove(ordenSeleccionada);
                                  _ordenesBloqueadas.remove(ordenId);
                                  ordenSeleccionada = null;
                                  _ordenTienePdf = false;
                                });
                                await _cargarBloqueadas(); // refresca estado
                                await _refrescarUltimoUMHome();
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Error al eliminar: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 24),
                      // _iconAction(
                      //   context,
                      IconActionButton(
                        icon: Icons.edit_note,
                        label: 'Modifica Orden',
                        enabled: !deshabilitarAcciones, // bloquea por SQLite
                        onTap: () async {
                          if (ordenSeleccionada == null ||
                              ordenSeleccionada!.cliente.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '⚠️ Selecciona una orden para modificar.',
                                ),
                              ),
                            );
                          } else {
                            final modificada = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => NuevaOrden(
                                      ordenExistente: ordenSeleccionada,
                                      cliente:
                                          ordenSeleccionada!
                                              .cliente, // ✅ ahora sí funciona
                                    ),
                              ),
                               ).then((_) async {
                              if (!mounted) return;
                              await _cargarBloqueadas(); // refresca estado
                              await _refrescarUltimoUMHome();
                               }
                            );

                            if (modificada != null && modificada is Orden) {
                              setState(() {
                                final index = ordenesRecientes.indexWhere(
                                  (o) => o.orden == modificada.orden,
                                );
                                if (index != -1) {
                                  ordenesRecientes[index] = modificada;
                                }
                              });
                            }
                          }
                        },
                      ),

                      const SizedBox(width: 12),
                      const SizedBox(width: 24),

                      // Consulta Orden (buscador)
                      Focus(
                        focusNode: _fnConsultaOrden,
                        child: IconActionButton(
                          icon: Icons.remove_red_eye_outlined,
                          label: 'Consulta Orden',
                          onTap: () async {
                            final buscarOrden = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BuscarOrdenPage(),
                              ),
                            );
                            if (!mounted) return;
                            if (buscarOrden != null && buscarOrden is Orden) {
                              setState(() {
                                final i = ordenesRecientes.indexWhere(
                                  (o) => o.orden == buscarOrden.orden,
                                );
                                if (i != -1) ordenesRecientes[i] = buscarOrden;
                                ordenSeleccionada = buscarOrden;
                              });
                              await _cargarBloqueadas(); // refresca bloqueadas
                              await _refrescarUltimoUMHome();
                            }
                          },
                        ),
                      ),

                      const SizedBox(width: 24),

                      // PDF
                      Focus(
                        focusNode: _fnPDF,
                        child: GestureDetector(
                          onTap: () async {
                            // 👉 tu lógica actual de abrir PDF (la que ya tienes)
                            if (ordenSeleccionada == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '⚠️ Selecciona una orden para descargar el PDF.',
                                  ),
                                ),
                              );
                              return;
                            }
                            final id = ordenSeleccionada!.orden;
                            final bloqueada = await _estaBloqueadaEnDb(id);

                            if (bloqueada) {
                              setState(() => _ordenesBloqueadas.add(id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '🔒 La orden $id ya tiene PDF generado. Se abrirá en solo lectura.',
                                  ),
                                ),
                              );
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => PdfOtForms(
                                        orden: ordenSeleccionada!,
                                        soloLectura: true,
                                      ),
                                ),
                              );
                              await _cargarBloqueadas();
                              return;
                            }

                            final resultado = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => PdfOtForms(
                                      orden: ordenSeleccionada!,
                                      soloLectura: false,
                                    ),
                              ),
                            );
                            if (!mounted) return;
                            if (resultado != null) {
                              await _cargarBloqueadas();
                              setState(() => pdfGenerados.add(resultado));
                              await _refrescarUltimoUMHome();
                            }
                          },

                          // ⬇️ Mantener 3 s para DESBLOQUEAR (1→0)
                          onTapDown: (_) {
                            if (ordenSeleccionada != null) {
                              _startHoldToUnlock(ordenSeleccionada!.orden);
                            }
                          },
                          onTapUp: (_) => _cancelHoldToUnlock(),
                          onTapCancel: _cancelHoldToUnlock,

                          child: IconActionButton(
                            icon: Icons.picture_as_pdf_outlined,
                            label: 'PDF',
                            enabled: !deshabilitarAcciones,
                          ),
                        ),
                      ),


                      
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                const Text(
                  '📑 Órdenes recientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD2691E),
                  ),
                ),
                const SizedBox(height: 10),

                // Lista
                Expanded(
                  child: Focus(
                    focusNode: _fnLista,
                    child:
                        ordenesRecientes.isEmpty
                            ? Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: const Text(
                                'No hay órdenes para mostrar.\nPulsa “Sincronizar” o crea una nueva orden.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                            )
                            : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor:
                                      MaterialStateProperty.resolveWith(
                                        (_) => const Color(0xFFF7B234),
                                      ),
                                  columnSpacing: 12,
                                  dataRowMinHeight: 30,
                                  dataRowMaxHeight: 40,
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'Orden',
                                        style: TextStyle(color: Colors.black),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Nombre',
                                        style: TextStyle(color: Colors.black),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Fecha Captura',
                                        style: TextStyle(color: Colors.black),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Cliente',
                                        style: TextStyle(color: Colors.black),
                                      ),
                                    ),
                                  ],
                                  rows:
                                      ordenesRecientes.map((orden) {
                                        final estaGenerado = _estaGenerado(
                                          orden,
                                        ); // por SQLite
                                        final isSelected =
                                            ordenSeleccionada == orden;

                                        return DataRow(
                                          color:
                                              MaterialStateProperty.resolveWith<
                                                Color?
                                              >((_) {
                                                if (isSelected)
                                                  return Colors.blue.shade100;
                                                if (estaGenerado)
                                                  return Colors.green.shade100;
                                                return null;
                                              }),
                                          cells: [
                                            // DataCell(
                                            //   Row(
                                            //     children: [
                                            //       Text(
                                            //         orden.orden,
                                            //         style: const TextStyle(
                                            //           color: Colors.black,
                                            //         ),
                                            //       ),
                                            //       const SizedBox(width: 6),
                                            //       if (_ordenesBloqueadas
                                            //           .contains(orden.orden))
                                            //         const Icon(
                                            //           Icons.lock,
                                            //           color: Colors.redAccent,
                                            //           size: 18,
                                            //         ),
                                            //       if (marbetesSincronizados
                                            //           .contains(orden.orden))
                                            //         const Icon(
                                            //           Icons.cloud_done,
                                            //           color: Colors.green,
                                            //           size: 18,
                                            //         ),
                                            //     ],
                                            //   ),
                                            //   onTap: () async {
                                            //     if (!mounted) return;
                                            //     setState(
                                            //       () =>
                                            //           ordenSeleccionada = orden,
                                            //     );
                                            //     // Lee del Set (_ordenesBloqueadas) — no hace falta query
                                            //     setState(
                                            //       () =>
                                            //           _ordenTienePdf =
                                            //               _ordenesBloqueadas
                                            //                   .contains(
                                            //                     orden.orden,
                                            //                   ),
                                            //     );
                                            //   },
                                            // ),
                                            DataCell(
                                              GestureDetector(
                                                behavior:
                                                    HitTestBehavior
                                                        .opaque, // toda la celda capta el gesto
                                                onTap: () {
                                                  if (!mounted) return;
                                                  setState(
                                                    () =>
                                                        ordenSeleccionada =
                                                            orden,
                                                  );
                                                  setState(
                                                    () =>
                                                        _ordenTienePdf =
                                                            _ordenesBloqueadas
                                                                .contains(
                                                                  orden.orden,
                                                                ),
                                                  );
                                                },
                                                // ⬇️ Mantener 3s para DESBLOQUEAR (1→0)
                                                onTapDown: (_) {
                                                  _startHoldToUnlock(
                                                    orden.orden,
                                                  );
                                                  if (_ordenesBloqueadas
                                                      .contains(orden.orden)) {}
                                                },
                                                onTapUp:
                                                    (_) =>
                                                        _cancelHoldToUnlock(),
                                                onTapCancel:
                                                    _cancelHoldToUnlock,
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      orden.orden,
                                                      style: const TextStyle(
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    if (_ordenesBloqueadas
                                                        .contains(orden.orden))
                                                      const Icon(
                                                        Icons.lock,
                                                        color: Colors.redAccent,
                                                        size: 18,
                                                      ),
                                                    if (marbetesSincronizados
                                                        .contains(orden.orden))
                                                      const Icon(
                                                        Icons.cloud_done,
                                                        color: Colors.green,
                                                        size: 18,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // ===== Columna: Nombre (razonsocial)
                                            DataCell(
                                              GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap: () {
                                                  if (!mounted) return;
                                                  setState(
                                                    () =>
                                                        ordenSeleccionada =
                                                            orden,
                                                  );

                                                  setState(
                                                    () =>
                                                        _ordenTienePdf =
                                                            _ordenesBloqueadas
                                                                .contains(
                                                                  orden.orden,
                                                                ),
                                                  );
                                                },
                                                onTapDown: (_) {
                                                  _startHoldToUnlock(
                                                    orden.orden,
                                                  );
                                                  if (_ordenesBloqueadas
                                                      .contains(orden.orden)) {}
                                                },
                                                onTapUp:
                                                    (_) =>
                                                        _cancelHoldToUnlock(),
                                                onTapCancel:
                                                    _cancelHoldToUnlock,
                                                child: Text(
                                                  orden.razonsocial,
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // DataCell(
                                            //   Text(
                                            //     orden.razonsocial,
                                            //     style: const TextStyle(
                                            //       color: Colors.black,
                                            //     ),
                                            //   ),
                                            //   onTap: () async {
                                            //     if (!mounted) return;
                                            //     setState(
                                            //       () =>
                                            //           ordenSeleccionada = orden,
                                            //     );
                                            //     setState(
                                            //       () =>
                                            //           _ordenTienePdf =
                                            //               _ordenesBloqueadas
                                            //                   .contains(
                                            //                     orden.orden,
                                            //                   ),
                                            //     );
                                            //   },
                                            // ),
                                            // ===== Columna: Fecha Captura
                                            DataCell(
                                              GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap: () {
                                                  if (!mounted) return;
                                                  setState(
                                                    () =>
                                                        ordenSeleccionada =
                                                            orden,
                                                  );
                                                  setState(
                                                    () =>
                                                        _ordenTienePdf =
                                                            _ordenesBloqueadas
                                                                .contains(
                                                                  orden.orden,
                                                                ),
                                                  );
                                                },
                                                onTapDown: (_) {
                                                  _startHoldToUnlock(
                                                    orden.orden,
                                                  );
                                                  if (_ordenesBloqueadas
                                                      .contains(orden.orden)) {}
                                                },
                                                onTapUp:
                                                    (_) =>
                                                        _cancelHoldToUnlock(),
                                                onTapCancel:
                                                    _cancelHoldToUnlock,
                                                child: Text(
                                                  orden.fechaCaptura != null
                                                      ? DateFormat(
                                                        'dd/MM/yyyy HH:mm',
                                                      ).format(
                                                        orden.fechaCaptura!,
                                                      )
                                                      : 'Fecha inválida',
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // DataCell(
                                            //   Text(
                                            //     orden.fechaCaptura != null
                                            //         ? DateFormat(
                                            //           'dd/MM/yyyy HH:mm',
                                            //         ).format(
                                            //           orden.fechaCaptura!,
                                            //         )
                                            //         : 'Fecha inválida',
                                            //     style: const TextStyle(
                                            //       color: Colors.black,
                                            //     ),
                                            //   ),
                                            //   onTap: () async {
                                            //     if (!mounted) return;
                                            //     setState(
                                            //       () =>
                                            //           ordenSeleccionada = orden,
                                            //     );
                                            //     setState(
                                            //       () =>
                                            //           _ordenTienePdf =
                                            //               _ordenesBloqueadas
                                            //                   .contains(
                                            //                     orden.orden,
                                            //                   ),
                                            //     );
                                            //   },
                                            // ),
                                            // ===== Columna: Cliente
                                            DataCell(
                                              GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap: () {
                                                  if (!mounted) return;
                                                  setState(
                                                    () =>
                                                        ordenSeleccionada =
                                                            orden,
                                                  );
                                                  setState(
                                                    () =>
                                                        _ordenTienePdf =
                                                            _ordenesBloqueadas
                                                                .contains(
                                                                  orden.orden,
                                                                ),
                                                  );
                                                },
                                                onTapDown: (_) {
                                                  _startHoldToUnlock(
                                                    orden.orden,
                                                  );
                                                  if (_ordenesBloqueadas
                                                      .contains(orden.orden)) {
                                                    // ScaffoldMessenger.of(context).showSnackBar(
                                                    //   const SnackBar(
                                                    //     duration: Duration(seconds: 1),
                                                    //     content: Text('Mantén 3s para desbloquear…'),
                                                    //   ),
                                                    // );
                                                  }
                                                },
                                                onTapUp:
                                                    (_) =>
                                                        _cancelHoldToUnlock(),
                                                onTapCancel:
                                                    _cancelHoldToUnlock,
                                                child: Text(
                                                  orden.cliente,
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                ),
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

  // ====== UI helpers ======
  Widget _infoTile(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
        ),
      ],
    );
  }
}

/// Botón redondo con etiqueta.
class IconActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  final bool enabled;

  const IconActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? (color ?? Colors.orange) : Colors.grey.shade400;

    final child = Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: bg,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.black87 : Colors.black38,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: IgnorePointer(
        ignoring: !enabled,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: child,
          ),
        ),
      ),
    );
  }
}
