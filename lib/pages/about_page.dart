import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: 
                        Image.asset('assets/images/SODIM1.png', height: 64),

            ),
            const SizedBox(height: 24),
            const Text(
              'SODIM- Sistema de Orden por Dispositivo Movil',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Versión: 1.0.7',
              style: TextStyle(fontSize: 16),
            ),
            const Text(
              '30/09/2025',
              style: TextStyle(fontSize: 16),
            ),
             const Text(
              '16:00 Hr',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Desarrollado por: Kevin Lael de Jesús Flores',
              style: TextStyle(fontSize: 16),
            ),
            const Text(
              'Diseñado por: Jorge Carlos Linares',
              style: TextStyle(fontSize: 16),
            ),
             const Text(
              'Funcionamiento por: Gabriel Garcia Sanchez',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              '© 2025 Todos los derechos reservados.\n\n'
              'Esta aplicación está protegida por derechos de autor. '
              'Queda prohibida su reproducción total o parcial, '
              'distribución, modificación o uso con fines comerciales '
              'sin autorización previa y por escrito del desarrollador.',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.justify,
            ),
          ],
        ),
      ),
    );
  }
}
