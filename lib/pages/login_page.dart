// ignore_for_file: use_build_context_synchronously, avoid_print, deprecated_member_use, unrelated_type_equality_checks

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sodim/models/vendedor_model.dart';
import '../api/api_service.dart' as api;
import '../db/db_helper.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController claveController = TextEditingController(
    // text: 'DEA',
  );
  final apiService = api.ApiService();

  bool loading = false;

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _tieneInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<void> _login(BuildContext context) async {
    final clave = claveController.text.trim();
    if (clave.isEmpty) {
      await _mostrarError('Debes ingresar una clave.');
      return;
    }

    setState(() => loading = true);

    final conectado = await _tieneInternet();
    Map<String, dynamic>? datosVendedor;

    if (conectado) {
      try {
        datosVendedor = await apiService.login(clave);

        if (datosVendedor != null) {
          final vendedor = Vendedor.fromJson(datosVendedor);
          print('👤 Vendedor recibido: ${vendedor.toJson()}');


          final prefs = await SharedPreferences.getInstance();
          final empresaAnterior = prefs.getString('empresa_guardada');

          // 👇 fuerza ambos a String para comparar correctamente
          final empresaNueva = vendedor.empresa.toString();

          if (empresaAnterior != null && empresaAnterior != empresaNueva) {
            print(
              '⚠️ Cambio de empresa detectado ($empresaAnterior → $empresaNueva). Limpiando datos locales...',
            );
            // si REALMENTE cambió, entonces sí limpia:
            // await prefs.clear();
            // await DBHelper.limpiarBaseDatos();
          } else {
            print('✅ Empresa sin cambio: NO se limpian datos locales.');
          }

          await prefs.setString('empresa_guardada', empresaNueva);
          await prefs.setString('vendedor', json.encode(vendedor.toJson()));
          await DBHelper.insertVendedor(vendedor);
          await apiService.sincronizarDatos(clave);

          await Future.delayed(
            const Duration(seconds: 5),
          ); // ⏱ espera 5 segundos

          if (!context.mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomePage(vendedor: vendedor)),
          );
          setState(() => loading = false);
          return;
        } else {
          await _mostrarError(
            '❌ Clave inválida.\nVerifica que la clave sea correcta o consulta con sistemas.',
          );
        }
      } on TimeoutException {
        await _mostrarError(
          '⏱ El servidor no respondió a tiempo.\nInténtalo nuevamente en unos segundos.',
        );
      } on SocketException {
        await _mostrarError(
          '📡 Error de red.\nNo se pudo conectar con el servidor.',
        );
      } catch (e) {
        await _mostrarError(
          '❌ Clave inválida.\nVerifica que la clave sea correcta o consulta con sistemas.',
        );
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final vendedorStr = prefs.getString('vendedor');

      if (vendedorStr != null) {
        final vendedorMap = json.decode(vendedorStr);
        final vendedor = Vendedor.fromJson(vendedorMap);

        await Future.delayed(const Duration(seconds: 5)); // espera 5 segundos

        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(vendedor: vendedor)),
        );
      } else {
        await _mostrarError(
          '📴 No tienes conexión a internet y no se ha iniciado sesión previamente.',
        );
      }
    }

    setState(() => loading = false);
  }

  Future<void> _mostrarError(String mensaje) async {
    return showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
            titlePadding: const EdgeInsets.only(top: 16),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            title: Column(
              children: const [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: Colors.orange,
                ),
                SizedBox(height: 8),
                Text(
                  'Atención',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            content: Text(
              mensaje,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black, // <-- Color negro aquí
              ),
              textAlign: TextAlign.center,
            ),

            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Entendido',
                  style: TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7B234), Color(0xFFF7B234)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child:
            (_controller.isAnimating || _controller.isCompleted)
                ? ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildLoginCard(),
                )
                : _buildLoginCard(),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/SODIM1.png', height: 64),
          const SizedBox(height: 16),
          const Text(
            'Sistema de Órdenes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 133, 29, 110),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ingrese su clave de vendedor para continuar',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: claveController,
            inputFormatters: [UpperCaseTextFormatter()],
            style: const TextStyle(
              color: Colors.black,
            ), // <-- Aquí se define el color del texto
            decoration: InputDecoration(
              labelText: 'Clave del Vendedor',
              labelStyle: const TextStyle(
                color: Colors.black,
              ), // <-- Opcional: color del label
              prefixIcon: const Icon(
                Icons.person_outline,
                color: Colors.black,
              ), // <-- color del ícono
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: loading ? null : () => _login(context),
            icon: const Icon(Icons.login),

            label:
                loading
                    ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Text('Ingresar'),
            style: ElevatedButton.styleFrom(
              // backgroundColor: const Color(0xFF3E3E98),
              backgroundColor: Color(0xFFD2691E), // botón naranja oscuro
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
