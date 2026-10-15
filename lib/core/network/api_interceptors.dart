import 'dart:async';

import 'package:dio/dio.dart';

import '../services/auth_token_storage.dart';
import '../services/session_meta.dart';
import '../strings/locale_manager.dart';
import 'api_endpoints.dart';

/// Keys for storing auth data.
class AuthStorageKeys {
  AuthStorageKeys._();

  static const String token = 'auth_token';
  static const String userId = 'user_id';
}

/// Interceptor that adds the Bearer token to authenticated requests.
/// Tags every request with the UI language so the backend can answer in it.
///
/// Read per request rather than baked into `BaseOptions.headers`, because the
/// user can switch language at any time and the `Dio` instance outlives that
/// change. Today the backend only uses this for the verification e-mail.
class LocaleInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Accept-Language'] = LocaleManager.current.code;
    handler.next(options);
  }
}

class AuthInterceptor extends Interceptor {
  final AuthTokenStorage _tokens;

  /// Called when an *authenticated* request 401s, so the app can perform a
  /// full logout-to-login. Null-safe; wired from the provider layer.
  final void Function()? _onUnauthorized;

  AuthInterceptor(this._tokens, {void Function()? onUnauthorized})
      : _onUnauthorized = onUnauthorized;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokens.token;

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    options.headers['Accept'] = 'application/json';

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 401 → token expired or revoked; clear local copy.
    if (err.response?.statusCode == 401) {
      _tokens.clearToken();

      // Escalate to a full logout only when the failed request actually carried
      // our bearer token (an authenticated session went invalid) and it wasn't
      // the logout call itself. Unauthenticated endpoints (login, guest
      // register, resolve-code) legitimately 401 on bad input and must not wipe
      // the app.
      final sentAuth = err.requestOptions.headers.containsKey('Authorization');
      final isLogout = err.requestOptions.path.endsWith(ApiEndpoints.logout);
      if (sentAuth && !isLogout) {
        _onUnauthorized?.call();
      }
    }

    handler.next(err);
  }
}

/// Rotates the access token before it expires for shared-device sessions
/// (and persistent sessions, which simply rotate before the 30-day mark).
///
/// Triggered by [SessionMeta.needsRotation]. Concurrent requests share a
/// single in-flight rotate via [_rotating] so we don't spam /api/auth/refresh.
/// A 401 from /api/auth/refresh terminates the session — handled upstream
/// by the existing AuthInterceptor onError clearing the token.
class TokenRotationInterceptor extends Interceptor {
  final Dio _dio;
  final AuthTokenStorage _tokens;
  final SessionMeta _session;
  Future<void>? _rotating;

  TokenRotationInterceptor({
    required Dio dio,
    required AuthTokenStorage tokens,
    required SessionMeta session,
  })  : _dio = dio,
        _tokens = tokens,
        _session = session;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Never rotate while calling rotate (avoid recursion) or when not authed.
    final isRotateCall = options.path.endsWith(ApiEndpoints.authRefresh);
    final isLogoutCall = options.path.endsWith(ApiEndpoints.logout);

    if (!isRotateCall && !isLogoutCall && (_tokens.token ?? '').isNotEmpty) {
      // NOTE: do NOT touch activity here. This interceptor fires on every
      // app-issued request, including automated background traffic (periodic
      // SyncService, connectivity-triggered syncs, token rotation). Counting
      // those as activity keeps resetting the idle clock so the 15-minute
      // shared-device inactivity logout never fires (BR-9SAH2R). Genuine user
      // activity is tracked by InactivityWatcher's pointer listener.
      if (_session.needsRotation()) {
        try {
          await _ensureRotated();
        } catch (_) {
          // Rotation failed — let the original request fly. If token is
          // truly dead the server will 401 and AuthInterceptor clears it.
        }
      }
    }

    handler.next(options);
  }

  Future<void> _ensureRotated() {
    return _rotating ??= _doRotate().whenComplete(() => _rotating = null);
  }

  Future<void> _doRotate() async {
    final response = await _dio.post(ApiEndpoints.authRefresh);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final newToken = data['token'] as String?;
      if (newToken != null && newToken.isNotEmpty) {
        await _tokens.setToken(newToken);
      }
      // Rotation is automated, not user activity — don't reset the idle clock.
      await _session.applyFromAuthResponse(data, markActive: false);
    }
  }
}

/// Interceptor for logging requests and responses (debug mode).
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}

/// Interceptor that handles retry logic for transient failures.
class RetryInterceptor extends Interceptor {
  final Dio _dio;
  final int _maxRetries;

  RetryInterceptor(this._dio, {int maxRetries = 1}) : _maxRetries = maxRetries;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = (err.requestOptions.extra['retryCount'] as int?) ?? 0;

    final shouldRetry = _isRetryable(err.requestOptions) &&
        _isRetryableError(err) &&
        retryCount < _maxRetries;

    if (shouldRetry) {
      final delay = Duration(milliseconds: 1000 * (retryCount + 1));
      await Future.delayed(delay);

      final options = err.requestOptions;
      options.extra['retryCount'] = retryCount + 1;

      try {
        final response = await _dio.fetch(options);
        handler.resolve(response);
        return;
      } catch (_) {
        // Fall through.
      }
    }

    handler.next(err);
  }

  /// Only auto-retry idempotent requests. Retrying a POST/PUT/PATCH/DELETE that
  /// timed out is unsafe: the server may have already processed the first call,
  /// so a blind resend duplicates the side effect. This bit chat messages
  /// (BR-NT8CEC) — the slow first-message POST timed out client-side, got
  /// resent, and the server created a second user+assistant pair, surfacing as
  /// the block context appearing twice. GET/HEAD carry no side effects, so the
  /// sync/read traffic that actually benefits from retries is unaffected.
  bool _isRetryable(RequestOptions options) {
    final method = options.method.toUpperCase();
    return method == 'GET' || method == 'HEAD';
  }

  bool _isRetryableError(DioException err) {
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      return true;
    }

    final statusCode = err.response?.statusCode;
    return statusCode != null && statusCode >= 500 && statusCode < 600;
  }
}
