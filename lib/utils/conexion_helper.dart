import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConexionHelper {
  static Future<bool> hayInternet() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return false;

    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
