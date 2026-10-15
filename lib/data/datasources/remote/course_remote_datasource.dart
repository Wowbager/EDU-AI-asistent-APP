import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// Remote course data from the API.
/// For listings, only metadata is included (data is null).
/// Full data is available via download endpoint.
class RemoteCourse {
  final int id;
  final String courseId;
  final String name;
  final int version;
  final String status;
  final String language;
  final String? description;
  final String? author;
  final String? emoji;
  final int lessonCount;
  final int estimatedMinutes;
  final int? fileSize;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime updatedAt;

  RemoteCourse({
    required this.id,
    required this.courseId,
    required this.name,
    required this.version,
    required this.status,
    required this.language,
    this.description,
    this.author,
    this.emoji,
    this.lessonCount = 0,
    this.estimatedMinutes = 0,
    this.fileSize,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteCourse.fromJson(Map<String, dynamic> json) {
    // Build data map from metadata for local storage compatibility
    // This allows Knihovna to display courses without full download
    final dataFromJson = json['data'] as Map<String, dynamic>?;
    final data = dataFromJson ?? {
      'emoji': json['emoji'],
      'description': json['description'],
      'author': json['author'],
      'only_once': json['only_once'],
      'private': json['private'],
      'logged_only': json['logged_only'],
      'quiz_evaluate': json['quiz_evaluate'],
      'only_quiz': json['only_quiz'],
      'starts_with_quiz': json['starts_with_quiz'],
      'open_all_lessons': json['open_all_lessons'],
      // Carry denormalized listing metadata so the library card can show
      // duration/lesson count for not-yet-downloaded courses (the full
      // lessons+blocks data only arrives on download).
      'lesson_count': json['lesson_count'],
      'estimated_minutes': json['estimated_minutes'],
      // The course cover set in admin. Served as its own listing field
      // (the full JSON only arrives on download), so a library card can
      // show it before the course is downloaded (BR-YKYXC6).
      'header_image': json['header_image'],
      'lessons': List.generate(
        json['lesson_count'] as int? ?? 0,
        (i) => {'lesson_id': 'L${i + 1}'},
      ),
    };

    return RemoteCourse(
      id: json['id'] as int,
      courseId: json['course_id'] as String,
      name: json['name'] as String,
      version: json['version'] as int? ?? 1,
      status: json['status'] as String? ?? 'published',
      language: json['language'] as String? ?? 'en',
      description: json['description'] as String?,
      author: json['author'] as String?,
      emoji: json['emoji'] as String?,
      lessonCount: json['lesson_count'] as int? ?? 0,
      estimatedMinutes: json['estimated_minutes'] as int? ?? 0,
      fileSize: json['file_size'] as int?,
      data: data,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'name': name,
      'version': version,
      'status': status,
      'language': language,
      'description': description,
      'author': author,
      'emoji': emoji,
      'lesson_count': lessonCount,
      'estimated_minutes': estimatedMinutes,
      'file_size': fileSize,
      'data': data,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Result from checking for course updates.
class CourseUpdatesResult {
  final List<RemoteCourse> updatedCourses;
  final List<int> deletedCourseIds;
  final DateTime serverTime;

  CourseUpdatesResult({
    required this.updatedCourses,
    required this.deletedCourseIds,
    required this.serverTime,
  });
}

/// Remote data source for courses using the API.
class CourseRemoteDataSource {
  final ApiClient _apiClient;

  CourseRemoteDataSource(this._apiClient);

  /// Fetch all courses from the API.
  Future<ApiResult<List<RemoteCourse>>> getAllCourses() async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.courses,
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      final coursesJson = result.data!['data'] as List<dynamic>? ??
          result.data!['courses'] as List<dynamic>? ??
          [];

      final courses = coursesJson
          .map((json) => RemoteCourse.fromJson(json as Map<String, dynamic>))
          .toList();

      return ApiResult.success(courses);
    } catch (e) {
      return ApiResult.failure('Failed to parse courses: $e');
    }
  }

  /// Fetch a single course by server ID.
  Future<ApiResult<RemoteCourse>> getCourse(int id) async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.course(id),
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      final courseJson = result.data!['data'] as Map<String, dynamic>? ??
          result.data!;

      return ApiResult.success(RemoteCourse.fromJson(courseJson));
    } catch (e) {
      return ApiResult.failure('Failed to parse course: $e');
    }
  }

  /// Lookup a course by its unique access code.
  /// Returns 404 if course not found or not published.
  Future<ApiResult<RemoteCourse>> findCourseByCode(String code) async {
    // Normalize code: uppercase, trim whitespace
    final normalizedCode = code.toUpperCase().trim();

    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.courseByCode(normalizedCode),
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      final courseJson = result.data!['data'] as Map<String, dynamic>? ??
          result.data!;

      return ApiResult.success(RemoteCourse.fromJson(courseJson));
    } catch (e) {
      return ApiResult.failure('Failed to parse course: $e');
    }
  }

