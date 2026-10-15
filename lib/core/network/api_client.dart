import 'package:dio/dio.dart';

import '../services/auth_token_storage.dart';
import '../services/session_meta.dart';
import 'api_endpoints.dart';
import 'api_interceptors.dart';
import 'oauth_api_port.dart';

/// Result wrapper for API responses.
class ApiResult<T> {
  final T? data;
  final String? error;
  final int? statusCode;

  const ApiResult._({this.data, this.error, this.statusCode});

  factory ApiResult.success(T data, {int? statusCode}) =>
      ApiResult._(data: data, statusCode: statusCode);

  factory ApiResult.failure(String error, {int? statusCode}) =>
      ApiResult._(error: error, statusCode: statusCode);

  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}

/// Configured Dio client for API communication.
class ApiClient implements OAuthApiPort {
  late final Dio _dio;
  final AuthTokenStorage _tokens;
  final SessionMeta? _session;

  /// Invoked when an authenticated request comes back 401 (token expired or
  /// revoked server-side). Set by the provider layer to trigger a full
  /// logout-to-login so the app never lingers in a half-authenticated state.
  /// Late-bound because the coordinator depends on this client.
  void Function()? onUnauthorized;

  ApiClient(
    this._tokens, {
    SessionMeta? session,
    bool enableLogging = false,
  }) : _session = session {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(LocaleInterceptor());

    // Add interceptors in order. Token rotation must come before AuthInterceptor
    // so the rotated token is attached to the in-flight request.
    final session = _session;
    if (session != null) {
      _dio.interceptors.add(TokenRotationInterceptor(
        dio: _dio,
        tokens: _tokens,
        session: session,
      ));
    }
    _dio.interceptors.add(AuthInterceptor(
      _tokens,
      onUnauthorized: () => onUnauthorized?.call(),
    ));
    _dio.interceptors.add(RetryInterceptor(_dio));

    if (enableLogging) {
      _dio.interceptors.add(LoggingInterceptor());
    }
  }

  /// Session metadata accessor for callers that need to read shared_device
  /// flag, expiry, or update activity timestamps.
  SessionMeta? get session => _session;

  /// The underlying Dio instance for direct access if needed.
  Dio get dio => _dio;

  // ═══════════════════════════════════════════════════════════════════════════
  // Generic HTTP Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Perform a GET request.
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
      );

      final data =
          fromJson != null ? fromJson(response.data) : response.data as T;

      return ApiResult.success(data, statusCode: response.statusCode);
    } on DioException catch (e) {
      return _handleError(e);
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  /// Perform a POST request.
  ///
  /// [receiveTimeout] replaces the client-wide 30s for this one call, for
  /// endpoints that legitimately take longer to answer (AI evaluation).
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
    Duration? receiveTimeout,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: receiveTimeout == null
            ? null
            : Options(receiveTimeout: receiveTimeout),
      );

      final result =
          fromJson != null ? fromJson(response.data) : response.data as T;

      return ApiResult.success(result, statusCode: response.statusCode);
    } on DioException catch (e) {
      return _handleError(e);
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  /// Convert the current shared-device session into a persistent one
  /// ("this is my device", BR-CAQQW2). Re-issues the token via the refresh
  /// endpoint with an explicit `shared_device: false`, so the server drops the
  /// shared flag and grants a 30-day token. On success the new token and
  /// session metadata are stored. The pre-login default for the device is left
  /// alone on purpose: this is consent for the *current* session, not for the
  /// machine, and carrying it over would pre-tick the opt-out for the next
  /// person on a shared PC (BR-4TASK2). Returns true on success.
  Future<bool> convertSessionToPersistent() async {
    try {
      final response = await _dio.post(
        ApiEndpoints.authRefresh,
        data: {'shared_device': false},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return false;

      final newToken = data['token'] as String?;
      if (newToken != null && newToken.isNotEmpty) {
        await _tokens.setToken(newToken);
      }
      // Genuine user action — mark active so any residual idle state is reset.
      // applyFromAuthResponse writes session_shared_device=false, which is what
      // hides the banner and stops the idle timer for this session.
      await _session?.applyFromAuthResponse(data);
      return (data['shared_device'] as bool?) == false;
    } catch (_) {
      return false;
    }
  }

  /// Perform a PUT request.
  Future<ApiResult<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
      );

      final result =
          fromJson != null ? fromJson(response.data) : response.data as T;

      return ApiResult.success(result, statusCode: response.statusCode);
    } on DioException catch (e) {
      return _handleError(e);
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  /// Perform a PATCH request.
  Future<ApiResult<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
      );

      final result =
          fromJson != null ? fromJson(response.data) : response.data as T;

      return ApiResult.success(result, statusCode: response.statusCode);
    } on DioException catch (e) {
      return _handleError(e);
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  /// Perform a DELETE request.
  Future<ApiResult<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
      );

      final result =
          fromJson != null ? fromJson(response.data) : response.data as T;

      return ApiResult.success(result, statusCode: response.statusCode);
    } on DioException catch (e) {
      return _handleError(e);
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  /// Handle Dio errors and convert to ApiResult.
  ApiResult<T> _handleError<T>(DioException e) {
    String message;
    final statusCode = e.response?.statusCode;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please check your internet connection.';
        break;
      case DioExceptionType.connectionError:
        message = 'No internet connection.';
        break;
      case DioExceptionType.badResponse:
        message = _extractErrorMessage(e.response);
        break;
      case DioExceptionType.cancel:
        message = 'Request was cancelled.';
        break;
      default:
        message = e.message ?? 'An unexpected error occurred.';
    }

    return ApiResult.failure(message, statusCode: statusCode);
  }

  /// Extract error message from response body.
  String _extractErrorMessage(Response? response) {
    if (response?.data == null) {
      return 'Server error: ${response?.statusCode}';
    }

    final data = response!.data;

    if (data is Map) {
      // Laravel validation errors.
      if (data['errors'] != null) {
        final errors = data['errors'] as Map;
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          return firstError.first.toString();
        }
      }

      // Standard error message.
      if (data['message'] != null) {
        return data['message'].toString();
      }
    }

    return 'Server error: ${response.statusCode}';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // User Profile Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update user name.
  Future<ApiResult<Map<String, dynamic>>> updateUserName(String name) {
    return put<Map<String, dynamic>>(
      ApiEndpoints.updateProfile,
      data: {'name': name},
      fromJson: (data) => data as Map<String, dynamic>,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Auth Token Management
  // ═══════════════════════════════════════════════════════════════════════════

  /// Store the auth token.
  Future<void> setAuthToken(String token) async {
    await _tokens.setToken(token);
  }

  /// Get the current auth token.
  String? getAuthToken() => _tokens.token;

  /// Clear the auth token (logout).
  Future<void> clearAuthToken() async {
    await _tokens.clearToken();
  }

  /// Check if user is authenticated.
  bool get isAuthenticated => _tokens.isAuthenticated;
}
