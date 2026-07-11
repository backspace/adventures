import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/flavors.dart';
import 'package:landgrab/refresh_token_interceptor.dart';
import 'package:landgrab/routes/login_route.dart';
import 'package:landgrab/routes/home_route.dart';
import 'package:landgrab/services/env_service.dart';
import 'package:landgrab/services/env_switch_service.dart';
import 'package:landgrab/services/user_service.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Env-switch unlock state is best-effort — if SharedPreferences
    // takes a moment, `visible` just flips from false → true later.
    // Not awaited before setting _ready so first paint doesn't wait.
    EnvSwitchService.load();
    EnvService.instance.initialize().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    );

    if (!_ready) {
      return MaterialApp(
        title: F.title,
        theme: theme,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return ValueListenableBuilder<String?>(
      valueListenable: EnvService.instance.currentApiRoot,
      builder: (context, root, _) {
        final apiRoot = root ?? 'http://localhost:4000';
        return MaterialApp(
          key: ValueKey(apiRoot),
          title: F.title,
          theme: theme,
          home: _Boot(apiRoot: apiRoot),
        );
      },
    );
  }
}

class _Boot extends StatefulWidget {
  final String apiRoot;
  const _Boot({required this.apiRoot});

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  LandgrabApi? _api;
  bool? _loggedIn;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    UserService.setCurrentApiRoot(widget.apiRoot);
    final api = _buildApi(widget.apiRoot);
    final loggedIn = await UserService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _api = api;
      _loggedIn = loggedIn;
    });
    // Boot telemetry: only meaningful once we know the user is
    // authenticated. Fire-and-forget so a slow / offline network
    // doesn't stall the UI. The API layer already swallows errors.
    if (loggedIn) {
      api.pingAppOpened();
    }
  }

  LandgrabApi _buildApi(String apiRoot) {
    final baseOptions = BaseOptions(
      baseUrl: apiRoot,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    final dio = Dio(baseOptions);
    final renewalDio = Dio(baseOptions);
    final postRenewalDio = Dio(baseOptions);

    dio.interceptors.add(RefreshTokenInterceptor(
      dio: dio,
      renewalDio: renewalDio,
      postRenewalDio: postRenewalDio,
    ));

    // Gate on `kDebugMode`, not flavor. In release-mode builds
    // (TestFlight, `flutter run --release`) `print` routes through
    // NSLog on iOS, and NSLog serialises big payloads very slowly —
    // pretty-printing the drafts endpoint's response can block the
    // event loop for seconds. Debug builds print via the VM service,
    // which is fast. Keeping the logger in dev / local-alpha is
    // fine; excluding it from all release builds is what we want.
    if (kDebugMode) {
      dio.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        compact: true,
      ));
    }

    return LandgrabApi(dio);
  }

  @override
  Widget build(BuildContext context) {
    final api = _api;
    if (api == null || _loggedIn == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _loggedIn!
        ? HomeRoute(api: api)
        : LoginRoute(api: api);
  }
}
