/// Why a mini game cannot be played right now.
///
/// The server owns this decision — the client only renders it. [offline] is
/// the one value the server never sends: it is set locally when the listing
/// comes from cache and we could not confirm the entitlement.
enum MiniGameLock {
  /// User's level is below the game's `min_level`.
  level,

  /// Daily attempt quota is used up.
  attempts,

  /// A waiting period since the last play has not elapsed yet.
  cooldown,

  /// Listing was served from cache; entitlement is unknown.
  offline;

  static MiniGameLock? fromJson(String? value) => switch (value) {
        'level' => MiniGameLock.level,
        'attempts' => MiniGameLock.attempts,
        'cooldown' => MiniGameLock.cooldown,
        'offline' => MiniGameLock.offline,
        _ => null,
      };

  String get asJson => name;
}

/// A single mini game ("Minihra").
///
/// The playable game itself ships with the app build and is resolved by
/// [code]; everything here is metadata plus the server's verdict on whether
/// the user may start a run.
class MiniGame {
  final int id;
  final String code;
  final String title;
  final String perex;
  final String? description;
  final String? imageUrl;

  /// Hardware the game needs, e.g. `gyroscope`. Rendered as a tag.
  final String? sensor;
  final int? durationMinutes;
  final int minLevel;

  /// null = unlimited plays per day.
  final int? dailyAttempts;

  /// null or 0 = no waiting period between plays.
  final int? cooldownHours;

  /// Free-form per-game configuration, developed separately.
  final Map<String, dynamic>? setup;

  final bool isPlayable;
  final MiniGameLock? lockReason;

  /// null when the game has no daily quota.
  final int? attemptsLeft;

  /// When a [cooldown] or [attempts] lock lifts. null for other states.
  final DateTime? unlocksAt;

  const MiniGame({
    required this.id,
    required this.code,
    required this.title,
    required this.perex,
    this.description,
    this.imageUrl,
    this.sensor,
    this.durationMinutes,
    required this.minLevel,
    this.dailyAttempts,
    this.cooldownHours,
    this.setup,
    required this.isPlayable,
    this.lockReason,
    this.attemptsLeft,
    this.unlocksAt,
  });

  factory MiniGame.fromJson(Map<String, dynamic> json) {
    return MiniGame(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      perex: json['perex'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      sensor: json['sensor'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      minLevel: json['min_level'] as int? ?? 1,
      dailyAttempts: json['daily_attempts'] as int?,
      cooldownHours: json['cooldown_hours'] as int?,
      setup: json['setup'] as Map<String, dynamic>?,
      isPlayable: json['is_playable'] as bool? ?? false,
      lockReason: MiniGameLock.fromJson(json['lock_reason'] as String?),
      attemptsLeft: json['attempts_left'] as int?,
      unlocksAt: json['unlocks_at'] == null
          ? null
          : DateTime.tryParse(json['unlocks_at'] as String),
    );
  }

  /// Round-trips through the local cache. Mirrors the server payload exactly
  /// so a cached entry parses back through [fromJson].
  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'title': title,
        'perex': perex,
        'description': description,
        'image_url': imageUrl,
        'sensor': sensor,
        'duration_minutes': durationMinutes,
        'min_level': minLevel,
        'daily_attempts': dailyAttempts,
        'cooldown_hours': cooldownHours,
        'setup': setup,
        'is_playable': isPlayable,
        'lock_reason': lockReason?.asJson,
        'attempts_left': attemptsLeft,
        'unlocks_at': unlocksAt?.toIso8601String(),
      };

  /// Collapse to the "we cannot confirm entitlement" state used offline.
  MiniGame asOffline() => MiniGame(
        id: id,
        code: code,
        title: title,
        perex: perex,
        description: description,
        imageUrl: imageUrl,
        sensor: sensor,
        durationMinutes: durationMinutes,
        minLevel: minLevel,
        dailyAttempts: dailyAttempts,
        cooldownHours: cooldownHours,
        setup: setup,
        isPlayable: false,
        lockReason: MiniGameLock.offline,
        attemptsLeft: null,
        unlocksAt: null,
      );
}

/// A run the server has just authorised.
///
/// [playId] identifies the `mini_game_plays` row the attempt was booked
/// against; the final score is reported back against it once the run ends.
/// Deliberately not part of [MiniGame]: a run is per-attempt state and must
/// never reach the offline cache.
class MiniGameRun {
  final MiniGame game;
  final int? playId;

  const MiniGameRun({required this.game, this.playId});
}

/// What a finished run reports back (BR-HK9828).
///
/// The engine used to pop a bare score. Coins ride alongside rather than being
/// derived from it: the score already mixes height climbed with coin points,
/// so it cannot be unpicked into a coin count afterwards.
class MiniGameOutcome {
  final int score;

  /// EDUX coins collected during the run, excluding boost pickups.
  final int coins;

  const MiniGameOutcome({required this.score, this.coins = 0});
}

/// The mini games listing plus the level it was evaluated against.
class MiniGameList {
  final List<MiniGame> items;
  final int level;

  /// True when [items] came from the local cache rather than the server.
  final bool fromCache;

  const MiniGameList({
    required this.items,
    required this.level,
    this.fromCache = false,
  });
}
