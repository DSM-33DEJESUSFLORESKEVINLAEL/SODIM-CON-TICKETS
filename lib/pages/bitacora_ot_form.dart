import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sodim/pages/login_page.dart';

class BitacoraOTFormPage extends StatefulWidget {
  final String? orden;
  final String? marbete;
  final String? cliente; // 👈 nuevo campo

  const BitacoraOTFormPage({
    super.key,
    this.orden,
    this.marbete,
    this.cliente,
  });

  @override
  State<BitacoraOTFormPage> createState() => _BitacoraOTFormPageState();
}

class _BitacoraOTFormPageState extends State<BitacoraOTFormPage> {
  final TextEditingController ordenController = TextEditingController();
  final TextEditingController marbeteController = TextEditingController();
  final TextEditingController observacionController = TextEditingController();
  final TextEditingController clienteController = TextEditingController();
  DateTime fechasys = DateTime.now();

  @override
  void initState() {
    super.initState();
    ordenController.text = widget.orden ?? '';
    marbeteController.text = widget.marbete ?? '';
    clienteController.text = widget.cliente ?? '';
  }

  void _guardar() {
    if (ordenController.text.isEmpty || marbeteController.text.isEmpty || clienteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Llena todos los campos obligatorios')),
      );
      return;
    }

    final datos = {
      'ORDEN': ordenController.text,
      'MARBETE': marbeteController.text,
      'OBSERVACION': observacionController.text,
      'FECHASYS': fechasys.toIso8601String(),
      'USUARIO': clienteController.text,
    };

    debugPrint('✅ Bitácora enviada: $datos');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Bitácora guardada')),
    );
    Navigator.pop(context);
  }

  void _cancelar() {
    Navigator.pop(context);
  }

  Widget _buildCampo(String label, TextEditingController controller, {bool obligatorio = false}) {
    return SizedBox(
      width: 250,
      child: TextField(
        controller: controller,
        inputFormatters: [UpperCaseTextFormatter()],
        decoration: InputDecoration(
          labelText: obligatorio ? '$label *' : label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: onTap == null ? Colors.grey : Colors.deepPurple,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            padding: const EdgeInsets.all(16),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('📝 Bitácora OT'),
        backgroundColor: Colors.indigo,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📌 Orden: ${widget.orden}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('🕒 Fecha: ${DateFormat('yyyy-MM-dd HH:mm').format(fechasys)}'),
                const Divider(height: 32),
                Wrap(
                  spacing: 28,
                  runSpacing: 12,
                  children: [
                    _buildCampo('Orden', ordenController, obligatorio: true),
                    _buildCampo('Marbete', marbeteController, obligatorio: true),
                    _buildCampo('Observación', observacionController),
                    _buildCampo('Usuario', clienteController, obligatorio: true),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconAction(icon: Icons.save, label: 'Guardar', onTap: _guardar),
                    const SizedBox(width: 32),
                    _iconAction(icon: Icons.cancel, label: 'Cancelar', onTap: _cancelar),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
