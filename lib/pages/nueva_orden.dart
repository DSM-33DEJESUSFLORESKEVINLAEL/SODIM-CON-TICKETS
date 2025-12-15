// ignore_for_file: use_build_context_synchronously, no_leading_underscores_for_local_identifiers

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodim/api/api_service.dart';
import 'package:sodim/db/catalogo_dao.dart';
import 'package:sodim/db/ordenes_dao.dart';
import 'package:sodim/models/orden_model.dart';
import 'package:sodim/pages/marbetes_forms.dart';
import 'package:sodim/utils/sincronizador_service.dart';
import 'package:sodim/widgets/scan_orden_page.dart'; // ScanCodigoButton / ScanOrdenPage
import 'package:onboarding_overlay/onboarding_overlay.dart'; // 👈 Onboarding

/// ===== Formatter simple para mayúsculas =====
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

/// ===== Formatter que maneja prefijo + máscara + cursor/borrado =====
class MaskedOrdenFormatter extends TextInputFormatter {
  final String prefix;
  final int maxLength; // longitud total = prefijo + dígitos
  final List<int> defaultGroups;

  /// Si true, cuando no hay dígitos, muestra "PFX ___ ____".
  /// Si false y no hay dígitos, muestra solo "PFX " (sin subrayados).
  final bool padWithUnderscores;

  /// Si true, al tipear reinyecta el prefijo cuando no está.
  /// Si false, NO reinyecta el prefijo si el usuario lo borró todo.
  final bool enforcePrefix;

  MaskedOrdenFormatter({
    required this.prefix,
    required this.maxLength,
    this.defaultGroups = const [3, 4],
    this.padWithUnderscores = true,
    this.enforcePrefix = true,
  });

  List<int> _buildGroups(int maxDigits) {
    final groups = <int>[];
    int remaining = maxDigits;
    int gi = 0;
    while (remaining > 0) {
      final want =
          (gi < defaultGroups.length) ? defaultGroups[gi] : defaultGroups.last;
      final take = remaining >= want ? want : remaining;
      groups.add(take);
      remaining -= take;
      gi++;
    }
    return groups;
  }

  (String masked, List<int> slotIndexes) _maskFromDigits(
    String digits,
    int maxDigits,
  ) {
    final groups = _buildGroups(maxDigits);
    final buf = StringBuffer();
    final slotIdx = <int>[];

    if (prefix.isNotEmpty) {
      buf.write(prefix);
      if (digits.isNotEmpty || padWithUnderscores) {
        buf.write(' ');
      }
    }

    if (digits.isEmpty && !padWithUnderscores) {
      return (buf.toString(), slotIdx);
    }

    int consumed = 0;
    for (int gIndex = 0; gIndex < groups.length; gIndex++) {
      if (gIndex > 0) buf.write(' ');
      final g = groups[gIndex];
      for (int i = 0; i < g; i++) {
        final pos = buf.length;
        if (consumed < digits.length) {
          buf.write(digits[consumed]);
          consumed++;
        } else {
          buf.write('_');
        }
        slotIdx.add(pos);
      }
    }

    return (buf.toString(), slotIdx);
  }

  String _extractDigitsFrom(String text) {
    String withoutPrefix =
        text.startsWith(prefix) ? text.substring(prefix.length) : text;
    withoutPrefix = withoutPrefix.trimLeft();
    return withoutPrefix.replaceAll(RegExp(r'[^0-9]'), '');
  }

  int _caretToSlotIndex(int caret, List<int> slotIndexes) {
    int i = 0;
    // ignore: curly_braces_in_flow_control_structures
    while (i < slotIndexes.length && slotIndexes[i] < caret) i++;
    return i;
  }

  int _slotIndexToCaret(int slotIndex, List<int> slotIndexes, String masked) {
    if (slotIndexes.isEmpty) return masked.length;
    if (slotIndex <= 0) return slotIndexes.first;
    if (slotIndex >= slotIndexes.length) return masked.length;
    return slotIndexes[slotIndex];
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String rawText = newValue.text;

    if (enforcePrefix && !rawText.startsWith(prefix)) {
      rawText = '$prefix ${rawText.trimLeft()}';
    }

    final maxDigits =
        (maxLength > prefix.length) ? maxLength - prefix.length : 0;

    final oldDigits = _extractDigitsFrom(oldValue.text);
    String newDigits = _extractDigitsFrom(rawText);

    if (!enforcePrefix && newDigits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      );
    }

