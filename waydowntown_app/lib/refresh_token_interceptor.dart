// Adapted from https://medium.com/@dariovarrialeapps/how-to-create-a-refresh-token-interceptor-in-flutter-with-dio-64a3ab0be6fa

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RefreshTokenInterceptor extends InterceptorsWrapper {
  final Dio dio;
  final Dio? renewalDio;
  final Dio? postRenewalDio;

  RefreshTokenInterceptor({
    required this.dio,
    this.renewalDio,
    this.postRenewalDio,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    _addTokenIfNeeded(options, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    _debugPrint('### Error: ${err.response?.statusCode} ###');
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    _refreshTokenAndResolveError(err, handler);
  }

  /// Adds the user token to the request headers if it's not already there.
  /// If the token is not present, the request will be sent without it.
  ///
  /// If the token is present, it will be added to the headers.
  void _addTokenIfNeeded(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.headers.containsKey('Authorization')) {
      return handler.next(options);
    }

    final prefs = await SharedPreferences.getInstance();
    final userToken = prefs.getString('access_token');

    if (userToken != null && userToken.isNotEmpty) {
      options.headers['Authorization'] = userToken;
    }

    handler.next(options);
  }

  /// Refreshes the user token and retries the request.
  /// If the token refresh fails, the error will be passed to the next interceptor.
  void _refreshTokenAndResolveError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    _debugPrint('### Refreshing token... ###');
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('renewal_token');

    if (refreshToken == null) {
      return handler.next(err);
    }

    late final Response authResponse;

    Dio actualRenewalDio;

    if (renewalDio == null) {
      actualRenewalDio = Dio();
      actualRenewalDio.options = dio.options;
      print('renewal dio options: ${actualRenewalDio.options.baseUrl}');
    } else {
      print("using provided renewal dio");
      actualRenewalDio = renewalDio!;
    }

    print("headers");
    print({
      'Authorization': refreshToken,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    });

    try {
      authResponse = await actualRenewalDio.post(
        '/powapi/session/renew',
        options: Options(headers: {
          'Authorization': refreshToken,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        }),
      );
    } catch (e) {
      prefs.remove('access_token');
      prefs.remove('renewal_token');

      if (e is DioException) {
        return handler.next(e);
      }

      return handler.next(err);
    }

    _debugPrint('### Token refreshed! ###');

    await prefs.setString(
        'access_token', authResponse.data['data']['access_token']);
    await prefs.setString(
        'renewal_token', authResponse.data['data']['renewal_token']);

    err.requestOptions.headers['Authorization'] =
        '${authResponse.data['data']['access_token']}';

    Dio actualPostRenewalDio;

    if (postRenewalDio == null) {
      actualPostRenewalDio = Dio();
      actualPostRenewalDio.options = dio.options;
    } else {
      actualPostRenewalDio = postRenewalDio!;
    }

    final refreshResponse =
        await actualPostRenewalDio.fetch(err.requestOptions);
    return handler.resolve(refreshResponse);
  }

  void _debugPrint(String message) {
    if (kDebugMode) {
      print(message);
    }
  }
}
