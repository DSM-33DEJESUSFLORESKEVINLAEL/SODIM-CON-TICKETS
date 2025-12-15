import 'package:flutter/services.dart';

class StarBluetooth {
  static const MethodChannel _channel = MethodChannel('star_bt_channel');

  static Future<List<Map<String, dynamic>>> scan() async {
    final List result = await _channel.invokeMethod("scan");

    return result.map<Map<String, dynamic>>((item) {
      return {
        "name": item["name"]?.toString() ?? "",
        "mac": item["mac"]?.toString() ?? "",
      };
    }).toList();
  }

  static Future<bool> printText(String text, String mac) async {
    final bool result = await _channel.invokeMethod(
      "printStarBluetooth",
      {"text": text, "mac": mac},
    );
    return result;
  }
}
