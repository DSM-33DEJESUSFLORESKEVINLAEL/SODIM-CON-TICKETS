// ignore_for_file: deprecated_member_use, unused_local_variable

import 'package:flutter/material.dart';
import 'package:sodim/api/api_service.dart';

class BuscarOrdenPage extends StatefulWidget {
  const BuscarOrdenPage({super.key});

  @override
  State<BuscarOrdenPage> createState() => _BuscarOrdenPageState();
}

class _BuscarOrdenPageState extends State<BuscarOrdenPage> {
  final TextEditingController ordenController = TextEditingController();
  final ApiService api = ApiService();

  List<Map<String, dynamic>> resultados = [];
  bool cargando = false;

  @override
  void initState() {
    super.initState();
    ordenController.addListener(() {
      final text = ordenController.text.toUpperCase();
      if (ordenController.text != text) {
        ordenController.value = ordenController.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });
  }

  Future<void> buscarPorOrden() async {
    setState(() => cargando = true);
    final datos = await api.getMarbetesPorOrden(ordenController.text.trim());

    setState(() {
      resultados = datos;

      // 🔹 Ordenar alfanuméricamente
      resultados.sort((a, b) {
        final marbeteA = a['MARBETE']?.toString() ?? '';
        final marbeteB = b['MARBETE']?.toString() ?? '';
        return marbeteA.compareTo(marbeteB);
      });

      cargando = false;
    });
  }

  Future<void> buscarPorCliente() async {
    setState(() => cargando = true);
    final datos = await api.getMarbetesPorCliente(ordenController.text.trim());

    setState(() {
      resultados = datos;

      // ✅ Ordena MARBETE alfanuméricamente de menor a mayor
      resultados.sort((a, b) {
        final marbeteA = a['MARBETE']?.toString() ?? '';
        final marbeteB = b['MARBETE']?.toString() ?? '';
        return marbeteA.compareTo(marbeteB);
      });

      cargando = false;
    });
  }

  double calcularTotal() {
    return resultados.fold(0.0, (acumulador, item) {
      final valor = double.tryParse(item['VALOR']?.toString() ?? '0') ?? 0;
      return acumulador + valor;
    });
  }

  String _formatearFecha(String? fechaISO) {
    if (fechaISO == null || fechaISO.isEmpty) return '';
    try {
      final fecha = DateTime.parse(fechaISO);
      return '${fecha.day.toString().padLeft(2, '0')}/'
          '${fecha.month.toString().padLeft(2, '0')}/'
          '${fecha.year}';
    } catch (e) {
      return fechaISO; // En caso de error, muestra la original
    }
  }

  String _statusTexto(dynamic statusValue) {
    final s = int.tryParse(statusValue?.toString() ?? '');
    switch (s) {
      case 0:
        return 'EN PLANTA SIN PROCESO';
      case 1:
        return 'EN PRODUCCION INICIO';
      case 2:
        return 'PRODUCCION AVANZADO';
      case 3:
        return 'TERMINADO';
      case 4:
        return 'TERMINADO/FACTURADO';
      default:
        return statusValue?.toString() ?? '';
    }
  }

  Color _statusColor(dynamic statusValue) {
    final s = int.tryParse(statusValue?.toString() ?? '');
    switch (s) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.orange.shade700;
      case 2:
        return Colors.amber;
      case 3:
        return Colors.green;
      case 4:
        return Colors.blue;
      default:
        return Colors.black87;
    }
  }

  // ====== WIDGETS DE ENCABEZADO (recuadro con CLIENTE y RAZONSOCIAL) ======
  Widget _encabezadoCaja(Map<String, dynamic> data) {
    final cliente = (data['CLIENTE'] ?? '').toString();
    final razon =
        (data['RAZONSOCIAL'] ?? data['RAZON_SOCIAL'] ?? '').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Flexible(
                flex: 4, // ocupa menos espacio
                child: _campoCaja('CLIENTE', cliente),
              ),
              const SizedBox(width: 16),
              Flexible(
                flex: 7, // ocupa más espacio y queda "más a la izquierda"
                child: _campoCaja('RAEUZONSOCIAL', razon),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _campoCaja(String etiqueta, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$etiqueta:',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.black, width: 1.4)),
          ),
          child: Text(
            valor.isEmpty ? '__________' : valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final encabezado = resultados.isNotEmpty ? resultados.first : null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ruta'),
        backgroundColor: const Color(0xFFFFA500),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: ordenController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'Buscar',
                labelStyle: TextStyle(color: Colors.black),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.lightBlue, width: 2),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                    ),
                    onPressed: buscarPorCliente,
                    child: const Text(
                      'Cliente*',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                    ),
                    onPressed: buscarPorOrden,
                    child: const Text(
                      'Orden*',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ===== Encabezado con recuadro (solo si hay resultados) =====
            if (!cargando && encabezado != null) ...[
              _encabezadoCaja(encabezado),
              const SizedBox(height: 12),
            ],

            if (!cargando && resultados.isNotEmpty) ...[
              Expanded(
                child: Container(
                  color: const Color.fromARGB(255, 247, 245, 245),
                  child: ListView.builder(
                    itemCount: resultados.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Espaciador/placeholder para separación visual
                        return const SizedBox(height: 4);
                      }

                      final item = resultados[index - 1];
                      final statusTexto = _statusTexto(item['STATUS']);
                      final statusColor = _statusColor(item['STATUS']);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 6.0,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FECHA   : ${_formatearFecha(item['FECHA'])}',
                                style: const TextStyle(color: Colors.black),
                              ),
                              Text(
                                'MARBETE : ${item['MARBETE'] ?? ''}',
                                style: const TextStyle(color: Colors.black),
                              ),
                              Text(
                                'MARCA   : ${item['MARCA'] ?? ''}',
                                style: const TextStyle(color: Colors.black),
                              ),
                              Text(
                                'MEDIDA  : ${item['MEDIDA'] ?? ''}',
                                style: const TextStyle(color: Colors.black),
                              ),
                              Text(
                                'TRABAJO : ${item['TRABAJO'] ?? ''}',
                                style: const TextStyle(color: Colors.black),
                              ),
                              Text(
                                'TERMINADO : ${item['TERMINADO'] ?? ''}',
                                style: TextStyle(
                                  color:
                                      (item['TERMINADO']
                                                  ?.toString()
                                                  .toUpperCase() ==
                                              'MALA')
                                          ? Colors.red
                                          : Colors.black,
                                  fontWeight:
                                      (item['TERMINADO']
                                                  ?.toString()
                                                  .toUpperCase() ==
                                              'MALA')
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),

                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Text(
                                    'STATUS : ',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      statusTexto,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // TOTAL MOSTRADO ABAJO DE LA LISTA
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.orangeAccent),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '📦 Total registros: ${resultados.length}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],

            if (!cargando && resultados.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  '🔍 No se encontraron resultados.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),

            if (cargando)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
