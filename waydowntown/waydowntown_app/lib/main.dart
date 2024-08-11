import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:logger/logger.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:waydowntown/routes/bluetooth_scanner_route.dart';
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
    final dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));

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
                          builder: (context) => RequestGameRoute(
                                dio: dio,
                              )));
                }),
            const SizedBox(height: 20),
            ElevatedButton(
                child: const Text('Request a bluetooth_collector game'),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => RequestGameRoute(
                                dio: dio,
                                concept: 'bluetooth_collector',
                              )));
                }),
            const SizedBox(height: 20),
            ElevatedButton(
                child: const Text('Request a fill_in_the_blank game'),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => RequestGameRoute(
                                dio: dio,
                                concept: 'fill_in_the_blank',
                              )));
                }),
            const SizedBox(height: 20),
            ElevatedButton(
                child: const Text('Bluetooth Scanner'),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const BluetoothScannerRoute()));
                }),
          ],
        ),
      ),
    );
  }
}
