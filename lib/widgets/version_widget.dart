import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionWidget extends StatefulWidget {
  const VersionWidget({super.key});

  @override
  State<VersionWidget> createState() => _VersionWidgetState();
}

class _VersionWidgetState extends State<VersionWidget> {
  String _version = "";

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = "Versión: ${info.version}+${info.buildNumber}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _version,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    );
  }
}
