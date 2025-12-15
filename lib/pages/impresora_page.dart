import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodim/pages/star_bluetooth.dart';
import 'dart:io';

class ImpresoraPage extends StatefulWidget {
  const ImpresoraPage({super.key});

  @override
  State<ImpresoraPage> createState() => _ImpresoraPageState();
}

class _ImpresoraPageState extends State<ImpresoraPage> {
  List<Map<String, dynamic>> devices = [];
  String? selectedMac; // MAC seleccionada en pantalla
  String? savedMac; // MAC guardada previamente
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
    searchDevices();
  }

  // ======================================================================
  // Cargar impresora guardada
  // ======================================================================
  Future<void> _loadSavedPrinter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    savedMac = prefs.getString("printer_mac");
    setState(() {});
  }

  // ======================================================================
  // Guardar impresora seleccionada
  // ======================================================================
  Future<void> _savePrinter() async {
    if (selectedMac == null) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("printer_mac", selectedMac!);

    savedMac = selectedMac;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Impresora guardada correctamente')),
    );

    setState(() {});
  }

  // ======================================================================
  // Escanear dispositivos
  // ======================================================================

  Future<void> searchDevices() async {
    setState(() {
      isLoading = true;
      devices = [];
    });

    devices = await StarBluetooth.scan();

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Impresora Bluetooth"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: searchDevices),
        ],
      ),

      body: Column(
        children: [
          if (savedMac != null)
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              color: Colors.green.withOpacity(0.15),
              child: Text(
                "Impresora guardada: $savedMac",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

          // Expanded(
          //   child: devices.isEmpty
          //       ? const Center(child: Text("No se encontraron impresoras"))
          //       : ListView.builder(
          //           itemCount: devices.length,
          //           itemBuilder: (context, index) {
          Expanded(
            child:
                isLoading
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text("Buscando impresoras..."),
                        ],
                      ),
                    )
                    : devices.isEmpty
                    ? const Center(child: Text("No se encontraron impresoras"))
                    : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final d = devices[index];
                        final mac = d["mac"];

                        return ListTile(
                          title: Text(d["name"] ?? "Desconocido"),
                          subtitle: Text(mac),
                          trailing:
                              selectedMac == mac
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.blue,
                                  )
                                  : null,
                          onTap: () {
                            setState(() => selectedMac = mac);
                          },
                        );
                      },
                    ),
          ),

          // ===============================================================
          // BOTÓN GUARDAR
          // ===============================================================
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("Guardar impresora"),
              onPressed: selectedMac == null ? null : _savePrinter,
            ),
          ),
        ],
      ),
    );
  }
}
