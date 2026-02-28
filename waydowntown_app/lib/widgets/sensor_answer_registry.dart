import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:waydowntown/flutter_blue_plus_mockable.dart';
import 'package:waydowntown/games/bluetooth_collector.dart';
import 'package:waydowntown/games/code_collector.dart';
import 'package:waydowntown/games/collector_game.dart';

class SensorConfig {
  final String title;
  final StringDetector Function() detectorFactory;
  final Widget Function(BuildContext, StringDetector) inputBuilder;
  final IconData icon;

  const SensorConfig({
    required this.title,
    required this.detectorFactory,
    required this.inputBuilder,
    required this.icon,
  });
}

class SensorAnswerRegistry {
  static SensorConfig? configForConcept(String? concept) {
    switch (concept) {
      case 'bluetooth_collector':
        return SensorConfig(
          title: 'Scan Bluetooth Devices',
          detectorFactory: () => BluetoothDetector(FlutterBluePlusMockable()),
          inputBuilder: (_, __) => const SizedBox(),
          icon: Icons.bluetooth_searching,
        );
      case 'code_collector':
        return SensorConfig(
          title: 'Scan Barcodes',
          detectorFactory: () => CodeDetector(null),
          inputBuilder: (context, detector) => SizedBox(
            height: 300,
            child: MobileScanner(
              controller: (detector as CodeDetector).controller,
            ),
          ),
          icon: Icons.qr_code_scanner,
        );
      default:
        return null;
    }
  }
}