    final bool probableDelete =
        newDigits.length < oldDigits.length ||
        newValue.text.length < oldValue.text.length;

    if (probableDelete) {
      final chars = oldDigits.split('');
      final (oldMasked, oldSlots) = _maskFromDigits(oldDigits, maxDigits);
      final oldSel = oldValue.selection;
      final oldSlotIndex = _caretToSlotIndex(oldSel.baseOffset, oldSlots);

      int deleteAt = oldSlotIndex - 1;
      if (deleteAt < 0) deleteAt = 0;
      if (chars.isNotEmpty) {
        if (deleteAt >= chars.length) deleteAt = chars.length - 1;
        chars.removeAt(deleteAt);
      }
      newDigits = chars.join();
    }

    if (newDigits.length > maxDigits) {
      newDigits = newDigits.substring(0, maxDigits);
    }

    final (masked, slots) = _maskFromDigits(newDigits, maxDigits);

    int targetSlotIndex = newDigits.length;
    final caret = _slotIndexToCaret(targetSlotIndex, slots, masked);

    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: caret),
      composing: TextRange.empty,
    );
  }
}

// ====================== UI ======================
class NuevaOrden extends StatefulWidget {
  final Orden? ordenExistente;
  final String? cliente;
  final String? ordenInicial;

  const NuevaOrden({
    super.key,
    this.ordenExistente,
    this.cliente,
    this.ordenInicial,
  });

  @override
  State<NuevaOrden> createState() => _NuevaOrdenState();
}

class _NuevaOrdenState extends State<NuevaOrden> {
  // === Onboarding ===
  final GlobalKey<OnboardingState> _onboardingKey =
      GlobalKey<OnboardingState>();
  late final FocusNode _ordenFN, _clienteFN, _aceptarFN;

  final TextEditingController ordenController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController empresaController = TextEditingController();
  final TextEditingController vendedorController = TextEditingController();
  final TextEditingController fCapturaController = TextEditingController();
  final TextEditingController clienteComboController = TextEditingController();

  List<String> clientes = [];
  List<String> prefijos = [];
  List<Orden> ordenesRecientes = [];
  String _prefijoActual = ''; // ✅ prefijo en uso
  // En _NuevaOrdenState:
  String _ultimoPrefijoCatalogo = ''; // para visualizar y usar el último

  String? clienteSeleccionado;
  bool loading = true;

  /// Longitud total esperada para ORDEN (incluye prefijo).
  int _lonOrden = 0;

