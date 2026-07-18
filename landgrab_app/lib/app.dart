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
    // Dark theme to match the (dark) registrations site. The map layers
    // deliberately stay on the light Positron basemap — dark basemaps
    // wash out in sunlight, and an outdoor game needs a legible map — so
    // only the app chrome is dark, not the map itself.
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        // landgrab-river from the registrations site palette.
        seedColor: const Color(0xFF2D6A9F),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      // Anton is the site wordmark's display face; app bar titles
      // carry the branding in-app. Display-only — body text stays on
      // the default face for legibility. Bone echoes the site wordmark.
      appBarTheme: const AppBarTheme(
        titleTextStyle: TextStyle(
          fontFamily: 'Anton',
          fontSize: 22,
          color: Color(0xFFECE4D3),
        ),
      ),
    );

    if (!_ready) {
      return MaterialApp(
        title: F.title,
        theme: theme,
        builder: _flavorBanner,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return ListenableBuilder(
      // Env change (new api root) or an in-place account swap (bumped
      // sessionEpoch) both re-key the MaterialApp, forcing a fresh _Boot
      // that re-reads the active session.
      listenable: Listenable.merge([
        EnvService.instance.currentApiRoot,
        EnvService.instance.sessionEpoch,
      ]),
      builder: (context, _) {
        final apiRoot =
            EnvService.instance.currentApiRoot.value ?? 'http://localhost:4000';
        final epoch = EnvService.instance.sessionEpoch.value;
        return MaterialApp(
          key: ValueKey('$apiRoot#$epoch'),
          title: F.title,
          theme: theme,
          builder: _flavorBanner,
          home: _Boot(apiRoot: apiRoot),
        );
      },
    );
  }
}

/// Wraps every screen in a corner ribbon on any non-production build, so a
/// staging/dev build — e.g. the `alpha` (staging) build if it's ever handed
/// to external testers instead of the `beta` production build — is obvious at
/// a glance and can't masquerade as the real attendee app. The production
/// flavor (the attendee build) shows nothing.
Widget _flavorBanner(BuildContext context, Widget? child) {
  final content = child ?? const SizedBox.shrink();
  if (F.appFlavor == Flavor.production) return content;
  return Banner(
    message: F.name.toUpperCase(),
    location: BannerLocation.topEnd,
    color: const Color(0xFFB00020),
    child: content,
  );
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
