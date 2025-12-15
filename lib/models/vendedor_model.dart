class Vendedor {
  final String  id;           // ← VENDEDOR
  final String claveCel;  // ← CLAVE_CEL
  final String nombre;    // ← NOMBRE
  final String mail;      // ← MAIL
  final int empresa;      // ← EMPRESA
  final int lon_orden;

  Vendedor({
    required this.id,
    required this.claveCel,
    required this.nombre,
    required this.mail,
    required this.empresa,
    required this.lon_orden,
  });

  factory Vendedor.fromJson(Map<String, dynamic> json) {
    return Vendedor(
      id: json['VENDEDOR'].toString(),  // 🔒 Conserva ceros
      claveCel: json['CLAVE_CEL'] ?? '',
      nombre: json['NOMBRE'] ?? '',
      mail: json['MAIL'] ?? '',
      empresa: int.tryParse(json['EMPRESA'].toString()) ?? 0,
      lon_orden: int.tryParse(json['LON_ORDEN'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clave_cel': claveCel,
      'nombre': nombre,
      'mail': mail,
      'empresa': empresa,
      'lon_orden': lon_orden,
    };
  }

  // ✅ Este método permite guardar en SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'VENDEDOR': id,
      'CLAVE_CEL': claveCel,
      'NOMBRE': nombre,
      'MAIL': mail,
      'EMPRESA': empresa,
      'LON_ORDEN' : lon_orden,
    };
  }
  factory Vendedor.fromMap(Map<String, dynamic> map) {
  return Vendedor(
      id: map['id'].toString(), // 🔒 String
    claveCel: map['clave_cel'] ?? '',
    nombre: map['nombre'] ?? '',
    mail: map['mail'] ?? '',
    empresa: map['empresa'] ?? 0,
    lon_orden: map['lon_orden'] ?? 0,
  );
}

}
