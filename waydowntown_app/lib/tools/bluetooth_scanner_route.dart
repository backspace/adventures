import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:waydowntown/main.dart';

class BluetoothScannerRoute extends StatefulWidget {
  const BluetoothScannerRoute({super.key});

  @override
  BluetoothScannerRouteState createState() => BluetoothScannerRouteState();
}

class BluetoothScannerRouteState extends State<BluetoothScannerRoute> {
  var names = <String>{};
  var resultsLength = 0;
  var isScanning = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Scanner'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text('Bluetooth Scanner'),
            Text('Scan results: $resultsLength'),
            isScanning
                ? ElevatedButton(
                    child: const Text('Stop'),
                    onPressed: () {
                      FlutterBluePlus.stopScan();
                      setState(() {
                        isScanning = false;
                      });
                    })
                : ElevatedButton(
                    child: const Text('Scan'),
                    onPressed: () {
                      requestBluetooth();
                    }),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go back!'),
            ),
            names.isEmpty
                ? const Text('No devices found')
                : Column(
                    children: names.map((name) => Text(name)).toList(),
                  )
          ],
        ),
      ),
    );
  }

  Future<void> requestBluetooth() async {
    var subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        setState(() {
          resultsLength = results.length;
        });

        if (results.isNotEmpty) {
          ScanResult r = results.last;
          logger.i(
              '${r.device.remoteId}: "${r.advertisementData.advName}" found!');

          if (r.advertisementData.advName.isNotEmpty) {
            setState(() {
              names.add(r.advertisementData.advName);
            });
          }
        }
      },
      onError: (e) => logger.i(e),
    );

    FlutterBluePlus.cancelWhenScanComplete(subscription);

    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first;

    await FlutterBluePlus.startScan(
        continuousUpdates: true, removeIfGone: const Duration(seconds: 15));

    setState(() {
      isScanning = true;
    });
  }
}
