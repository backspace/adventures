import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:waydowntown/developer_tools.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/refresh_token_interceptor.dart';
import 'package:waydowntown/routes/request_run_route.dart';
import 'package:waydowntown/widgets/regions_table.dart';
import 'package:waydowntown/widgets/session_widget.dart';

var talker = Talker();

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
      navigatorObservers: [TalkerRouteObserver(talker)],
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

    final renewalDio = Dio(BaseOptions(
      baseUrl: dotenv.env['API_ROOT']!,
    ));

    final postRenewalDio = Dio(BaseOptions(
      baseUrl: dotenv.env['API_ROOT']!,
      headers: {
        'Content-Type': 'application/vnd.api+json',
        'Accept': 'application/vnd.api+json',
      },
    ));

    TalkerDioLogger talkerDioLogger = TalkerDioLogger(
        talker: talker,
        settings: const TalkerDioLoggerSettings(
          printResponseData: true,
          printResponseHeaders: true,
          printResponseMessage: true,
          printErrorData: true,
          printErrorHeaders: true,
          printErrorMessage: true,
          printRequestData: true,
          printRequestHeaders: true,
        ));

    dio.interceptors.add(talkerDioLogger);
    renewalDio.interceptors.add(talkerDioLogger);
    postRenewalDio.interceptors.add(talkerDioLogger);

    dio.interceptors.add(RefreshTokenInterceptor(
        dio: dio, postRenewalDio: postRenewalDio, renewalDio: renewalDio));

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
                SessionWidget(dio: dio, apiBaseUrl: dotenv.env['API_ROOT']!),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      child: const Text('Regions'),
                      onPressed: () {
                        Future<void> loadRegions() async {
                          try {
                            final response =
                                await dio.get('/waydowntown/regions');
                            if (response.statusCode == 200) {
                              final regions =
                                  Region.parseRegions(response.data);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RegionsTable(
                                      dio: dio,
                                      regions: regions,
                                      secureStorage: FlutterSecureStorage(),
                                      onRefresh: () {
                                        loadRegions();
                                      }),
                                ),
                              );
                            }
                          } catch (e) {
                            talker.error('Error loading regions: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Failed to load regions')),
                            );
                          }
                        }

                        loadRegions();
                      },
                    ),
                    ElevatedButton(
                      child: const Text('Developer Tools'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DeveloperTools(dio: dio),
                          ),
                        );
                      },
                    ),
                  ],
                ),
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
