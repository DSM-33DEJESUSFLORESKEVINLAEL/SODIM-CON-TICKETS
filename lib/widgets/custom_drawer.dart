// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sodim/pages/about_page.dart';
import 'package:sodim/pages/impresora_page.dart';
import 'package:sqflite/sqflite.dart';

import 'package:sodim/db/db_helper.dart';
import 'package:sodim/pages/login_page.dart' show LoginPage;
import '../models/vendedor_model.dart';

class CustomDrawer extends StatelessWidget {
  final Vendedor vendedor;

  const CustomDrawer({super.key, required this.vendedor});

  Future<void> _cerrarSesion(BuildContext context) async {
    await DBHelper.close();

    // final dbPath = join(await getDatabasesPath(), 'sodim.db');
    // await deleteDatabase(dbPath);

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> exportarBaseDeDatos(BuildContext context) async {
    try {
      bool tienePermiso = false;

      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.isGranted) {
          tienePermiso = true;
        } else {
          final status = await Permission.manageExternalStorage.request();
          tienePermiso = status.isGranted;
        }
      }

      if (!tienePermiso) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ Permiso denegado')));
        return;
      }

      final origen = '${await getDatabasesPath()}/sodim.db';
      final destino = '/sdcard/Download/sodim.db';

      final archivo = File(origen);
      if (!await archivo.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ La base de datos no existe')),
        );
        return;
      }

      await archivo.copy(destino);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Exportado con éxito a: $destino')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error exportando: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFA500),
                  Color(0xFFF7B234),
                ], // Naranja tipo logo
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/SODIM1.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendedor.nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        vendedor.mail,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.print,
                  text: 'Sincronización de impresora',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ImpresoraPage()),
                    );
                  },
                ),

                _buildDrawerItem(
                  context,
                  icon: Icons.file_download,
                  text: 'Descargar Base',

                  onTap: () => exportarBaseDeDatos(context),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.info_outline,
                  text: 'Acerca de',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
                ),

                _buildDrawerItem(
                  context,
                  icon: Icons.logout,
                  text: 'Cerrar sesión',
                  onTap: () => _cerrarSesion(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.deepPurple.shade100,
      child: ListTile(
        leading: Icon(icon, color: Color(0xFFF7B234)),
        title: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black, // ✅ texto en color negro
          ),
        ),
      ),
    );
  }
}
