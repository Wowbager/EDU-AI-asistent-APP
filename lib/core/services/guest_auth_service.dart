import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';

/// Generates fun Czech guest names like "Chytry Tucnak" or "Vesela Liska".
class CzechNameGenerator {
  static const _adjectives = [
    'Chytry',
    'Vesely',
    'Rychly',
    'Odvazny',
    'Zvedly',
    'Sikovna',
    'Mazany',
    'Hravy',
    'Zariva',
    'Smelej',
    'Vtipny',
    'Bystry',
    'Neznamy',
    'Tajemny',
    'Zabavny',
    'Zvikovy',
    'Pysny',
    'Statecny',
  ];

  static const _animals = [
    'Tucnak',
    'Liska',
    'Medved',
    'Sova',
    'Delfin',
    'Panda',
    'Tygr',
    'Orel',
    'Koala',
    'Papousek',
    'Jezek',
    'Kolibrik',
    'Mravenec',
    'Chameleon',
    'Veverka',
    'Vydra',
    'Plamenak',
    'Levhart',
  ];

  static String generate() {
    final random = Random();
    final adjective = _adjectives[random.nextInt(_adjectives.length)];
    final animal = _animals[random.nextInt(_animals.length)];
    return '$adjective $animal';
  }
}

/// Service for managing guest authentication with the server.
///
/// Handles:
/// - Generating and persisting a device_id
/// - Registering guest users on the server (POST /api/guest/register)
/// - Claiming/upgrading guests to full users (POST /api/guest/claim)
class GuestAuthService {
  final ApiClient _apiClient;
  final SharedPreferences _prefs;

  static const String _deviceIdKey = 'guest_device_id';
  static const String _forceNewKey = 'guest_force_new';

  GuestAuthService({
    required ApiClient apiClient,
    required SharedPreferences prefs,
  })  : _apiClient = apiClient,
        _prefs = prefs;

  Future<void> _persistSessionMeta(Map<String, dynamic> data) async {
    final session = _apiClient.session;
    if (session != null) {
      await session.applyFromAuthResponse(data);
    }
  }

  /// Mark that the next guest registration should create a fresh identity.
  /// Called on logout so the server detaches the old guest and revokes tokens.
  void markForceNewGuest() {
    _prefs.setBool(_forceNewKey, true);
  }

  /// Get or create a persistent device ID for this device.
  String getOrCreateDeviceId() {
    var deviceId = _prefs.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      _prefs.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  /// Register a guest user on the server.
  ///
  /// Returns the Sanctum token on success, or null on failure.
  /// If a guest with this device_id already exists and force_new is not set,
  /// the server returns the existing guest's token (reconnect).
  /// After logout, force_new=true tells the server to detach old guests
  /// and create a fresh identity.
  Future<GuestRegisterResult?> registerGuest({bool sharedDevice = false}) async {
    final deviceId = getOrCreateDeviceId();
    final name = CzechNameGenerator.generate();
    final forceNew = _prefs.getBool(_forceNewKey) ?? false;

    // Consume the flag before the API call
    if (forceNew) {
      _prefs.remove(_forceNewKey);
    }

    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.guestRegister,
      data: {
        'device_id': deviceId,
        'name': name,
        'shared_device': sharedDevice,
        if (forceNew) 'force_new': true,
      },
      fromJson: (data) => data as Map<String, dynamic>,
    );


    if (result.isSuccess && result.data != null) {
      final data = result.data!;
      final token = data['token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      final serverName = user?['name'] as String? ?? name;


      if (token != null && token.isNotEmpty) {
        // Store the token
        await _apiClient.setAuthToken(token);
        await _persistSessionMeta(data);
        return GuestRegisterResult(
          token: token,
          name: serverName,
          serverId: user?['id'] as int?,
        );
      }
    }

    return null;
  }

  /// Resolve a code against the API — could be a course PIN or a student
  /// login code. Returns a discriminated [ResolveCodeResult].
  ///
  /// The API responds with `{ "type": "course"|"user", ... }`.
  /// - type=course → course data in `course` key
  /// - type=user  → auth token + user profile in `token`/`user` keys
  ///
  /// [mergeGuest] tells the server the code was typed by the guest whose
  /// token rides along, so their progress is folded into the student account
  /// even on a shared device — where it is otherwise skipped, because there
  /// the guest is likely someone else (BR-ZDXP7C, BR-35W2HV).
  Future<ResolveCodeResult?> resolveCode(
    String code, {
    bool sharedDevice = false,
    bool mergeGuest = false,
  }) async {
    final normalizedCode = code.toUpperCase().trim();

    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.resolveCode,
      data: {
        'code': normalizedCode,
        'shared_device': sharedDevice,
        'merge_guest': mergeGuest,
      },
      fromJson: (data) => data as Map<String, dynamic>,
    );

    if (result.isFailure || result.data == null) {
      return null;
    }

    final data = result.data!;
    final type = data['type'] as String?;

    if (type == 'user') {
      final token = data['token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      if (token != null && token.isNotEmpty) {
        await _apiClient.setAuthToken(token);
        await _persistSessionMeta(data);
        return ResolveCodeResult.user(
          token: token,
          userId: user?['id'] as int?,
          name: user?['name'] as String?,
          email: user?['email'] as String?,
          minor: data['minor'] == true,
          profileSetupRequired: data['profile_setup_required'] == true,
        );
      }
    }

    if (type == 'course') {
      final courseData = data['course'] as Map<String, dynamic>?;
      if (courseData != null) {
        return ResolveCodeResult.course(courseData);
      }
    }

    return null;
  }

