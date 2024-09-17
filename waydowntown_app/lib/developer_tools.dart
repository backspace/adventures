import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:waydowntown/tools/auth_webview.dart';
import 'package:waydowntown/tools/bluetooth_scanner_route.dart';
import 'package:waydowntown/tools/map_route.dart';
import 'package:waydowntown/tools/motion_sensors_route.dart';

class DeveloperTools extends StatelessWidget {
  final Dio dio;

  const DeveloperTools({super.key, required this.dio});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer Tools')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFlexibleButtonGrid(
              context,
              [
                ('Auth', 'auth_webview'),
                ('Bluetooth\nScanner', 'bluetooth_scanner'),
                ('Map', 'map'),
                ('Motion\nSensors', 'motion_sensors'),
              ],
              (tool) {
                switch (tool) {
                  case 'bluetooth_scanner':
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const BluetoothScannerRoute()));
                    break;
                  case 'map':
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => MapRoute(dio: dio)));
                    break;
                  case 'motion_sensors':
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const MotionSensorsRoute()));
                    break;
                  case 'auth_webview':
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AuthWebView(
                                apiBaseUrl: dotenv.env['API_ROOT']!,
                                dio: dio)));
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlexibleButtonGrid(BuildContext context,
      List<(String, String)> buttons, Function(String) onPressed) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8.0,
      runSpacing: 8.0,
      children: buttons.map((button) {
        return SizedBox(
          width: 100,
          child: ElevatedButton(
            onPressed: () => onPressed(button.$2),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              button.$1,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      }).toList(),
    );
  }
}
