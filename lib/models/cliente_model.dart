class Cliente {
  final String clave;
  final String nombre;

  Cliente({required this.clave, required this.nombre});

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      clave: json['CLIENTE'],
      nombre: json['NOMBRE'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clave': clave,
      'nombre': nombre,
    };
  }
}
