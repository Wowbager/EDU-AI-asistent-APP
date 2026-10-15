import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../models/avatar_model.dart';

/// The user's server-side avatar state: outfit plus inventory.
class RemoteUserAvatar {
  final Map<AvatarSlot, String> equipped;
  final Set<String> ownedCodes;
  final DateTime? updatedAt;

  const RemoteUserAvatar({
    required this.equipped,
    required this.ownedCodes,
    this.updatedAt,
  });

  factory RemoteUserAvatar.fromJson(Map<String, dynamic> json) {
    final owned = (json['owned'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toSet();

    final rawUpdatedAt = json['updated_at'] as String?;

    return RemoteUserAvatar(
      equipped: AvatarState.parseEquipped(
        (json['equipped'] as Map?)?.cast<String, dynamic>(),
      ),
      ownedCodes: owned,
      updatedAt: rawUpdatedAt == null ? null : DateTime.tryParse(rawUpdatedAt),
    );
  }
}

/// Remote data source for avatar cosmetics.
class AvatarRemoteDataSource {
  final ApiClient _apiClient;

  /// A bare client for the public R2 bucket.
  ///
  /// Deliberately *not* [ApiClient.dio]: that instance attaches our Sanctum
  /// bearer token to every request from an interceptor, which would both leak
  /// the token to a third-party host and make R2 reject the request outright —
  /// an S3-compatible endpoint tries to parse `Authorization` as a signature.
  /// Its 401 handling would then read a bucket error as an expired session and
  /// log the user out.
  final Dio _storage;

  AvatarRemoteDataSource(this._apiClient, {Dio? storageClient})
      : _storage = storageClient ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              responseType: ResponseType.plain,
            ));

  /// Fetch the cosmetics catalog.
  Future<ApiResult<List<AvatarItem>>> getCatalog() async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.avatarCatalog,
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      final itemsJson = result.data!['data'] as List<dynamic>? ?? [];

      // `fromJson` returns null for slots this build does not know — those are
      // dropped rather than failing the whole catalog, so the server can add a
      // slot before the client that renders it ships.
      final items = itemsJson
          .map((json) => AvatarItem.fromJson(json as Map<String, dynamic>))
          .whereType<AvatarItem>()
          .toList();

      return ApiResult.success(items);
    } catch (e) {
      return ApiResult.failure('Failed to parse avatar catalog: $e');
    }
  }

  /// Fetch the caller's outfit and inventory.
  Future<ApiResult<RemoteUserAvatar>> getUserAvatar() async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.userAvatar,
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      return ApiResult.success(
        RemoteUserAvatar.fromJson(result.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResult.failure('Failed to parse user avatar: $e');
    }
  }

  /// Acquire an item. Idempotent server-side, so a retry is safe.
  Future<ApiResult<RemoteUserAvatar>> purchase(String code) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.avatarPurchase(code),
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      return ApiResult.success(
        RemoteUserAvatar.fromJson(result.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResult.failure('Failed to parse user avatar: $e');
    }
  }

  /// Replace the worn outfit.
  Future<ApiResult<RemoteUserAvatar>> updateEquipped(
    Map<String, String> equipped,
  ) async {
    final result = await _apiClient.put<Map<String, dynamic>>(
      ApiEndpoints.userAvatar,
      data: {'equipped': equipped},
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      return ApiResult.success(
        RemoteUserAvatar.fromJson(result.data!['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResult.failure('Failed to parse user avatar: $e');
    }
  }

  /// Download an item's SVG markup from R2.
  ///
  /// Uses the bare [_storage] client: the URL is absolute, the response is
  /// plain text rather than the `{data: ...}` envelope every API endpoint
  /// returns, and the bucket must never see our bearer token.
  Future<ApiResult<String>> downloadSvg(String url) async {
    try {
      final response = await _storage.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );

      final body = response.data;
      if (body == null || !body.contains('<svg')) {
        return ApiResult.failure('Not an SVG: $url');
      }

      return ApiResult.success(body, statusCode: response.statusCode);
    } on DioException catch (e) {
      return ApiResult.failure(
        e.message ?? 'Failed to download $url',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }
}
