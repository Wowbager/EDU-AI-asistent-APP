import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../models/mini_game_model.dart';

/// Remote data source for mini games ("Minihry").
class MiniGamesRemoteDataSource {
  final ApiClient _apiClient;

  MiniGamesRemoteDataSource(this._apiClient);

  /// Fetch the listing plus the level the entitlement was evaluated against.
  Future<ApiResult<MiniGameList>> getMiniGames() async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.miniGames,
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      final itemsJson = result.data!['data'] as List<dynamic>? ?? [];
      final items = itemsJson
          .map((json) => MiniGame.fromJson(json as Map<String, dynamic>))
          .toList();

      final meta = result.data!['meta'] as Map<String, dynamic>?;

      return ApiResult.success(MiniGameList(
        items: items,
        level: meta?['level'] as int? ?? 1,
      ));
    } catch (e) {
      return ApiResult.failure('Failed to parse mini games: $e');
    }
  }

  /// Spend an attempt and start the cooldown.
  ///
  /// A 409 means the server refused: the client's snapshot was stale. The
  /// refreshed entitlement comes back in the body either way.
  Future<ApiResult<MiniGameRun>> play(String code) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.miniGamePlay(code),
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      final itemJson = result.data!['data'] as Map<String, dynamic>;
      return ApiResult.success(MiniGameRun(
        game: MiniGame.fromJson(itemJson),
        playId: itemJson['play_id'] as int?,
      ));
    } catch (e) {
      return ApiResult.failure('Failed to parse mini game: $e');
    }
  }

  /// Report the final score of a finished run.
  ///
  /// Separate from [play] because [play] is what spends the attempt — reporting
  /// a score through it would cost the user a second one.
  Future<ApiResult<void>> submitScore(int playId, int score, int coins) async {
    final result = await _apiClient.patch<Map<String, dynamic>>(
      ApiEndpoints.miniGamePlayScore(playId),
      data: {'score': score, 'coins': coins},
    );

    return result.isFailure
        ? ApiResult.failure(result.error!, statusCode: result.statusCode)
        : ApiResult.success(null);
  }
}
