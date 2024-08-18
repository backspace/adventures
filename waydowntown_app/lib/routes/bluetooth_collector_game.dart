import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:waydowntown/flutter_blue_plus_mockable.dart';
import 'package:waydowntown/get_region_path.dart';
import 'package:waydowntown/main.dart';
import 'package:waydowntown/models/game.dart';

class BluetoothCollectorGame extends StatefulWidget {
  final Dio dio;
  final Game game;
  final FlutterBluePlusMockable flutterBluePlus;

  BluetoothCollectorGame({
    super.key,
    required this.dio,
    required this.game,
    FlutterBluePlusMockable? flutterBluePlus,
  }) : flutterBluePlus = flutterBluePlus ?? FlutterBluePlusMockable();

  @override
  BluetoothCollectorGameState createState() => BluetoothCollectorGameState();
}

enum DeviceSubmissionState {
  unsubmitted,
  submitting,
  error,
  correct,
  incorrect
}

class DetectedDevice {
  final BluetoothDevice device;
  DeviceSubmissionState state;

  DetectedDevice(this.device, {this.state = DeviceSubmissionState.unsubmitted});
}

class BluetoothCollectorGameState extends State<BluetoothCollectorGame> {
  List<DetectedDevice> detectedDevices = [];
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    startScan();
  }

  void startScan() {
    setState(() {
      isScanning = true;
    });
    _scanResultsSubscription =
        widget.flutterBluePlus.onScanResults.listen((results) {
      setState(() {
        for (var result in results) {
          if (result.device.platformName.isNotEmpty) {
            var existingDevice = detectedDevices.firstWhere(
                (d) => d.device.remoteId == result.device.remoteId,
                orElse: () => DetectedDevice(result.device));
            if (!detectedDevices.contains(existingDevice)) {
              logger.i('Adding device ${existingDevice.device.platformName}');
              detectedDevices.add(existingDevice);
            }
          }
        }
      });
    }, onError: (e) => logger.e('Error scanning: $e'));
    FlutterBluePlus.startScan();
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanResultsSubscription?.cancel();
    setState(() {
      isScanning = false;
    });
  }

  Future<void> submitDevice(DetectedDevice detectedDevice) async {
    setState(() {
      detectedDevice.state = DeviceSubmissionState.submitting;
    });

    try {
      final response = await widget.dio.post(
        '/waydowntown/answers?include=game',
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': detectedDevice.device.platformName,
            },
            'relationships': {
              'game': {
                'data': {'type': 'games', 'id': widget.game.id},
              },
            },
          },
        },
      );

      setState(() {
        if (response.data['data']['attributes']['correct']) {
          detectedDevice.state = DeviceSubmissionState.correct;
        } else {
          detectedDevice.state = DeviceSubmissionState.incorrect;
        }
      });
    } catch (e) {
      logger.e('Error submitting device: $e');
      setState(() {
        detectedDevice.state = DeviceSubmissionState.error;
      });
    }
  }

  Icon _getIconForState(DeviceSubmissionState state) {
    switch (state) {
      case DeviceSubmissionState.unsubmitted:
        return const Icon(Icons.radio_button_unchecked,
            color: Colors.grey, size: 24.0);
      case DeviceSubmissionState.submitting:
        return const Icon(Icons.hourglass_empty,
            color: Colors.blue, size: 24.0);
      case DeviceSubmissionState.error:
        return const Icon(Icons.error, color: Colors.red, size: 24.0);
      case DeviceSubmissionState.correct:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24.0);
      case DeviceSubmissionState.incorrect:
        return const Icon(Icons.cancel, color: Colors.orange, size: 24.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Collector'),
      ),
      body: Column(
        children: [
          Text(getRegionPath(widget.game.incarnation)),
          Expanded(
              child: ListView.builder(
            itemCount: detectedDevices.length,
            itemBuilder: (context, index) {
              DetectedDevice detectedDevice = detectedDevices[index];
              return ListTile(
                title: Text(detectedDevice.device.platformName),
                leading: _getIconForState(detectedDevice.state),
                onTap: detectedDevice.state == DeviceSubmissionState.unsubmitted
                    ? () => submitDevice(detectedDevice)
                    : null,
              );
            },
          )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isScanning ? stopScan : startScan,
        child: Icon(isScanning ? Icons.stop : Icons.refresh),
      ),
    );
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    super.dispose();
  }
}
