// Adapted from https://medium.com/@dariovarrialeapps/how-to-create-a-refresh-token-interceptor-in-flutter-with-dio-64a3ab0be6fa

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:poles/services/user_service.dart';

final _log = Logger();

class RefreshTokenInterceptor extends InterceptorsWrapper {
  final Dio dio;
  final Dio? renewalDio;
  final Dio? postRenewalDio;

  // Single-flight lock: when a renewal is already in progress, concurrent
  // 401s await the same future instead of each POSTing to /session/renew
  // with the soon-to-be-rotated refresh token.
  Future<String?>? _inFlightRenewal;

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

    final newAccessToken = await _renewOnce();
    if (newAccessToken == null) {
      return handler.next(err);
    }

    err.requestOptions.headers['Authorization'] = newAccessToken;
    final retryDio = postRenewalDio ?? (Dio()..options = dio.options);
    try {
      final response = await retryDio.fetch(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }

  /// Returns the new access token, or null if renewal failed. Concurrent
  /// callers share a single in-flight renewal so the renewal token (which
  /// Pow rotates on every successful renew) is only spent once.
  Future<String?> _renewOnce() {
    final inFlight = _inFlightRenewal;
    if (inFlight != null) return inFlight;

    final future = _doRenew();
    _inFlightRenewal = future;
    future.whenComplete(() => _inFlightRenewal = null);
    return future;
  }

  Future<String?> _doRenew() async {
    _log.d('Refreshing token...');
    final refreshToken = await UserService.getRenewalToken();
    if (refreshToken == null) return null;

    final renewDio = renewalDio ?? (Dio()..options = dio.options);
    try {
      final authResponse = await renewDio.post(
        '/powapi/session/renew',
        options: Options(headers: {
          'Authorization': refreshToken,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        }),
      );
      final newAccessToken = authResponse.data['data']['access_token'] as String;
      final newRenewalToken = authResponse.data['data']['renewal_token'] as String;
      await UserService.setTokens(newAccessToken, newRenewalToken);
      return newAccessToken;
    } catch (_) {
      await UserService.clearUserData();
      return null;
    }
  }
}
