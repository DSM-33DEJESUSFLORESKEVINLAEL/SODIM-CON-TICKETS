import 'dart:io';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';

Future<void> guardarPDF(Uint8List pdfData, String nombreArchivo) async {
  final status = await Permission.storage.request();

  if (!status.isGranted) {
    throw Exception('Permiso de almacenamiento denegado');
  }

  final directory = Directory('/storage/emulated/0/Download');
  final file = File('${directory.path}/$nombreArchivo');

  await file.writeAsBytes(pdfData);
}
