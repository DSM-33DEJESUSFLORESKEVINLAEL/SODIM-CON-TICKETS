import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Orden {
  final String orden;
  final String fecha;
  final String cliente;
  final String razonsocial;
  final String fcierre;
  final String fcaptura;
  final int empresa;
  final int vend;
  final String ruta;
  final int enviada;
  final int diasentrega; 
  final String clietipo;
  final String ucaptura;
  String local; 
  bool pdfGenerado;


  Orden({
    required this.orden,
    required this.fecha,
    required this.cliente,
    required this.razonsocial,
    required this.fcierre,
    required this.fcaptura,
    required this.empresa,
    required this.vend,
    required this.ruta,
    required this.enviada,
    required this.diasentrega,
    required this.clietipo,
    required this.ucaptura,
    this.local = 'N', // ✅ por defecto no local
    this.pdfGenerado = false,
  });

factory Orden.fromJson(Map<String, dynamic> json) {
  try {
    return Orden(
      orden: json['ORDEN']?.toString().trim() ?? '',
      fecha: (json['FECHA']?.toString().trim().isNotEmpty ?? false)
          ? json['FECHA'].toString().trim()
          : DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()), // ✅ AQUI
      cliente: json['CLIENTE']?.toString().trim() ?? '',
      razonsocial: json['RAZONSOCIAL']?.toString().trim() ?? '',
      fcierre: json['FCIERRE']?.toString().trim() ?? '',
      fcaptura: json['FCAPTURA']?.toString().trim() ?? '',
      empresa: int.tryParse(json['EMPRESA']?.toString() ?? '') ?? 0,
      vend: int.tryParse(json['VEND']?.toString() ?? '') ?? 0,
      ruta: json['RUTA']?.toString().trim() ?? '',
      enviada: int.tryParse(json['ENVIADA']?.toString() ?? '') ?? 0,
      diasentrega: int.tryParse(json['DIAS_ENTREGA']?.toString() ?? '') ?? 0,
      clietipo: json['CLIE_TIPO']?.toString().trim() ?? '',
      ucaptura: json['UCAPTURA']?.toString().trim() ?? '',
      local: 'N',
      pdfGenerado: (json['pdf_generado'] ?? 0) == 1,
    );
  } catch (e) {
    debugPrint('❌ Error en Orden.fromJson: $e\n$json');
    rethrow;
  }
}

factory Orden.fromMap(Map<String, dynamic> map) {
  try {
    return Orden(
      orden: map['orden']?.toString().trim() ?? '',
      fecha: map['fecha']?.toString().trim() ?? '',
      cliente: map['cliente']?.toString().trim() ?? '',
      razonsocial: map['razonsocial']?.toString().trim() ?? '',
      fcierre: map['fcierre']?.toString().trim() ?? '',
      fcaptura: map['fcaptura']?.toString().trim() ?? '',
      empresa: map['empresa'] ?? 0,
      vend: map['vend'] ?? 0,
      ruta: map['ruta']?.toString().trim() ?? '',
      enviada: map['enviada'] ?? 0,
      diasentrega: map['diasentrega'] ?? 0,
      clietipo: map['clietipo']?.toString().trim() ?? '',
      ucaptura: map['ucaptura']?.toString().trim() ?? '',
      local: map['local']?.toString() ?? 'N',
      pdfGenerado: (map['pdf_generado'] ?? 0) == 1, // ✅ ESTA LÍNEA ES CLAVE
    );
  } catch (e) {
    debugPrint('❌ Error en Orden.fromMap: $e\n$map');
    rethrow;
  }
}

  Map<String, dynamic> toJson() => {
        'ORDEN': orden,
        'FECHA': fecha,
        'CLIENTE': cliente,
        'RAZONSOCIAL': razonsocial,
        'FCIERRE': fcierre,
        'FCAPTURA': fcaptura,
        'EMPRESA': empresa,
        'VEND': vend,
        'RUTA': ruta,
        'ENVIADA': enviada,
        'DIAS_ENTREGA': diasentrega,
        'CLIE_TIPO': clietipo,
        'UCAPTURA': ucaptura,
      };

  Map<String, dynamic> toMap() => {
        'orden': orden,
        'fecha': fecha,
        'cliente': cliente,
        'razonsocial': razonsocial,
        'fcierre': fcierre,
        'fcaptura': fcaptura,
        'empresa': empresa,
        'vend': vend,
        'ruta': ruta,
        'enviada': enviada,
        'diasentrega': diasentrega,
        'clietipo': clietipo,
        'ucaptura': ucaptura,
        'local': local, // ✅ GUARDADO
        'pdf_generado': pdfGenerado ? 1 : 0, // 👈 AQUÍ
      };

  DateTime? get fechaCaptura {
    try {
      return DateTime.parse(fcaptura);
    } catch (e) {
      debugPrint('⚠️ Fecha inválida para $orden: $fcaptura');
      return null;
    }
  }
}