  @override
  void initState() {
    super.initState();
    cargarDatosIniciales();

    // init FocusNodes
    _ordenFN = FocusNode(debugLabel: 'orden');
    _clienteFN = FocusNode(debugLabel: 'cliente');
    _aceptarFN = FocusNode(debugLabel: 'aceptar');

    if (widget.ordenExistente != null) {
      final orden = widget.ordenExistente!;
      ordenController.text = orden.orden;
      clienteSeleccionado = orden.cliente;
      nombreController.text = orden.razonsocial;
      empresaController.text = orden.empresa.toString();
      vendedorController.text = orden.vend.toString();
      fCapturaController.text = orden.fcaptura;
      clienteComboController.text =
          '$clienteSeleccionado - ${orden.razonsocial}';
    } else {
      fCapturaController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (widget.cliente != null) {
        clienteSeleccionado = widget.cliente;
        nombreController.text = widget.cliente!;
      }

      // Sincroniza en background
      Future.delayed(Duration.zero, () async {
        try {
          await SincronizadorService.sincronizarOrdenes();
          await SincronizadorService.sincronizarMarbetes();
        } catch (e) {
          debugPrint('⚠️ Error al intentar sincronizar: $e');
        }
      });
    }

    // Mostrar guía la PRIMERA vez
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_nuevaorden_done') ?? false;
      if (!done && mounted) {
        _onboardingKey.currentState?.show(); // paso 0
        await prefs.setBool('onboarding_nuevaorden_done', true);
      }
    });
  }

  @override
  void dispose() {
    _ordenFN.dispose();
    _clienteFN.dispose();
    _aceptarFN.dispose();
    super.dispose();
  }

  Future<void> cargarDatosIniciales() async {
    await Future.wait([
      cargarCatalogosDesdeSQLite(), // ← aquí ya se setea _ultimoPrefijoCatalogo
      cargarVendedorDesdePreferencias(), // ← podría setear _prefijoActual
    ]);

    // 1) si hay orden existente, prefijo desde ella (si aún no lo tienes)
    if (widget.ordenExistente != null && _prefijoActual.isEmpty) {
      final prefFromOrden = _extraerPrefijo(widget.ordenExistente!.orden);
      if (prefFromOrden.isNotEmpty) _prefijoActual = prefFromOrden;
    }

    // 2) si sigue vacío => usa el último del catálogo
    if (_prefijoActual.isEmpty && _ultimoPrefijoCatalogo.isNotEmpty) {
      _prefijoActual = _ultimoPrefijoCatalogo;
    }

    // Inicializa máscara si es nueva
    if (widget.ordenExistente == null &&
        ordenController.text.isEmpty &&
        _prefijoActual.isNotEmpty) {
      final maxDigits =
          (_lonOrden > _prefijoActual.length)
              ? _lonOrden - _prefijoActual.length
              : 0;
      ordenController.text = _formatMasked(_prefijoActual, '', maxDigits);
    }

    setState(() => loading = false);
  }

  Future<void> cargarCatalogosDesdeSQLite() async {
    final datos = await Future.wait([
      CatalogoDAO.obtenerCatalogoSimple(tabla: 'clientes', campo: 'nombre'),
      CatalogoDAO.obtenerCatalogoSimple(tabla: 'prefijos', campo: 'prefijo'),
    ]);

    setState(() {
      clientes = datos[0];
      prefijos = datos[1];

      // 🧠 Último prefijo "registrado" = el último del arreglo
      _ultimoPrefijoCatalogo = prefijos.isNotEmpty ? prefijos.last : '';

      // Solo si aún no hay prefijo elegido por vendedor/orden, usa el último
      if (_prefijoActual.isEmpty && _ultimoPrefijoCatalogo.isNotEmpty) {
        _prefijoActual = _ultimoPrefijoCatalogo;
      }

      if (clienteSeleccionado != null &&
          !clientes.contains(clienteSeleccionado)) {
        clienteSeleccionado = null;
        nombreController.clear();
      }

      debugPrint('🛠️ Prefijos: $prefijos (último: $_ultimoPrefijoCatalogo)');
    });
  }

  Future<void> cargarVendedorDesdePreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    final vendedorStr = prefs.getString('vendedor');
    if (vendedorStr != null) {
      final vendedorMap = json.decode(vendedorStr);
      empresaController.text = vendedorMap['EMPRESA'].toString();
      vendedorController.text = vendedorMap['VENDEDOR'].toString();

      _lonOrden =
          int.tryParse(vendedorMap['LON_ORDEN']?.toString() ?? '0') ?? 0;
      debugPrint('📏 LON_ORDEN cargado: $_lonOrden');

      // ✅ si tienes almacenado el prefijo del usuario, úsalo como valor por defecto
      final prefGuardado =
          (vendedorMap['PREFIJO'] ?? '').toString().trim().toUpperCase();
      if (prefGuardado.isNotEmpty && _prefijoActual.isEmpty) {
        _prefijoActual = prefGuardado;
      }
    }
  }

  // ===================== Helpers de máscara / prefijo =====================
  String _formatMasked(
    String prefix,
    String digits,
    int maxDigits, {
    List<int> defaultGroups = const [3, 4],
  }) {
    if (maxDigits > 0 && digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    final groups = <int>[];
    int remaining = maxDigits;
    int gi = 0;
    while (remaining > 0) {
      final want =
          (gi < defaultGroups.length) ? defaultGroups[gi] : defaultGroups.last;
      final take = (remaining >= want) ? want : remaining;
      groups.add(take);
      remaining -= take;
      gi++;
    }

    final out = StringBuffer();
    int consumed = 0;
    for (int i = 0; i < groups.length; i++) {
      if (i > 0) out.write(' ');
      final g = groups[i];
      final have = (digits.length - consumed);
      final use = have > 0 ? (have >= g ? g : have) : 0;

      if (use > 0) {
        out.write(digits.substring(consumed, consumed + use));
        consumed += use;
      }

      final pads = g - use;
      if (pads > 0) {
        out.write('_' * pads);
      }
    }

    return prefix.isNotEmpty ? '$prefix ${out.toString()}' : out.toString();
  }

  String _extractDigitsFromMasked(String text, String prefix) {
    final t = text.startsWith(prefix) ? text.substring(prefix.length) : text;
    return t.replaceAll(' ', '').replaceAll('_', '');
  }

  String _extraerPrefijo(String valor) {
    final m = RegExp(r'^[A-Z]+').firstMatch(valor.toUpperCase().trim());
    return m?.group(0) ?? '';
  }
  // =======================================================================

  String? _normalizarOrdenDesdeCodigo(
    String raw,
    String prefijoActual,
    int lonOrden,
  ) {
    if (raw.trim().isEmpty) return null;
    final upper =
        raw.toUpperCase().replaceAll(' ', '').replaceAll('-', '').trim();

    final prefMatch = RegExp(r'^[A-Z]+').firstMatch(upper);
    final pref = (prefMatch != null) ? prefMatch.group(0)! : prefijoActual;
    final digits = upper.replaceAll(RegExp(r'[^0-9]'), '');

    if (pref.isEmpty || digits.isEmpty) return null;

    String combinado = '$pref$digits';
    if (lonOrden > 0 && combinado.length > lonOrden) {
      combinado = combinado.substring(0, lonOrden);
    }

    final maxDigits =
        (lonOrden > pref.length) ? (lonOrden - pref.length) : digits.length;
    final soloDigits = combinado.substring(pref.length);
    return _formatMasked(pref, soloDigits, maxDigits);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Onboarding(
      key: _onboardingKey,
      steps: <OnboardingStep>[
        OnboardingStep(
          focusNode: _ordenFN,
          titleText: 'Orden',
          bodyText:
              'Ingresa o escanea la orden. Puedes usar el botón del escáner y aquí mismo lo puedes editar.',
          overlayBehavior: HitTestBehavior.deferToChild,
          hasLabelBox: true,
          arrowPosition: ArrowPosition.autoVerticalCenter,
        ),
        OnboardingStep(
          focusNode: _clienteFN,
          titleText: 'Cliente',
          bodyText: 'Busca y selecciona el cliente en el autocompletado.',
          overlayBehavior: HitTestBehavior.deferToChild,
          hasLabelBox: true,
        ),
        OnboardingStep(
          focusNode: _aceptarFN,
          titleText: 'Guardar',
          bodyText: 'Valida y guarda la orden con Aceptar.',
          overlayBehavior: HitTestBehavior.deferToChild,
          hasLabelBox: true,
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            widget.ordenExistente != null
                ? '✏️ Modificar Orden'
                : '📦 Nueva Orden',
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF7B234), Color(0xFFE19A14)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Mostrar tutorial',
              onPressed: () => _onboardingKey.currentState?.show(),
              onLongPress: () => _onboardingKey.currentState?.hide(),
            ),
          ],
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
                        'Registro de Orden',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: const Color(0xFFD2691E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // === Orden (Paso 1)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // Campo ORDEN con la máscara y el prefijo en uso
                      Focus(
                        focusNode: _ordenFN,
                        child: _buildCampoLabeled(
                          context,
                          'Orden',
                          ordenController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Cliente'),
                  const SizedBox(height: 6),

                  // === Cliente (Paso 2)
                  // Focus(
                  //   focusNode: _clienteFN,
                  //   child:
                  //   TypeAheadFormField<String>(
                  //     textFieldConfiguration: TextFieldConfiguration(
                  //       controller: clienteComboController,
                  //       decoration: const InputDecoration(
                  //         hintText: 'Seleccionar cliente',
                  //         border: OutlineInputBorder(),
                  //       ),
                  //     ),
                  //     suggestionsCallback:
                  //         (pattern) =>
                  //             clientes
                  //                 .where(
                  //                   (c) => c.toLowerCase().contains(
                  //                     pattern.toLowerCase(),
                  //                   ),
                  //                 )
                  //                 .toList(),
                  //     itemBuilder:
                  //         (context, String suggestion) =>
                  //             ListTile(title: Text(suggestion)),
                  //     onSuggestionSelected: (String suggestion) {
                  //       final partes = suggestion.split(' - ');
                  //       setState(() {
                  //         clienteSeleccionado = partes.first.trim();
                  //         nombreController.text =
                  //             partes.length > 1 ? partes[1].trim() : '';
                  //         clienteComboController.text = suggestion;
                  //       });
                  //     },
                  //   ),
                  // ),
                  Focus(
                    focusNode: _clienteFN,
                    child: TypeAheadField<String>(
                      controller: clienteComboController,
                      suggestionsCallback: (pattern) {
                        return clientes
                            .where(
                              (c) => c.toLowerCase().contains(
                                pattern.toLowerCase(),
                              ),
                            )
                            .toList();
                      },
                      builder: (context, textController, focusNode) {
                        return TextField(
                          controller: clienteComboController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            hintText: 'Seleccionar cliente',
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                      itemBuilder: (context, item) {
                        return ListTile(title: Text(item));
                      },
                      onSelected: (item) {
                        final partes = item.split(' - ');
                        setState(() {
                          clienteSeleccionado = partes.first.trim();
                          nombreController.text =
                              partes.length > 1 ? partes[1].trim() : '';
                          clienteComboController.text = item;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCampoLabeled(
                          context,
                          'Empresa',
                          empresaController,
                          enabled: false,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCampoLabeled(
                          context,
                          'Vendedor',
                          vendedorController,
                          enabled: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCampoLabeled(
                    context,
                    'Fecha de Captura',
                    fCapturaController,
                    enabled: false,
                    readOnly: true,
                  ),

                  const SizedBox(height: 20),

                  // === Aceptar (Paso 3)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Focus(
                      focusNode: _aceptarFN,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final prefix = _prefijoActual; // ✅ prefijo en uso
                          final digits = _extractDigitsFromMasked(
                            ordenController.text,
                            prefix,
                          );
                          final ordenSinEspacios = '$prefix$digits';

                          if (digits.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '⚠️ El campo "Orden" es obligatorio',
                                ),
                              ),
                            );
                            return;
                          }

                          if (clienteSeleccionado == null ||
                              clienteSeleccionado!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '⚠️ Debes seleccionar un cliente',
                                ),
                              ),
                            );
                            return;
                          }

                          if (_lonOrden > 0 &&
                              ordenSinEspacios.length != _lonOrden) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '⚠️ La orden debe tener exactamente $_lonOrden caracteres',
                                ),
                              ),
                            );
                            return;
                          }

                          final Map<String, String?> jsonFinal = {
                            'ORDEN': ordenSinEspacios,
                            'FECHA': DateFormat(
                              'yyyy-MM-dd',
                            ).format(DateTime.now()),
                            'CLIENTE': clienteSeleccionado,
                            'RAZONSOCIAL': nombreController.text.trim(),
                            'FCIERRE': null,
                            'FCAPTURA': DateFormat(
                              'yyyy-MM-dd HH:mm:ss',
                            ).format(DateTime.now()),
                            'EMPRESA': empresaController.text.trim(),
                            'VEND': vendedorController.text.trim(),
                            'RUTA': null,
                            'ENVIADA': null,
                            'DIAS_ENTREGA': null,
                            'CLIE_TIPO': null,
                            'UCAPTURA': null,
                          };

                          debugPrint(
                            '📤 Enviando JSON: ${jsonEncode(jsonFinal)}',
                          );

                          try {
                            final api = ApiService();
                            final resultado =
                                widget.ordenExistente == null
                                    ? await api.insertOrdenes(jsonFinal)
                                    : await api.updateOrdenes(jsonFinal);

                            // 🔎 Si el servidor dice que la orden ya existe como marbete → regresar
                            String _normalize(String s) {
                              // quita acentos y pasa a mayúsculas para comparar robusto
                              const withAccents = 'áéíóúäëïöüÁÉÍÓÚÄËÏÖÜñÑ';
                              const noAccents = 'aeiouaeiouAEIOUAEIOUnN';
                              final map = {
                                for (int i = 0; i < withAccents.length; i++)
                                  withAccents[i]: noAccents[i],
                              };
                              final sb = StringBuffer();
                              for (final ch in s.characters) {
                                sb.write(map[ch] ?? ch);
                              }
                              return sb.toString().toUpperCase().trim();
                            }

                            final msg = (resultado).toString();
                            final norm = _normalize(msg);

                            // Cubre variantes: con/si "ORDEN CREADA:", mayúsc/minúsc, acentos, etc.
                            final yaExiste =
                                norm.contains(
                                  'LA ORDEN YA EXISTE COMO MARBETE',
                                ) ||
                                norm.contains(
                                  'ORDEN CREADA: LA ORDEN YA EXISTE COMO MARBETE',
                                );

                            if (yaExiste) {
                              if (!mounted) return;

                              final messenger = ScaffoldMessenger.of(context);
                              messenger
                                ..clearSnackBars()
                                ..showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    backgroundColor: Colors.redAccent,
                                    duration: const Duration(
                                      seconds: 2,
                                    ), // visible un poco más
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.report,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'La ORDEN YA EXISTE como marbete',
                                            style: TextStyle(
                                              fontSize: 18, // 👈 más grande
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );

                              // Espera breve para que se vea el mensaje y luego vuelve atrás
                              await Future.delayed(
                                const Duration(milliseconds: 1200),
                              );
                              if (!mounted) return;
                              Navigator.pop(context);
                              return;
                            }

                            if (widget.ordenExistente != null) {
                              final clienteAnterior =
                                  widget.ordenExistente!.cliente;
                              final clienteActual = clienteSeleccionado;

                              if (clienteAnterior != clienteActual) {
                                final bitacoraData = {
                                  'REG': 1,
                                  'ORDEN': ordenSinEspacios,
                                  'MARBETE': null,
                                  'OBSERVACION':
                                      'Cliente modificado: De $clienteAnterior a $clienteActual',
                                  'FECHASYS': DateFormat(
                                    'yyyy-MM-dd HH:mm:ss',
                                  ).format(DateTime.now()),
                                  'USUARIO': vendedorController.text.trim(),
                                };

                                try {
                                  final r = await api.insertBitacorasOt(
                                    bitacoraData,
                                  );
                                  debugPrint('✅ Bitácora registrada: $r');
                                } catch (_) {
                                  try {
                                    final r2 = await api.updateBitacorasOt(
                                      bitacoraData,
                                    );
                                    debugPrint('🔄 Bitácora actualizada: $r2');
                                  } catch (e2) {
                                    debugPrint(
                                      '❌ No se pudo registrar/actualizar bitácora: $e2',
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '❌ Error al registrar bitácora',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ Orden ${widget.ordenExistente == null ? "creada" : "actualizada"}: $resultado',
                                ),
                              ),
                            );

                            final nueva = Orden(
                              orden: jsonFinal['ORDEN'] ?? '',
                              fecha: jsonFinal['FECHA'] ?? '',
                              cliente: jsonFinal['CLIENTE'] ?? '',
                              razonsocial: jsonFinal['RAZONSOCIAL'] ?? '',
                              fcierre: jsonFinal['FCIERRE'] ?? '',
                              fcaptura: jsonFinal['FCAPTURA'] ?? '',
                              empresa:
                                  int.tryParse(jsonFinal['EMPRESA'] ?? '') ?? 0,
                              vend: int.tryParse(jsonFinal['VEND'] ?? '') ?? 0,
                              ruta: jsonFinal['RUTA'] ?? '',
                              enviada: jsonFinal['ENVIADA'] == 'S' ? 1 : 0,
                              diasentrega:
                                  int.tryParse(
                                    jsonFinal['DIAS_ENTREGA'] ?? '',
                                  ) ??
                                  0,
                              clietipo: jsonFinal['CLIE_TIPO'] ?? '',
                              ucaptura: jsonFinal['UCAPTURA'] ?? '',
                              local: 'N',
                            );

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => MarbetesForms(orden: nueva),
                              ),
                            );

                            if (widget.ordenExistente == null) {
                              setState(() => ordenesRecientes.add(nueva));
                            }
                          } catch (e) {
                            debugPrint('❌ Error: $e');

                            if (e.toString().contains('Failed host lookup')) {
                              debugPrint('📴 Guardando orden localmente...');

                              final nueva = Orden(
                                orden: ordenSinEspacios,
                                fecha: DateFormat(
                                  'yyyy-MM-dd',
                                ).format(DateTime.now()),
                                cliente: clienteSeleccionado ?? '',
                                razonsocial: nombreController.text.trim(),
                                fcierre: '',
                                fcaptura: DateFormat(
                                  'yyyy-MM-dd HH:mm:ss',
                                ).format(DateTime.now()),
                                empresa:
                                    int.tryParse(empresaController.text) ?? 0,
                                vend:
                                    int.tryParse(vendedorController.text) ?? 0,
                                ruta: '',
                                enviada: 0,
                                diasentrega: 0,
                                clietipo: '',
                                ucaptura: '',
                                local: 'S',
                              );

                              await OrdenesDAO.insertarOrden(nueva);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('📴 Orden guardada localmente'),
                                ),
                              );

                              Navigator.pop(context, nueva);
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('❌ Error al guardar: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Aceptar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD2691E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
      ),
    );
  }

  /// Campo genérico
  Widget _buildCampoLabeled(
    BuildContext context,
    String label,
    TextEditingController controller, {
    bool enabled = true,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final esOrden = label.toLowerCase() == 'orden';
    final prefix = _prefijoActual; // ✅ usar el prefijo en uso
    final maxDigits =
        (_lonOrden > prefix.length) ? _lonOrden - prefix.length : 0;
    final esNueva = widget.ordenExistente == null;

    // SOLO si es nueva orden y primera vez vacío → inicializa máscara.
    if (esOrden && esNueva && controller.text.isEmpty && prefix.isNotEmpty) {
      controller.text = _formatMasked(prefix, '', maxDigits);
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }

    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap, // no forzar máscara aquí
      enabled: enabled,
      keyboardType: esOrden ? TextInputType.number : TextInputType.text,
      inputFormatters:
          esOrden
              ? [
                MaskedOrdenFormatter(
                  prefix: prefix, // ✅
                  maxLength: _lonOrden,
                  defaultGroups: const [3, 4],
                  padWithUnderscores: esNueva,
                  enforcePrefix: esNueva,
                ),
              ]
              : [
                UpperCaseTextFormatter(),
                LengthLimitingTextInputFormatter(50),
              ],
      decoration: InputDecoration(
        labelText: label,
        hintText:
            esOrden
                ? (prefix.isEmpty ? 'Prefijo + número' : '$prefix ___ ____')
                : null,
        border: const OutlineInputBorder(),
        // 👇 Botón para abrir el escáner
        suffixIcon:
            esOrden
                ? ScanCodigoButton(
                  onScanned: (raw) {
                    final normalizado = _normalizarOrdenDesdeCodigo(
                      raw,
                      prefix, // ✅
                      _lonOrden,
                    );
                    if (normalizado != null) {
                      controller.text = normalizado;
                      controller.selection = TextSelection.collapsed(
                        offset: normalizado.length,
                      );
                      setState(() {});
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠️ Código inválido')),
                      );
                    }
                  },
                )
                : null,
      ),
      style: esOrden ? const TextStyle(fontWeight: FontWeight.w900) : null,

      // ✅ Soporte para lectores que "pegan" el texto y envían Enter
      onSubmitted: (value) {
        if (!esOrden) return;
        final normalizado = _normalizarOrdenDesdeCodigo(
          value,
          prefix, // ✅
          _lonOrden,
        );
        if (normalizado != null) {
          controller.text = normalizado;
          controller.selection = TextSelection.collapsed(
            offset: normalizado.length,
          );
          setState(() {});
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('⚠️ Código inválido')));
        }
      },

      // Validación final para Orden
      onEditingComplete: () {
        if (!esOrden) return;

        final digits = _extractDigitsFromMasked(controller.text, prefix); // ✅
        final completo = '$prefix$digits';
        if (_lonOrden > 0 && completo.length != _lonOrden) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ La orden debe tener exactamente $_lonOrden caracteres',
              ),
            ),
          );
        }
      },
    );
  }
}
