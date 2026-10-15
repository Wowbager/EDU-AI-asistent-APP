import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../providers/core_providers.dart';

/// A class the student is (or is about to be) a member of.
class ClassroomSummary {
  final int id;
  final String name;

  const ClassroomSummary({required this.id, required this.name});

  factory ClassroomSummary.fromJson(Map<String, dynamic> json) =>
      ClassroomSummary(
        id: (json['id'] as num).toInt(),
        name: (json['name'] as String?) ?? '',
      );

  static List<ClassroomSummary> listFromJson(dynamic json) => (json as List?)
          ?.whereType<Map>()
          .map((m) => ClassroomSummary.fromJson(m.cast<String, dynamic>()))
          .toList() ??
      const [];
}

/// What a student code would join — the dry run behind the confirmation
/// dialog. [studentName] is the name the teacher typed on the roster.
class ClassroomLookup {
  final ClassroomSummary classroom;
  final String? studentName;

  const ClassroomLookup({required this.classroom, this.studentName});
}

/// Result of a successful join: the class just joined plus the full list.
class ClassroomJoined {
  final ClassroomSummary classroom;
  final List<ClassroomSummary> classrooms;

  const ClassroomJoined({required this.classroom, required this.classrooms});
}

/// Join a class by the student code a teacher handed out (BR-3V2P22).
///
/// Server-side a student code is the login code of a placeholder account on
/// the teacher's roster, so joining = folding that placeholder into the
/// account the student already uses. The API does all of that; this class
/// is a thin, typed wrapper over the three endpoints. Every failure comes
/// back as [ApiResult.failure] whose `error` is the server's client-facing
/// message (Czech copy from ClassroomJoinService on the API) and whose
/// `statusCode` tells callers apart: 404 = not a student code at all.
class ClassroomJoinService {
  final ApiClient _api;

  ClassroomJoinService(this._api);

  Future<ApiResult<List<ClassroomSummary>>> myClassrooms() async {
    final result = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.userClassrooms,
      fromJson: (data) => data as Map<String, dynamic>,
    );
    if (result.isFailure || result.data == null) {
      return ApiResult.failure(result.error ?? 'Unknown error',
          statusCode: result.statusCode);
    }
    return ApiResult.success(
      ClassroomSummary.listFromJson(result.data!['data']),
      statusCode: result.statusCode,
    );
  }

  Future<ApiResult<ClassroomLookup>> lookup(String code) async {
    final result = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.userClassroomsLookup,
      data: {'code': _normalize(code)},
      fromJson: (data) => data as Map<String, dynamic>,
    );
    if (result.isFailure || result.data == null) {
      return ApiResult.failure(result.error ?? 'Unknown error',
          statusCode: result.statusCode);
    }
    final data = result.data!['data'] as Map<String, dynamic>? ?? const {};
    final classroomJson = data['classroom'] as Map<String, dynamic>?;
    if (classroomJson == null) {
      return ApiResult.failure('Malformed lookup response',
          statusCode: result.statusCode);
    }
    return ApiResult.success(
      ClassroomLookup(
        classroom: ClassroomSummary.fromJson(classroomJson),
        studentName: data['student_name'] as String?,
      ),
      statusCode: result.statusCode,
    );
  }

  Future<ApiResult<ClassroomJoined>> join(String code) async {
    final result = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.userClassroomsJoin,
      data: {'code': _normalize(code)},
      fromJson: (data) => data as Map<String, dynamic>,
    );
    if (result.isFailure || result.data == null) {
      return ApiResult.failure(result.error ?? 'Unknown error',
          statusCode: result.statusCode);
    }
    final data = result.data!['data'] as Map<String, dynamic>? ?? const {};
    final classroomJson = data['classroom'] as Map<String, dynamic>?;
    if (classroomJson == null) {
      return ApiResult.failure('Malformed join response',
          statusCode: result.statusCode);
    }
    return ApiResult.success(
      ClassroomJoined(
        classroom: ClassroomSummary.fromJson(classroomJson),
        classrooms: ClassroomSummary.listFromJson(data['classrooms']),
      ),
      statusCode: result.statusCode,
    );
  }

  /// Same canonical form the API applies (uppercase, trimmed); the server
  /// additionally folds Crockford confusables, so nothing more is done here.
  static String _normalize(String code) => code.trim().toUpperCase();
}

final classroomJoinServiceProvider = Provider<ClassroomJoinService>(
  (ref) => ClassroomJoinService(ref.watch(apiClientProvider)),
);
