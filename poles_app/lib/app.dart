import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/flavors.dart';
import 'package:poles/refresh_token_interceptor.dart';
import 'package:poles/routes/login_route.dart';
import 'package:poles/routes/home_route.dart';
import 'package:poles/services/env_service.dart';
import 'package:poles/services/user_service.dart';
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
  PolesApi? _api;
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
  }

  PolesApi _buildApi(String apiRoot) {
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

    if (F.appFlavor != Flavor.production) {
      dio.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        compact: true,
      ));
    }

    return PolesApi(dio);
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
