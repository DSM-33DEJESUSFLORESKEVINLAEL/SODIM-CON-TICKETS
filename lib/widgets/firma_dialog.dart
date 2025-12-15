// import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

/// Muestra un diálogo modal con un lienzo para firmar.
/// Devuelve un Map con { 'tipo': String, 'firma': Uint8List }
class FirmaDialog extends StatefulWidget {
  final String titulo;
  final Color trazoColor;
  final double trazoGrosor;
  final Color fondoColor;

  const FirmaDialog({
    super.key,
    this.titulo = 'Capturar firma',
    this.trazoColor = Colors.black,
    this.trazoGrosor = 2.0,
    this.fondoColor = Colors.white,
  });

  @override
  State<FirmaDialog> createState() => _FirmaDialogState();
}

class _FirmaDialogState extends State<FirmaDialog> {
  late final SignatureController _controller;
  String _tipoSeleccionado = 'Chofer'; // 👈 Línea 1: default

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: widget.trazoGrosor,
      penColor: widget.trazoColor,
      exportBackgroundColor: widget.fondoColor,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero dibuja tu firma.')),
      );
      return;
    }
    final pngBytes = await _controller.toPngBytes();
    if (!mounted) return;

    // 👈 Línea 2: devolvemos también el tipo seleccionado
    Navigator.pop<Map<String, dynamic>>(context, {
      'tipo': _tipoSeleccionado,
      'firma': pngBytes,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selector Chofer/Cliente
          DropdownButton<String>(
            value: _tipoSeleccionado,
            items: const [
              DropdownMenuItem(value: 'Chofer', child: Text('Firma Chofer')),
              DropdownMenuItem(value: 'Cliente', child: Text('Firma Cliente')),
            ],
            onChanged: (val) => setState(() => _tipoSeleccionado = val!),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.maxFinite,
            height: 200,
            decoration: BoxDecoration(
              color: widget.fondoColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Signature(
                controller: _controller,
                backgroundColor: widget.fondoColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: () => _controller.clear(),
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Limpiar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: _guardar,
                icon: const Icon(Icons.check),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
