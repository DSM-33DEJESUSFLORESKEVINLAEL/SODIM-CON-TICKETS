// lib/widgets/scan_orden_page.dart
// Componente de escaneo con cámara + botón reutilizable

// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Página completa que abre la cámara y retorna el string escaneado.
class ScanOrdenPage extends StatefulWidget {
  const ScanOrdenPage({super.key});

  @override
  State<ScanOrdenPage> createState() => _ScanOrdenPageState();
}

class _ScanOrdenPageState extends State<ScanOrdenPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    // formats: [BarcodeFormat.code128, BarcodeFormat.ean13, BarcodeFormat.qrCode],
  );

  bool _handled = false; // evita pops múltiples

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;

    _handled = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear código'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Linterna',
          ),
          IconButton(
            icon: Icon(Platform.isIOS ? Icons.cameraswitch_rounded : Icons.flip_camera_android),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Cambiar cámara',
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay simple (cuadro guía)
          IgnorePointer(
            child: Container(
              decoration: ShapeDecoration(
                shape: _ScannerOverlayShape(
                  borderColor: Colors.white,
                  borderWidth: 4,
                  borderRadius: 12,
                  borderLength: 32,
                  cutOutSize: 260,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            child: Text(
              'Alinea el código dentro del recuadro',
              style: const TextStyle(color: Colors.white70),
            ),
          )
        ],
      ),
    );
  }
}

/// Botón reutilizable que abre la página de escaneo y entrega el texto leído.
/// Úsalo como suffixIcon o en cualquier parte de la UI.
class ScanCodigoButton extends StatelessWidget {
  final void Function(String code) onScanned;
  final String tooltip;
  final IconData icon;

  const ScanCodigoButton({
    super.key,
    required this.onScanned,
    this.tooltip = 'Escanear código',
    this.icon = Icons.qr_code_scanner,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: () async {
        final result = await Navigator.push<String?>(
          context,
          MaterialPageRoute(builder: (_) => const ScanOrdenPage()),
        );
        if (result != null && result.trim().isNotEmpty) {
          onScanned(result.trim());
        }
      },
    );
  }
}

/// Overlay con esquinas marcadas
/// Overlay con esquinas marcadas
class _ScannerOverlayShape extends ShapeBorder {
  final double borderRadius;
  final double borderWidth;
  final double borderLength;
  final double cutOutSize;
  final Color borderColor;

  const _ScannerOverlayShape({
    this.borderRadius = 12,
    this.borderLength = 32,
    this.borderWidth = 8,
    this.cutOutSize = 280,
    this.borderColor = Colors.white,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    // El contorno "externo" del shape es todo el rectángulo del widget
    return Path()..addRect(rect);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    // Para este overlay no necesitamos un inner path especial,
    // devolvemos también el rectángulo completo.
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    // Fondo oscurecido con recorte al centro (cutout)
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..style = PaintingStyle.fill;

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    final overlayPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            cutOutRect,
            Radius.circular(borderRadius),
          ),
        ),
    );
    canvas.drawPath(overlayPath, paint);

    // Líneas de las esquinas
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    void drawCorner(Offset start, Offset end) {
      canvas.drawLine(start, end, borderPaint);
    }

    final tl = cutOutRect.topLeft;
    final tr = cutOutRect.topRight;
    final bl = cutOutRect.bottomLeft;
    final br = cutOutRect.bottomRight;

    // Top-left
    drawCorner(tl, tl + Offset(borderLength, 0));
    drawCorner(tl, tl + Offset(0, borderLength));
    // Top-right
    drawCorner(tr, tr + Offset(-borderLength, 0));
    drawCorner(tr, tr + Offset(0, borderLength));
    // Bottom-left
    drawCorner(bl, bl + Offset(borderLength, 0));
    drawCorner(bl, bl + Offset(0, -borderLength));
    // Bottom-right
    drawCorner(br, br + Offset(-borderLength, 0));
    drawCorner(br, br + Offset(0, -borderLength));
  }

  @override
  ShapeBorder scale(double t) => this;
}
