import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/flavors.dart';
import 'package:poles/refresh_token_interceptor.dart';
import 'package:poles/routes/login_route.dart';
import 'package:poles/routes/home_route.dart';
import 'package:poles/services/user_service.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final apiRoot = dotenv.maybeGet('API_ROOT') ?? 'http://localhost:4000';

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

    if (F.appFlavor == Flavor.local) {
      dio.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        compact: true,
      ));
    }

    final api = PolesApi(dio);

    return MaterialApp(
      title: F.title,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: _Boot(api: api),
    );
  }
}

class _Boot extends StatefulWidget {
  final PolesApi api;
  const _Boot({required this.api});

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  bool? _loggedIn;

  @override
  void initState() {
    super.initState();
    UserService.isLoggedIn().then((v) {
      if (mounted) setState(() => _loggedIn = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedIn == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _loggedIn!
        ? HomeRoute(api: widget.api)
        : LoginRoute(api: widget.api);
  }
}
