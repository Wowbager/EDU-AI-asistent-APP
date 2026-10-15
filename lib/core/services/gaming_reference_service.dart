import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../providers/core_providers.dart';
import '../util/silent_log.dart';

/// Previous valid, non-gaming reaction times per task — the reference the
/// Pilot 2 gaming rule reads (BR-H3TCRE).
///
/// The server collects them from every student's quiz answers; the quiz
/// passes a block's list to [isGamingAttempt], and GamingGuard.classify turns
/// ten or more of them into the robust median/MAD threshold. Offline, a failed
/// request or a block the server knows nothing about all come back empty,
/// which is the fixed 2 s floor — exactly the cold-start rule — so a missing
/// reference never blocks or fails an answer.
class GamingReferenceService {
  final ApiClient _api;

  GamingReferenceService(this._api);

  /// Reaction times in seconds keyed by block id, for [blockIds] (blank ids —
  /// quiz blocks without a block_id — are skipped; the server never logs them).
  Future<Map<String, List<double>>> fetch(Iterable<String> blockIds) async {
    final ids = {for (final id in blockIds) if (id.isNotEmpty) id};
    if (ids.isEmpty) return const {};

    try {
      final result = await _api.get<Map<String, dynamic>>(
        ApiEndpoints.eloGamingReference,
        queryParameters: {'block_ids': ids.join(',')},
      );
      if (result.isFailure || result.data == null) return const {};
      return _parse(result.data!['data']);
    } catch (e, st) {
      silentLog('gaming_reference_service', e, st);
      return const {};
    }
  }

  static Map<String, List<double>> _parse(Object? data) {
    if (data is! Map) return const {};
    return {
      for (final entry in data.entries)
        if (entry.key is String && entry.value is List)
          entry.key as String: [
            for (final t in entry.value as List)
              if (t is num) t.toDouble(),
          ],
    };
  }
}

final gamingReferenceServiceProvider = Provider<GamingReferenceService>(
  (ref) => GamingReferenceService(ref.watch(apiClientProvider)),
);
