import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// Repository for email validation operations.
/// Handles API calls for email verification flow and local database updates.
class EmailValidationRepository {
  final ApiClient _apiClient;
  final AppDatabase _database;

  EmailValidationRepository({
    required ApiClient apiClient,
    required AppDatabase database,
  })  : _apiClient = apiClient,
        _database = database;

  /// Check if an email already exists in the system.
  /// Returns true if the email exists, false otherwise.
  Future<ApiResult<bool>> checkEmailExists(String email) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.emailCheck,
      data: {'email': email},
    );

    if (result.isSuccess && result.data != null) {
      final exists = result.data!['exists'] as bool? ?? false;
      return ApiResult.success(exists);
    }

    return ApiResult.failure(result.error ?? 'Failed to check email');
  }

  /// Send a verification code to the specified email.
  /// Returns success if the code was sent.
  Future<ApiResult<SendCodeResponse>> sendVerificationCode(String email) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.emailSendCode,
      data: {'email': email},
    );

    if (result.isSuccess && result.data != null) {
      final sent = result.data!['sent'] as bool? ?? false;
      final expiresIn = result.data!['expires_in'] as int? ?? 600;

      if (sent) {
        return ApiResult.success(SendCodeResponse(
          sent: true,
          expiresIn: expiresIn,
        ));
      }

      return ApiResult.failure('Failed to send verification code');
    }

    return ApiResult.failure(result.error ?? 'Failed to send verification code');
  }

  /// Verify the code sent to the email.
  /// Returns true if the code is valid.
  Future<ApiResult<VerifyCodeResponse>> verifyCode(
    String email,
    String code, {
    bool sharedDevice = false,
  }) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.emailVerify,
      data: {
        'email': email,
        'code': code,
        'shared_device': sharedDevice,
      },
    );

    // Debug: Log raw API response

    if (result.isSuccess && result.data != null) {
      final valid = result.data!['valid'] as bool? ?? false;
      final token = result.data!['token'] as String?;

      return ApiResult.success(VerifyCodeResponse(
        valid: valid,
        token: token,
        sharedDevice: result.data!['shared_device'] as bool?,
        expiresAt: result.data!['expires_at'] as String?,
        sessionStartedAt: result.data!['session_started_at'] as String?,
      ));
    }

    // Parse specific error types from the response
    final errorMessage = result.error ?? 'Failed to verify code';

    if (result.statusCode == 400) {
      return ApiResult.failure('invalid_code');
    } else if (result.statusCode == 410) {
      return ApiResult.failure('code_expired');
    } else if (result.statusCode == 429) {
      return ApiResult.failure('rate_limited');
    }

    return ApiResult.failure(errorMessage);
  }

  /// Register or sync a user after email verification.
  /// This endpoint doesn't require a password - email verification acts as auth.
  Future<ApiResult<RegisterVerifiedResponse>> registerVerified({
    required String email,
    required String name,
    int? avatarIndex,
    List<String>? selectedSubjects,
    bool sharedDevice = false,
  }) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.registerVerified,
      data: {
        'email': email,
        'name': name,
        'shared_device': sharedDevice,
        if (avatarIndex != null) 'avatar_index': avatarIndex,
        if (selectedSubjects != null) 'selected_subjects': selectedSubjects,
      },
    );

    if (result.isSuccess && result.data != null) {
      final success = result.data!['success'] as bool? ?? false;

      if (success) {
        return ApiResult.success(RegisterVerifiedResponse.fromJson(result.data!));
      }

      final error = result.data!['error'] as String? ?? 'unknown_error';
      return ApiResult.failure(error);
    }

    // Handle specific error cases
    if (result.statusCode == 403) {
      return ApiResult.failure('email_not_verified');
    }

    return ApiResult.failure(result.error ?? 'Failed to register');
  }

  /// Mark a user's email as validated in the local database.
  Future<void> markEmailValidated(String userId) async {
    await _database.markEmailValidated(userId);
  }

  /// Get the current active user's email validation status.
  Future<bool> isCurrentUserEmailValidated() async {
    final user = await _database.getActiveUser();
    return user?.isEmailValidated ?? false;
  }
}

/// Response model for sending verification code.
class SendCodeResponse {
  final bool sent;
  final int expiresIn;

  const SendCodeResponse({
    required this.sent,
    required this.expiresIn,
  });
}

/// Response model for verifying code.
class VerifyCodeResponse {
  final bool valid;
  final String? token;
  final bool? sharedDevice;
  final String? expiresAt;
  final String? sessionStartedAt;

  const VerifyCodeResponse({
    required this.valid,
    this.token,
    this.sharedDevice,
    this.expiresAt,
    this.sessionStartedAt,
  });

  /// Shape that matches what [SessionMeta.applyFromAuthResponse] expects.
  Map<String, dynamic> sessionPayload() => {
        'shared_device': sharedDevice ?? false,
        'expires_at': expiresAt,
        'session_started_at': sessionStartedAt,
      };
}

/// Response model for register-verified endpoint.
class RegisterVerifiedResponse {
  final bool isNewUser;
  final RegisteredUser user;
  final String token;
  final bool? sharedDevice;
  final String? expiresAt;
  final String? sessionStartedAt;

  const RegisterVerifiedResponse({
    required this.isNewUser,
    required this.user,
    required this.token,
    this.sharedDevice,
    this.expiresAt,
    this.sessionStartedAt,
  });

  factory RegisterVerifiedResponse.fromJson(Map<String, dynamic> json) {
    return RegisterVerifiedResponse(
      isNewUser: json['is_new_user'] as bool? ?? true,
      user: RegisteredUser.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
      sharedDevice: json['shared_device'] as bool?,
      expiresAt: json['expires_at'] as String?,
      sessionStartedAt: json['session_started_at'] as String?,
    );
  }

  /// Shape that matches what [SessionMeta.applyFromAuthResponse] expects.
  Map<String, dynamic> sessionPayload() => {
        'shared_device': sharedDevice ?? false,
        'expires_at': expiresAt,
        'session_started_at': sessionStartedAt,
      };
}

/// User data returned from registration.
class RegisteredUser {
  final int id;
  final String name;
  final String email;
  final int? avatarIndex;
  final List<String>? selectedSubjects;
  final DateTime? emailVerifiedAt;

  /// When the account finished the sign-up onboarding, null if it never has
  /// (BR-YXVMKY). Backfilled to the creation date for every account that
  /// predates the column, so a returning user is never asked again.
  final DateTime? onboardedAt;

  const RegisteredUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarIndex,
    this.selectedSubjects,
    this.emailVerifiedAt,
    this.onboardedAt,
  });

  bool get hasOnboarded => onboardedAt != null;

  factory RegisteredUser.fromJson(Map<String, dynamic> json) {
    return RegisteredUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarIndex: json['avatar_index'] as int?,
      selectedSubjects: json['selected_subjects'] != null
          ? List<String>.from(json['selected_subjects'] as List)
          : null,
      emailVerifiedAt: json['email_verified_at'] != null
          ? DateTime.tryParse(json['email_verified_at'] as String)
          : null,
      onboardedAt: json['onboarded_at'] != null
          ? DateTime.tryParse(json['onboarded_at'] as String)
          : null,
    );
  }
}
