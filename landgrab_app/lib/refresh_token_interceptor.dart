// Adapted from https://medium.com/@dariovarrialeapps/how-to-create-a-refresh-token-interceptor-in-flutter-with-dio-64a3ab0be6fa

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:landgrab/services/user_service.dart';

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
      // Pow rotates the renewal token on each renew, so keep this
      // account's saved bundle in sync — otherwise switching back to it
      // later would restore an already-spent renewal token and 401.
      await UserService.rememberCurrentAccount();
      return newAccessToken;
    } on DioException catch (e) {
      // Only a genuine auth rejection (401) means the renewal token is dead
      // and the user must sign in again. A transient failure — no response,
      // timeout, connection error, or a 5xx — must NOT wipe the session: the
      // token is probably still valid, and a later request (or the home
      // screen's "Try again") can renew once connectivity returns. Clearing
      // on those was forcing needless logouts on flaky networks.
      if (e.response?.statusCode == 401) {
        await UserService.clearUserData();
      }
      return null;
    } catch (_) {
      // A non-Dio error (e.g. an unexpectedly shaped 200 body) — fail this
      // renewal without destroying the session over an ambiguous response.
      return null;
    }
  }
}
