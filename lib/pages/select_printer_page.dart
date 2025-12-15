import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectPrinterPage extends StatelessWidget {
  final List<Map<String, String>> devices;

  const SelectPrinterPage({super.key, required this.devices});

  Future<void> guardarImpresora(BuildContext context, String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("impresora_mac", mac);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("🖨️ Impresora guardada: $mac")),
    );

    Navigator.pop(context); // regresar a la pantalla anterior
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Seleccionar Impresora")),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final d = devices[index];
          return ListTile(
            title: Text(d["name"] ?? ""),
            subtitle: Text(d["mac"] ?? ""),
            onTap: () => guardarImpresora(context, d["mac"]!),
          );
        },
      ),
    );
  }
}
