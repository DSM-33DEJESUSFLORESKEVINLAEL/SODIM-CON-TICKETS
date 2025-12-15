
class MarbeteUtils {
  static String extraerPrefijo(String valor) {
    final m = RegExp(r'^[A-Z]+').firstMatch(valor.toUpperCase().trim());
    return m?.group(0) ?? 'T';
  }

  static int? numeroFinal(String marbete, String prefijo) {
    final up = marbete.toUpperCase().trim();
    if (!up.startsWith(prefijo)) return null;
    final tail = up.substring(prefijo.length).replaceAll(RegExp(r'[^0-9]'), '');
    if (tail.isEmpty) return null;
    return int.tryParse(tail);
  }

  static String? siguiente(String ultimo, String prefijo) {
    final up = ultimo.toUpperCase().trim();
    if (!up.startsWith(prefijo)) return null;
    final tail = up.substring(prefijo.length).replaceAll(RegExp(r'[^0-9]'), '');
    if (tail.isEmpty) return null;
    final width = tail.length;
    final inc = (int.tryParse(tail) ?? 0) + 1;
    return '$prefijo${inc.toString().padLeft(width, '0')}';
  }
}
