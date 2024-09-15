import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/routes/request_run_route.dart';
import 'package:waydowntown/tools/auth_webview.dart';
import 'package:waydowntown/tools/bluetooth_scanner_route.dart';
import 'package:waydowntown/tools/map_route.dart';
import 'package:waydowntown/tools/motion_sensors_route.dart';

var logger = Logger();

Future main() async {
  runApp(const Waydowntown());
}

class Waydowntown extends StatelessWidget {
  const Waydowntown({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'waydowntown',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF059FC2)),
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
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SvgPicture.asset("assets/images/logo.svg",
                    width: 200, semanticsLabel: 'Winnipeg Walkway logo'),
                const Text("waydowntown",
                    style: TextStyle(color: Colors.white)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      child: const Text('Request any game'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RequestRunRoute(dio: dio),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      child: const Text('Request nearby game'),
                      onPressed: () async {
                        try {
                          Position position = await _determinePosition();
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RequestRunRoute(
                                dio: dio,
                                position:
                                    '${position.latitude},${position.longitude}',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white),
                const Text("Location-specific Games",
                    style: TextStyle(color: Colors.white)),
                _buildFlexibleButtonGrid([
                  ('Bluetooth\nCollector', 'bluetooth_collector'),
                  ('Code\nCollector', 'code_collector'),
                  ('Fill in the\nBlank', 'fill_in_the_blank'),
                  ('Food Court\nFrenzy', 'food_court_frenzy'),
                  ('String\nCollector', 'string_collector'),
                ], (concept) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RequestRunRoute(
                        dio: dio,
                        concept: concept,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                const Divider(color: Colors.white),
                const Text("Placeless Games",
                    style: TextStyle(color: Colors.white)),
                _buildFlexibleButtonGrid([
                  ('Orientation\nMemory', 'orientation_memory'),
                  ('Cardinal\nMemory', 'cardinal_memory'),
                ], (concept) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RequestRunRoute(
                        dio: dio,
                        concept: concept,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                const Divider(color: Colors.white),
                const Text("Tools", style: TextStyle(color: Colors.white)),
                _buildFlexibleButtonGrid([
                  ('Auth', 'auth_webview'),
                  ('Bluetooth\nScanner', 'bluetooth_scanner'),
                  ('Map', 'map'),
                  ('Motion\nSensors', 'motion_sensors'),
                ], (tool) {
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
                              builder: (context) =>
                                  const MotionSensorsRoute()));
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
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlexibleButtonGrid(
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

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied, we cannot request permissions.';
    }

    return await Geolocator.getCurrentPosition();
  }
}
