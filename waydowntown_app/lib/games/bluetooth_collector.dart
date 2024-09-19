import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/flutter_blue_plus_mockable.dart';
import 'package:waydowntown/games/collector_game.dart';
import 'package:waydowntown/models/run.dart';

class BluetoothCollectorGame extends StatelessWidget {
  final Dio dio;
  final Run run;
  final FlutterBluePlusMockable? flutterBluePlus;

  BluetoothCollectorGame({
    Key? key,
    required this.dio,
    required this.run,
    this.flutterBluePlus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final detector =
        BluetoothDetector(flutterBluePlus ?? FlutterBluePlusMockable());
    return CollectorGame(
      dio: dio,
      run: run,
      detector: detector,
      inputBuilder: (context, detector) =>
          const SizedBox(), // No input UI for Bluetooth
    );
  }
}

class BluetoothDetector implements StringDetector {
  final FlutterBluePlusMockable flutterBluePlus;
  final _detectedDevicesController = StreamController<String>.broadcast();

  BluetoothDetector(this.flutterBluePlus);

  @override
  Stream<String> get detectedStrings => _detectedDevicesController.stream;

  @override
  void startDetecting() {
    flutterBluePlus.onScanResults.listen((results) {
      for (var result in results) {
        if (result.device.platformName.isNotEmpty) {
          _detectedDevicesController.add(result.device.platformName);
        }
      }
    }, onError: (e) => logger.e('Error scanning: $e'));

    FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first
        .then((_) => FlutterBluePlus.startScan());
  }

  @override
  void stopDetecting() {
    FlutterBluePlus.stopScan();
  }

  @override
  void dispose() {
    _detectedDevicesController.close();
  }
}