  /// Claim/upgrade a guest account to a full user with email.
  ///
  /// Requires the guest to already have a Sanctum token (from registerGuest).
  /// Returns true on success.
  Future<GuestClaimResult?> claimGuest(String email, {String? name}) async {

    final result = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.guestClaim,
      data: {
        'email': email,
        if (name != null && name.isNotEmpty) 'name': name,
      },
      fromJson: (data) => data as Map<String, dynamic>,
    );

    if (result.isSuccess && result.data != null) {
      final data = result.data!;
      final token = data['token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;

      // Update token if new one provided
      if (token != null && token.isNotEmpty) {
        await _apiClient.setAuthToken(token);
      }
      await _persistSessionMeta(data);

      return GuestClaimResult(
        token: token,
        userId: user?['id'] as int?,
        email: user?['email'] as String? ?? email,
      );
    }

    return null;
  }
}

/// Result of guest registration.
class GuestRegisterResult {
  final String token;
  final String name;
  final int? serverId;

  const GuestRegisterResult({
    required this.token,
    required this.name,
    this.serverId,
  });
}

/// Result of guest claim (upgrade to full user).
class GuestClaimResult {
  final String? token;
  final int? userId;
  final String email;

  const GuestClaimResult({
    this.token,
    this.userId,
    required this.email,
  });
}

/// Discriminated result from the resolve-code endpoint.
///
/// Either [isUser] (student login) or [isCourse] (course found).
class ResolveCodeResult {
  final bool isUser;
  final bool isCourse;

  // User fields (when isUser)
  final String? token;
  final int? userId;
  final String? name;
  final String? email;

  /// Whether the logged-in account is a minor (consent-gated child account).
  /// Feeds `minorModeProvider` immediately on login — `/api/user` on the next
  /// boot is the ongoing authority, but this makes the current session
  /// correct without waiting for a restart.
  final bool minor;

  /// The server's verdict on whether this login stops at the sign-up
  /// onboarding — true only until the account has been through it once
  /// (BR-YXVMKY). A student's first entry into the app is a code login, not a
  /// registration: the teacher created the account, so nothing else on this
  /// path can tell "never opened before" from "signs in every morning".
  final bool profileSetupRequired;

  // Course fields (when isCourse)
  final Map<String, dynamic>? courseData;

  const ResolveCodeResult._({
    this.isUser = false,
    this.isCourse = false,
    this.token,
    this.userId,
    this.name,
    this.email,
    this.minor = false,
    this.profileSetupRequired = false,
    this.courseData,
  });

  factory ResolveCodeResult.user({
    required String token,
    int? userId,
    String? name,
    String? email,
    bool minor = false,
    bool profileSetupRequired = false,
  }) =>
      ResolveCodeResult._(
        isUser: true,
        token: token,
        userId: userId,
        name: name,
        email: email,
        minor: minor,
        profileSetupRequired: profileSetupRequired,
      );

  factory ResolveCodeResult.course(Map<String, dynamic> courseData) =>
      ResolveCodeResult._(isCourse: true, courseData: courseData);
}