  /// Create a new course on the server.
  Future<ApiResult<RemoteCourse>> createCourse({
    required String courseId,
    required String name,
    required int version,
    required String status,
    required String language,
    required Map<String, dynamic> data,
  }) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.courses,
      data: {
        'course_id': courseId,
        'name': name,
        'version': version,
        'status': status,
        'language': language,
        'data': data,
      },
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      final courseJson = result.data!['data'] as Map<String, dynamic>? ??
          result.data!;

      return ApiResult.success(RemoteCourse.fromJson(courseJson));
    } catch (e) {
      return ApiResult.failure('Failed to parse created course: $e');
    }
  }

  /// Update an existing course on the server.
  Future<ApiResult<RemoteCourse>> updateCourse({
    required int id,
    String? courseId,
    String? name,
    int? version,
    String? status,
    String? language,
    Map<String, dynamic>? data,
  }) async {
    final updateData = <String, dynamic>{};

    if (courseId != null) updateData['course_id'] = courseId;
    if (name != null) updateData['name'] = name;
    if (version != null) updateData['version'] = version;
    if (status != null) updateData['status'] = status;
    if (language != null) updateData['language'] = language;
    if (data != null) updateData['data'] = data;

    final result = await _apiClient.put<Map<String, dynamic>>(
      ApiEndpoints.course(id),
      data: updateData,
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      final courseJson = result.data!['data'] as Map<String, dynamic>? ??
          result.data!;

      return ApiResult.success(RemoteCourse.fromJson(courseJson));
    } catch (e) {
      return ApiResult.failure('Failed to parse updated course: $e');
    }
  }

  /// Delete a course on the server (soft delete).
  Future<ApiResult<bool>> deleteCourse(int id) async {
    final result = await _apiClient.delete<Map<String, dynamic>>(
      ApiEndpoints.course(id),
    );

    if (result.isFailure && result.statusCode != 404) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    // Success or already deleted (404).
    return ApiResult.success(true);
  }

  /// Check for course updates since a given timestamp.
  Future<ApiResult<CourseUpdatesResult>> checkUpdates({
    DateTime? since,
  }) async {
    final queryParams = <String, dynamic>{};
    if (since != null) {
      queryParams['since'] = since.toIso8601String();
    }

    final result = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.coursesCheckUpdates,
      queryParameters: queryParams,
    );

    if (result.isFailure) {
      return ApiResult.failure(result.error!, statusCode: result.statusCode);
    }

    try {
      final data = result.data!;

      final updatedCoursesJson = data['courses'] as List<dynamic>? ?? [];
      final updatedCourses = updatedCoursesJson
          .map((json) => RemoteCourse.fromJson(json as Map<String, dynamic>))
          .toList();

      final deletedIds = (data['deleted_ids'] as List<dynamic>?)
              ?.map((id) => id as int)
              .toList() ??
          [];

      final serverTime = data['server_time'] != null
          ? DateTime.parse(data['server_time'] as String)
          : DateTime.now();

      return ApiResult.success(
        CourseUpdatesResult(
          updatedCourses: updatedCourses,
          deletedCourseIds: deletedIds,
          serverTime: serverTime,
        ),
      );
    } catch (e) {
      return ApiResult.failure('Failed to parse updates: $e');
    }
  }

  /// Download full course JSON from R2 storage.
  /// Returns the complete course data including lessons with names.
  ///
  /// On web: requests inline JSON from the API (avoids CORS with R2).
  /// On native: fetches a signed R2 URL and downloads directly (faster).
  Future<ApiResult<Map<String, dynamic>>> downloadCourseJson(int serverId) async {

    // On web, request inline JSON to avoid CORS issues with R2 signed URLs.
    final queryParams = kIsWeb ? {'inline': 'true'} : null;

    // Step 1: Get download URL (or inline JSON on web) from API
    final urlResult = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.courseDownload(serverId),
      queryParameters: queryParams,
    );

    if (urlResult.isFailure) {
      return ApiResult.failure(
        urlResult.error ?? 'Failed to get download URL',
        statusCode: urlResult.statusCode,
      );
    }

    try {
      final responseData = urlResult.data!;
      final dataWrapper = responseData['data'] as Map<String, dynamic>?;

      // Check if API returned inline course data (web mode).
      final inlineCourseData = dataWrapper?['course_data'] as Map<String, dynamic>?
          ?? responseData['course_data'] as Map<String, dynamic>?;
      if (inlineCourseData != null) {
        return ApiResult.success(inlineCourseData);
      }

      // Otherwise, use the signed download URL (native platforms).
      final downloadUrl = (dataWrapper?['download_url'] ?? responseData['download_url']) as String?;
      if (downloadUrl == null) {
        return ApiResult.failure('No download URL or inline data in response');
      }

      // Step 2: Fetch full JSON from R2 using the signed URL
      final dio = Dio();
      final response = await dio.get(downloadUrl);

      Map<String, dynamic> jsonData;
      if (response.data is String) {
        jsonData = jsonDecode(response.data as String) as Map<String, dynamic>;
      } else if (response.data is Map<String, dynamic>) {
        jsonData = response.data as Map<String, dynamic>;
      } else {
        return ApiResult.failure('Unexpected response type from storage');
      }

      return ApiResult.success(jsonData);
    } catch (e, stack) {
      return ApiResult.failure('Failed to download course: $e');
    }
  }

}
