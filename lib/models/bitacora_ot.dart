class BitacoraOT {
  final int? reg;
  final String orden;
  final String marbete;
  final String observacion;
  final DateTime fechasys;
  final String usuario;

  BitacoraOT({
    this.reg,
    required this.orden,
    required this.marbete,
    required this.observacion,
    required this.fechasys,
    required this.usuario,
  });

  Map<String, dynamic> toJson() {
    return {
      'ORDEN': orden,
      'MARBETE': marbete,
      'OBSERVACION': observacion,
      'FECHASYS': fechasys.toIso8601String(),
      'USUARIO': usuario,
    };
  }

  factory BitacoraOT.fromJson(Map<String, dynamic> json) {
    return BitacoraOT(
      reg: json['REG'],
      orden: json['ORDEN'],
      marbete: json['MARBETE'],
      observacion: json['OBSERVACION'],
      fechasys: DateTime.parse(json['FECHASYS']),
      usuario: json['USUARIO'],
    );
  }
}
