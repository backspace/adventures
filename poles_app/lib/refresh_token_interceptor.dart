// Adapted from https://medium.com/@dariovarrialeapps/how-to-create-a-refresh-token-interceptor-in-flutter-with-dio-64a3ab0be6fa

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:poles/services/user_service.dart';

final _log = Logger();

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
    if (options.headers.containsKey('Authorization')) {
      return handler.next(options);
    }

    final userToken = await UserService.getAccessToken();
    if (userToken != null && userToken.isNotEmpty) {
      options.headers['Authorization'] = userToken;
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    await _refreshTokenAndResolveError(err, handler);
  }

  Future<void> _refreshTokenAndResolveError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    _log.d('Refreshing token...');
    final refreshToken = await UserService.getRenewalToken();
    if (refreshToken == null) {
      return handler.next(err);
    }

    final actualRenewalDio = renewalDio ?? (Dio()..options = dio.options);

    late final Response authResponse;
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
      if (e is DioException) return handler.next(e);
      return handler.next(err);
    }

    final newAccessToken = authResponse.data['data']['access_token'];
    final newRenewalToken = authResponse.data['data']['renewal_token'];
    await UserService.setTokens(newAccessToken, newRenewalToken);

    err.requestOptions.headers['Authorization'] = newAccessToken;

    final actualPostRenewalDio = postRenewalDio ?? (Dio()..options = dio.options);
    final refreshResponse = await actualPostRenewalDio.fetch(err.requestOptions);
    handler.resolve(refreshResponse);
  }
}
