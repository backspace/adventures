import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/flutter_blue_plus_mockable.dart';
import 'package:waydowntown/game_header.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/widgets/completion_animation.dart';

class BluetoothCollectorGame extends StatefulWidget {
  final Dio dio;
  final Run game;
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
  Map<String, String> deviceErrors = {};
  bool isGameComplete = false;

  late Run currentGame;

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    currentGame = widget.game;
    startScan();
  }

  Future<void> startScan() async {
    setState(() {
      isScanning = true;
    });
    _scanResultsSubscription =
        widget.flutterBluePlus.onScanResults.listen((results) {
      for (var result in results) {
        if (result.device.platformName.isNotEmpty) {
          var existingDevice = detectedDevices.firstWhere(
              (d) => d.device.remoteId == result.device.remoteId,
              orElse: () => DetectedDevice(result.device));
          if (!detectedDevices.contains(existingDevice)) {
            logger.i('Adding device ${existingDevice.device.platformName}');
            _addDevice(existingDevice);
          }
        }
      }
    }, onError: (e) => logger.e('Error scanning: $e'));

    await FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first;

    FlutterBluePlus.startScan();
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanResultsSubscription?.cancel();
    setState(() {
      isScanning = false;
    });
  }

  void _showCompletionAnimation() {
    CompletionAnimation.show(context);
  }

  Future<void> submitDevice(DetectedDevice detectedDevice) async {
    setState(() {
      detectedDevice.state = DeviceSubmissionState.submitting;
    });

    try {
      final response = await widget.dio.post(
        '/waydowntown/answers',
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': detectedDevice.device.platformName,
            },
            'relationships': {
              'game': {
                'data': {'type': 'games', 'id': currentGame.id},
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

        if (response.data['included'] != null) {
          final gameData = response.data['included'].firstWhere(
            (included) =>
                included['type'] == 'games' && included['id'] == currentGame.id,
            orElse: () => null,
          );
          if (gameData != null) {
            currentGame = Run.fromJson(
                {'data': gameData, 'included': response.data['included']},
                existingSpecification: currentGame.specification);
          }
        }

        if (currentGame.correctAnswers == currentGame.totalAnswers) {
          isGameComplete = true;
          stopScan();
          _showCompletionAnimation();
        }
      });
    } catch (e) {
      logger.e('Error submitting device: $e');
      setState(() {
        detectedDevice.state = DeviceSubmissionState.error;
        deviceErrors[detectedDevice.device.remoteId.toString()] = e.toString();
      });
    }
  }

  Widget _getIconForState(DeviceSubmissionState state, String deviceId) {
    switch (state) {
      case DeviceSubmissionState.unsubmitted:
        return const Icon(Icons.radio_button_unchecked,
            color: Colors.grey, size: 24.0);
      case DeviceSubmissionState.submitting:
        return const Icon(Icons.hourglass_empty,
            color: Colors.blue, size: 24.0);
      case DeviceSubmissionState.error:
        return IconButton(
          icon: const Icon(Icons.info, color: Colors.red, size: 24.0),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Error'),
                  content: Text(
                    deviceErrors[deviceId] ?? 'Unknown error',
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Close'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      case DeviceSubmissionState.correct:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24.0);
      case DeviceSubmissionState.incorrect:
        return const Icon(Icons.cancel, color: Colors.orange, size: 24.0);
    }
  }

  void _addDevice(DetectedDevice device) {
    setState(() {
      int index = detectedDevices.length;
      detectedDevices.add(device);
      _listKey.currentState?.insertItem(index);
    });
  }

  Widget _buildItem(
      BuildContext context, int index, Animation<double> animation) {
    DetectedDevice detectedDevice = detectedDevices[index];
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      )),
      child: ListTile(
        title: Text(detectedDevice.device.platformName),
        leading: _getIconForState(
            detectedDevice.state, detectedDevice.device.remoteId.toString()),
        onTap: detectedDevice.state == DeviceSubmissionState.unsubmitted ||
                detectedDevice.state == DeviceSubmissionState.error
            ? () => submitDevice(detectedDevice)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Collector'),
      ),
      body: Column(
        children: [
          GameHeader(game: currentGame),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Progress: ${currentGame.correctAnswers}/${currentGame.totalAnswers}',
            ),
          ),
          if (isGameComplete)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Congratulations! You have completed the game.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: AnimatedList(
              key: _listKey,
              initialItemCount: detectedDevices.length,
              itemBuilder: (context, index, animation) {
                return _buildItem(context, index, animation);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isGameComplete
          ? null
          : FloatingActionButton(
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
