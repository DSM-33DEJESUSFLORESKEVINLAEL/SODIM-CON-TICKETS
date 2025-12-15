// // ignore_for_file: avoid_print, unused_field

// ignore_for_file: unused_field, avoid_print

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('❌ FlutterError: ${details.exception}');
  };

  runApp(const MyApp());
}

// 🔸 SplashScreen que se muestra al iniciar
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool mostrarTexto = false;

  // ⬇️ Versión de la app (leída desde package_info_plus)
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();

    print('🟡 Splash iniciado');

    _loadVersion(); // carga versión/builder

    // Mostrar el texto con ligera demora
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => mostrarTexto = true);
    });

    // Navegar al login luego de 4 segundos
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;       // ej. 1.0.1
        _buildNumber = info.buildNumber;  // ej. 4
      });
    } catch (e) {
      debugPrint('⚠️ No se pudo leer versión: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7B234), Color(0xFFE19A14)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/SODIM1.png', height: 100),
                const SizedBox(height: 20),
                AnimatedOpacity(
                  opacity: mostrarTexto ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: const Text(
                    'Bienvenido a SODiM ',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // ⬇️ Texto de versión (aparece con la misma animación)
                AnimatedOpacity(
                  opacity: mostrarTexto ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: Text(
                        'Version: 1.0.7',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
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
}

// 🔸 App principal
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SODIM',
      debugShowCheckedModeBanner: false,

      // Tema claro personalizado
      theme: ThemeData(
        primaryColor: const Color(0xFFF7B234),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7B234),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF7B234),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF7B234), width: 2),
          ),
        ),
        useMaterial3: true,
      ),

      // Tema oscuro
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF7B234),
            foregroundColor: Colors.black,
          ),
        ),
      ),

      // Pantalla inicial con logo
      home: const SplashScreen(),
    );
  }
}

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized(); // ✅ Muy importante
//   await FtpService.subirPdf(
//     data: Uint8List.fromList([1, 2, 3, 4]), // bytes de prueba
//     fileName: 'test.txt',
//     empresa: 'demo',
//   );
//   print('✅ Subido');
// }
