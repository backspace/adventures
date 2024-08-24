import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logger/logger.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/routes/bluetooth_scanner_route.dart';
import 'package:waydowntown/routes/map_route.dart';
import 'package:waydowntown/routes/motion_sensors_route.dart';
import 'package:waydowntown/routes/request_game_route.dart';

var logger = Logger();

Future main() async {
  await dotenv.load(fileName: '.env');
  Logger.level = kDebugMode ? Level.debug : Level.warning;
  runApp(const Waydowntown());
}

class Waydowntown extends StatelessWidget {
  const Waydowntown({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'waydowntown',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF479CBE)),
        fontFamily: 'Roadgeek',
        textTheme: const TextTheme(
          displayLarge:
              TextStyle(fontSize: 12.0, fontWeight: FontWeight.normal),
        ),
        useMaterial3: true,
      ),
      home: const Home(title: 'waydowntown'),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key, required this.title});

  final String title;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    final dio = Dio(BaseOptions(
      baseUrl: dotenv.env['API_ROOT']!,
      headers: {
        'Content-Type': 'application/vnd.api+json',
        'Accept': 'application/vnd.api+json',
      },
    ));

    dio.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 90,
        logPrint: (message) {
          logger.d(message);
        }));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SvgPicture.asset("assets/images/logo.svg",
                width: 200, semanticsLabel: 'Winnipeg Walkway logo'),
            const Text("waydowntown", style: TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Request a game'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RequestGameRoute(dio: dio),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildButtonRow([
              ('Bluetooth\nCollector', 'bluetooth_collector'),
              ('Code\nCollector', 'code_collector'),
              ('Fill in the\nBlank', 'fill_in_the_blank'),
            ], (concept) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RequestGameRoute(
                    dio: dio,
                    concept: concept,
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            _buildButtonRow([
              ('Bluetooth\nScanner', 'bluetooth_scanner'),
              ('Map', 'map'),
              ('Motion\nSensors', 'motion_sensors'),
            ], (tool) {
              switch (tool) {
                case 'bluetooth_scanner':
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const BluetoothScannerRoute()));
                  break;
                case 'map':
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const MapRoute()));
                  break;
                case 'motion_sensors':
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const MotionSensorsRoute()));
                  break;
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow(
      List<(String, String)> buttons, Function(String) onPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: buttons.map((button) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
          ),
        );
      }).toList(),
    );
  }
}
