// Adapted from https://medium.com/@dariovarrialeapps/how-to-create-a-refresh-token-interceptor-in-flutter-with-dio-64a3ab0be6fa

import 'package:dio/dio.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/services/user_service.dart';

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
    await _addTokenIfNeeded(options, handler);
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

    await _refreshTokenAndResolveError(err, handler);
  }

  /// Adds the user token to the request headers if it's not already there.
  /// If the token is not present, the request will be sent without it.
  ///
  /// If the token is present, it will be added to the headers.
  Future<void> _addTokenIfNeeded(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.headers.containsKey('Authorization')) {
      return handler.next(options);
    }

    final userToken = await UserService.getAccessToken();

    if (userToken != null && userToken.isNotEmpty) {
      options.headers['Authorization'] = userToken;
    }

    handler.next(options);
  }

  /// Refreshes the user token and retries the request.
  /// If the token refresh fails, the error will be passed to the next interceptor.
  Future<void> _refreshTokenAndResolveError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    _debugPrint('### Refreshing token... ###');
    final refreshToken = await UserService.getRenewalToken();

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
      await UserService.clearUserData();

      if (e is DioException) {
        return handler.next(e);
      }

      return handler.next(err);
    }

    _debugPrint('### Token refreshed! ###');

    final newAccessToken = authResponse.data['data']['access_token'];
    final newRenewalToken = authResponse.data['data']['renewal_token'];

    await UserService.setTokens(newAccessToken, newRenewalToken);

    err.requestOptions.headers['Authorization'] = newAccessToken;

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
    talker.debug(message);
  }
}
