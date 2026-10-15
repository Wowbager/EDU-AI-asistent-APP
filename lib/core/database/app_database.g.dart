// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CoursesTableTable extends CoursesTable
    with TableInfo<$CoursesTableTable, CoursesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoursesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en'),
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _onlyOnceMeta = const VerificationMeta(
    'onlyOnce',
  );
  @override
  late final GeneratedColumn<bool> onlyOnce = GeneratedColumn<bool>(
    'only_once',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("only_once" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    courseId,
    name,
    version,
    status,
    language,
    data,
    onlyOnce,
    syncStatus,
    createdAt,
    updatedAt,
    serverUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'courses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoursesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    }
    if (data.containsKey('only_once')) {
      context.handle(
        _onlyOnceMeta,
        onlyOnce.isAcceptableOrUnknown(data['only_once']!, _onlyOnceMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CoursesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoursesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      onlyOnce: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}only_once'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
    );
  }

  @override
  $CoursesTableTable createAlias(String alias) {
    return $CoursesTableTable(attachedDatabase, alias);
  }
}

class CoursesTableData extends DataClass
    implements Insertable<CoursesTableData> {
  /// Local unique identifier (UUID).
  final String id;

  /// Server-side ID (null if created offline and not yet synced).
  final int? serverId;

  /// Course identifier string (e.g., "course-001").
  final String courseId;

  /// Course name/title.
  final String name;

  /// Version number for conflict detection.
  final int version;

  /// Publication status: draft, published, archived.
  final String status;

  /// Course language code (e.g., "en", "cs").
  final String language;

  /// JSON-encoded course data (lessons, exercises, etc.).
  final String data;

  /// Course-level "only once" flag (typically a test): the course cannot be
  /// re-entered after completion and none of its blocks may feed practice.
  ///
  /// Denormalised out of [data] on write (see `AppDatabase.upsertCourse`) so
  /// the practice queue can filter on it with a two-column lookup instead of
  /// decoding every course JSON — a course blob carries its blocks and can run
  /// to megabytes (BR-E495XK).
  final bool onlyOnce;

  /// Sync status: 0=synced, 1=pending, 2=conflict.
  final int syncStatus;

  /// When the record was created locally.
  final DateTime createdAt;

  /// When the record was last updated (local or remote).
  final DateTime updatedAt;

  /// Server's last update timestamp (for conflict detection).
  final DateTime? serverUpdatedAt;
  const CoursesTableData({
    required this.id,
    this.serverId,
    required this.courseId,
    required this.name,
    required this.version,
    required this.status,
    required this.language,
    required this.data,
    required this.onlyOnce,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.serverUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['course_id'] = Variable<String>(courseId);
    map['name'] = Variable<String>(name);
    map['version'] = Variable<int>(version);
    map['status'] = Variable<String>(status);
    map['language'] = Variable<String>(language);
    map['data'] = Variable<String>(data);
    map['only_once'] = Variable<bool>(onlyOnce);
    map['sync_status'] = Variable<int>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    return map;
  }

  CoursesTableCompanion toCompanion(bool nullToAbsent) {
    return CoursesTableCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      courseId: Value(courseId),
      name: Value(name),
      version: Value(version),
      status: Value(status),
      language: Value(language),
      data: Value(data),
      onlyOnce: Value(onlyOnce),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
    );
  }

  factory CoursesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoursesTableData(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      courseId: serializer.fromJson<String>(json['courseId']),
      name: serializer.fromJson<String>(json['name']),
      version: serializer.fromJson<int>(json['version']),
      status: serializer.fromJson<String>(json['status']),
      language: serializer.fromJson<String>(json['language']),
      data: serializer.fromJson<String>(json['data']),
      onlyOnce: serializer.fromJson<bool>(json['onlyOnce']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'courseId': serializer.toJson<String>(courseId),
      'name': serializer.toJson<String>(name),
      'version': serializer.toJson<int>(version),
      'status': serializer.toJson<String>(status),
      'language': serializer.toJson<String>(language),
      'data': serializer.toJson<String>(data),
      'onlyOnce': serializer.toJson<bool>(onlyOnce),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
    };
  }

  CoursesTableData copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? courseId,
    String? name,
    int? version,
    String? status,
    String? language,
    String? data,
    bool? onlyOnce,
    int? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
  }) => CoursesTableData(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    courseId: courseId ?? this.courseId,
    name: name ?? this.name,
    version: version ?? this.version,
    status: status ?? this.status,
    language: language ?? this.language,
    data: data ?? this.data,
    onlyOnce: onlyOnce ?? this.onlyOnce,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
  );
  CoursesTableData copyWithCompanion(CoursesTableCompanion data) {
    return CoursesTableData(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      name: data.name.present ? data.name.value : this.name,
      version: data.version.present ? data.version.value : this.version,
      status: data.status.present ? data.status.value : this.status,
      language: data.language.present ? data.language.value : this.language,
      data: data.data.present ? data.data.value : this.data,
      onlyOnce: data.onlyOnce.present ? data.onlyOnce.value : this.onlyOnce,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoursesTableData(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('courseId: $courseId, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('status: $status, ')
          ..write('language: $language, ')
          ..write('data: $data, ')
          ..write('onlyOnce: $onlyOnce, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    courseId,
    name,
    version,
    status,
    language,
    data,
    onlyOnce,
    syncStatus,
    createdAt,
    updatedAt,
    serverUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoursesTableData &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.courseId == this.courseId &&
          other.name == this.name &&
          other.version == this.version &&
          other.status == this.status &&
          other.language == this.language &&
          other.data == this.data &&
          other.onlyOnce == this.onlyOnce &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt);
}

class CoursesTableCompanion extends UpdateCompanion<CoursesTableData> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> courseId;
  final Value<String> name;
  final Value<int> version;
  final Value<String> status;
  final Value<String> language;
  final Value<String> data;
  final Value<bool> onlyOnce;
  final Value<int> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> serverUpdatedAt;
  final Value<int> rowid;
  const CoursesTableCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.name = const Value.absent(),
    this.version = const Value.absent(),
    this.status = const Value.absent(),
    this.language = const Value.absent(),
    this.data = const Value.absent(),
    this.onlyOnce = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoursesTableCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String courseId,
    required String name,
    this.version = const Value.absent(),
    this.status = const Value.absent(),
    this.language = const Value.absent(),
    this.data = const Value.absent(),
    this.onlyOnce = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       courseId = Value(courseId),
       name = Value(name);
  static Insertable<CoursesTableData> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? courseId,
    Expression<String>? name,
    Expression<int>? version,
    Expression<String>? status,
    Expression<String>? language,
    Expression<String>? data,
    Expression<bool>? onlyOnce,
    Expression<int>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (courseId != null) 'course_id': courseId,
      if (name != null) 'name': name,
      if (version != null) 'version': version,
      if (status != null) 'status': status,
      if (language != null) 'language': language,
      if (data != null) 'data': data,
      if (onlyOnce != null) 'only_once': onlyOnce,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoursesTableCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? courseId,
    Value<String>? name,
    Value<int>? version,
    Value<String>? status,
    Value<String>? language,
    Value<String>? data,
    Value<bool>? onlyOnce,
    Value<int>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? serverUpdatedAt,
    Value<int>? rowid,
  }) {
    return CoursesTableCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      courseId: courseId ?? this.courseId,
      name: name ?? this.name,
      version: version ?? this.version,
      status: status ?? this.status,
      language: language ?? this.language,
      data: data ?? this.data,
      onlyOnce: onlyOnce ?? this.onlyOnce,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (onlyOnce.present) {
      map['only_once'] = Variable<bool>(onlyOnce.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoursesTableCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('courseId: $courseId, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('status: $status, ')
          ..write('language: $language, ')
          ..write('data: $data, ')
          ..write('onlyOnce: $onlyOnce, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LessonsTableTable extends LessonsTable
    with TableInfo<$LessonsTableTable, LessonsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    courseId,
    lessonId,
    title,
    description,
    orderIndex,
    content,
    durationMinutes,
    syncStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lessons';
  @override
  VerificationContext validateIntegrity(
    Insertable<LessonsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LessonsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LessonsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LessonsTableTable createAlias(String alias) {
    return $LessonsTableTable(attachedDatabase, alias);
  }
}

class LessonsTableData extends DataClass
    implements Insertable<LessonsTableData> {
  /// Local unique identifier (UUID).
  final String id;

  /// Server-side ID (null if created offline).
  final int? serverId;

  /// Reference to the parent course (local ID).
  final String courseId;

  /// Lesson identifier string.
  final String lessonId;

  /// Lesson title.
  final String title;

  /// Lesson description/summary.
  final String description;

  /// Order within the course.
  final int orderIndex;

  /// JSON-encoded lesson content.
  final String content;

  /// Duration in minutes (estimated).
  final int durationMinutes;

  /// Sync status: 0=synced, 1=pending, 2=conflict.
  final int syncStatus;

  /// When the record was created locally.
  final DateTime createdAt;

  /// When the record was last updated.
  final DateTime updatedAt;
  const LessonsTableData({
    required this.id,
    this.serverId,
    required this.courseId,
    required this.lessonId,
    required this.title,
    required this.description,
    required this.orderIndex,
    required this.content,
    required this.durationMinutes,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['course_id'] = Variable<String>(courseId);
    map['lesson_id'] = Variable<String>(lessonId);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['order_index'] = Variable<int>(orderIndex);
    map['content'] = Variable<String>(content);
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['sync_status'] = Variable<int>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LessonsTableCompanion toCompanion(bool nullToAbsent) {
    return LessonsTableCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      courseId: Value(courseId),
      lessonId: Value(lessonId),
      title: Value(title),
      description: Value(description),
      orderIndex: Value(orderIndex),
      content: Value(content),
      durationMinutes: Value(durationMinutes),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LessonsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LessonsTableData(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      courseId: serializer.fromJson<String>(json['courseId']),
      lessonId: serializer.fromJson<String>(json['lessonId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      content: serializer.fromJson<String>(json['content']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'courseId': serializer.toJson<String>(courseId),
      'lessonId': serializer.toJson<String>(lessonId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'content': serializer.toJson<String>(content),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LessonsTableData copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? courseId,
    String? lessonId,
    String? title,
    String? description,
    int? orderIndex,
    String? content,
    int? durationMinutes,
    int? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LessonsTableData(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    courseId: courseId ?? this.courseId,
    lessonId: lessonId ?? this.lessonId,
    title: title ?? this.title,
    description: description ?? this.description,
    orderIndex: orderIndex ?? this.orderIndex,
    content: content ?? this.content,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LessonsTableData copyWithCompanion(LessonsTableCompanion data) {
    return LessonsTableData(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      content: data.content.present ? data.content.value : this.content,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LessonsTableData(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('courseId: $courseId, ')
          ..write('lessonId: $lessonId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('content: $content, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    courseId,
    lessonId,
    title,
    description,
    orderIndex,
    content,
    durationMinutes,
    syncStatus,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonsTableData &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.courseId == this.courseId &&
          other.lessonId == this.lessonId &&
          other.title == this.title &&
          other.description == this.description &&
          other.orderIndex == this.orderIndex &&
          other.content == this.content &&
          other.durationMinutes == this.durationMinutes &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LessonsTableCompanion extends UpdateCompanion<LessonsTableData> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> courseId;
  final Value<String> lessonId;
  final Value<String> title;
  final Value<String> description;
  final Value<int> orderIndex;
  final Value<String> content;
  final Value<int> durationMinutes;
  final Value<int> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LessonsTableCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.content = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LessonsTableCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String courseId,
    required String lessonId,
    required String title,
    this.description = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.content = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       courseId = Value(courseId),
       lessonId = Value(lessonId),
       title = Value(title);
  static Insertable<LessonsTableData> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? courseId,
    Expression<String>? lessonId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? orderIndex,
    Expression<String>? content,
    Expression<int>? durationMinutes,
    Expression<int>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (courseId != null) 'course_id': courseId,
      if (lessonId != null) 'lesson_id': lessonId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (orderIndex != null) 'order_index': orderIndex,
      if (content != null) 'content': content,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LessonsTableCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? courseId,
    Value<String>? lessonId,
    Value<String>? title,
    Value<String>? description,
    Value<int>? orderIndex,
    Value<String>? content,
    Value<int>? durationMinutes,
    Value<int>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LessonsTableCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      courseId: courseId ?? this.courseId,
      lessonId: lessonId ?? this.lessonId,
      title: title ?? this.title,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      content: content ?? this.content,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonsTableCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('courseId: $courseId, ')
          ..write('lessonId: $lessonId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('content: $content, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserProgressTableTable extends UserProgressTable
    with TableInfo<$UserProgressTableTable, UserProgressTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProgressTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _progressPercentMeta = const VerificationMeta(
    'progressPercent',
  );
  @override
  late final GeneratedColumn<int> progressPercent = GeneratedColumn<int>(
    'progress_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastPositionMeta = const VerificationMeta(
    'lastPosition',
  );
  @override
  late final GeneratedColumn<int> lastPosition = GeneratedColumn<int>(
    'last_position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _progressDataMeta = const VerificationMeta(
    'progressData',
  );
  @override
  late final GeneratedColumn<String> progressData = GeneratedColumn<String>(
    'progress_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _timeSpentSecondsMeta = const VerificationMeta(
    'timeSpentSeconds',
  );
  @override
  late final GeneratedColumn<int> timeSpentSeconds = GeneratedColumn<int>(
    'time_spent_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    userId,
    courseId,
    lessonId,
    progressPercent,
    isCompleted,
    lastPosition,
    progressData,
    timeSpentSeconds,
    startedAt,
    completedAt,
    syncStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProgressTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    }
    if (data.containsKey('progress_percent')) {
      context.handle(
        _progressPercentMeta,
        progressPercent.isAcceptableOrUnknown(
          data['progress_percent']!,
          _progressPercentMeta,
        ),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('last_position')) {
      context.handle(
        _lastPositionMeta,
        lastPosition.isAcceptableOrUnknown(
          data['last_position']!,
          _lastPositionMeta,
        ),
      );
    }
    if (data.containsKey('progress_data')) {
      context.handle(
        _progressDataMeta,
        progressData.isAcceptableOrUnknown(
          data['progress_data']!,
          _progressDataMeta,
        ),
      );
    }
    if (data.containsKey('time_spent_seconds')) {
      context.handle(
        _timeSpentSecondsMeta,
        timeSpentSeconds.isAcceptableOrUnknown(
          data['time_spent_seconds']!,
          _timeSpentSecondsMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProgressTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProgressTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      ),
      progressPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progress_percent'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      lastPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_position'],
      )!,
      progressData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}progress_data'],
      )!,
      timeSpentSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_spent_seconds'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserProgressTableTable createAlias(String alias) {
    return $UserProgressTableTable(attachedDatabase, alias);
  }
}

class UserProgressTableData extends DataClass
    implements Insertable<UserProgressTableData> {
  /// Local unique identifier (UUID).
  final String id;

  /// Server-side ID (null if created offline).
  final int? serverId;

  /// User ID (from auth system).
  final String userId;

  /// Reference to the course (local ID).
  final String courseId;

  /// Reference to the lesson (local ID, nullable for course-level progress).
  final String? lessonId;

  /// Progress percentage (0-100).
  final int progressPercent;

  /// Whether the item is completed.
  final bool isCompleted;

  /// Last position/checkpoint within content (e.g., question index).
  final int lastPosition;

  /// JSON-encoded additional progress data (answers, scores, etc.).
  final String progressData;

  /// Time spent in seconds.
  final int timeSpentSeconds;

  /// When the user started this item.
  final DateTime? startedAt;

  /// When the user completed this item.
  final DateTime? completedAt;

  /// Sync status: 0=synced, 1=pending, 2=conflict.
  final int syncStatus;

  /// When the record was created locally.
  final DateTime createdAt;

  /// When the record was last updated.
  final DateTime updatedAt;
  const UserProgressTableData({
    required this.id,
    this.serverId,
    required this.userId,
    required this.courseId,
    this.lessonId,
    required this.progressPercent,
    required this.isCompleted,
    required this.lastPosition,
    required this.progressData,
    required this.timeSpentSeconds,
    this.startedAt,
    this.completedAt,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['user_id'] = Variable<String>(userId);
    map['course_id'] = Variable<String>(courseId);
    if (!nullToAbsent || lessonId != null) {
      map['lesson_id'] = Variable<String>(lessonId);
    }
    map['progress_percent'] = Variable<int>(progressPercent);
    map['is_completed'] = Variable<bool>(isCompleted);
    map['last_position'] = Variable<int>(lastPosition);
    map['progress_data'] = Variable<String>(progressData);
    map['time_spent_seconds'] = Variable<int>(timeSpentSeconds);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserProgressTableCompanion toCompanion(bool nullToAbsent) {
    return UserProgressTableCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      userId: Value(userId),
      courseId: Value(courseId),
      lessonId: lessonId == null && nullToAbsent
          ? const Value.absent()
          : Value(lessonId),
      progressPercent: Value(progressPercent),
      isCompleted: Value(isCompleted),
      lastPosition: Value(lastPosition),
      progressData: Value(progressData),
      timeSpentSeconds: Value(timeSpentSeconds),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserProgressTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProgressTableData(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      userId: serializer.fromJson<String>(json['userId']),
      courseId: serializer.fromJson<String>(json['courseId']),
      lessonId: serializer.fromJson<String?>(json['lessonId']),
      progressPercent: serializer.fromJson<int>(json['progressPercent']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      lastPosition: serializer.fromJson<int>(json['lastPosition']),
      progressData: serializer.fromJson<String>(json['progressData']),
      timeSpentSeconds: serializer.fromJson<int>(json['timeSpentSeconds']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'userId': serializer.toJson<String>(userId),
      'courseId': serializer.toJson<String>(courseId),
      'lessonId': serializer.toJson<String?>(lessonId),
      'progressPercent': serializer.toJson<int>(progressPercent),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'lastPosition': serializer.toJson<int>(lastPosition),
      'progressData': serializer.toJson<String>(progressData),
      'timeSpentSeconds': serializer.toJson<int>(timeSpentSeconds),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserProgressTableData copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? userId,
    String? courseId,
    Value<String?> lessonId = const Value.absent(),
    int? progressPercent,
    bool? isCompleted,
    int? lastPosition,
    String? progressData,
    int? timeSpentSeconds,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    int? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserProgressTableData(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    userId: userId ?? this.userId,
    courseId: courseId ?? this.courseId,
    lessonId: lessonId.present ? lessonId.value : this.lessonId,
    progressPercent: progressPercent ?? this.progressPercent,
    isCompleted: isCompleted ?? this.isCompleted,
    lastPosition: lastPosition ?? this.lastPosition,
    progressData: progressData ?? this.progressData,
    timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserProgressTableData copyWithCompanion(UserProgressTableCompanion data) {
    return UserProgressTableData(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      userId: data.userId.present ? data.userId.value : this.userId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      progressPercent: data.progressPercent.present
          ? data.progressPercent.value
          : this.progressPercent,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      lastPosition: data.lastPosition.present
          ? data.lastPosition.value
          : this.lastPosition,
      progressData: data.progressData.present
          ? data.progressData.value
          : this.progressData,
      timeSpentSeconds: data.timeSpentSeconds.present
          ? data.timeSpentSeconds.value
          : this.timeSpentSeconds,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProgressTableData(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('courseId: $courseId, ')
          ..write('lessonId: $lessonId, ')
          ..write('progressPercent: $progressPercent, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('lastPosition: $lastPosition, ')
          ..write('progressData: $progressData, ')
          ..write('timeSpentSeconds: $timeSpentSeconds, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    userId,
    courseId,
    lessonId,
    progressPercent,
    isCompleted,
    lastPosition,
    progressData,
    timeSpentSeconds,
    startedAt,
    completedAt,
    syncStatus,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProgressTableData &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.userId == this.userId &&
          other.courseId == this.courseId &&
          other.lessonId == this.lessonId &&
          other.progressPercent == this.progressPercent &&
          other.isCompleted == this.isCompleted &&
          other.lastPosition == this.lastPosition &&
          other.progressData == this.progressData &&
          other.timeSpentSeconds == this.timeSpentSeconds &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserProgressTableCompanion
    extends UpdateCompanion<UserProgressTableData> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> userId;
  final Value<String> courseId;
  final Value<String?> lessonId;
  final Value<int> progressPercent;
  final Value<bool> isCompleted;
  final Value<int> lastPosition;
  final Value<String> progressData;
  final Value<int> timeSpentSeconds;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> completedAt;
  final Value<int> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserProgressTableCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.userId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.progressPercent = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.lastPosition = const Value.absent(),
    this.progressData = const Value.absent(),
    this.timeSpentSeconds = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProgressTableCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String userId,
    required String courseId,
    this.lessonId = const Value.absent(),
    this.progressPercent = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.lastPosition = const Value.absent(),
    this.progressData = const Value.absent(),
    this.timeSpentSeconds = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       courseId = Value(courseId);
  static Insertable<UserProgressTableData> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? userId,
    Expression<String>? courseId,
    Expression<String>? lessonId,
    Expression<int>? progressPercent,
    Expression<bool>? isCompleted,
    Expression<int>? lastPosition,
    Expression<String>? progressData,
    Expression<int>? timeSpentSeconds,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (userId != null) 'user_id': userId,
      if (courseId != null) 'course_id': courseId,
      if (lessonId != null) 'lesson_id': lessonId,
      if (progressPercent != null) 'progress_percent': progressPercent,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (lastPosition != null) 'last_position': lastPosition,
      if (progressData != null) 'progress_data': progressData,
      if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProgressTableCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? userId,
    Value<String>? courseId,
    Value<String?>? lessonId,
    Value<int>? progressPercent,
    Value<bool>? isCompleted,
    Value<int>? lastPosition,
    Value<String>? progressData,
    Value<int>? timeSpentSeconds,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? completedAt,
    Value<int>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserProgressTableCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      lessonId: lessonId ?? this.lessonId,
      progressPercent: progressPercent ?? this.progressPercent,
      isCompleted: isCompleted ?? this.isCompleted,
      lastPosition: lastPosition ?? this.lastPosition,
      progressData: progressData ?? this.progressData,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (progressPercent.present) {
      map['progress_percent'] = Variable<int>(progressPercent.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (lastPosition.present) {
      map['last_position'] = Variable<int>(lastPosition.value);
    }
    if (progressData.present) {
      map['progress_data'] = Variable<String>(progressData.value);
    }
    if (timeSpentSeconds.present) {
      map['time_spent_seconds'] = Variable<int>(timeSpentSeconds.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProgressTableCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('courseId: $courseId, ')
          ..write('lessonId: $lessonId, ')
          ..write('progressPercent: $progressPercent, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('lastPosition: $lastPosition, ')
          ..write('progressData: $progressData, ')
          ..write('timeSpentSeconds: $timeSpentSeconds, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTableTable extends SyncQueueTable
    with TableInfo<$SyncQueueTableTable, SyncQueueTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tableName_Meta = const VerificationMeta(
    'tableName_',
  );
  @override
  late final GeneratedColumn<String> tableName_ = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _scheduledAtMeta = const VerificationMeta(
    'scheduledAt',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledAt = GeneratedColumn<DateTime>(
    'scheduled_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tableName_,
    recordId,
    operation,
    payload,
    retryCount,
    lastError,
    priority,
    createdAt,
    scheduledAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _tableName_Meta,
        tableName_.isAcceptableOrUnknown(data['table_name']!, _tableName_Meta),
      );
    } else if (isInserting) {
      context.missing(_tableName_Meta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('scheduled_at')) {
      context.handle(
        _scheduledAtMeta,
        scheduledAt.isAcceptableOrUnknown(
          data['scheduled_at']!,
          _scheduledAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tableName_: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      scheduledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_at'],
      )!,
    );
  }

  @override
  $SyncQueueTableTable createAlias(String alias) {
    return $SyncQueueTableTable(attachedDatabase, alias);
  }
}

class SyncQueueTableData extends DataClass
    implements Insertable<SyncQueueTableData> {
  /// Unique identifier for the queue entry.
  final int id;

  /// Table name the operation applies to (courses, lessons, user_progress).
  final String tableName_;

  /// Local record ID the operation applies to.
  final String recordId;

  /// Operation type: create, update, delete.
  final String operation;

  /// JSON-encoded payload to send to the server.
  final String payload;

  /// Number of sync attempts.
  final int retryCount;

  /// Last error message if sync failed.
  final String? lastError;

  /// Priority for processing (lower = higher priority).
  final int priority;

  /// When the operation was queued.
  final DateTime createdAt;

  /// When the operation should next be attempted.
  final DateTime scheduledAt;
  const SyncQueueTableData({
    required this.id,
    required this.tableName_,
    required this.recordId,
    required this.operation,
    required this.payload,
    required this.retryCount,
    this.lastError,
    required this.priority,
    required this.createdAt,
    required this.scheduledAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['table_name'] = Variable<String>(tableName_);
    map['record_id'] = Variable<String>(recordId);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['priority'] = Variable<int>(priority);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['scheduled_at'] = Variable<DateTime>(scheduledAt);
    return map;
  }

  SyncQueueTableCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueTableCompanion(
      id: Value(id),
      tableName_: Value(tableName_),
      recordId: Value(recordId),
      operation: Value(operation),
      payload: Value(payload),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      priority: Value(priority),
      createdAt: Value(createdAt),
      scheduledAt: Value(scheduledAt),
    );
  }

  factory SyncQueueTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueTableData(
      id: serializer.fromJson<int>(json['id']),
      tableName_: serializer.fromJson<String>(json['tableName_']),
      recordId: serializer.fromJson<String>(json['recordId']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      priority: serializer.fromJson<int>(json['priority']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      scheduledAt: serializer.fromJson<DateTime>(json['scheduledAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tableName_': serializer.toJson<String>(tableName_),
      'recordId': serializer.toJson<String>(recordId),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
      'priority': serializer.toJson<int>(priority),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'scheduledAt': serializer.toJson<DateTime>(scheduledAt),
    };
  }

  SyncQueueTableData copyWith({
    int? id,
    String? tableName_,
    String? recordId,
    String? operation,
    String? payload,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
    int? priority,
    DateTime? createdAt,
    DateTime? scheduledAt,
  }) => SyncQueueTableData(
    id: id ?? this.id,
    tableName_: tableName_ ?? this.tableName_,
    recordId: recordId ?? this.recordId,
    operation: operation ?? this.operation,
    payload: payload ?? this.payload,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    priority: priority ?? this.priority,
    createdAt: createdAt ?? this.createdAt,
    scheduledAt: scheduledAt ?? this.scheduledAt,
  );
  SyncQueueTableData copyWithCompanion(SyncQueueTableCompanion data) {
    return SyncQueueTableData(
      id: data.id.present ? data.id.value : this.id,
      tableName_: data.tableName_.present
          ? data.tableName_.value
          : this.tableName_,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      priority: data.priority.present ? data.priority.value : this.priority,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      scheduledAt: data.scheduledAt.present
          ? data.scheduledAt.value
          : this.scheduledAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueTableData(')
          ..write('id: $id, ')
          ..write('tableName_: $tableName_, ')
          ..write('recordId: $recordId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('scheduledAt: $scheduledAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tableName_,
    recordId,
    operation,
    payload,
    retryCount,
    lastError,
    priority,
    createdAt,
    scheduledAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueTableData &&
          other.id == this.id &&
          other.tableName_ == this.tableName_ &&
          other.recordId == this.recordId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError &&
          other.priority == this.priority &&
          other.createdAt == this.createdAt &&
          other.scheduledAt == this.scheduledAt);
}

class SyncQueueTableCompanion extends UpdateCompanion<SyncQueueTableData> {
  final Value<int> id;
  final Value<String> tableName_;
  final Value<String> recordId;
  final Value<String> operation;
  final Value<String> payload;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<int> priority;
  final Value<DateTime> createdAt;
  final Value<DateTime> scheduledAt;
  const SyncQueueTableCompanion({
    this.id = const Value.absent(),
    this.tableName_ = const Value.absent(),
    this.recordId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.priority = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.scheduledAt = const Value.absent(),
  });
  SyncQueueTableCompanion.insert({
    this.id = const Value.absent(),
    required String tableName_,
    required String recordId,
    required String operation,
    required String payload,
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.priority = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.scheduledAt = const Value.absent(),
  }) : tableName_ = Value(tableName_),
       recordId = Value(recordId),
       operation = Value(operation),
       payload = Value(payload);
  static Insertable<SyncQueueTableData> custom({
    Expression<int>? id,
    Expression<String>? tableName_,
    Expression<String>? recordId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<int>? priority,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? scheduledAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tableName_ != null) 'table_name': tableName_,
      if (recordId != null) 'record_id': recordId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (priority != null) 'priority': priority,
      if (createdAt != null) 'created_at': createdAt,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
    });
  }

  SyncQueueTableCompanion copyWith({
    Value<int>? id,
    Value<String>? tableName_,
    Value<String>? recordId,
    Value<String>? operation,
    Value<String>? payload,
    Value<int>? retryCount,
    Value<String?>? lastError,
    Value<int>? priority,
    Value<DateTime>? createdAt,
    Value<DateTime>? scheduledAt,
  }) {
    return SyncQueueTableCompanion(
      id: id ?? this.id,
      tableName_: tableName_ ?? this.tableName_,
      recordId: recordId ?? this.recordId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tableName_.present) {
      map['table_name'] = Variable<String>(tableName_.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (scheduledAt.present) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueTableCompanion(')
          ..write('id: $id, ')
          ..write('tableName_: $tableName_, ')
          ..write('recordId: $recordId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('scheduledAt: $scheduledAt')
          ..write(')'))
        .toString();
  }
}

class $UsersTableTable extends UsersTable
    with TableInfo<$UsersTableTable, UsersTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarIndexMeta = const VerificationMeta(
    'avatarIndex',
  );
  @override
  late final GeneratedColumn<int> avatarIndex = GeneratedColumn<int>(
    'avatar_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _selectedSubjectsMeta = const VerificationMeta(
    'selectedSubjects',
  );
  @override
  late final GeneratedColumn<String> selectedSubjects = GeneratedColumn<String>(
    'selected_subjects',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[0]'),
  );
  static const VerificationMeta _isEmailValidatedMeta = const VerificationMeta(
    'isEmailValidated',
  );
  @override
  late final GeneratedColumn<bool> isEmailValidated = GeneratedColumn<bool>(
    'is_email_validated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_email_validated" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    email,
    name,
    avatarIndex,
    selectedSubjects,
    isEmailValidated,
    isActive,
    syncStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsersTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar_index')) {
      context.handle(
        _avatarIndexMeta,
        avatarIndex.isAcceptableOrUnknown(
          data['avatar_index']!,
          _avatarIndexMeta,
        ),
      );
    }
    if (data.containsKey('selected_subjects')) {
      context.handle(
        _selectedSubjectsMeta,
        selectedSubjects.isAcceptableOrUnknown(
          data['selected_subjects']!,
          _selectedSubjectsMeta,
        ),
      );
    }
    if (data.containsKey('is_email_validated')) {
      context.handle(
        _isEmailValidatedMeta,
        isEmailValidated.isAcceptableOrUnknown(
          data['is_email_validated']!,
          _isEmailValidatedMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UsersTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsersTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      avatarIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avatar_index'],
      )!,
      selectedSubjects: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_subjects'],
      )!,
      isEmailValidated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_email_validated'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UsersTableTable createAlias(String alias) {
    return $UsersTableTable(attachedDatabase, alias);
  }
}

class UsersTableData extends DataClass implements Insertable<UsersTableData> {
  /// Local unique identifier (UUID).
  final String id;

  /// User's email address.
  final String email;

  /// User's display name.
  final String name;

  /// Selected avatar index (0-5).
  final int avatarIndex;

  /// Selected subjects as JSON array of indices.
  final String selectedSubjects;

  /// Whether the email has been validated.
  final bool isEmailValidated;

  /// Whether this is the currently active/logged in user.
  final bool isActive;

  /// Sync status: 0=synced, 1=pending, 2=conflict.
  final int syncStatus;

  /// When the user was created.
  final DateTime createdAt;

  /// When the user was last updated.
  final DateTime updatedAt;
  const UsersTableData({
    required this.id,
    required this.email,
    required this.name,
    required this.avatarIndex,
    required this.selectedSubjects,
    required this.isEmailValidated,
    required this.isActive,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['email'] = Variable<String>(email);
    map['name'] = Variable<String>(name);
    map['avatar_index'] = Variable<int>(avatarIndex);
    map['selected_subjects'] = Variable<String>(selectedSubjects);
    map['is_email_validated'] = Variable<bool>(isEmailValidated);
    map['is_active'] = Variable<bool>(isActive);
    map['sync_status'] = Variable<int>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UsersTableCompanion toCompanion(bool nullToAbsent) {
    return UsersTableCompanion(
      id: Value(id),
      email: Value(email),
      name: Value(name),
      avatarIndex: Value(avatarIndex),
      selectedSubjects: Value(selectedSubjects),
      isEmailValidated: Value(isEmailValidated),
      isActive: Value(isActive),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UsersTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsersTableData(
      id: serializer.fromJson<String>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      name: serializer.fromJson<String>(json['name']),
      avatarIndex: serializer.fromJson<int>(json['avatarIndex']),
      selectedSubjects: serializer.fromJson<String>(json['selectedSubjects']),
      isEmailValidated: serializer.fromJson<bool>(json['isEmailValidated']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String>(email),
      'name': serializer.toJson<String>(name),
      'avatarIndex': serializer.toJson<int>(avatarIndex),
      'selectedSubjects': serializer.toJson<String>(selectedSubjects),
      'isEmailValidated': serializer.toJson<bool>(isEmailValidated),
      'isActive': serializer.toJson<bool>(isActive),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UsersTableData copyWith({
    String? id,
    String? email,
    String? name,
    int? avatarIndex,
    String? selectedSubjects,
    bool? isEmailValidated,
    bool? isActive,
    int? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UsersTableData(
    id: id ?? this.id,
    email: email ?? this.email,
    name: name ?? this.name,
    avatarIndex: avatarIndex ?? this.avatarIndex,
    selectedSubjects: selectedSubjects ?? this.selectedSubjects,
    isEmailValidated: isEmailValidated ?? this.isEmailValidated,
    isActive: isActive ?? this.isActive,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UsersTableData copyWithCompanion(UsersTableCompanion data) {
    return UsersTableData(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      name: data.name.present ? data.name.value : this.name,
      avatarIndex: data.avatarIndex.present
          ? data.avatarIndex.value
          : this.avatarIndex,
      selectedSubjects: data.selectedSubjects.present
          ? data.selectedSubjects.value
          : this.selectedSubjects,
      isEmailValidated: data.isEmailValidated.present
          ? data.isEmailValidated.value
          : this.isEmailValidated,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsersTableData(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('name: $name, ')
          ..write('avatarIndex: $avatarIndex, ')
          ..write('selectedSubjects: $selectedSubjects, ')
          ..write('isEmailValidated: $isEmailValidated, ')
          ..write('isActive: $isActive, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    email,
    name,
    avatarIndex,
    selectedSubjects,
    isEmailValidated,
    isActive,
    syncStatus,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsersTableData &&
          other.id == this.id &&
          other.email == this.email &&
          other.name == this.name &&
          other.avatarIndex == this.avatarIndex &&
          other.selectedSubjects == this.selectedSubjects &&
          other.isEmailValidated == this.isEmailValidated &&
          other.isActive == this.isActive &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UsersTableCompanion extends UpdateCompanion<UsersTableData> {
  final Value<String> id;
  final Value<String> email;
  final Value<String> name;
  final Value<int> avatarIndex;
  final Value<String> selectedSubjects;
  final Value<bool> isEmailValidated;
  final Value<bool> isActive;
  final Value<int> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UsersTableCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarIndex = const Value.absent(),
    this.selectedSubjects = const Value.absent(),
    this.isEmailValidated = const Value.absent(),
    this.isActive = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersTableCompanion.insert({
    required String id,
    required String email,
    required String name,
    this.avatarIndex = const Value.absent(),
    this.selectedSubjects = const Value.absent(),
    this.isEmailValidated = const Value.absent(),
    this.isActive = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       email = Value(email),
       name = Value(name);
  static Insertable<UsersTableData> custom({
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? name,
    Expression<int>? avatarIndex,
    Expression<String>? selectedSubjects,
    Expression<bool>? isEmailValidated,
    Expression<bool>? isActive,
    Expression<int>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (name != null) 'name': name,
      if (avatarIndex != null) 'avatar_index': avatarIndex,
      if (selectedSubjects != null) 'selected_subjects': selectedSubjects,
      if (isEmailValidated != null) 'is_email_validated': isEmailValidated,
      if (isActive != null) 'is_active': isActive,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersTableCompanion copyWith({
    Value<String>? id,
    Value<String>? email,
    Value<String>? name,
    Value<int>? avatarIndex,
    Value<String>? selectedSubjects,
    Value<bool>? isEmailValidated,
    Value<bool>? isActive,
    Value<int>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UsersTableCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      selectedSubjects: selectedSubjects ?? this.selectedSubjects,
      isEmailValidated: isEmailValidated ?? this.isEmailValidated,
      isActive: isActive ?? this.isActive,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatarIndex.present) {
      map['avatar_index'] = Variable<int>(avatarIndex.value);
    }
    if (selectedSubjects.present) {
      map['selected_subjects'] = Variable<String>(selectedSubjects.value);
    }
    if (isEmailValidated.present) {
      map['is_email_validated'] = Variable<bool>(isEmailValidated.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersTableCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('name: $name, ')
          ..write('avatarIndex: $avatarIndex, ')
          ..write('selectedSubjects: $selectedSubjects, ')
          ..write('isEmailValidated: $isEmailValidated, ')
          ..write('isActive: $isActive, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserCoursesTableTable extends UserCoursesTable
    with TableInfo<$UserCoursesTableTable, UserCoursesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserCoursesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('downloaded'),
  );
  static const VerificationMeta _progressPercentMeta = const VerificationMeta(
    'progressPercent',
  );
  @override
  late final GeneratedColumn<int> progressPercent = GeneratedColumn<int>(
    'progress_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedLessonsMeta = const VerificationMeta(
    'completedLessons',
  );
  @override
  late final GeneratedColumn<int> completedLessons = GeneratedColumn<int>(
    'completed_lessons',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalLessonsMeta = const VerificationMeta(
    'totalLessons',
  );
  @override
  late final GeneratedColumn<int> totalLessons = GeneratedColumn<int>(
    'total_lessons',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentLessonIndexMeta =
      const VerificationMeta('currentLessonIndex');
  @override
  late final GeneratedColumn<int> currentLessonIndex = GeneratedColumn<int>(
    'current_lesson_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _timeSpentSecondsMeta = const VerificationMeta(
    'timeSpentSeconds',
  );
  @override
  late final GeneratedColumn<int> timeSpentSeconds = GeneratedColumn<int>(
    'time_spent_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _progressDataJsonMeta = const VerificationMeta(
    'progressDataJson',
  );
  @override
  late final GeneratedColumn<String> progressDataJson = GeneratedColumn<String>(
    'progress_data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _downloadedVersionMeta = const VerificationMeta(
    'downloadedVersion',
  );
  @override
  late final GeneratedColumn<int> downloadedVersion = GeneratedColumn<int>(
    'downloaded_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    userId,
    courseId,
    status,
    progressPercent,
    completedLessons,
    totalLessons,
    currentLessonIndex,
    timeSpentSeconds,
    progressDataJson,
    downloadedVersion,
    startedAt,
    completedAt,
    syncStatus,
    createdAt,
    updatedAt,
    serverUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_courses';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserCoursesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('progress_percent')) {
      context.handle(
        _progressPercentMeta,
        progressPercent.isAcceptableOrUnknown(
          data['progress_percent']!,
          _progressPercentMeta,
        ),
      );
    }
    if (data.containsKey('completed_lessons')) {
      context.handle(
        _completedLessonsMeta,
        completedLessons.isAcceptableOrUnknown(
          data['completed_lessons']!,
          _completedLessonsMeta,
        ),
      );
    }
    if (data.containsKey('total_lessons')) {
      context.handle(
        _totalLessonsMeta,
        totalLessons.isAcceptableOrUnknown(
          data['total_lessons']!,
          _totalLessonsMeta,
        ),
      );
    }
    if (data.containsKey('current_lesson_index')) {
      context.handle(
        _currentLessonIndexMeta,
        currentLessonIndex.isAcceptableOrUnknown(
          data['current_lesson_index']!,
          _currentLessonIndexMeta,
        ),
      );
    }
    if (data.containsKey('time_spent_seconds')) {
      context.handle(
        _timeSpentSecondsMeta,
        timeSpentSeconds.isAcceptableOrUnknown(
          data['time_spent_seconds']!,
          _timeSpentSecondsMeta,
        ),
      );
    }
    if (data.containsKey('progress_data_json')) {
      context.handle(
        _progressDataJsonMeta,
        progressDataJson.isAcceptableOrUnknown(
          data['progress_data_json']!,
          _progressDataJsonMeta,
        ),
      );
    }
    if (data.containsKey('downloaded_version')) {
      context.handle(
        _downloadedVersionMeta,
        downloadedVersion.isAcceptableOrUnknown(
          data['downloaded_version']!,
          _downloadedVersionMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserCoursesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserCoursesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      progressPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progress_percent'],
      )!,
      completedLessons: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_lessons'],
      )!,
      totalLessons: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_lessons'],
      )!,
      currentLessonIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_lesson_index'],
      )!,
      timeSpentSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_spent_seconds'],
      )!,
      progressDataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}progress_data_json'],
      )!,
      downloadedVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_version'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
    );
  }

  @override
  $UserCoursesTableTable createAlias(String alias) {
    return $UserCoursesTableTable(attachedDatabase, alias);
  }
}

class UserCoursesTableData extends DataClass
    implements Insertable<UserCoursesTableData> {
  /// Local unique identifier (UUID).
  final String id;

  /// Server-side ID (null if created offline and not yet synced).
  final int? serverId;

  /// The user who owns this course enrollment.
  final String userId;

  /// The course ID (references courses table).
  final String courseId;

  /// Status: downloaded, in_progress, completed.
  final String status;

  /// Overall progress percentage (0-100).
  final int progressPercent;

  /// Number of lessons completed.
  final int completedLessons;

  /// Total number of lessons in the course.
  final int totalLessons;

  /// Index of the current lesson (for resume functionality).
  final int currentLessonIndex;

  /// Total time spent on this course in seconds.
  final int timeSpentSeconds;

  /// JSON-encoded lesson-by-lesson progress data.
  final String progressDataJson;

  /// The version of the course that was downloaded.
  /// Used to detect when a newer version is available on the server.
  final int downloadedVersion;

  /// When the user started this course.
  final DateTime? startedAt;

  /// When the user completed this course.
  final DateTime? completedAt;

  /// Sync status: 0=synced, 1=pending, 2=conflict.
  final int syncStatus;

  /// When the record was created locally.
  final DateTime createdAt;

  /// When the record was last updated (local or remote).
  final DateTime updatedAt;

  /// Server's last update timestamp (for conflict detection).
  final DateTime? serverUpdatedAt;
  const UserCoursesTableData({
    required this.id,
    this.serverId,
    required this.userId,
    required this.courseId,
    required this.status,
    required this.progressPercent,
    required this.completedLessons,
    required this.totalLessons,
    required this.currentLessonIndex,
    required this.timeSpentSeconds,
    required this.progressDataJson,
    required this.downloadedVersion,
    this.startedAt,
    this.completedAt,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.serverUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['user_id'] = Variable<String>(userId);
    map['course_id'] = Variable<String>(courseId);
    map['status'] = Variable<String>(status);
    map['progress_percent'] = Variable<int>(progressPercent);
    map['completed_lessons'] = Variable<int>(completedLessons);
    map['total_lessons'] = Variable<int>(totalLessons);
    map['current_lesson_index'] = Variable<int>(currentLessonIndex);
    map['time_spent_seconds'] = Variable<int>(timeSpentSeconds);
    map['progress_data_json'] = Variable<String>(progressDataJson);
    map['downloaded_version'] = Variable<int>(downloadedVersion);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    return map;
  }

  UserCoursesTableCompanion toCompanion(bool nullToAbsent) {
    return UserCoursesTableCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      userId: Value(userId),
      courseId: Value(courseId),
      status: Value(status),
      progressPercent: Value(progressPercent),
      completedLessons: Value(completedLessons),
      totalLessons: Value(totalLessons),
      currentLessonIndex: Value(currentLessonIndex),
      timeSpentSeconds: Value(timeSpentSeconds),
      progressDataJson: Value(progressDataJson),
      downloadedVersion: Value(downloadedVersion),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
    );
  }

  factory UserCoursesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserCoursesTableData(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      userId: serializer.fromJson<String>(json['userId']),
      courseId: serializer.fromJson<String>(json['courseId']),
      status: serializer.fromJson<String>(json['status']),
      progressPercent: serializer.fromJson<int>(json['progressPercent']),
      completedLessons: serializer.fromJson<int>(json['completedLessons']),
      totalLessons: serializer.fromJson<int>(json['totalLessons']),
      currentLessonIndex: serializer.fromJson<int>(json['currentLessonIndex']),
      timeSpentSeconds: serializer.fromJson<int>(json['timeSpentSeconds']),
      progressDataJson: serializer.fromJson<String>(json['progressDataJson']),
      downloadedVersion: serializer.fromJson<int>(json['downloadedVersion']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'userId': serializer.toJson<String>(userId),
      'courseId': serializer.toJson<String>(courseId),
      'status': serializer.toJson<String>(status),
      'progressPercent': serializer.toJson<int>(progressPercent),
      'completedLessons': serializer.toJson<int>(completedLessons),
      'totalLessons': serializer.toJson<int>(totalLessons),
      'currentLessonIndex': serializer.toJson<int>(currentLessonIndex),
      'timeSpentSeconds': serializer.toJson<int>(timeSpentSeconds),
      'progressDataJson': serializer.toJson<String>(progressDataJson),
      'downloadedVersion': serializer.toJson<int>(downloadedVersion),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
    };
  }

  UserCoursesTableData copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? userId,
    String? courseId,
    String? status,
    int? progressPercent,
    int? completedLessons,
    int? totalLessons,
    int? currentLessonIndex,
    int? timeSpentSeconds,
    String? progressDataJson,
    int? downloadedVersion,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    int? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
  }) => UserCoursesTableData(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    userId: userId ?? this.userId,
    courseId: courseId ?? this.courseId,
    status: status ?? this.status,
    progressPercent: progressPercent ?? this.progressPercent,
    completedLessons: completedLessons ?? this.completedLessons,
    totalLessons: totalLessons ?? this.totalLessons,
    currentLessonIndex: currentLessonIndex ?? this.currentLessonIndex,
    timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
    progressDataJson: progressDataJson ?? this.progressDataJson,
    downloadedVersion: downloadedVersion ?? this.downloadedVersion,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
  );
  UserCoursesTableData copyWithCompanion(UserCoursesTableCompanion data) {
    return UserCoursesTableData(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      userId: data.userId.present ? data.userId.value : this.userId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      status: data.status.present ? data.status.value : this.status,
      progressPercent: data.progressPercent.present
          ? data.progressPercent.value
          : this.progressPercent,
      completedLessons: data.completedLessons.present
          ? data.completedLessons.value
          : this.completedLessons,
      totalLessons: data.totalLessons.present
          ? data.totalLessons.value
          : this.totalLessons,
      currentLessonIndex: data.currentLessonIndex.present
          ? data.currentLessonIndex.value
          : this.currentLessonIndex,
      timeSpentSeconds: data.timeSpentSeconds.present
          ? data.timeSpentSeconds.value
          : this.timeSpentSeconds,
      progressDataJson: data.progressDataJson.present
          ? data.progressDataJson.value
          : this.progressDataJson,
      downloadedVersion: data.downloadedVersion.present
          ? data.downloadedVersion.value
          : this.downloadedVersion,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserCoursesTableData(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('courseId: $courseId, ')
          ..write('status: $status, ')
          ..write('progressPercent: $progressPercent, ')
          ..write('completedLessons: $completedLessons, ')
          ..write('totalLessons: $totalLessons, ')
          ..write('currentLessonIndex: $currentLessonIndex, ')
          ..write('timeSpentSeconds: $timeSpentSeconds, ')
          ..write('progressDataJson: $progressDataJson, ')
          ..write('downloadedVersion: $downloadedVersion, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    userId,
    courseId,
    status,
    progressPercent,
    completedLessons,
    totalLessons,
    currentLessonIndex,
    timeSpentSeconds,
    progressDataJson,
    downloadedVersion,
    startedAt,
    completedAt,
    syncStatus,
    createdAt,
    updatedAt,
    serverUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserCoursesTableData &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.userId == this.userId &&
          other.courseId == this.courseId &&
          other.status == this.status &&
          other.progressPercent == this.progressPercent &&
          other.completedLessons == this.completedLessons &&
          other.totalLessons == this.totalLessons &&
          other.currentLessonIndex == this.currentLessonIndex &&
          other.timeSpentSeconds == this.timeSpentSeconds &&
          other.progressDataJson == this.progressDataJson &&
          other.downloadedVersion == this.downloadedVersion &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt);
}

class UserCoursesTableCompanion extends UpdateCompanion<UserCoursesTableData> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> userId;
  final Value<String> courseId;
  final Value<String> status;
  final Value<int> progressPercent;
  final Value<int> completedLessons;
  final Value<int> totalLessons;
  final Value<int> currentLessonIndex;
  final Value<int> timeSpentSeconds;
  final Value<String> progressDataJson;
  final Value<int> downloadedVersion;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> completedAt;
  final Value<int> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> serverUpdatedAt;
  final Value<int> rowid;
  const UserCoursesTableCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.userId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.status = const Value.absent(),
    this.progressPercent = const Value.absent(),
    this.completedLessons = const Value.absent(),
    this.totalLessons = const Value.absent(),
    this.currentLessonIndex = const Value.absent(),
    this.timeSpentSeconds = const Value.absent(),
    this.progressDataJson = const Value.absent(),
    this.downloadedVersion = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserCoursesTableCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String userId,
    required String courseId,
    this.status = const Value.absent(),
    this.progressPercent = const Value.absent(),
    this.completedLessons = const Value.absent(),
    this.totalLessons = const Value.absent(),
    this.currentLessonIndex = const Value.absent(),
    this.timeSpentSeconds = const Value.absent(),
    this.progressDataJson = const Value.absent(),
    this.downloadedVersion = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       courseId = Value(courseId);
  static Insertable<UserCoursesTableData> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? userId,
    Expression<String>? courseId,
    Expression<String>? status,
    Expression<int>? progressPercent,
    Expression<int>? completedLessons,
    Expression<int>? totalLessons,
    Expression<int>? currentLessonIndex,
    Expression<int>? timeSpentSeconds,
    Expression<String>? progressDataJson,
    Expression<int>? downloadedVersion,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (userId != null) 'user_id': userId,
      if (courseId != null) 'course_id': courseId,
      if (status != null) 'status': status,
      if (progressPercent != null) 'progress_percent': progressPercent,
      if (completedLessons != null) 'completed_lessons': completedLessons,
      if (totalLessons != null) 'total_lessons': totalLessons,
      if (currentLessonIndex != null)
        'current_lesson_index': currentLessonIndex,
      if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
      if (progressDataJson != null) 'progress_data_json': progressDataJson,
      if (downloadedVersion != null) 'downloaded_version': downloadedVersion,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserCoursesTableCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? userId,
    Value<String>? courseId,
    Value<String>? status,
    Value<int>? progressPercent,
    Value<int>? completedLessons,
    Value<int>? totalLessons,
    Value<int>? currentLessonIndex,
    Value<int>? timeSpentSeconds,
    Value<String>? progressDataJson,
    Value<int>? downloadedVersion,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? completedAt,
    Value<int>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? serverUpdatedAt,
    Value<int>? rowid,
  }) {
    return UserCoursesTableCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      completedLessons: completedLessons ?? this.completedLessons,
      totalLessons: totalLessons ?? this.totalLessons,
      currentLessonIndex: currentLessonIndex ?? this.currentLessonIndex,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      progressDataJson: progressDataJson ?? this.progressDataJson,
      downloadedVersion: downloadedVersion ?? this.downloadedVersion,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progressPercent.present) {
      map['progress_percent'] = Variable<int>(progressPercent.value);
    }
    if (completedLessons.present) {
      map['completed_lessons'] = Variable<int>(completedLessons.value);
    }
    if (totalLessons.present) {
      map['total_lessons'] = Variable<int>(totalLessons.value);
    }
    if (currentLessonIndex.present) {
      map['current_lesson_index'] = Variable<int>(currentLessonIndex.value);
    }
    if (timeSpentSeconds.present) {
      map['time_spent_seconds'] = Variable<int>(timeSpentSeconds.value);
    }
    if (progressDataJson.present) {
      map['progress_data_json'] = Variable<String>(progressDataJson.value);
    }
    if (downloadedVersion.present) {
      map['downloaded_version'] = Variable<int>(downloadedVersion.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserCoursesTableCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('courseId: $courseId, ')
          ..write('status: $status, ')
          ..write('progressPercent: $progressPercent, ')
          ..write('completedLessons: $completedLessons, ')
          ..write('totalLessons: $totalLessons, ')
          ..write('currentLessonIndex: $currentLessonIndex, ')
          ..write('timeSpentSeconds: $timeSpentSeconds, ')
          ..write('progressDataJson: $progressDataJson, ')
          ..write('downloadedVersion: $downloadedVersion, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserStatsTableTable extends UserStatsTable
    with TableInfo<$UserStatsTableTable, UserStatsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserStatsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _xpPointsMeta = const VerificationMeta(
    'xpPoints',
  );
  @override
  late final GeneratedColumn<int> xpPoints = GeneratedColumn<int>(
    'xp_points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _coursesCountMeta = const VerificationMeta(
    'coursesCount',
  );
  @override
  late final GeneratedColumn<int> coursesCount = GeneratedColumn<int>(
    'courses_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _streakDaysMeta = const VerificationMeta(
    'streakDays',
  );
  @override
  late final GeneratedColumn<int> streakDays = GeneratedColumn<int>(
    'streak_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _achievementsCountMeta = const VerificationMeta(
    'achievementsCount',
  );
  @override
  late final GeneratedColumn<int> achievementsCount = GeneratedColumn<int>(
    'achievements_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastStreakDateMeta = const VerificationMeta(
    'lastStreakDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastStreakDate =
      GeneratedColumn<DateTime>(
        'last_streak_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dailyXpDateMeta = const VerificationMeta(
    'dailyXpDate',
  );
  @override
  late final GeneratedColumn<DateTime> dailyXpDate = GeneratedColumn<DateTime>(
    'daily_xp_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dailyXpAmountMeta = const VerificationMeta(
    'dailyXpAmount',
  );
  @override
  late final GeneratedColumn<int> dailyXpAmount = GeneratedColumn<int>(
    'daily_xp_amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _coinsEarnedMeta = const VerificationMeta(
    'coinsEarned',
  );
  @override
  late final GeneratedColumn<int> coinsEarned = GeneratedColumn<int>(
    'coins_earned',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _coinsBalanceMeta = const VerificationMeta(
    'coinsBalance',
  );
  @override
  late final GeneratedColumn<int> coinsBalance = GeneratedColumn<int>(
    'coins_balance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    userId,
    level,
    xpPoints,
    coursesCount,
    streakDays,
    achievementsCount,
    lastStreakDate,
    dailyXpDate,
    dailyXpAmount,
    coinsEarned,
    coinsBalance,
    syncStatus,
    createdAt,
    updatedAt,
    serverUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserStatsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('xp_points')) {
      context.handle(
        _xpPointsMeta,
        xpPoints.isAcceptableOrUnknown(data['xp_points']!, _xpPointsMeta),
      );
    }
    if (data.containsKey('courses_count')) {
      context.handle(
        _coursesCountMeta,
        coursesCount.isAcceptableOrUnknown(
          data['courses_count']!,
          _coursesCountMeta,
        ),
      );
    }
    if (data.containsKey('streak_days')) {
      context.handle(
        _streakDaysMeta,
        streakDays.isAcceptableOrUnknown(data['streak_days']!, _streakDaysMeta),
      );
    }
    if (data.containsKey('achievements_count')) {
      context.handle(
        _achievementsCountMeta,
        achievementsCount.isAcceptableOrUnknown(
          data['achievements_count']!,
          _achievementsCountMeta,
        ),
      );
    }
    if (data.containsKey('last_streak_date')) {
      context.handle(
        _lastStreakDateMeta,
        lastStreakDate.isAcceptableOrUnknown(
          data['last_streak_date']!,
          _lastStreakDateMeta,
        ),
      );
    }
    if (data.containsKey('daily_xp_date')) {
      context.handle(
        _dailyXpDateMeta,
        dailyXpDate.isAcceptableOrUnknown(
          data['daily_xp_date']!,
          _dailyXpDateMeta,
        ),
      );
    }
    if (data.containsKey('daily_xp_amount')) {
      context.handle(
        _dailyXpAmountMeta,
        dailyXpAmount.isAcceptableOrUnknown(
          data['daily_xp_amount']!,
          _dailyXpAmountMeta,
        ),
      );
    }
    if (data.containsKey('coins_earned')) {
      context.handle(
        _coinsEarnedMeta,
        coinsEarned.isAcceptableOrUnknown(
          data['coins_earned']!,
          _coinsEarnedMeta,
        ),
      );
    }
    if (data.containsKey('coins_balance')) {
      context.handle(
        _coinsBalanceMeta,
        coinsBalance.isAcceptableOrUnknown(
          data['coins_balance']!,
          _coinsBalanceMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserStatsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserStatsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      xpPoints: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}xp_points'],
      )!,
      coursesCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}courses_count'],
      )!,
      streakDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak_days'],
      )!,
      achievementsCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}achievements_count'],
      )!,
      lastStreakDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_streak_date'],
      ),
      dailyXpDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}daily_xp_date'],
      ),
      dailyXpAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_xp_amount'],
      )!,
      coinsEarned: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coins_earned'],
      )!,
      coinsBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coins_balance'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
    );
  }

  @override
  $UserStatsTableTable createAlias(String alias) {
    return $UserStatsTableTable(attachedDatabase, alias);
  }
}

class UserStatsTableData extends DataClass
    implements Insertable<UserStatsTableData> {
  /// Local unique identifier (UUID).
  final String id;

  /// Server-side ID (null if created offline and not yet synced).
  final int? serverId;

  /// The user who owns these stats.
  final String userId;

  /// User's current level.
  final int level;

  /// User's experience points.
  final int xpPoints;

  /// Number of courses the user has (downloaded/completed).
  final int coursesCount;

  /// Current streak in days.
  final int streakDays;

  /// Number of achievements earned.
  final int achievementsCount;

  /// Date of last streak activity (for streak calculation).
  final DateTime? lastStreakDate;

  /// Date of last daily XP tracking (for daily soft cap).
  final DateTime? dailyXpDate;

  /// XP earned on the [dailyXpDate] (resets each new day).
  final int dailyXpAmount;

  /// EDUX coins earned over the account's lifetime — the number the
  /// Achievements screen shows. Only ever grows (BR-HK9828).
  final int coinsEarned;

  /// EDUX coins still available to spend. Tracked apart from [coinsEarned] so
  /// buying something in the shop cannot shrink what the student has earned.
  final int coinsBalance;

  /// Sync status: 0=synced, 1=pending, 2=conflict.
  final int syncStatus;

  /// When the record was created locally.
  final DateTime createdAt;

  /// When the record was last updated (local or remote).
  final DateTime updatedAt;

  /// Server's last update timestamp (for conflict detection).
  final DateTime? serverUpdatedAt;
  const UserStatsTableData({
    required this.id,
    this.serverId,
    required this.userId,
    required this.level,
    required this.xpPoints,
    required this.coursesCount,
    required this.streakDays,
    required this.achievementsCount,
    this.lastStreakDate,
    this.dailyXpDate,
    required this.dailyXpAmount,
    required this.coinsEarned,
    required this.coinsBalance,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.serverUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['user_id'] = Variable<String>(userId);
    map['level'] = Variable<int>(level);
    map['xp_points'] = Variable<int>(xpPoints);
    map['courses_count'] = Variable<int>(coursesCount);
    map['streak_days'] = Variable<int>(streakDays);
    map['achievements_count'] = Variable<int>(achievementsCount);
    if (!nullToAbsent || lastStreakDate != null) {
      map['last_streak_date'] = Variable<DateTime>(lastStreakDate);
    }
    if (!nullToAbsent || dailyXpDate != null) {
      map['daily_xp_date'] = Variable<DateTime>(dailyXpDate);
    }
    map['daily_xp_amount'] = Variable<int>(dailyXpAmount);
    map['coins_earned'] = Variable<int>(coinsEarned);
    map['coins_balance'] = Variable<int>(coinsBalance);
    map['sync_status'] = Variable<int>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    return map;
  }

  UserStatsTableCompanion toCompanion(bool nullToAbsent) {
    return UserStatsTableCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      userId: Value(userId),
      level: Value(level),
      xpPoints: Value(xpPoints),
      coursesCount: Value(coursesCount),
      streakDays: Value(streakDays),
      achievementsCount: Value(achievementsCount),
      lastStreakDate: lastStreakDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStreakDate),
      dailyXpDate: dailyXpDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dailyXpDate),
      dailyXpAmount: Value(dailyXpAmount),
      coinsEarned: Value(coinsEarned),
      coinsBalance: Value(coinsBalance),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
    );
  }

  factory UserStatsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserStatsTableData(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      userId: serializer.fromJson<String>(json['userId']),
      level: serializer.fromJson<int>(json['level']),
      xpPoints: serializer.fromJson<int>(json['xpPoints']),
      coursesCount: serializer.fromJson<int>(json['coursesCount']),
      streakDays: serializer.fromJson<int>(json['streakDays']),
      achievementsCount: serializer.fromJson<int>(json['achievementsCount']),
      lastStreakDate: serializer.fromJson<DateTime?>(json['lastStreakDate']),
      dailyXpDate: serializer.fromJson<DateTime?>(json['dailyXpDate']),
      dailyXpAmount: serializer.fromJson<int>(json['dailyXpAmount']),
      coinsEarned: serializer.fromJson<int>(json['coinsEarned']),
      coinsBalance: serializer.fromJson<int>(json['coinsBalance']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'userId': serializer.toJson<String>(userId),
      'level': serializer.toJson<int>(level),
      'xpPoints': serializer.toJson<int>(xpPoints),
      'coursesCount': serializer.toJson<int>(coursesCount),
      'streakDays': serializer.toJson<int>(streakDays),
      'achievementsCount': serializer.toJson<int>(achievementsCount),
      'lastStreakDate': serializer.toJson<DateTime?>(lastStreakDate),
      'dailyXpDate': serializer.toJson<DateTime?>(dailyXpDate),
      'dailyXpAmount': serializer.toJson<int>(dailyXpAmount),
      'coinsEarned': serializer.toJson<int>(coinsEarned),
      'coinsBalance': serializer.toJson<int>(coinsBalance),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
    };
  }

  UserStatsTableData copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    String? userId,
    int? level,
    int? xpPoints,
    int? coursesCount,
    int? streakDays,
    int? achievementsCount,
    Value<DateTime?> lastStreakDate = const Value.absent(),
    Value<DateTime?> dailyXpDate = const Value.absent(),
    int? dailyXpAmount,
    int? coinsEarned,
    int? coinsBalance,
    int? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
  }) => UserStatsTableData(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    userId: userId ?? this.userId,
    level: level ?? this.level,
    xpPoints: xpPoints ?? this.xpPoints,
    coursesCount: coursesCount ?? this.coursesCount,
    streakDays: streakDays ?? this.streakDays,
    achievementsCount: achievementsCount ?? this.achievementsCount,
    lastStreakDate: lastStreakDate.present
        ? lastStreakDate.value
        : this.lastStreakDate,
    dailyXpDate: dailyXpDate.present ? dailyXpDate.value : this.dailyXpDate,
    dailyXpAmount: dailyXpAmount ?? this.dailyXpAmount,
    coinsEarned: coinsEarned ?? this.coinsEarned,
    coinsBalance: coinsBalance ?? this.coinsBalance,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
  );
  UserStatsTableData copyWithCompanion(UserStatsTableCompanion data) {
    return UserStatsTableData(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      userId: data.userId.present ? data.userId.value : this.userId,
      level: data.level.present ? data.level.value : this.level,
      xpPoints: data.xpPoints.present ? data.xpPoints.value : this.xpPoints,
      coursesCount: data.coursesCount.present
          ? data.coursesCount.value
          : this.coursesCount,
      streakDays: data.streakDays.present
          ? data.streakDays.value
          : this.streakDays,
      achievementsCount: data.achievementsCount.present
          ? data.achievementsCount.value
          : this.achievementsCount,
      lastStreakDate: data.lastStreakDate.present
          ? data.lastStreakDate.value
          : this.lastStreakDate,
      dailyXpDate: data.dailyXpDate.present
          ? data.dailyXpDate.value
          : this.dailyXpDate,
      dailyXpAmount: data.dailyXpAmount.present
          ? data.dailyXpAmount.value
          : this.dailyXpAmount,
      coinsEarned: data.coinsEarned.present
          ? data.coinsEarned.value
          : this.coinsEarned,
      coinsBalance: data.coinsBalance.present
          ? data.coinsBalance.value
          : this.coinsBalance,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserStatsTableData(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('level: $level, ')
          ..write('xpPoints: $xpPoints, ')
          ..write('coursesCount: $coursesCount, ')
          ..write('streakDays: $streakDays, ')
          ..write('achievementsCount: $achievementsCount, ')
          ..write('lastStreakDate: $lastStreakDate, ')
          ..write('dailyXpDate: $dailyXpDate, ')
          ..write('dailyXpAmount: $dailyXpAmount, ')
          ..write('coinsEarned: $coinsEarned, ')
          ..write('coinsBalance: $coinsBalance, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    userId,
    level,
    xpPoints,
    coursesCount,
    streakDays,
    achievementsCount,
    lastStreakDate,
    dailyXpDate,
    dailyXpAmount,
    coinsEarned,
    coinsBalance,
    syncStatus,
    createdAt,
    updatedAt,
    serverUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserStatsTableData &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.userId == this.userId &&
          other.level == this.level &&
          other.xpPoints == this.xpPoints &&
          other.coursesCount == this.coursesCount &&
          other.streakDays == this.streakDays &&
          other.achievementsCount == this.achievementsCount &&
          other.lastStreakDate == this.lastStreakDate &&
          other.dailyXpDate == this.dailyXpDate &&
          other.dailyXpAmount == this.dailyXpAmount &&
          other.coinsEarned == this.coinsEarned &&
          other.coinsBalance == this.coinsBalance &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt);
}

class UserStatsTableCompanion extends UpdateCompanion<UserStatsTableData> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<String> userId;
  final Value<int> level;
  final Value<int> xpPoints;
  final Value<int> coursesCount;
  final Value<int> streakDays;
  final Value<int> achievementsCount;
  final Value<DateTime?> lastStreakDate;
  final Value<DateTime?> dailyXpDate;
  final Value<int> dailyXpAmount;
  final Value<int> coinsEarned;
  final Value<int> coinsBalance;
  final Value<int> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> serverUpdatedAt;
  final Value<int> rowid;
  const UserStatsTableCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.userId = const Value.absent(),
    this.level = const Value.absent(),
    this.xpPoints = const Value.absent(),
    this.coursesCount = const Value.absent(),
    this.streakDays = const Value.absent(),
    this.achievementsCount = const Value.absent(),
    this.lastStreakDate = const Value.absent(),
    this.dailyXpDate = const Value.absent(),
    this.dailyXpAmount = const Value.absent(),
    this.coinsEarned = const Value.absent(),
    this.coinsBalance = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserStatsTableCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String userId,
    this.level = const Value.absent(),
    this.xpPoints = const Value.absent(),
    this.coursesCount = const Value.absent(),
    this.streakDays = const Value.absent(),
    this.achievementsCount = const Value.absent(),
    this.lastStreakDate = const Value.absent(),
    this.dailyXpDate = const Value.absent(),
    this.dailyXpAmount = const Value.absent(),
    this.coinsEarned = const Value.absent(),
    this.coinsBalance = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId);
  static Insertable<UserStatsTableData> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<String>? userId,
    Expression<int>? level,
    Expression<int>? xpPoints,
    Expression<int>? coursesCount,
    Expression<int>? streakDays,
    Expression<int>? achievementsCount,
    Expression<DateTime>? lastStreakDate,
    Expression<DateTime>? dailyXpDate,
    Expression<int>? dailyXpAmount,
    Expression<int>? coinsEarned,
    Expression<int>? coinsBalance,
    Expression<int>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (userId != null) 'user_id': userId,
      if (level != null) 'level': level,
      if (xpPoints != null) 'xp_points': xpPoints,
      if (coursesCount != null) 'courses_count': coursesCount,
      if (streakDays != null) 'streak_days': streakDays,
      if (achievementsCount != null) 'achievements_count': achievementsCount,
      if (lastStreakDate != null) 'last_streak_date': lastStreakDate,
      if (dailyXpDate != null) 'daily_xp_date': dailyXpDate,
      if (dailyXpAmount != null) 'daily_xp_amount': dailyXpAmount,
      if (coinsEarned != null) 'coins_earned': coinsEarned,
      if (coinsBalance != null) 'coins_balance': coinsBalance,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserStatsTableCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<String>? userId,
    Value<int>? level,
    Value<int>? xpPoints,
    Value<int>? coursesCount,
    Value<int>? streakDays,
    Value<int>? achievementsCount,
    Value<DateTime?>? lastStreakDate,
    Value<DateTime?>? dailyXpDate,
    Value<int>? dailyXpAmount,
    Value<int>? coinsEarned,
    Value<int>? coinsBalance,
    Value<int>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? serverUpdatedAt,
    Value<int>? rowid,
  }) {
    return UserStatsTableCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      level: level ?? this.level,
      xpPoints: xpPoints ?? this.xpPoints,
      coursesCount: coursesCount ?? this.coursesCount,
      streakDays: streakDays ?? this.streakDays,
      achievementsCount: achievementsCount ?? this.achievementsCount,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
      dailyXpDate: dailyXpDate ?? this.dailyXpDate,
      dailyXpAmount: dailyXpAmount ?? this.dailyXpAmount,
      coinsEarned: coinsEarned ?? this.coinsEarned,
      coinsBalance: coinsBalance ?? this.coinsBalance,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (xpPoints.present) {
      map['xp_points'] = Variable<int>(xpPoints.value);
    }
    if (coursesCount.present) {
      map['courses_count'] = Variable<int>(coursesCount.value);
    }
    if (streakDays.present) {
      map['streak_days'] = Variable<int>(streakDays.value);
    }
    if (achievementsCount.present) {
      map['achievements_count'] = Variable<int>(achievementsCount.value);
    }
    if (lastStreakDate.present) {
      map['last_streak_date'] = Variable<DateTime>(lastStreakDate.value);
    }
    if (dailyXpDate.present) {
      map['daily_xp_date'] = Variable<DateTime>(dailyXpDate.value);
    }
    if (dailyXpAmount.present) {
      map['daily_xp_amount'] = Variable<int>(dailyXpAmount.value);
    }
    if (coinsEarned.present) {
      map['coins_earned'] = Variable<int>(coinsEarned.value);
    }
    if (coinsBalance.present) {
      map['coins_balance'] = Variable<int>(coinsBalance.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserStatsTableCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('level: $level, ')
          ..write('xpPoints: $xpPoints, ')
          ..write('coursesCount: $coursesCount, ')
          ..write('streakDays: $streakDays, ')
          ..write('achievementsCount: $achievementsCount, ')
          ..write('lastStreakDate: $lastStreakDate, ')
          ..write('dailyXpDate: $dailyXpDate, ')
          ..write('dailyXpAmount: $dailyXpAmount, ')
          ..write('coinsEarned: $coinsEarned, ')
          ..write('coinsBalance: $coinsBalance, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTableTable extends BookmarksTable
    with TableInfo<$BookmarksTableTable, BookmarksTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    courseId,
    blockId,
    lessonId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookmarksTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blockIdMeta);
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookmarksTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarksTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BookmarksTableTable createAlias(String alias) {
    return $BookmarksTableTable(attachedDatabase, alias);
  }
}

class BookmarksTableData extends DataClass
    implements Insertable<BookmarksTableData> {
  /// Local unique identifier (UUID).
  final String id;

  /// The user who owns this bookmark.
  final String userId;

  /// The course containing the bookmarked block.
  final String courseId;

  /// The block ID within the course.
  final String blockId;

  /// The lesson containing the bookmarked block.
  final String lessonId;

  /// When the bookmark was created.
  final DateTime createdAt;
  const BookmarksTableData({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.blockId,
    required this.lessonId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['course_id'] = Variable<String>(courseId);
    map['block_id'] = Variable<String>(blockId);
    map['lesson_id'] = Variable<String>(lessonId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookmarksTableCompanion toCompanion(bool nullToAbsent) {
    return BookmarksTableCompanion(
      id: Value(id),
      userId: Value(userId),
      courseId: Value(courseId),
      blockId: Value(blockId),
      lessonId: Value(lessonId),
      createdAt: Value(createdAt),
    );
  }

  factory BookmarksTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarksTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      courseId: serializer.fromJson<String>(json['courseId']),
      blockId: serializer.fromJson<String>(json['blockId']),
      lessonId: serializer.fromJson<String>(json['lessonId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'courseId': serializer.toJson<String>(courseId),
      'blockId': serializer.toJson<String>(blockId),
      'lessonId': serializer.toJson<String>(lessonId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BookmarksTableData copyWith({
    String? id,
    String? userId,
    String? courseId,
    String? blockId,
    String? lessonId,
    DateTime? createdAt,
  }) => BookmarksTableData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    courseId: courseId ?? this.courseId,
    blockId: blockId ?? this.blockId,
    lessonId: lessonId ?? this.lessonId,
    createdAt: createdAt ?? this.createdAt,
  );
  BookmarksTableData copyWithCompanion(BookmarksTableCompanion data) {
    return BookmarksTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('courseId: $courseId, ')
          ..write('blockId: $blockId, ')
          ..write('lessonId: $lessonId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, courseId, blockId, lessonId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarksTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.courseId == this.courseId &&
          other.blockId == this.blockId &&
          other.lessonId == this.lessonId &&
          other.createdAt == this.createdAt);
}

class BookmarksTableCompanion extends UpdateCompanion<BookmarksTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> courseId;
  final Value<String> blockId;
  final Value<String> lessonId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BookmarksTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.blockId = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksTableCompanion.insert({
    required String id,
    required String userId,
    required String courseId,
    required String blockId,
    this.lessonId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       courseId = Value(courseId),
       blockId = Value(blockId);
  static Insertable<BookmarksTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? courseId,
    Expression<String>? blockId,
    Expression<String>? lessonId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (courseId != null) 'course_id': courseId,
      if (blockId != null) 'block_id': blockId,
      if (lessonId != null) 'lesson_id': lessonId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksTableCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? courseId,
    Value<String>? blockId,
    Value<String>? lessonId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BookmarksTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      blockId: blockId ?? this.blockId,
      lessonId: lessonId ?? this.lessonId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('courseId: $courseId, ')
          ..write('blockId: $blockId, ')
          ..write('lessonId: $lessonId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserEloProfileTableTable extends UserEloProfileTable
    with TableInfo<$UserEloProfileTableTable, UserEloProfileTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserEloProfileTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profilEloMeta = const VerificationMeta(
    'profilElo',
  );
  @override
  late final GeneratedColumn<String> profilElo = GeneratedColumn<String>(
    'profil_elo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profilPocetMeta = const VerificationMeta(
    'profilPocet',
  );
  @override
  late final GeneratedColumn<String> profilPocet = GeneratedColumn<String>(
    'profil_pocet',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    profilElo,
    profilPocet,
    syncStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_elo_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserEloProfileTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('profil_elo')) {
      context.handle(
        _profilEloMeta,
        profilElo.isAcceptableOrUnknown(data['profil_elo']!, _profilEloMeta),
      );
    } else if (isInserting) {
      context.missing(_profilEloMeta);
    }
    if (data.containsKey('profil_pocet')) {
      context.handle(
        _profilPocetMeta,
        profilPocet.isAcceptableOrUnknown(
          data['profil_pocet']!,
          _profilPocetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_profilPocetMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserEloProfileTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserEloProfileTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      profilElo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profil_elo'],
      )!,
      profilPocet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profil_pocet'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserEloProfileTableTable createAlias(String alias) {
    return $UserEloProfileTableTable(attachedDatabase, alias);
  }
}

class UserEloProfileTableData extends DataClass
    implements Insertable<UserEloProfileTableData> {
  /// Local unique identifier (UUID).
  final String id;

  /// The user who owns this profile.
  final String userId;

  /// JSON-encoded list of 35 doubles (nullable per element) — student ELO.
  final String profilElo;

  /// JSON-encoded list of 35 ints — per-subconstruct task counts.
  final String profilPocet;

  /// Sync status: 0=synced, 1=pending, 2=conflict.
  final int syncStatus;

  /// When the record was created locally.
  final DateTime createdAt;

  /// When the record was last updated (local or remote).
  final DateTime updatedAt;
  const UserEloProfileTableData({
    required this.id,
    required this.userId,
    required this.profilElo,
    required this.profilPocet,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['profil_elo'] = Variable<String>(profilElo);
    map['profil_pocet'] = Variable<String>(profilPocet);
    map['sync_status'] = Variable<int>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserEloProfileTableCompanion toCompanion(bool nullToAbsent) {
    return UserEloProfileTableCompanion(
      id: Value(id),
      userId: Value(userId),
      profilElo: Value(profilElo),
      profilPocet: Value(profilPocet),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserEloProfileTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserEloProfileTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      profilElo: serializer.fromJson<String>(json['profilElo']),
      profilPocet: serializer.fromJson<String>(json['profilPocet']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'profilElo': serializer.toJson<String>(profilElo),
      'profilPocet': serializer.toJson<String>(profilPocet),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserEloProfileTableData copyWith({
    String? id,
    String? userId,
    String? profilElo,
    String? profilPocet,
    int? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserEloProfileTableData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    profilElo: profilElo ?? this.profilElo,
    profilPocet: profilPocet ?? this.profilPocet,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserEloProfileTableData copyWithCompanion(UserEloProfileTableCompanion data) {
    return UserEloProfileTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      profilElo: data.profilElo.present ? data.profilElo.value : this.profilElo,
      profilPocet: data.profilPocet.present
          ? data.profilPocet.value
          : this.profilPocet,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserEloProfileTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('profilElo: $profilElo, ')
          ..write('profilPocet: $profilPocet, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    profilElo,
    profilPocet,
    syncStatus,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserEloProfileTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.profilElo == this.profilElo &&
          other.profilPocet == this.profilPocet &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserEloProfileTableCompanion
    extends UpdateCompanion<UserEloProfileTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> profilElo;
  final Value<String> profilPocet;
  final Value<int> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserEloProfileTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.profilElo = const Value.absent(),
    this.profilPocet = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserEloProfileTableCompanion.insert({
    required String id,
    required String userId,
    required String profilElo,
    required String profilPocet,
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       profilElo = Value(profilElo),
       profilPocet = Value(profilPocet);
  static Insertable<UserEloProfileTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? profilElo,
    Expression<String>? profilPocet,
    Expression<int>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (profilElo != null) 'profil_elo': profilElo,
      if (profilPocet != null) 'profil_pocet': profilPocet,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserEloProfileTableCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? profilElo,
    Value<String>? profilPocet,
    Value<int>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserEloProfileTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      profilElo: profilElo ?? this.profilElo,
      profilPocet: profilPocet ?? this.profilPocet,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (profilElo.present) {
      map['profil_elo'] = Variable<String>(profilElo.value);
    }
    if (profilPocet.present) {
      map['profil_pocet'] = Variable<String>(profilPocet.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserEloProfileTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('profilElo: $profilElo, ')
          ..write('profilPocet: $profilPocet, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GamificationConfigTableTable extends GamificationConfigTable
    with TableInfo<$GamificationConfigTableTable, GamificationConfigTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GamificationConfigTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, version, configJson, downloadedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gamification_config';
  @override
  VerificationContext validateIntegrity(
    Insertable<GamificationConfigTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GamificationConfigTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GamificationConfigTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      )!,
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      )!,
    );
  }

  @override
  $GamificationConfigTableTable createAlias(String alias) {
    return $GamificationConfigTableTable(attachedDatabase, alias);
  }
}

class GamificationConfigTableData extends DataClass
    implements Insertable<GamificationConfigTableData> {
  /// Fixed PK — always "config".
  final String id;

  /// Config version from server (used for staleness checks).
  final int version;

  /// Full JSON string of the config payload.
  final String configJson;

  /// When the config was last downloaded.
  final DateTime downloadedAt;
  const GamificationConfigTableData({
    required this.id,
    required this.version,
    required this.configJson,
    required this.downloadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    map['config_json'] = Variable<String>(configJson);
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  GamificationConfigTableCompanion toCompanion(bool nullToAbsent) {
    return GamificationConfigTableCompanion(
      id: Value(id),
      version: Value(version),
      configJson: Value(configJson),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory GamificationConfigTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GamificationConfigTableData(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      configJson: serializer.fromJson<String>(json['configJson']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'configJson': serializer.toJson<String>(configJson),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  GamificationConfigTableData copyWith({
    String? id,
    int? version,
    String? configJson,
    DateTime? downloadedAt,
  }) => GamificationConfigTableData(
    id: id ?? this.id,
    version: version ?? this.version,
    configJson: configJson ?? this.configJson,
    downloadedAt: downloadedAt ?? this.downloadedAt,
  );
  GamificationConfigTableData copyWithCompanion(
    GamificationConfigTableCompanion data,
  ) {
    return GamificationConfigTableData(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GamificationConfigTableData(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('configJson: $configJson, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, version, configJson, downloadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GamificationConfigTableData &&
          other.id == this.id &&
          other.version == this.version &&
          other.configJson == this.configJson &&
          other.downloadedAt == this.downloadedAt);
}

class GamificationConfigTableCompanion
    extends UpdateCompanion<GamificationConfigTableData> {
  final Value<String> id;
  final Value<int> version;
  final Value<String> configJson;
  final Value<DateTime> downloadedAt;
  final Value<int> rowid;
  const GamificationConfigTableCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.configJson = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GamificationConfigTableCompanion.insert({
    required String id,
    this.version = const Value.absent(),
    this.configJson = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<GamificationConfigTableData> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<String>? configJson,
    Expression<DateTime>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (configJson != null) 'config_json': configJson,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GamificationConfigTableCompanion copyWith({
    Value<String>? id,
    Value<int>? version,
    Value<String>? configJson,
    Value<DateTime>? downloadedAt,
    Value<int>? rowid,
  }) {
    return GamificationConfigTableCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      configJson: configJson ?? this.configJson,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GamificationConfigTableCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('configJson: $configJson, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserAchievementsTableTable extends UserAchievementsTable
    with TableInfo<$UserAchievementsTableTable, UserAchievementsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserAchievementsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _achievementIdMeta = const VerificationMeta(
    'achievementId',
  );
  @override
  late final GeneratedColumn<String> achievementId = GeneratedColumn<String>(
    'achievement_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _earnedAtMeta = const VerificationMeta(
    'earnedAt',
  );
  @override
  late final GeneratedColumn<DateTime> earnedAt = GeneratedColumn<DateTime>(
    'earned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    achievementId,
    earnedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_achievements';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserAchievementsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('achievement_id')) {
      context.handle(
        _achievementIdMeta,
        achievementId.isAcceptableOrUnknown(
          data['achievement_id']!,
          _achievementIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_achievementIdMeta);
    }
    if (data.containsKey('earned_at')) {
      context.handle(
        _earnedAtMeta,
        earnedAt.isAcceptableOrUnknown(data['earned_at']!, _earnedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {userId, achievementId},
  ];
  @override
  UserAchievementsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserAchievementsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      achievementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}achievement_id'],
      )!,
      earnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}earned_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $UserAchievementsTableTable createAlias(String alias) {
    return $UserAchievementsTableTable(attachedDatabase, alias);
  }
}

class UserAchievementsTableData extends DataClass
    implements Insertable<UserAchievementsTableData> {
  /// Local unique identifier (UUID).
  final String id;

  /// The user who earned this achievement.
  final String userId;

  /// Matches trophy/goal/challenge ID from the gamification config.
  final String achievementId;

  /// When the achievement was earned.
  final DateTime earnedAt;

  /// Sync status: 0=synced, 1=pending.
  final int syncStatus;
  const UserAchievementsTableData({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.earnedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['achievement_id'] = Variable<String>(achievementId);
    map['earned_at'] = Variable<DateTime>(earnedAt);
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  UserAchievementsTableCompanion toCompanion(bool nullToAbsent) {
    return UserAchievementsTableCompanion(
      id: Value(id),
      userId: Value(userId),
      achievementId: Value(achievementId),
      earnedAt: Value(earnedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory UserAchievementsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserAchievementsTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      achievementId: serializer.fromJson<String>(json['achievementId']),
      earnedAt: serializer.fromJson<DateTime>(json['earnedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'achievementId': serializer.toJson<String>(achievementId),
      'earnedAt': serializer.toJson<DateTime>(earnedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  UserAchievementsTableData copyWith({
    String? id,
    String? userId,
    String? achievementId,
    DateTime? earnedAt,
    int? syncStatus,
  }) => UserAchievementsTableData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    achievementId: achievementId ?? this.achievementId,
    earnedAt: earnedAt ?? this.earnedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  UserAchievementsTableData copyWithCompanion(
    UserAchievementsTableCompanion data,
  ) {
    return UserAchievementsTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      achievementId: data.achievementId.present
          ? data.achievementId.value
          : this.achievementId,
      earnedAt: data.earnedAt.present ? data.earnedAt.value : this.earnedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserAchievementsTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('achievementId: $achievementId, ')
          ..write('earnedAt: $earnedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, achievementId, earnedAt, syncStatus);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserAchievementsTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.achievementId == this.achievementId &&
          other.earnedAt == this.earnedAt &&
          other.syncStatus == this.syncStatus);
}

class UserAchievementsTableCompanion
    extends UpdateCompanion<UserAchievementsTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> achievementId;
  final Value<DateTime> earnedAt;
  final Value<int> syncStatus;
  final Value<int> rowid;
  const UserAchievementsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.achievementId = const Value.absent(),
    this.earnedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserAchievementsTableCompanion.insert({
    required String id,
    required String userId,
    required String achievementId,
    this.earnedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       achievementId = Value(achievementId);
  static Insertable<UserAchievementsTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? achievementId,
    Expression<DateTime>? earnedAt,
    Expression<int>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (achievementId != null) 'achievement_id': achievementId,
      if (earnedAt != null) 'earned_at': earnedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserAchievementsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? achievementId,
    Value<DateTime>? earnedAt,
    Value<int>? syncStatus,
    Value<int>? rowid,
  }) {
    return UserAchievementsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      achievementId: achievementId ?? this.achievementId,
      earnedAt: earnedAt ?? this.earnedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (achievementId.present) {
      map['achievement_id'] = Variable<String>(achievementId.value);
    }
    if (earnedAt.present) {
      map['earned_at'] = Variable<DateTime>(earnedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserAchievementsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('achievementId: $achievementId, ')
          ..write('earnedAt: $earnedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlockStatsTableTable extends BlockStatsTable
    with TableInfo<$BlockStatsTableTable, BlockStatsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlockStatsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemPocetMeta = const VerificationMeta(
    'itemPocet',
  );
  @override
  late final GeneratedColumn<String> itemPocet = GeneratedColumn<String>(
    'item_pocet',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eloVectorMeta = const VerificationMeta(
    'eloVector',
  );
  @override
  late final GeneratedColumn<String> eloVector = GeneratedColumn<String>(
    'elo_vector',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    blockId,
    itemPocet,
    eloVector,
    courseId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'block_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlockStatsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blockIdMeta);
    }
    if (data.containsKey('item_pocet')) {
      context.handle(
        _itemPocetMeta,
        itemPocet.isAcceptableOrUnknown(data['item_pocet']!, _itemPocetMeta),
      );
    } else if (isInserting) {
      context.missing(_itemPocetMeta);
    }
    if (data.containsKey('elo_vector')) {
      context.handle(
        _eloVectorMeta,
        eloVector.isAcceptableOrUnknown(data['elo_vector']!, _eloVectorMeta),
      );
    } else if (isInserting) {
      context.missing(_eloVectorMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {blockId};
  @override
  BlockStatsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlockStatsTableData(
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      )!,
      itemPocet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_pocet'],
      )!,
      eloVector: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}elo_vector'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BlockStatsTableTable createAlias(String alias) {
    return $BlockStatsTableTable(attachedDatabase, alias);
  }
}

class BlockStatsTableData extends DataClass
    implements Insertable<BlockStatsTableData> {
  final String blockId;
  final String itemPocet;
  final String eloVector;

  /// The downloaded course whose pull wrote this row — the per-course cursor
  /// of the next pull. Null on rows from before schema 21 (none survive it).
  final String? courseId;

  /// The server's `updated_at` for the row.
  final DateTime updatedAt;
  const BlockStatsTableData({
    required this.blockId,
    required this.itemPocet,
    required this.eloVector,
    this.courseId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['block_id'] = Variable<String>(blockId);
    map['item_pocet'] = Variable<String>(itemPocet);
    map['elo_vector'] = Variable<String>(eloVector);
    if (!nullToAbsent || courseId != null) {
      map['course_id'] = Variable<String>(courseId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BlockStatsTableCompanion toCompanion(bool nullToAbsent) {
    return BlockStatsTableCompanion(
      blockId: Value(blockId),
      itemPocet: Value(itemPocet),
      eloVector: Value(eloVector),
      courseId: courseId == null && nullToAbsent
          ? const Value.absent()
          : Value(courseId),
      updatedAt: Value(updatedAt),
    );
  }

  factory BlockStatsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlockStatsTableData(
      blockId: serializer.fromJson<String>(json['blockId']),
      itemPocet: serializer.fromJson<String>(json['itemPocet']),
      eloVector: serializer.fromJson<String>(json['eloVector']),
      courseId: serializer.fromJson<String?>(json['courseId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'blockId': serializer.toJson<String>(blockId),
      'itemPocet': serializer.toJson<String>(itemPocet),
      'eloVector': serializer.toJson<String>(eloVector),
      'courseId': serializer.toJson<String?>(courseId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BlockStatsTableData copyWith({
    String? blockId,
    String? itemPocet,
    String? eloVector,
    Value<String?> courseId = const Value.absent(),
    DateTime? updatedAt,
  }) => BlockStatsTableData(
    blockId: blockId ?? this.blockId,
    itemPocet: itemPocet ?? this.itemPocet,
    eloVector: eloVector ?? this.eloVector,
    courseId: courseId.present ? courseId.value : this.courseId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BlockStatsTableData copyWithCompanion(BlockStatsTableCompanion data) {
    return BlockStatsTableData(
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      itemPocet: data.itemPocet.present ? data.itemPocet.value : this.itemPocet,
      eloVector: data.eloVector.present ? data.eloVector.value : this.eloVector,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlockStatsTableData(')
          ..write('blockId: $blockId, ')
          ..write('itemPocet: $itemPocet, ')
          ..write('eloVector: $eloVector, ')
          ..write('courseId: $courseId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(blockId, itemPocet, eloVector, courseId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockStatsTableData &&
          other.blockId == this.blockId &&
          other.itemPocet == this.itemPocet &&
          other.eloVector == this.eloVector &&
          other.courseId == this.courseId &&
          other.updatedAt == this.updatedAt);
}

class BlockStatsTableCompanion extends UpdateCompanion<BlockStatsTableData> {
  final Value<String> blockId;
  final Value<String> itemPocet;
  final Value<String> eloVector;
  final Value<String?> courseId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BlockStatsTableCompanion({
    this.blockId = const Value.absent(),
    this.itemPocet = const Value.absent(),
    this.eloVector = const Value.absent(),
    this.courseId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlockStatsTableCompanion.insert({
    required String blockId,
    required String itemPocet,
    required String eloVector,
    this.courseId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : blockId = Value(blockId),
       itemPocet = Value(itemPocet),
       eloVector = Value(eloVector);
  static Insertable<BlockStatsTableData> custom({
    Expression<String>? blockId,
    Expression<String>? itemPocet,
    Expression<String>? eloVector,
    Expression<String>? courseId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (blockId != null) 'block_id': blockId,
      if (itemPocet != null) 'item_pocet': itemPocet,
      if (eloVector != null) 'elo_vector': eloVector,
      if (courseId != null) 'course_id': courseId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlockStatsTableCompanion copyWith({
    Value<String>? blockId,
    Value<String>? itemPocet,
    Value<String>? eloVector,
    Value<String?>? courseId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BlockStatsTableCompanion(
      blockId: blockId ?? this.blockId,
      itemPocet: itemPocet ?? this.itemPocet,
      eloVector: eloVector ?? this.eloVector,
      courseId: courseId ?? this.courseId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (itemPocet.present) {
      map['item_pocet'] = Variable<String>(itemPocet.value);
    }
    if (eloVector.present) {
      map['elo_vector'] = Variable<String>(eloVector.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlockStatsTableCompanion(')
          ..write('blockId: $blockId, ')
          ..write('itemPocet: $itemPocet, ')
          ..write('eloVector: $eloVector, ')
          ..write('courseId: $courseId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatSessionsTableTable extends ChatSessionsTable
    with TableInfo<$ChatSessionsTableTable, ChatSessionsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatSessionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _personaMeta = const VerificationMeta(
    'persona',
  );
  @override
  late final GeneratedColumn<String> persona = GeneratedColumn<String>(
    'persona',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ai_teacher'),
  );
  static const VerificationMeta _lastMessageAtMeta = const VerificationMeta(
    'lastMessageAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastMessageAt =
      GeneratedColumn<DateTime>(
        'last_message_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    serverId,
    title,
    persona,
    lastMessageAt,
    syncStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatSessionsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('persona')) {
      context.handle(
        _personaMeta,
        persona.isAcceptableOrUnknown(data['persona']!, _personaMeta),
      );
    }
    if (data.containsKey('last_message_at')) {
      context.handle(
        _lastMessageAtMeta,
        lastMessageAt.isAcceptableOrUnknown(
          data['last_message_at']!,
          _lastMessageAtMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatSessionsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatSessionsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      persona: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona'],
      )!,
      lastMessageAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_message_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChatSessionsTableTable createAlias(String alias) {
    return $ChatSessionsTableTable(attachedDatabase, alias);
  }
}

class ChatSessionsTableData extends DataClass
    implements Insertable<ChatSessionsTableData> {
  final String id;
  final String userId;
  final int? serverId;
  final String title;
  final String persona;
  final DateTime lastMessageAt;
  final String syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ChatSessionsTableData({
    required this.id,
    required this.userId,
    this.serverId,
    required this.title,
    required this.persona,
    required this.lastMessageAt,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['title'] = Variable<String>(title);
    map['persona'] = Variable<String>(persona);
    map['last_message_at'] = Variable<DateTime>(lastMessageAt);
    map['sync_status'] = Variable<String>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChatSessionsTableCompanion toCompanion(bool nullToAbsent) {
    return ChatSessionsTableCompanion(
      id: Value(id),
      userId: Value(userId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      title: Value(title),
      persona: Value(persona),
      lastMessageAt: Value(lastMessageAt),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChatSessionsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatSessionsTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      title: serializer.fromJson<String>(json['title']),
      persona: serializer.fromJson<String>(json['persona']),
      lastMessageAt: serializer.fromJson<DateTime>(json['lastMessageAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'serverId': serializer.toJson<int?>(serverId),
      'title': serializer.toJson<String>(title),
      'persona': serializer.toJson<String>(persona),
      'lastMessageAt': serializer.toJson<DateTime>(lastMessageAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ChatSessionsTableData copyWith({
    String? id,
    String? userId,
    Value<int?> serverId = const Value.absent(),
    String? title,
    String? persona,
    DateTime? lastMessageAt,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ChatSessionsTableData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    serverId: serverId.present ? serverId.value : this.serverId,
    title: title ?? this.title,
    persona: persona ?? this.persona,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChatSessionsTableData copyWithCompanion(ChatSessionsTableCompanion data) {
    return ChatSessionsTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      title: data.title.present ? data.title.value : this.title,
      persona: data.persona.present ? data.persona.value : this.persona,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatSessionsTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('serverId: $serverId, ')
          ..write('title: $title, ')
          ..write('persona: $persona, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    serverId,
    title,
    persona,
    lastMessageAt,
    syncStatus,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatSessionsTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.serverId == this.serverId &&
          other.title == this.title &&
          other.persona == this.persona &&
          other.lastMessageAt == this.lastMessageAt &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChatSessionsTableCompanion
    extends UpdateCompanion<ChatSessionsTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<int?> serverId;
  final Value<String> title;
  final Value<String> persona;
  final Value<DateTime> lastMessageAt;
  final Value<String> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ChatSessionsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.title = const Value.absent(),
    this.persona = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatSessionsTableCompanion.insert({
    required String id,
    required String userId,
    this.serverId = const Value.absent(),
    this.title = const Value.absent(),
    this.persona = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId);
  static Insertable<ChatSessionsTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<int>? serverId,
    Expression<String>? title,
    Expression<String>? persona,
    Expression<DateTime>? lastMessageAt,
    Expression<String>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (serverId != null) 'server_id': serverId,
      if (title != null) 'title': title,
      if (persona != null) 'persona': persona,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatSessionsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<int?>? serverId,
    Value<String>? title,
    Value<String>? persona,
    Value<DateTime>? lastMessageAt,
    Value<String>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ChatSessionsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      persona: persona ?? this.persona,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (persona.present) {
      map['persona'] = Variable<String>(persona.value);
    }
    if (lastMessageAt.present) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatSessionsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('serverId: $serverId, ')
          ..write('title: $title, ')
          ..write('persona: $persona, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTableTable extends ChatMessagesTable
    with TableInfo<$ChatMessagesTableTable, ChatMessagesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageTypeMeta = const VerificationMeta(
    'messageType',
  );
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
    'message_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _feedbackTypeMeta = const VerificationMeta(
    'feedbackType',
  );
  @override
  late final GeneratedColumn<String> feedbackType = GeneratedColumn<String>(
    'feedback_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _feedbackDetailMeta = const VerificationMeta(
    'feedbackDetail',
  );
  @override
  late final GeneratedColumn<String> feedbackDetail = GeneratedColumn<String>(
    'feedback_detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    serverId,
    role,
    content,
    messageType,
    metadata,
    feedbackType,
    feedbackDetail,
    syncStatus,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessagesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('message_type')) {
      context.handle(
        _messageTypeMeta,
        messageType.isAcceptableOrUnknown(
          data['message_type']!,
          _messageTypeMeta,
        ),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('feedback_type')) {
      context.handle(
        _feedbackTypeMeta,
        feedbackType.isAcceptableOrUnknown(
          data['feedback_type']!,
          _feedbackTypeMeta,
        ),
      );
    }
    if (data.containsKey('feedback_detail')) {
      context.handle(
        _feedbackDetailMeta,
        feedbackDetail.isAcceptableOrUnknown(
          data['feedback_detail']!,
          _feedbackDetailMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessagesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessagesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      messageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_type'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
      feedbackType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feedback_type'],
      ),
      feedbackDetail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feedback_detail'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ChatMessagesTableTable createAlias(String alias) {
    return $ChatMessagesTableTable(attachedDatabase, alias);
  }
}

class ChatMessagesTableData extends DataClass
    implements Insertable<ChatMessagesTableData> {
  final String id;
  final String sessionId;
  final int? serverId;
  final String role;
  final String content;
  final String messageType;
  final String metadata;
  final String? feedbackType;
  final String? feedbackDetail;
  final String syncStatus;
  final DateTime createdAt;
  const ChatMessagesTableData({
    required this.id,
    required this.sessionId,
    this.serverId,
    required this.role,
    required this.content,
    required this.messageType,
    required this.metadata,
    this.feedbackType,
    this.feedbackDetail,
    required this.syncStatus,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['message_type'] = Variable<String>(messageType);
    map['metadata'] = Variable<String>(metadata);
    if (!nullToAbsent || feedbackType != null) {
      map['feedback_type'] = Variable<String>(feedbackType);
    }
    if (!nullToAbsent || feedbackDetail != null) {
      map['feedback_detail'] = Variable<String>(feedbackDetail);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChatMessagesTableCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesTableCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      role: Value(role),
      content: Value(content),
      messageType: Value(messageType),
      metadata: Value(metadata),
      feedbackType: feedbackType == null && nullToAbsent
          ? const Value.absent()
          : Value(feedbackType),
      feedbackDetail: feedbackDetail == null && nullToAbsent
          ? const Value.absent()
          : Value(feedbackDetail),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
    );
  }

  factory ChatMessagesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessagesTableData(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      messageType: serializer.fromJson<String>(json['messageType']),
      metadata: serializer.fromJson<String>(json['metadata']),
      feedbackType: serializer.fromJson<String?>(json['feedbackType']),
      feedbackDetail: serializer.fromJson<String?>(json['feedbackDetail']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'serverId': serializer.toJson<int?>(serverId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'messageType': serializer.toJson<String>(messageType),
      'metadata': serializer.toJson<String>(metadata),
      'feedbackType': serializer.toJson<String?>(feedbackType),
      'feedbackDetail': serializer.toJson<String?>(feedbackDetail),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChatMessagesTableData copyWith({
    String? id,
    String? sessionId,
    Value<int?> serverId = const Value.absent(),
    String? role,
    String? content,
    String? messageType,
    String? metadata,
    Value<String?> feedbackType = const Value.absent(),
    Value<String?> feedbackDetail = const Value.absent(),
    String? syncStatus,
    DateTime? createdAt,
  }) => ChatMessagesTableData(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    serverId: serverId.present ? serverId.value : this.serverId,
    role: role ?? this.role,
    content: content ?? this.content,
    messageType: messageType ?? this.messageType,
    metadata: metadata ?? this.metadata,
    feedbackType: feedbackType.present ? feedbackType.value : this.feedbackType,
    feedbackDetail: feedbackDetail.present
        ? feedbackDetail.value
        : this.feedbackDetail,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
  );
  ChatMessagesTableData copyWithCompanion(ChatMessagesTableCompanion data) {
    return ChatMessagesTableData(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      messageType: data.messageType.present
          ? data.messageType.value
          : this.messageType,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      feedbackType: data.feedbackType.present
          ? data.feedbackType.value
          : this.feedbackType,
      feedbackDetail: data.feedbackDetail.present
          ? data.feedbackDetail.value
          : this.feedbackDetail,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesTableData(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('serverId: $serverId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('messageType: $messageType, ')
          ..write('metadata: $metadata, ')
          ..write('feedbackType: $feedbackType, ')
          ..write('feedbackDetail: $feedbackDetail, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    serverId,
    role,
    content,
    messageType,
    metadata,
    feedbackType,
    feedbackDetail,
    syncStatus,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessagesTableData &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.serverId == this.serverId &&
          other.role == this.role &&
          other.content == this.content &&
          other.messageType == this.messageType &&
          other.metadata == this.metadata &&
          other.feedbackType == this.feedbackType &&
          other.feedbackDetail == this.feedbackDetail &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt);
}

class ChatMessagesTableCompanion
    extends UpdateCompanion<ChatMessagesTableData> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int?> serverId;
  final Value<String> role;
  final Value<String> content;
  final Value<String> messageType;
  final Value<String> metadata;
  final Value<String?> feedbackType;
  final Value<String?> feedbackDetail;
  final Value<String> syncStatus;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ChatMessagesTableCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.messageType = const Value.absent(),
    this.metadata = const Value.absent(),
    this.feedbackType = const Value.absent(),
    this.feedbackDetail = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesTableCompanion.insert({
    required String id,
    required String sessionId,
    this.serverId = const Value.absent(),
    required String role,
    required String content,
    this.messageType = const Value.absent(),
    this.metadata = const Value.absent(),
    this.feedbackType = const Value.absent(),
    this.feedbackDetail = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       role = Value(role),
       content = Value(content);
  static Insertable<ChatMessagesTableData> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? serverId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? messageType,
    Expression<String>? metadata,
    Expression<String>? feedbackType,
    Expression<String>? feedbackDetail,
    Expression<String>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (serverId != null) 'server_id': serverId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (messageType != null) 'message_type': messageType,
      if (metadata != null) 'metadata': metadata,
      if (feedbackType != null) 'feedback_type': feedbackType,
      if (feedbackDetail != null) 'feedback_detail': feedbackDetail,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int?>? serverId,
    Value<String>? role,
    Value<String>? content,
    Value<String>? messageType,
    Value<String>? metadata,
    Value<String?>? feedbackType,
    Value<String?>? feedbackDetail,
    Value<String>? syncStatus,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ChatMessagesTableCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      serverId: serverId ?? this.serverId,
      role: role ?? this.role,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
      feedbackType: feedbackType ?? this.feedbackType,
      feedbackDetail: feedbackDetail ?? this.feedbackDetail,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (feedbackType.present) {
      map['feedback_type'] = Variable<String>(feedbackType.value);
    }
    if (feedbackDetail.present) {
      map['feedback_detail'] = Variable<String>(feedbackDetail.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesTableCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('serverId: $serverId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('messageType: $messageType, ')
          ..write('metadata: $metadata, ')
          ..write('feedbackType: $feedbackType, ')
          ..write('feedbackDetail: $feedbackDetail, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeCardsTableTable extends PracticeCardsTable
    with TableInfo<$PracticeCardsTableTable, PracticeCardsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeCardsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<int> state = GeneratedColumn<int>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _stabilityMeta = const VerificationMeta(
    'stability',
  );
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
    'stability',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _scheduledDaysMeta = const VerificationMeta(
    'scheduledDays',
  );
  @override
  late final GeneratedColumn<int> scheduledDays = GeneratedColumn<int>(
    'scheduled_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _elapsedDaysMeta = const VerificationMeta(
    'elapsedDays',
  );
  @override
  late final GeneratedColumn<int> elapsedDays = GeneratedColumn<int>(
    'elapsed_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReviewMeta = const VerificationMeta(
    'lastReview',
  );
  @override
  late final GeneratedColumn<DateTime> lastReview = GeneratedColumn<DateTime>(
    'last_review',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(5.0),
  );
  static const VerificationMeta _avgTimeSecMeta = const VerificationMeta(
    'avgTimeSec',
  );
  @override
  late final GeneratedColumn<int> avgTimeSec = GeneratedColumn<int>(
    'avg_time_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20),
  );
  static const VerificationMeta _skipConditionMeta = const VerificationMeta(
    'skipCondition',
  );
  @override
  late final GeneratedColumn<String> skipCondition = GeneratedColumn<String>(
    'skip_condition',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    userId,
    courseId,
    lessonId,
    blockId,
    sourceType,
    state,
    dueDate,
    stability,
    difficulty,
    reps,
    lapses,
    scheduledDays,
    elapsedDays,
    lastReview,
    weight,
    avgTimeSec,
    skipCondition,
    isActive,
    syncStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeCardsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blockIdMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('stability')) {
      context.handle(
        _stabilityMeta,
        stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    }
    if (data.containsKey('scheduled_days')) {
      context.handle(
        _scheduledDaysMeta,
        scheduledDays.isAcceptableOrUnknown(
          data['scheduled_days']!,
          _scheduledDaysMeta,
        ),
      );
    }
    if (data.containsKey('elapsed_days')) {
      context.handle(
        _elapsedDaysMeta,
        elapsedDays.isAcceptableOrUnknown(
          data['elapsed_days']!,
          _elapsedDaysMeta,
        ),
      );
    }
    if (data.containsKey('last_review')) {
      context.handle(
        _lastReviewMeta,
        lastReview.isAcceptableOrUnknown(data['last_review']!, _lastReviewMeta),
      );
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('avg_time_sec')) {
      context.handle(
        _avgTimeSecMeta,
        avgTimeSec.isAcceptableOrUnknown(
          data['avg_time_sec']!,
          _avgTimeSecMeta,
        ),
      );
    }
    if (data.containsKey('skip_condition')) {
      context.handle(
        _skipConditionMeta,
        skipCondition.isAcceptableOrUnknown(
          data['skip_condition']!,
          _skipConditionMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeCardsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeCardsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      )!,
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}state'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      )!,
      stability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
      scheduledDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_days'],
      )!,
      elapsedDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_days'],
      )!,
      lastReview: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_review'],
      ),
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      )!,
      avgTimeSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avg_time_sec'],
      )!,
      skipCondition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skip_condition'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PracticeCardsTableTable createAlias(String alias) {
    return $PracticeCardsTableTable(attachedDatabase, alias);
  }
}

class PracticeCardsTableData extends DataClass
    implements Insertable<PracticeCardsTableData> {
  final String id;
  final String? serverId;
  final String userId;
  final String courseId;
  final String lessonId;
  final String blockId;
  final String sourceType;
  final int state;
  final DateTime dueDate;
  final double stability;
  final double difficulty;
  final int reps;
  final int lapses;
  final int scheduledDays;
  final int elapsedDays;
  final DateTime? lastReview;
  final double weight;
  final int avgTimeSec;
  final String? skipCondition;
  final bool isActive;
  final int syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PracticeCardsTableData({
    required this.id,
    this.serverId,
    required this.userId,
    required this.courseId,
    required this.lessonId,
    required this.blockId,
    required this.sourceType,
    required this.state,
    required this.dueDate,
    required this.stability,
    required this.difficulty,
    required this.reps,
    required this.lapses,
    required this.scheduledDays,
    required this.elapsedDays,
    this.lastReview,
    required this.weight,
    required this.avgTimeSec,
    this.skipCondition,
    required this.isActive,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['user_id'] = Variable<String>(userId);
    map['course_id'] = Variable<String>(courseId);
    map['lesson_id'] = Variable<String>(lessonId);
    map['block_id'] = Variable<String>(blockId);
    map['source_type'] = Variable<String>(sourceType);
    map['state'] = Variable<int>(state);
    map['due_date'] = Variable<DateTime>(dueDate);
    map['stability'] = Variable<double>(stability);
    map['difficulty'] = Variable<double>(difficulty);
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    map['scheduled_days'] = Variable<int>(scheduledDays);
    map['elapsed_days'] = Variable<int>(elapsedDays);
    if (!nullToAbsent || lastReview != null) {
      map['last_review'] = Variable<DateTime>(lastReview);
    }
    map['weight'] = Variable<double>(weight);
    map['avg_time_sec'] = Variable<int>(avgTimeSec);
    if (!nullToAbsent || skipCondition != null) {
      map['skip_condition'] = Variable<String>(skipCondition);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['sync_status'] = Variable<int>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PracticeCardsTableCompanion toCompanion(bool nullToAbsent) {
    return PracticeCardsTableCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      userId: Value(userId),
      courseId: Value(courseId),
      lessonId: Value(lessonId),
      blockId: Value(blockId),
      sourceType: Value(sourceType),
      state: Value(state),
      dueDate: Value(dueDate),
      stability: Value(stability),
      difficulty: Value(difficulty),
      reps: Value(reps),
      lapses: Value(lapses),
      scheduledDays: Value(scheduledDays),
      elapsedDays: Value(elapsedDays),
      lastReview: lastReview == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReview),
      weight: Value(weight),
      avgTimeSec: Value(avgTimeSec),
      skipCondition: skipCondition == null && nullToAbsent
          ? const Value.absent()
          : Value(skipCondition),
      isActive: Value(isActive),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PracticeCardsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeCardsTableData(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      userId: serializer.fromJson<String>(json['userId']),
      courseId: serializer.fromJson<String>(json['courseId']),
      lessonId: serializer.fromJson<String>(json['lessonId']),
      blockId: serializer.fromJson<String>(json['blockId']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      state: serializer.fromJson<int>(json['state']),
      dueDate: serializer.fromJson<DateTime>(json['dueDate']),
      stability: serializer.fromJson<double>(json['stability']),
      difficulty: serializer.fromJson<double>(json['difficulty']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
      scheduledDays: serializer.fromJson<int>(json['scheduledDays']),
      elapsedDays: serializer.fromJson<int>(json['elapsedDays']),
      lastReview: serializer.fromJson<DateTime?>(json['lastReview']),
      weight: serializer.fromJson<double>(json['weight']),
      avgTimeSec: serializer.fromJson<int>(json['avgTimeSec']),
      skipCondition: serializer.fromJson<String?>(json['skipCondition']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<String?>(serverId),
      'userId': serializer.toJson<String>(userId),
      'courseId': serializer.toJson<String>(courseId),
      'lessonId': serializer.toJson<String>(lessonId),
      'blockId': serializer.toJson<String>(blockId),
      'sourceType': serializer.toJson<String>(sourceType),
      'state': serializer.toJson<int>(state),
      'dueDate': serializer.toJson<DateTime>(dueDate),
      'stability': serializer.toJson<double>(stability),
      'difficulty': serializer.toJson<double>(difficulty),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
      'scheduledDays': serializer.toJson<int>(scheduledDays),
      'elapsedDays': serializer.toJson<int>(elapsedDays),
      'lastReview': serializer.toJson<DateTime?>(lastReview),
      'weight': serializer.toJson<double>(weight),
      'avgTimeSec': serializer.toJson<int>(avgTimeSec),
      'skipCondition': serializer.toJson<String?>(skipCondition),
      'isActive': serializer.toJson<bool>(isActive),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PracticeCardsTableData copyWith({
    String? id,
    Value<String?> serverId = const Value.absent(),
    String? userId,
    String? courseId,
    String? lessonId,
    String? blockId,
    String? sourceType,
    int? state,
    DateTime? dueDate,
    double? stability,
    double? difficulty,
    int? reps,
    int? lapses,
    int? scheduledDays,
    int? elapsedDays,
    Value<DateTime?> lastReview = const Value.absent(),
    double? weight,
    int? avgTimeSec,
    Value<String?> skipCondition = const Value.absent(),
    bool? isActive,
    int? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PracticeCardsTableData(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    userId: userId ?? this.userId,
    courseId: courseId ?? this.courseId,
    lessonId: lessonId ?? this.lessonId,
    blockId: blockId ?? this.blockId,
    sourceType: sourceType ?? this.sourceType,
    state: state ?? this.state,
    dueDate: dueDate ?? this.dueDate,
    stability: stability ?? this.stability,
    difficulty: difficulty ?? this.difficulty,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    scheduledDays: scheduledDays ?? this.scheduledDays,
    elapsedDays: elapsedDays ?? this.elapsedDays,
    lastReview: lastReview.present ? lastReview.value : this.lastReview,
    weight: weight ?? this.weight,
    avgTimeSec: avgTimeSec ?? this.avgTimeSec,
    skipCondition: skipCondition.present
        ? skipCondition.value
        : this.skipCondition,
    isActive: isActive ?? this.isActive,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PracticeCardsTableData copyWithCompanion(PracticeCardsTableCompanion data) {
    return PracticeCardsTableData(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      userId: data.userId.present ? data.userId.value : this.userId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      state: data.state.present ? data.state.value : this.state,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      stability: data.stability.present ? data.stability.value : this.stability,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      scheduledDays: data.scheduledDays.present
          ? data.scheduledDays.value
          : this.scheduledDays,
      elapsedDays: data.elapsedDays.present
          ? data.elapsedDays.value
          : this.elapsedDays,
      lastReview: data.lastReview.present
          ? data.lastReview.value
          : this.lastReview,
      weight: data.weight.present ? data.weight.value : this.weight,
      avgTimeSec: data.avgTimeSec.present
          ? data.avgTimeSec.value
          : this.avgTimeSec,
      skipCondition: data.skipCondition.present
          ? data.skipCondition.value
          : this.skipCondition,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeCardsTableData(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('courseId: $courseId, ')
          ..write('lessonId: $lessonId, ')
          ..write('blockId: $blockId, ')
          ..write('sourceType: $sourceType, ')
          ..write('state: $state, ')
          ..write('dueDate: $dueDate, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('elapsedDays: $elapsedDays, ')
          ..write('lastReview: $lastReview, ')
          ..write('weight: $weight, ')
          ..write('avgTimeSec: $avgTimeSec, ')
          ..write('skipCondition: $skipCondition, ')
          ..write('isActive: $isActive, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    serverId,
    userId,
    courseId,
    lessonId,
    blockId,
    sourceType,
    state,
    dueDate,
    stability,
    difficulty,
    reps,
    lapses,
    scheduledDays,
    elapsedDays,
    lastReview,
    weight,
    avgTimeSec,
    skipCondition,
    isActive,
    syncStatus,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeCardsTableData &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.userId == this.userId &&
          other.courseId == this.courseId &&
          other.lessonId == this.lessonId &&
          other.blockId == this.blockId &&
          other.sourceType == this.sourceType &&
          other.state == this.state &&
          other.dueDate == this.dueDate &&
          other.stability == this.stability &&
          other.difficulty == this.difficulty &&
          other.reps == this.reps &&
          other.lapses == this.lapses &&
          other.scheduledDays == this.scheduledDays &&
          other.elapsedDays == this.elapsedDays &&
          other.lastReview == this.lastReview &&
          other.weight == this.weight &&
          other.avgTimeSec == this.avgTimeSec &&
          other.skipCondition == this.skipCondition &&
          other.isActive == this.isActive &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PracticeCardsTableCompanion
    extends UpdateCompanion<PracticeCardsTableData> {
  final Value<String> id;
  final Value<String?> serverId;
  final Value<String> userId;
  final Value<String> courseId;
  final Value<String> lessonId;
  final Value<String> blockId;
  final Value<String> sourceType;
  final Value<int> state;
  final Value<DateTime> dueDate;
  final Value<double> stability;
  final Value<double> difficulty;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<int> scheduledDays;
  final Value<int> elapsedDays;
  final Value<DateTime?> lastReview;
  final Value<double> weight;
  final Value<int> avgTimeSec;
  final Value<String?> skipCondition;
  final Value<bool> isActive;
  final Value<int> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PracticeCardsTableCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.userId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.blockId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.state = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.scheduledDays = const Value.absent(),
    this.elapsedDays = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.weight = const Value.absent(),
    this.avgTimeSec = const Value.absent(),
    this.skipCondition = const Value.absent(),
    this.isActive = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeCardsTableCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String userId,
    required String courseId,
    required String lessonId,
    required String blockId,
    required String sourceType,
    this.state = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.scheduledDays = const Value.absent(),
    this.elapsedDays = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.weight = const Value.absent(),
    this.avgTimeSec = const Value.absent(),
    this.skipCondition = const Value.absent(),
    this.isActive = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       courseId = Value(courseId),
       lessonId = Value(lessonId),
       blockId = Value(blockId),
       sourceType = Value(sourceType);
  static Insertable<PracticeCardsTableData> custom({
    Expression<String>? id,
    Expression<String>? serverId,
    Expression<String>? userId,
    Expression<String>? courseId,
    Expression<String>? lessonId,
    Expression<String>? blockId,
    Expression<String>? sourceType,
    Expression<int>? state,
    Expression<DateTime>? dueDate,
    Expression<double>? stability,
    Expression<double>? difficulty,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<int>? scheduledDays,
    Expression<int>? elapsedDays,
    Expression<DateTime>? lastReview,
    Expression<double>? weight,
    Expression<int>? avgTimeSec,
    Expression<String>? skipCondition,
    Expression<bool>? isActive,
    Expression<int>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (userId != null) 'user_id': userId,
      if (courseId != null) 'course_id': courseId,
      if (lessonId != null) 'lesson_id': lessonId,
      if (blockId != null) 'block_id': blockId,
      if (sourceType != null) 'source_type': sourceType,
      if (state != null) 'state': state,
      if (dueDate != null) 'due_date': dueDate,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (scheduledDays != null) 'scheduled_days': scheduledDays,
      if (elapsedDays != null) 'elapsed_days': elapsedDays,
      if (lastReview != null) 'last_review': lastReview,
      if (weight != null) 'weight': weight,
      if (avgTimeSec != null) 'avg_time_sec': avgTimeSec,
      if (skipCondition != null) 'skip_condition': skipCondition,
      if (isActive != null) 'is_active': isActive,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeCardsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? serverId,
    Value<String>? userId,
    Value<String>? courseId,
    Value<String>? lessonId,
    Value<String>? blockId,
    Value<String>? sourceType,
    Value<int>? state,
    Value<DateTime>? dueDate,
    Value<double>? stability,
    Value<double>? difficulty,
    Value<int>? reps,
    Value<int>? lapses,
    Value<int>? scheduledDays,
    Value<int>? elapsedDays,
    Value<DateTime?>? lastReview,
    Value<double>? weight,
    Value<int>? avgTimeSec,
    Value<String?>? skipCondition,
    Value<bool>? isActive,
    Value<int>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PracticeCardsTableCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      lessonId: lessonId ?? this.lessonId,
      blockId: blockId ?? this.blockId,
      sourceType: sourceType ?? this.sourceType,
      state: state ?? this.state,
      dueDate: dueDate ?? this.dueDate,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      lastReview: lastReview ?? this.lastReview,
      weight: weight ?? this.weight,
      avgTimeSec: avgTimeSec ?? this.avgTimeSec,
      skipCondition: skipCondition ?? this.skipCondition,
      isActive: isActive ?? this.isActive,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (state.present) {
      map['state'] = Variable<int>(state.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (scheduledDays.present) {
      map['scheduled_days'] = Variable<int>(scheduledDays.value);
    }
    if (elapsedDays.present) {
      map['elapsed_days'] = Variable<int>(elapsedDays.value);
    }
    if (lastReview.present) {
      map['last_review'] = Variable<DateTime>(lastReview.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (avgTimeSec.present) {
      map['avg_time_sec'] = Variable<int>(avgTimeSec.value);
    }
    if (skipCondition.present) {
      map['skip_condition'] = Variable<String>(skipCondition.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeCardsTableCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('courseId: $courseId, ')
          ..write('lessonId: $lessonId, ')
          ..write('blockId: $blockId, ')
          ..write('sourceType: $sourceType, ')
          ..write('state: $state, ')
          ..write('dueDate: $dueDate, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('elapsedDays: $elapsedDays, ')
          ..write('lastReview: $lastReview, ')
          ..write('weight: $weight, ')
          ..write('avgTimeSec: $avgTimeSec, ')
          ..write('skipCondition: $skipCondition, ')
          ..write('isActive: $isActive, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewLogsTableTable extends ReviewLogsTable
    with TableInfo<$ReviewLogsTableTable, ReviewLogsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewLogsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shownAtMeta = const VerificationMeta(
    'shownAt',
  );
  @override
  late final GeneratedColumn<DateTime> shownAt = GeneratedColumn<DateTime>(
    'shown_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta(
    'reviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> reviewedAt = GeneratedColumn<DateTime>(
    'reviewed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responseTimeSecMeta = const VerificationMeta(
    'responseTimeSec',
  );
  @override
  late final GeneratedColumn<int> responseTimeSec = GeneratedColumn<int>(
    'response_time_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repetitionNumberMeta = const VerificationMeta(
    'repetitionNumber',
  );
  @override
  late final GeneratedColumn<int> repetitionNumber = GeneratedColumn<int>(
    'repetition_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stabilityAfterMeta = const VerificationMeta(
    'stabilityAfter',
  );
  @override
  late final GeneratedColumn<double> stabilityAfter = GeneratedColumn<double>(
    'stability_after',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyAfterMeta = const VerificationMeta(
    'difficultyAfter',
  );
  @override
  late final GeneratedColumn<double> difficultyAfter = GeneratedColumn<double>(
    'difficulty_after',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextDueDateMeta = const VerificationMeta(
    'nextDueDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextDueDate = GeneratedColumn<DateTime>(
    'next_due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userFeedbackMeta = const VerificationMeta(
    'userFeedback',
  );
  @override
  late final GeneratedColumn<String> userFeedback = GeneratedColumn<String>(
    'user_feedback',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    cardId,
    userId,
    rating,
    shownAt,
    reviewedAt,
    responseTimeSec,
    repetitionNumber,
    stabilityAfter,
    difficultyAfter,
    nextDueDate,
    intervalDays,
    userFeedback,
    syncStatus,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewLogsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('shown_at')) {
      context.handle(
        _shownAtMeta,
        shownAt.isAcceptableOrUnknown(data['shown_at']!, _shownAtMeta),
      );
    } else if (isInserting) {
      context.missing(_shownAtMeta);
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewedAtMeta);
    }
    if (data.containsKey('response_time_sec')) {
      context.handle(
        _responseTimeSecMeta,
        responseTimeSec.isAcceptableOrUnknown(
          data['response_time_sec']!,
          _responseTimeSecMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_responseTimeSecMeta);
    }
    if (data.containsKey('repetition_number')) {
      context.handle(
        _repetitionNumberMeta,
        repetitionNumber.isAcceptableOrUnknown(
          data['repetition_number']!,
          _repetitionNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repetitionNumberMeta);
    }
    if (data.containsKey('stability_after')) {
      context.handle(
        _stabilityAfterMeta,
        stabilityAfter.isAcceptableOrUnknown(
          data['stability_after']!,
          _stabilityAfterMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stabilityAfterMeta);
    }
    if (data.containsKey('difficulty_after')) {
      context.handle(
        _difficultyAfterMeta,
        difficultyAfter.isAcceptableOrUnknown(
          data['difficulty_after']!,
          _difficultyAfterMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_difficultyAfterMeta);
    }
    if (data.containsKey('next_due_date')) {
      context.handle(
        _nextDueDateMeta,
        nextDueDate.isAcceptableOrUnknown(
          data['next_due_date']!,
          _nextDueDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextDueDateMeta);
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_intervalDaysMeta);
    }
    if (data.containsKey('user_feedback')) {
      context.handle(
        _userFeedbackMeta,
        userFeedback.isAcceptableOrUnknown(
          data['user_feedback']!,
          _userFeedbackMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewLogsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewLogsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      )!,
      shownAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}shown_at'],
      )!,
      reviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reviewed_at'],
      )!,
      responseTimeSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}response_time_sec'],
      )!,
      repetitionNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repetition_number'],
      )!,
      stabilityAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability_after'],
      )!,
      difficultyAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty_after'],
      )!,
      nextDueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_due_date'],
      )!,
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      userFeedback: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_feedback'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ReviewLogsTableTable createAlias(String alias) {
    return $ReviewLogsTableTable(attachedDatabase, alias);
  }
}

class ReviewLogsTableData extends DataClass
    implements Insertable<ReviewLogsTableData> {
  final String id;
  final String? serverId;
  final String cardId;
  final String userId;
  final int rating;
  final DateTime shownAt;
  final DateTime reviewedAt;
  final int responseTimeSec;
  final int repetitionNumber;
  final double stabilityAfter;
  final double difficultyAfter;
  final DateTime nextDueDate;
  final int intervalDays;
  final String? userFeedback;
  final int syncStatus;
  final DateTime createdAt;
  const ReviewLogsTableData({
    required this.id,
    this.serverId,
    required this.cardId,
    required this.userId,
    required this.rating,
    required this.shownAt,
    required this.reviewedAt,
    required this.responseTimeSec,
    required this.repetitionNumber,
    required this.stabilityAfter,
    required this.difficultyAfter,
    required this.nextDueDate,
    required this.intervalDays,
    this.userFeedback,
    required this.syncStatus,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['card_id'] = Variable<String>(cardId);
    map['user_id'] = Variable<String>(userId);
    map['rating'] = Variable<int>(rating);
    map['shown_at'] = Variable<DateTime>(shownAt);
    map['reviewed_at'] = Variable<DateTime>(reviewedAt);
    map['response_time_sec'] = Variable<int>(responseTimeSec);
    map['repetition_number'] = Variable<int>(repetitionNumber);
    map['stability_after'] = Variable<double>(stabilityAfter);
    map['difficulty_after'] = Variable<double>(difficultyAfter);
    map['next_due_date'] = Variable<DateTime>(nextDueDate);
    map['interval_days'] = Variable<int>(intervalDays);
    if (!nullToAbsent || userFeedback != null) {
      map['user_feedback'] = Variable<String>(userFeedback);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ReviewLogsTableCompanion toCompanion(bool nullToAbsent) {
    return ReviewLogsTableCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      cardId: Value(cardId),
      userId: Value(userId),
      rating: Value(rating),
      shownAt: Value(shownAt),
      reviewedAt: Value(reviewedAt),
      responseTimeSec: Value(responseTimeSec),
      repetitionNumber: Value(repetitionNumber),
      stabilityAfter: Value(stabilityAfter),
      difficultyAfter: Value(difficultyAfter),
      nextDueDate: Value(nextDueDate),
      intervalDays: Value(intervalDays),
      userFeedback: userFeedback == null && nullToAbsent
          ? const Value.absent()
          : Value(userFeedback),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
    );
  }

  factory ReviewLogsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewLogsTableData(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      cardId: serializer.fromJson<String>(json['cardId']),
      userId: serializer.fromJson<String>(json['userId']),
      rating: serializer.fromJson<int>(json['rating']),
      shownAt: serializer.fromJson<DateTime>(json['shownAt']),
      reviewedAt: serializer.fromJson<DateTime>(json['reviewedAt']),
      responseTimeSec: serializer.fromJson<int>(json['responseTimeSec']),
      repetitionNumber: serializer.fromJson<int>(json['repetitionNumber']),
      stabilityAfter: serializer.fromJson<double>(json['stabilityAfter']),
      difficultyAfter: serializer.fromJson<double>(json['difficultyAfter']),
      nextDueDate: serializer.fromJson<DateTime>(json['nextDueDate']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      userFeedback: serializer.fromJson<String?>(json['userFeedback']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<String?>(serverId),
      'cardId': serializer.toJson<String>(cardId),
      'userId': serializer.toJson<String>(userId),
      'rating': serializer.toJson<int>(rating),
      'shownAt': serializer.toJson<DateTime>(shownAt),
      'reviewedAt': serializer.toJson<DateTime>(reviewedAt),
      'responseTimeSec': serializer.toJson<int>(responseTimeSec),
      'repetitionNumber': serializer.toJson<int>(repetitionNumber),
      'stabilityAfter': serializer.toJson<double>(stabilityAfter),
      'difficultyAfter': serializer.toJson<double>(difficultyAfter),
      'nextDueDate': serializer.toJson<DateTime>(nextDueDate),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'userFeedback': serializer.toJson<String?>(userFeedback),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ReviewLogsTableData copyWith({
    String? id,
    Value<String?> serverId = const Value.absent(),
    String? cardId,
    String? userId,
    int? rating,
    DateTime? shownAt,
    DateTime? reviewedAt,
    int? responseTimeSec,
    int? repetitionNumber,
    double? stabilityAfter,
    double? difficultyAfter,
    DateTime? nextDueDate,
    int? intervalDays,
    Value<String?> userFeedback = const Value.absent(),
    int? syncStatus,
    DateTime? createdAt,
  }) => ReviewLogsTableData(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    cardId: cardId ?? this.cardId,
    userId: userId ?? this.userId,
    rating: rating ?? this.rating,
    shownAt: shownAt ?? this.shownAt,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    responseTimeSec: responseTimeSec ?? this.responseTimeSec,
    repetitionNumber: repetitionNumber ?? this.repetitionNumber,
    stabilityAfter: stabilityAfter ?? this.stabilityAfter,
    difficultyAfter: difficultyAfter ?? this.difficultyAfter,
    nextDueDate: nextDueDate ?? this.nextDueDate,
    intervalDays: intervalDays ?? this.intervalDays,
    userFeedback: userFeedback.present ? userFeedback.value : this.userFeedback,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
  );
  ReviewLogsTableData copyWithCompanion(ReviewLogsTableCompanion data) {
    return ReviewLogsTableData(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      userId: data.userId.present ? data.userId.value : this.userId,
      rating: data.rating.present ? data.rating.value : this.rating,
      shownAt: data.shownAt.present ? data.shownAt.value : this.shownAt,
      reviewedAt: data.reviewedAt.present
          ? data.reviewedAt.value
          : this.reviewedAt,
      responseTimeSec: data.responseTimeSec.present
          ? data.responseTimeSec.value
          : this.responseTimeSec,
      repetitionNumber: data.repetitionNumber.present
          ? data.repetitionNumber.value
          : this.repetitionNumber,
      stabilityAfter: data.stabilityAfter.present
          ? data.stabilityAfter.value
          : this.stabilityAfter,
      difficultyAfter: data.difficultyAfter.present
          ? data.difficultyAfter.value
          : this.difficultyAfter,
      nextDueDate: data.nextDueDate.present
          ? data.nextDueDate.value
          : this.nextDueDate,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      userFeedback: data.userFeedback.present
          ? data.userFeedback.value
          : this.userFeedback,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogsTableData(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('cardId: $cardId, ')
          ..write('userId: $userId, ')
          ..write('rating: $rating, ')
          ..write('shownAt: $shownAt, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('responseTimeSec: $responseTimeSec, ')
          ..write('repetitionNumber: $repetitionNumber, ')
          ..write('stabilityAfter: $stabilityAfter, ')
          ..write('difficultyAfter: $difficultyAfter, ')
          ..write('nextDueDate: $nextDueDate, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('userFeedback: $userFeedback, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    cardId,
    userId,
    rating,
    shownAt,
    reviewedAt,
    responseTimeSec,
    repetitionNumber,
    stabilityAfter,
    difficultyAfter,
    nextDueDate,
    intervalDays,
    userFeedback,
    syncStatus,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewLogsTableData &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.cardId == this.cardId &&
          other.userId == this.userId &&
          other.rating == this.rating &&
          other.shownAt == this.shownAt &&
          other.reviewedAt == this.reviewedAt &&
          other.responseTimeSec == this.responseTimeSec &&
          other.repetitionNumber == this.repetitionNumber &&
          other.stabilityAfter == this.stabilityAfter &&
          other.difficultyAfter == this.difficultyAfter &&
          other.nextDueDate == this.nextDueDate &&
          other.intervalDays == this.intervalDays &&
          other.userFeedback == this.userFeedback &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt);
}

class ReviewLogsTableCompanion extends UpdateCompanion<ReviewLogsTableData> {
  final Value<String> id;
  final Value<String?> serverId;
  final Value<String> cardId;
  final Value<String> userId;
  final Value<int> rating;
  final Value<DateTime> shownAt;
  final Value<DateTime> reviewedAt;
  final Value<int> responseTimeSec;
  final Value<int> repetitionNumber;
  final Value<double> stabilityAfter;
  final Value<double> difficultyAfter;
  final Value<DateTime> nextDueDate;
  final Value<int> intervalDays;
  final Value<String?> userFeedback;
  final Value<int> syncStatus;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ReviewLogsTableCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.cardId = const Value.absent(),
    this.userId = const Value.absent(),
    this.rating = const Value.absent(),
    this.shownAt = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.responseTimeSec = const Value.absent(),
    this.repetitionNumber = const Value.absent(),
    this.stabilityAfter = const Value.absent(),
    this.difficultyAfter = const Value.absent(),
    this.nextDueDate = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.userFeedback = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewLogsTableCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String cardId,
    required String userId,
    required int rating,
    required DateTime shownAt,
    required DateTime reviewedAt,
    required int responseTimeSec,
    required int repetitionNumber,
    required double stabilityAfter,
    required double difficultyAfter,
    required DateTime nextDueDate,
    required int intervalDays,
    this.userFeedback = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cardId = Value(cardId),
       userId = Value(userId),
       rating = Value(rating),
       shownAt = Value(shownAt),
       reviewedAt = Value(reviewedAt),
       responseTimeSec = Value(responseTimeSec),
       repetitionNumber = Value(repetitionNumber),
       stabilityAfter = Value(stabilityAfter),
       difficultyAfter = Value(difficultyAfter),
       nextDueDate = Value(nextDueDate),
       intervalDays = Value(intervalDays);
  static Insertable<ReviewLogsTableData> custom({
    Expression<String>? id,
    Expression<String>? serverId,
    Expression<String>? cardId,
    Expression<String>? userId,
    Expression<int>? rating,
    Expression<DateTime>? shownAt,
    Expression<DateTime>? reviewedAt,
    Expression<int>? responseTimeSec,
    Expression<int>? repetitionNumber,
    Expression<double>? stabilityAfter,
    Expression<double>? difficultyAfter,
    Expression<DateTime>? nextDueDate,
    Expression<int>? intervalDays,
    Expression<String>? userFeedback,
    Expression<int>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (cardId != null) 'card_id': cardId,
      if (userId != null) 'user_id': userId,
      if (rating != null) 'rating': rating,
      if (shownAt != null) 'shown_at': shownAt,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (responseTimeSec != null) 'response_time_sec': responseTimeSec,
      if (repetitionNumber != null) 'repetition_number': repetitionNumber,
      if (stabilityAfter != null) 'stability_after': stabilityAfter,
      if (difficultyAfter != null) 'difficulty_after': difficultyAfter,
      if (nextDueDate != null) 'next_due_date': nextDueDate,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (userFeedback != null) 'user_feedback': userFeedback,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewLogsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? serverId,
    Value<String>? cardId,
    Value<String>? userId,
    Value<int>? rating,
    Value<DateTime>? shownAt,
    Value<DateTime>? reviewedAt,
    Value<int>? responseTimeSec,
    Value<int>? repetitionNumber,
    Value<double>? stabilityAfter,
    Value<double>? difficultyAfter,
    Value<DateTime>? nextDueDate,
    Value<int>? intervalDays,
    Value<String?>? userFeedback,
    Value<int>? syncStatus,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ReviewLogsTableCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      cardId: cardId ?? this.cardId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      shownAt: shownAt ?? this.shownAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      responseTimeSec: responseTimeSec ?? this.responseTimeSec,
      repetitionNumber: repetitionNumber ?? this.repetitionNumber,
      stabilityAfter: stabilityAfter ?? this.stabilityAfter,
      difficultyAfter: difficultyAfter ?? this.difficultyAfter,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      intervalDays: intervalDays ?? this.intervalDays,
      userFeedback: userFeedback ?? this.userFeedback,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (shownAt.present) {
      map['shown_at'] = Variable<DateTime>(shownAt.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt.value);
    }
    if (responseTimeSec.present) {
      map['response_time_sec'] = Variable<int>(responseTimeSec.value);
    }
    if (repetitionNumber.present) {
      map['repetition_number'] = Variable<int>(repetitionNumber.value);
    }
    if (stabilityAfter.present) {
      map['stability_after'] = Variable<double>(stabilityAfter.value);
    }
    if (difficultyAfter.present) {
      map['difficulty_after'] = Variable<double>(difficultyAfter.value);
    }
    if (nextDueDate.present) {
      map['next_due_date'] = Variable<DateTime>(nextDueDate.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (userFeedback.present) {
      map['user_feedback'] = Variable<String>(userFeedback.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogsTableCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('cardId: $cardId, ')
          ..write('userId: $userId, ')
          ..write('rating: $rating, ')
          ..write('shownAt: $shownAt, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('responseTimeSec: $responseTimeSec, ')
          ..write('repetitionNumber: $repetitionNumber, ')
          ..write('stabilityAfter: $stabilityAfter, ')
          ..write('difficultyAfter: $difficultyAfter, ')
          ..write('nextDueDate: $nextDueDate, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('userFeedback: $userFeedback, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudentFsrsProfilesTableTable extends StudentFsrsProfilesTable
    with
        TableInfo<
          $StudentFsrsProfilesTableTable,
          StudentFsrsProfilesTableData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudentFsrsProfilesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _desiredRetentionMeta = const VerificationMeta(
    'desiredRetention',
  );
  @override
  late final GeneratedColumn<double> desiredRetention = GeneratedColumn<double>(
    'desired_retention',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.9),
  );
  static const VerificationMeta _maximumIntervalMeta = const VerificationMeta(
    'maximumInterval',
  );
  @override
  late final GeneratedColumn<int> maximumInterval = GeneratedColumn<int>(
    'maximum_interval',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(90),
  );
  static const VerificationMeta _enableFuzzMeta = const VerificationMeta(
    'enableFuzz',
  );
  @override
  late final GeneratedColumn<bool> enableFuzz = GeneratedColumn<bool>(
    'enable_fuzz',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enable_fuzz" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _enableShortTermMeta = const VerificationMeta(
    'enableShortTerm',
  );
  @override
  late final GeneratedColumn<bool> enableShortTerm = GeneratedColumn<bool>(
    'enable_short_term',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enable_short_term" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _learningStepsMeta = const VerificationMeta(
    'learningSteps',
  );
  @override
  late final GeneratedColumn<String> learningSteps = GeneratedColumn<String>(
    'learning_steps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('["1m","10m"]'),
  );
  static const VerificationMeta _relearningStepsMeta = const VerificationMeta(
    'relearningSteps',
  );
  @override
  late final GeneratedColumn<String> relearningSteps = GeneratedColumn<String>(
    'relearning_steps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('["10m"]'),
  );
  static const VerificationMeta _fsrsWeightsMeta = const VerificationMeta(
    'fsrsWeights',
  );
  @override
  late final GeneratedColumn<String> fsrsWeights = GeneratedColumn<String>(
    'fsrs_weights',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('default'),
  );
  static const VerificationMeta _profileVersionMeta = const VerificationMeta(
    'profileVersion',
  );
  @override
  late final GeneratedColumn<int> profileVersion = GeneratedColumn<int>(
    'profile_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _dailyNewLimitMeta = const VerificationMeta(
    'dailyNewLimit',
  );
  @override
  late final GeneratedColumn<int> dailyNewLimit = GeneratedColumn<int>(
    'daily_new_limit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _dailyReviewLimitMeta = const VerificationMeta(
    'dailyReviewLimit',
  );
  @override
  late final GeneratedColumn<int> dailyReviewLimit = GeneratedColumn<int>(
    'daily_review_limit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(50),
  );
  static const VerificationMeta _sessionExpirationSecMeta =
      const VerificationMeta('sessionExpirationSec');
  @override
  late final GeneratedColumn<int> sessionExpirationSec = GeneratedColumn<int>(
    'session_expiration_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(7200),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    desiredRetention,
    maximumInterval,
    enableFuzz,
    enableShortTerm,
    learningSteps,
    relearningSteps,
    fsrsWeights,
    profileVersion,
    dailyNewLimit,
    dailyReviewLimit,
    sessionExpirationSec,
    syncStatus,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'student_fsrs_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudentFsrsProfilesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('desired_retention')) {
      context.handle(
        _desiredRetentionMeta,
        desiredRetention.isAcceptableOrUnknown(
          data['desired_retention']!,
          _desiredRetentionMeta,
        ),
      );
    }
    if (data.containsKey('maximum_interval')) {
      context.handle(
        _maximumIntervalMeta,
        maximumInterval.isAcceptableOrUnknown(
          data['maximum_interval']!,
          _maximumIntervalMeta,
        ),
      );
    }
    if (data.containsKey('enable_fuzz')) {
      context.handle(
        _enableFuzzMeta,
        enableFuzz.isAcceptableOrUnknown(data['enable_fuzz']!, _enableFuzzMeta),
      );
    }
    if (data.containsKey('enable_short_term')) {
      context.handle(
        _enableShortTermMeta,
        enableShortTerm.isAcceptableOrUnknown(
          data['enable_short_term']!,
          _enableShortTermMeta,
        ),
      );
    }
    if (data.containsKey('learning_steps')) {
      context.handle(
        _learningStepsMeta,
        learningSteps.isAcceptableOrUnknown(
          data['learning_steps']!,
          _learningStepsMeta,
        ),
      );
    }
    if (data.containsKey('relearning_steps')) {
      context.handle(
        _relearningStepsMeta,
        relearningSteps.isAcceptableOrUnknown(
          data['relearning_steps']!,
          _relearningStepsMeta,
        ),
      );
    }
    if (data.containsKey('fsrs_weights')) {
      context.handle(
        _fsrsWeightsMeta,
        fsrsWeights.isAcceptableOrUnknown(
          data['fsrs_weights']!,
          _fsrsWeightsMeta,
        ),
      );
    }
    if (data.containsKey('profile_version')) {
      context.handle(
        _profileVersionMeta,
        profileVersion.isAcceptableOrUnknown(
          data['profile_version']!,
          _profileVersionMeta,
        ),
      );
    }
    if (data.containsKey('daily_new_limit')) {
      context.handle(
        _dailyNewLimitMeta,
        dailyNewLimit.isAcceptableOrUnknown(
          data['daily_new_limit']!,
          _dailyNewLimitMeta,
        ),
      );
    }
    if (data.containsKey('daily_review_limit')) {
      context.handle(
        _dailyReviewLimitMeta,
        dailyReviewLimit.isAcceptableOrUnknown(
          data['daily_review_limit']!,
          _dailyReviewLimitMeta,
        ),
      );
    }
    if (data.containsKey('session_expiration_sec')) {
      context.handle(
        _sessionExpirationSecMeta,
        sessionExpirationSec.isAcceptableOrUnknown(
          data['session_expiration_sec']!,
          _sessionExpirationSecMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudentFsrsProfilesTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudentFsrsProfilesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      desiredRetention: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}desired_retention'],
      )!,
      maximumInterval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}maximum_interval'],
      )!,
      enableFuzz: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enable_fuzz'],
      )!,
      enableShortTerm: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enable_short_term'],
      )!,
      learningSteps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learning_steps'],
      )!,
      relearningSteps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relearning_steps'],
      )!,
      fsrsWeights: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fsrs_weights'],
      )!,
      profileVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_version'],
      )!,
      dailyNewLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_new_limit'],
      )!,
      dailyReviewLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_review_limit'],
      )!,
      sessionExpirationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_expiration_sec'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StudentFsrsProfilesTableTable createAlias(String alias) {
    return $StudentFsrsProfilesTableTable(attachedDatabase, alias);
  }
}

class StudentFsrsProfilesTableData extends DataClass
    implements Insertable<StudentFsrsProfilesTableData> {
  final String id;
  final String userId;
  final double desiredRetention;
  final int maximumInterval;
  final bool enableFuzz;
  final bool enableShortTerm;
  final String learningSteps;
  final String relearningSteps;
  final String fsrsWeights;
  final int profileVersion;
  final int dailyNewLimit;
  final int dailyReviewLimit;
  final int sessionExpirationSec;
  final int syncStatus;
  final DateTime updatedAt;
  const StudentFsrsProfilesTableData({
    required this.id,
    required this.userId,
    required this.desiredRetention,
    required this.maximumInterval,
    required this.enableFuzz,
    required this.enableShortTerm,
    required this.learningSteps,
    required this.relearningSteps,
    required this.fsrsWeights,
    required this.profileVersion,
    required this.dailyNewLimit,
    required this.dailyReviewLimit,
    required this.sessionExpirationSec,
    required this.syncStatus,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['desired_retention'] = Variable<double>(desiredRetention);
    map['maximum_interval'] = Variable<int>(maximumInterval);
    map['enable_fuzz'] = Variable<bool>(enableFuzz);
    map['enable_short_term'] = Variable<bool>(enableShortTerm);
    map['learning_steps'] = Variable<String>(learningSteps);
    map['relearning_steps'] = Variable<String>(relearningSteps);
    map['fsrs_weights'] = Variable<String>(fsrsWeights);
    map['profile_version'] = Variable<int>(profileVersion);
    map['daily_new_limit'] = Variable<int>(dailyNewLimit);
    map['daily_review_limit'] = Variable<int>(dailyReviewLimit);
    map['session_expiration_sec'] = Variable<int>(sessionExpirationSec);
    map['sync_status'] = Variable<int>(syncStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StudentFsrsProfilesTableCompanion toCompanion(bool nullToAbsent) {
    return StudentFsrsProfilesTableCompanion(
      id: Value(id),
      userId: Value(userId),
      desiredRetention: Value(desiredRetention),
      maximumInterval: Value(maximumInterval),
      enableFuzz: Value(enableFuzz),
      enableShortTerm: Value(enableShortTerm),
      learningSteps: Value(learningSteps),
      relearningSteps: Value(relearningSteps),
      fsrsWeights: Value(fsrsWeights),
      profileVersion: Value(profileVersion),
      dailyNewLimit: Value(dailyNewLimit),
      dailyReviewLimit: Value(dailyReviewLimit),
      sessionExpirationSec: Value(sessionExpirationSec),
      syncStatus: Value(syncStatus),
      updatedAt: Value(updatedAt),
    );
  }

  factory StudentFsrsProfilesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudentFsrsProfilesTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      desiredRetention: serializer.fromJson<double>(json['desiredRetention']),
      maximumInterval: serializer.fromJson<int>(json['maximumInterval']),
      enableFuzz: serializer.fromJson<bool>(json['enableFuzz']),
      enableShortTerm: serializer.fromJson<bool>(json['enableShortTerm']),
      learningSteps: serializer.fromJson<String>(json['learningSteps']),
      relearningSteps: serializer.fromJson<String>(json['relearningSteps']),
      fsrsWeights: serializer.fromJson<String>(json['fsrsWeights']),
      profileVersion: serializer.fromJson<int>(json['profileVersion']),
      dailyNewLimit: serializer.fromJson<int>(json['dailyNewLimit']),
      dailyReviewLimit: serializer.fromJson<int>(json['dailyReviewLimit']),
      sessionExpirationSec: serializer.fromJson<int>(
        json['sessionExpirationSec'],
      ),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'desiredRetention': serializer.toJson<double>(desiredRetention),
      'maximumInterval': serializer.toJson<int>(maximumInterval),
      'enableFuzz': serializer.toJson<bool>(enableFuzz),
      'enableShortTerm': serializer.toJson<bool>(enableShortTerm),
      'learningSteps': serializer.toJson<String>(learningSteps),
      'relearningSteps': serializer.toJson<String>(relearningSteps),
      'fsrsWeights': serializer.toJson<String>(fsrsWeights),
      'profileVersion': serializer.toJson<int>(profileVersion),
      'dailyNewLimit': serializer.toJson<int>(dailyNewLimit),
      'dailyReviewLimit': serializer.toJson<int>(dailyReviewLimit),
      'sessionExpirationSec': serializer.toJson<int>(sessionExpirationSec),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StudentFsrsProfilesTableData copyWith({
    String? id,
    String? userId,
    double? desiredRetention,
    int? maximumInterval,
    bool? enableFuzz,
    bool? enableShortTerm,
    String? learningSteps,
    String? relearningSteps,
    String? fsrsWeights,
    int? profileVersion,
    int? dailyNewLimit,
    int? dailyReviewLimit,
    int? sessionExpirationSec,
    int? syncStatus,
    DateTime? updatedAt,
  }) => StudentFsrsProfilesTableData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    desiredRetention: desiredRetention ?? this.desiredRetention,
    maximumInterval: maximumInterval ?? this.maximumInterval,
    enableFuzz: enableFuzz ?? this.enableFuzz,
    enableShortTerm: enableShortTerm ?? this.enableShortTerm,
    learningSteps: learningSteps ?? this.learningSteps,
    relearningSteps: relearningSteps ?? this.relearningSteps,
    fsrsWeights: fsrsWeights ?? this.fsrsWeights,
    profileVersion: profileVersion ?? this.profileVersion,
    dailyNewLimit: dailyNewLimit ?? this.dailyNewLimit,
    dailyReviewLimit: dailyReviewLimit ?? this.dailyReviewLimit,
    sessionExpirationSec: sessionExpirationSec ?? this.sessionExpirationSec,
    syncStatus: syncStatus ?? this.syncStatus,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StudentFsrsProfilesTableData copyWithCompanion(
    StudentFsrsProfilesTableCompanion data,
  ) {
    return StudentFsrsProfilesTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      desiredRetention: data.desiredRetention.present
          ? data.desiredRetention.value
          : this.desiredRetention,
      maximumInterval: data.maximumInterval.present
          ? data.maximumInterval.value
          : this.maximumInterval,
      enableFuzz: data.enableFuzz.present
          ? data.enableFuzz.value
          : this.enableFuzz,
      enableShortTerm: data.enableShortTerm.present
          ? data.enableShortTerm.value
          : this.enableShortTerm,
      learningSteps: data.learningSteps.present
          ? data.learningSteps.value
          : this.learningSteps,
      relearningSteps: data.relearningSteps.present
          ? data.relearningSteps.value
          : this.relearningSteps,
      fsrsWeights: data.fsrsWeights.present
          ? data.fsrsWeights.value
          : this.fsrsWeights,
      profileVersion: data.profileVersion.present
          ? data.profileVersion.value
          : this.profileVersion,
      dailyNewLimit: data.dailyNewLimit.present
          ? data.dailyNewLimit.value
          : this.dailyNewLimit,
      dailyReviewLimit: data.dailyReviewLimit.present
          ? data.dailyReviewLimit.value
          : this.dailyReviewLimit,
      sessionExpirationSec: data.sessionExpirationSec.present
          ? data.sessionExpirationSec.value
          : this.sessionExpirationSec,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudentFsrsProfilesTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('desiredRetention: $desiredRetention, ')
          ..write('maximumInterval: $maximumInterval, ')
          ..write('enableFuzz: $enableFuzz, ')
          ..write('enableShortTerm: $enableShortTerm, ')
          ..write('learningSteps: $learningSteps, ')
          ..write('relearningSteps: $relearningSteps, ')
          ..write('fsrsWeights: $fsrsWeights, ')
          ..write('profileVersion: $profileVersion, ')
          ..write('dailyNewLimit: $dailyNewLimit, ')
          ..write('dailyReviewLimit: $dailyReviewLimit, ')
          ..write('sessionExpirationSec: $sessionExpirationSec, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    desiredRetention,
    maximumInterval,
    enableFuzz,
    enableShortTerm,
    learningSteps,
    relearningSteps,
    fsrsWeights,
    profileVersion,
    dailyNewLimit,
    dailyReviewLimit,
    sessionExpirationSec,
    syncStatus,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudentFsrsProfilesTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.desiredRetention == this.desiredRetention &&
          other.maximumInterval == this.maximumInterval &&
          other.enableFuzz == this.enableFuzz &&
          other.enableShortTerm == this.enableShortTerm &&
          other.learningSteps == this.learningSteps &&
          other.relearningSteps == this.relearningSteps &&
          other.fsrsWeights == this.fsrsWeights &&
          other.profileVersion == this.profileVersion &&
          other.dailyNewLimit == this.dailyNewLimit &&
          other.dailyReviewLimit == this.dailyReviewLimit &&
          other.sessionExpirationSec == this.sessionExpirationSec &&
          other.syncStatus == this.syncStatus &&
          other.updatedAt == this.updatedAt);
}

class StudentFsrsProfilesTableCompanion
    extends UpdateCompanion<StudentFsrsProfilesTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<double> desiredRetention;
  final Value<int> maximumInterval;
  final Value<bool> enableFuzz;
  final Value<bool> enableShortTerm;
  final Value<String> learningSteps;
  final Value<String> relearningSteps;
  final Value<String> fsrsWeights;
  final Value<int> profileVersion;
  final Value<int> dailyNewLimit;
  final Value<int> dailyReviewLimit;
  final Value<int> sessionExpirationSec;
  final Value<int> syncStatus;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StudentFsrsProfilesTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.desiredRetention = const Value.absent(),
    this.maximumInterval = const Value.absent(),
    this.enableFuzz = const Value.absent(),
    this.enableShortTerm = const Value.absent(),
    this.learningSteps = const Value.absent(),
    this.relearningSteps = const Value.absent(),
    this.fsrsWeights = const Value.absent(),
    this.profileVersion = const Value.absent(),
    this.dailyNewLimit = const Value.absent(),
    this.dailyReviewLimit = const Value.absent(),
    this.sessionExpirationSec = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudentFsrsProfilesTableCompanion.insert({
    required String id,
    required String userId,
    this.desiredRetention = const Value.absent(),
    this.maximumInterval = const Value.absent(),
    this.enableFuzz = const Value.absent(),
    this.enableShortTerm = const Value.absent(),
    this.learningSteps = const Value.absent(),
    this.relearningSteps = const Value.absent(),
    this.fsrsWeights = const Value.absent(),
    this.profileVersion = const Value.absent(),
    this.dailyNewLimit = const Value.absent(),
    this.dailyReviewLimit = const Value.absent(),
    this.sessionExpirationSec = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId);
  static Insertable<StudentFsrsProfilesTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<double>? desiredRetention,
    Expression<int>? maximumInterval,
    Expression<bool>? enableFuzz,
    Expression<bool>? enableShortTerm,
    Expression<String>? learningSteps,
    Expression<String>? relearningSteps,
    Expression<String>? fsrsWeights,
    Expression<int>? profileVersion,
    Expression<int>? dailyNewLimit,
    Expression<int>? dailyReviewLimit,
    Expression<int>? sessionExpirationSec,
    Expression<int>? syncStatus,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (desiredRetention != null) 'desired_retention': desiredRetention,
      if (maximumInterval != null) 'maximum_interval': maximumInterval,
      if (enableFuzz != null) 'enable_fuzz': enableFuzz,
      if (enableShortTerm != null) 'enable_short_term': enableShortTerm,
      if (learningSteps != null) 'learning_steps': learningSteps,
      if (relearningSteps != null) 'relearning_steps': relearningSteps,
      if (fsrsWeights != null) 'fsrs_weights': fsrsWeights,
      if (profileVersion != null) 'profile_version': profileVersion,
      if (dailyNewLimit != null) 'daily_new_limit': dailyNewLimit,
      if (dailyReviewLimit != null) 'daily_review_limit': dailyReviewLimit,
      if (sessionExpirationSec != null)
        'session_expiration_sec': sessionExpirationSec,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudentFsrsProfilesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<double>? desiredRetention,
    Value<int>? maximumInterval,
    Value<bool>? enableFuzz,
    Value<bool>? enableShortTerm,
    Value<String>? learningSteps,
    Value<String>? relearningSteps,
    Value<String>? fsrsWeights,
    Value<int>? profileVersion,
    Value<int>? dailyNewLimit,
    Value<int>? dailyReviewLimit,
    Value<int>? sessionExpirationSec,
    Value<int>? syncStatus,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StudentFsrsProfilesTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      desiredRetention: desiredRetention ?? this.desiredRetention,
      maximumInterval: maximumInterval ?? this.maximumInterval,
      enableFuzz: enableFuzz ?? this.enableFuzz,
      enableShortTerm: enableShortTerm ?? this.enableShortTerm,
      learningSteps: learningSteps ?? this.learningSteps,
      relearningSteps: relearningSteps ?? this.relearningSteps,
      fsrsWeights: fsrsWeights ?? this.fsrsWeights,
      profileVersion: profileVersion ?? this.profileVersion,
      dailyNewLimit: dailyNewLimit ?? this.dailyNewLimit,
      dailyReviewLimit: dailyReviewLimit ?? this.dailyReviewLimit,
      sessionExpirationSec: sessionExpirationSec ?? this.sessionExpirationSec,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (desiredRetention.present) {
      map['desired_retention'] = Variable<double>(desiredRetention.value);
    }
    if (maximumInterval.present) {
      map['maximum_interval'] = Variable<int>(maximumInterval.value);
    }
    if (enableFuzz.present) {
      map['enable_fuzz'] = Variable<bool>(enableFuzz.value);
    }
    if (enableShortTerm.present) {
      map['enable_short_term'] = Variable<bool>(enableShortTerm.value);
    }
    if (learningSteps.present) {
      map['learning_steps'] = Variable<String>(learningSteps.value);
    }
    if (relearningSteps.present) {
      map['relearning_steps'] = Variable<String>(relearningSteps.value);
    }
    if (fsrsWeights.present) {
      map['fsrs_weights'] = Variable<String>(fsrsWeights.value);
    }
    if (profileVersion.present) {
      map['profile_version'] = Variable<int>(profileVersion.value);
    }
    if (dailyNewLimit.present) {
      map['daily_new_limit'] = Variable<int>(dailyNewLimit.value);
    }
    if (dailyReviewLimit.present) {
      map['daily_review_limit'] = Variable<int>(dailyReviewLimit.value);
    }
    if (sessionExpirationSec.present) {
      map['session_expiration_sec'] = Variable<int>(sessionExpirationSec.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudentFsrsProfilesTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('desiredRetention: $desiredRetention, ')
          ..write('maximumInterval: $maximumInterval, ')
          ..write('enableFuzz: $enableFuzz, ')
          ..write('enableShortTerm: $enableShortTerm, ')
          ..write('learningSteps: $learningSteps, ')
          ..write('relearningSteps: $relearningSteps, ')
          ..write('fsrsWeights: $fsrsWeights, ')
          ..write('profileVersion: $profileVersion, ')
          ..write('dailyNewLimit: $dailyNewLimit, ')
          ..write('dailyReviewLimit: $dailyReviewLimit, ')
          ..write('sessionExpirationSec: $sessionExpirationSec, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkHeartbeatsTableTable extends WorkHeartbeatsTable
    with TableInfo<$WorkHeartbeatsTableTable, WorkHeartbeatsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkHeartbeatsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contextMeta = const VerificationMeta(
    'context',
  );
  @override
  late final GeneratedColumn<String> context = GeneratedColumn<String>(
    'context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    clientUuid,
    courseId,
    lessonId,
    context,
    occurredAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'work_heartbeats';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkHeartbeatsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUuidMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    }
    if (data.containsKey('context')) {
      context.handle(
        _contextMeta,
        this.context.isAcceptableOrUnknown(data['context']!, _contextMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientUuid};
  @override
  WorkHeartbeatsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkHeartbeatsTableData(
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      ),
      context: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $WorkHeartbeatsTableTable createAlias(String alias) {
    return $WorkHeartbeatsTableTable(attachedDatabase, alias);
  }
}

class WorkHeartbeatsTableData extends DataClass
    implements Insertable<WorkHeartbeatsTableData> {
  /// Local + server idempotency key (UUID v4).
  final String clientUuid;

  /// Course the user was working in.
  final String courseId;

  /// Lesson within the course, if known.
  final String? lessonId;

  /// Where the user was (e.g. 'lesson', 'quiz', 'chat', 'video').
  final String? context;

  /// When the heartbeat fired (device clock, UTC).
  final DateTime occurredAt;

  /// False until the API has accepted this row.
  final bool synced;
  const WorkHeartbeatsTableData({
    required this.clientUuid,
    required this.courseId,
    this.lessonId,
    this.context,
    required this.occurredAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_uuid'] = Variable<String>(clientUuid);
    map['course_id'] = Variable<String>(courseId);
    if (!nullToAbsent || lessonId != null) {
      map['lesson_id'] = Variable<String>(lessonId);
    }
    if (!nullToAbsent || context != null) {
      map['context'] = Variable<String>(context);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  WorkHeartbeatsTableCompanion toCompanion(bool nullToAbsent) {
    return WorkHeartbeatsTableCompanion(
      clientUuid: Value(clientUuid),
      courseId: Value(courseId),
      lessonId: lessonId == null && nullToAbsent
          ? const Value.absent()
          : Value(lessonId),
      context: context == null && nullToAbsent
          ? const Value.absent()
          : Value(context),
      occurredAt: Value(occurredAt),
      synced: Value(synced),
    );
  }

  factory WorkHeartbeatsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkHeartbeatsTableData(
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      courseId: serializer.fromJson<String>(json['courseId']),
      lessonId: serializer.fromJson<String?>(json['lessonId']),
      context: serializer.fromJson<String?>(json['context']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUuid': serializer.toJson<String>(clientUuid),
      'courseId': serializer.toJson<String>(courseId),
      'lessonId': serializer.toJson<String?>(lessonId),
      'context': serializer.toJson<String?>(context),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  WorkHeartbeatsTableData copyWith({
    String? clientUuid,
    String? courseId,
    Value<String?> lessonId = const Value.absent(),
    Value<String?> context = const Value.absent(),
    DateTime? occurredAt,
    bool? synced,
  }) => WorkHeartbeatsTableData(
    clientUuid: clientUuid ?? this.clientUuid,
    courseId: courseId ?? this.courseId,
    lessonId: lessonId.present ? lessonId.value : this.lessonId,
    context: context.present ? context.value : this.context,
    occurredAt: occurredAt ?? this.occurredAt,
    synced: synced ?? this.synced,
  );
  WorkHeartbeatsTableData copyWithCompanion(WorkHeartbeatsTableCompanion data) {
    return WorkHeartbeatsTableData(
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      context: data.context.present ? data.context.value : this.context,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkHeartbeatsTableData(')
          ..write('clientUuid: $clientUuid, ')
          ..write('courseId: $courseId, ')
          ..write('lessonId: $lessonId, ')
          ..write('context: $context, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(clientUuid, courseId, lessonId, context, occurredAt, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkHeartbeatsTableData &&
          other.clientUuid == this.clientUuid &&
          other.courseId == this.courseId &&
          other.lessonId == this.lessonId &&
          other.context == this.context &&
          other.occurredAt == this.occurredAt &&
          other.synced == this.synced);
}

class WorkHeartbeatsTableCompanion
    extends UpdateCompanion<WorkHeartbeatsTableData> {
  final Value<String> clientUuid;
  final Value<String> courseId;
  final Value<String?> lessonId;
  final Value<String?> context;
  final Value<DateTime> occurredAt;
  final Value<bool> synced;
  final Value<int> rowid;
  const WorkHeartbeatsTableCompanion({
    this.clientUuid = const Value.absent(),
    this.courseId = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.context = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkHeartbeatsTableCompanion.insert({
    required String clientUuid,
    required String courseId,
    this.lessonId = const Value.absent(),
    this.context = const Value.absent(),
    required DateTime occurredAt,
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : clientUuid = Value(clientUuid),
       courseId = Value(courseId),
       occurredAt = Value(occurredAt);
  static Insertable<WorkHeartbeatsTableData> custom({
    Expression<String>? clientUuid,
    Expression<String>? courseId,
    Expression<String>? lessonId,
    Expression<String>? context,
    Expression<DateTime>? occurredAt,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (courseId != null) 'course_id': courseId,
      if (lessonId != null) 'lesson_id': lessonId,
      if (context != null) 'context': context,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkHeartbeatsTableCompanion copyWith({
    Value<String>? clientUuid,
    Value<String>? courseId,
    Value<String?>? lessonId,
    Value<String?>? context,
    Value<DateTime>? occurredAt,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return WorkHeartbeatsTableCompanion(
      clientUuid: clientUuid ?? this.clientUuid,
      courseId: courseId ?? this.courseId,
      lessonId: lessonId ?? this.lessonId,
      context: context ?? this.context,
      occurredAt: occurredAt ?? this.occurredAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (context.present) {
      map['context'] = Variable<String>(context.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkHeartbeatsTableCompanion(')
          ..write('clientUuid: $clientUuid, ')
          ..write('courseId: $courseId, ')
          ..write('lessonId: $lessonId, ')
          ..write('context: $context, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GpfDimensionsTableTable extends GpfDimensionsTable
    with TableInfo<$GpfDimensionsTableTable, GpfDimensionsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GpfDimensionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dimensionIndexMeta = const VerificationMeta(
    'dimensionIndex',
  );
  @override
  late final GeneratedColumn<int> dimensionIndex = GeneratedColumn<int>(
    'dimension_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _domainCodeMeta = const VerificationMeta(
    'domainCode',
  );
  @override
  late final GeneratedColumn<String> domainCode = GeneratedColumn<String>(
    'domain_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _domainNameMeta = const VerificationMeta(
    'domainName',
  );
  @override
  late final GeneratedColumn<String> domainName = GeneratedColumn<String>(
    'domain_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _constructNameMeta = const VerificationMeta(
    'constructName',
  );
  @override
  late final GeneratedColumn<String> constructName = GeneratedColumn<String>(
    'construct_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    dimensionIndex,
    code,
    domainCode,
    domainName,
    constructName,
    name,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gpf_dimensions';
  @override
  VerificationContext validateIntegrity(
    Insertable<GpfDimensionsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dimension_index')) {
      context.handle(
        _dimensionIndexMeta,
        dimensionIndex.isAcceptableOrUnknown(
          data['dimension_index']!,
          _dimensionIndexMeta,
        ),
      );
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('domain_code')) {
      context.handle(
        _domainCodeMeta,
        domainCode.isAcceptableOrUnknown(data['domain_code']!, _domainCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_domainCodeMeta);
    }
    if (data.containsKey('domain_name')) {
      context.handle(
        _domainNameMeta,
        domainName.isAcceptableOrUnknown(data['domain_name']!, _domainNameMeta),
      );
    } else if (isInserting) {
      context.missing(_domainNameMeta);
    }
    if (data.containsKey('construct_name')) {
      context.handle(
        _constructNameMeta,
        constructName.isAcceptableOrUnknown(
          data['construct_name']!,
          _constructNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_constructNameMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dimensionIndex};
  @override
  GpfDimensionsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GpfDimensionsTableData(
      dimensionIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dimension_index'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      domainCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}domain_code'],
      )!,
      domainName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}domain_name'],
      )!,
      constructName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}construct_name'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $GpfDimensionsTableTable createAlias(String alias) {
    return $GpfDimensionsTableTable(attachedDatabase, alias);
  }
}

class GpfDimensionsTableData extends DataClass
    implements Insertable<GpfDimensionsTableData> {
  /// Zero-based index in the 35-element vector (0–34). Primary key.
  final int dimensionIndex;

  /// Hierarchical code, e.g. "N1.1".
  final String code;

  /// Parent domain code, e.g. "N".
  final String domainCode;

  /// Czech domain name, e.g. "Číslo a operace".
  final String domainName;

  /// Czech construct name, e.g. "Přirozená čísla".
  final String constructName;

  /// Czech subconstruct name.
  final String name;
  const GpfDimensionsTableData({
    required this.dimensionIndex,
    required this.code,
    required this.domainCode,
    required this.domainName,
    required this.constructName,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dimension_index'] = Variable<int>(dimensionIndex);
    map['code'] = Variable<String>(code);
    map['domain_code'] = Variable<String>(domainCode);
    map['domain_name'] = Variable<String>(domainName);
    map['construct_name'] = Variable<String>(constructName);
    map['name'] = Variable<String>(name);
    return map;
  }

  GpfDimensionsTableCompanion toCompanion(bool nullToAbsent) {
    return GpfDimensionsTableCompanion(
      dimensionIndex: Value(dimensionIndex),
      code: Value(code),
      domainCode: Value(domainCode),
      domainName: Value(domainName),
      constructName: Value(constructName),
      name: Value(name),
    );
  }

  factory GpfDimensionsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GpfDimensionsTableData(
      dimensionIndex: serializer.fromJson<int>(json['dimensionIndex']),
      code: serializer.fromJson<String>(json['code']),
      domainCode: serializer.fromJson<String>(json['domainCode']),
      domainName: serializer.fromJson<String>(json['domainName']),
      constructName: serializer.fromJson<String>(json['constructName']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dimensionIndex': serializer.toJson<int>(dimensionIndex),
      'code': serializer.toJson<String>(code),
      'domainCode': serializer.toJson<String>(domainCode),
      'domainName': serializer.toJson<String>(domainName),
      'constructName': serializer.toJson<String>(constructName),
      'name': serializer.toJson<String>(name),
    };
  }

  GpfDimensionsTableData copyWith({
    int? dimensionIndex,
    String? code,
    String? domainCode,
    String? domainName,
    String? constructName,
    String? name,
  }) => GpfDimensionsTableData(
    dimensionIndex: dimensionIndex ?? this.dimensionIndex,
    code: code ?? this.code,
    domainCode: domainCode ?? this.domainCode,
    domainName: domainName ?? this.domainName,
    constructName: constructName ?? this.constructName,
    name: name ?? this.name,
  );
  GpfDimensionsTableData copyWithCompanion(GpfDimensionsTableCompanion data) {
    return GpfDimensionsTableData(
      dimensionIndex: data.dimensionIndex.present
          ? data.dimensionIndex.value
          : this.dimensionIndex,
      code: data.code.present ? data.code.value : this.code,
      domainCode: data.domainCode.present
          ? data.domainCode.value
          : this.domainCode,
      domainName: data.domainName.present
          ? data.domainName.value
          : this.domainName,
      constructName: data.constructName.present
          ? data.constructName.value
          : this.constructName,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GpfDimensionsTableData(')
          ..write('dimensionIndex: $dimensionIndex, ')
          ..write('code: $code, ')
          ..write('domainCode: $domainCode, ')
          ..write('domainName: $domainName, ')
          ..write('constructName: $constructName, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    dimensionIndex,
    code,
    domainCode,
    domainName,
    constructName,
    name,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GpfDimensionsTableData &&
          other.dimensionIndex == this.dimensionIndex &&
          other.code == this.code &&
          other.domainCode == this.domainCode &&
          other.domainName == this.domainName &&
          other.constructName == this.constructName &&
          other.name == this.name);
}

class GpfDimensionsTableCompanion
    extends UpdateCompanion<GpfDimensionsTableData> {
  final Value<int> dimensionIndex;
  final Value<String> code;
  final Value<String> domainCode;
  final Value<String> domainName;
  final Value<String> constructName;
  final Value<String> name;
  const GpfDimensionsTableCompanion({
    this.dimensionIndex = const Value.absent(),
    this.code = const Value.absent(),
    this.domainCode = const Value.absent(),
    this.domainName = const Value.absent(),
    this.constructName = const Value.absent(),
    this.name = const Value.absent(),
  });
  GpfDimensionsTableCompanion.insert({
    this.dimensionIndex = const Value.absent(),
    required String code,
    required String domainCode,
    required String domainName,
    required String constructName,
    required String name,
  }) : code = Value(code),
       domainCode = Value(domainCode),
       domainName = Value(domainName),
       constructName = Value(constructName),
       name = Value(name);
  static Insertable<GpfDimensionsTableData> custom({
    Expression<int>? dimensionIndex,
    Expression<String>? code,
    Expression<String>? domainCode,
    Expression<String>? domainName,
    Expression<String>? constructName,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (dimensionIndex != null) 'dimension_index': dimensionIndex,
      if (code != null) 'code': code,
      if (domainCode != null) 'domain_code': domainCode,
      if (domainName != null) 'domain_name': domainName,
      if (constructName != null) 'construct_name': constructName,
      if (name != null) 'name': name,
    });
  }

  GpfDimensionsTableCompanion copyWith({
    Value<int>? dimensionIndex,
    Value<String>? code,
    Value<String>? domainCode,
    Value<String>? domainName,
    Value<String>? constructName,
    Value<String>? name,
  }) {
    return GpfDimensionsTableCompanion(
      dimensionIndex: dimensionIndex ?? this.dimensionIndex,
      code: code ?? this.code,
      domainCode: domainCode ?? this.domainCode,
      domainName: domainName ?? this.domainName,
      constructName: constructName ?? this.constructName,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dimensionIndex.present) {
      map['dimension_index'] = Variable<int>(dimensionIndex.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (domainCode.present) {
      map['domain_code'] = Variable<String>(domainCode.value);
    }
    if (domainName.present) {
      map['domain_name'] = Variable<String>(domainName.value);
    }
    if (constructName.present) {
      map['construct_name'] = Variable<String>(constructName.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GpfDimensionsTableCompanion(')
          ..write('dimensionIndex: $dimensionIndex, ')
          ..write('code: $code, ')
          ..write('domainCode: $domainCode, ')
          ..write('domainName: $domainName, ')
          ..write('constructName: $constructName, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $AvatarItemsTableTable extends AvatarItemsTable
    with TableInfo<$AvatarItemsTableTable, AvatarItemsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AvatarItemsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerMeta = const VerificationMeta('layer');
  @override
  late final GeneratedColumn<int> layer = GeneratedColumn<int>(
    'layer',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rarityMeta = const VerificationMeta('rarity');
  @override
  late final GeneratedColumn<String> rarity = GeneratedColumn<String>(
    'rarity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('common'),
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _svgSourceMeta = const VerificationMeta(
    'svgSource',
  );
  @override
  late final GeneratedColumn<String> svgSource = GeneratedColumn<String>(
    'svg_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _boundsLeftMeta = const VerificationMeta(
    'boundsLeft',
  );
  @override
  late final GeneratedColumn<double> boundsLeft = GeneratedColumn<double>(
    'bounds_left',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _boundsTopMeta = const VerificationMeta(
    'boundsTop',
  );
  @override
  late final GeneratedColumn<double> boundsTop = GeneratedColumn<double>(
    'bounds_top',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _boundsRightMeta = const VerificationMeta(
    'boundsRight',
  );
  @override
  late final GeneratedColumn<double> boundsRight = GeneratedColumn<double>(
    'bounds_right',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _boundsBottomMeta = const VerificationMeta(
    'boundsBottom',
  );
  @override
  late final GeneratedColumn<double> boundsBottom = GeneratedColumn<double>(
    'bounds_bottom',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    code,
    name,
    slot,
    layer,
    url,
    rarity,
    price,
    isDefault,
    svgSource,
    boundsLeft,
    boundsTop,
    boundsRight,
    boundsBottom,
    serverUpdatedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'avatar_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<AvatarItemsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('layer')) {
      context.handle(
        _layerMeta,
        layer.isAcceptableOrUnknown(data['layer']!, _layerMeta),
      );
    } else if (isInserting) {
      context.missing(_layerMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('rarity')) {
      context.handle(
        _rarityMeta,
        rarity.isAcceptableOrUnknown(data['rarity']!, _rarityMeta),
      );
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('svg_source')) {
      context.handle(
        _svgSourceMeta,
        svgSource.isAcceptableOrUnknown(data['svg_source']!, _svgSourceMeta),
      );
    }
    if (data.containsKey('bounds_left')) {
      context.handle(
        _boundsLeftMeta,
        boundsLeft.isAcceptableOrUnknown(data['bounds_left']!, _boundsLeftMeta),
      );
    }
    if (data.containsKey('bounds_top')) {
      context.handle(
        _boundsTopMeta,
        boundsTop.isAcceptableOrUnknown(data['bounds_top']!, _boundsTopMeta),
      );
    }
    if (data.containsKey('bounds_right')) {
      context.handle(
        _boundsRightMeta,
        boundsRight.isAcceptableOrUnknown(
          data['bounds_right']!,
          _boundsRightMeta,
        ),
      );
    }
    if (data.containsKey('bounds_bottom')) {
      context.handle(
        _boundsBottomMeta,
        boundsBottom.isAcceptableOrUnknown(
          data['bounds_bottom']!,
          _boundsBottomMeta,
        ),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  AvatarItemsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AvatarItemsTableData(
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      layer: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}layer'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      rarity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rarity'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      svgSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}svg_source'],
      ),
      boundsLeft: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bounds_left'],
      ),
      boundsTop: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bounds_top'],
      ),
      boundsRight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bounds_right'],
      ),
      boundsBottom: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bounds_bottom'],
      ),
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AvatarItemsTableTable createAlias(String alias) {
    return $AvatarItemsTableTable(attachedDatabase, alias);
  }
}

class AvatarItemsTableData extends DataClass
    implements Insertable<AvatarItemsTableData> {
  /// Server-side stable identifier ("head_zlata_korunka"). Primary key, so a
  /// re-fetch reconciles in place instead of duplicating the catalog.
  final String code;
  final String name;

  /// torso|legs|eyes|mouth|face|head|neck|hands|held
  final String slot;

  /// Paint order — items are drawn ascending.
  final int layer;

  /// R2 URL the artwork was downloaded from.
  final String url;
  final String rarity;

  /// Always 0 while the shop is free; kept so enabling credits is a data change.
  final int price;

  /// Part of the free starting outfit — owned implicitly by everyone.
  final bool isDefault;

  /// The downloaded SVG. Null means "catalog row known, artwork not fetched
  /// yet" — the item is listed but renders as a placeholder until a connection
  /// fills this in.
  final String? svgSource;

  /// Tight bounding box of the artwork's visible content, normalised to the
  /// shared canvas (0..1). Computed once when [svgSource] is cached.
  ///
  /// Assets are drawn where they belong on the body, so a crown is a small
  /// patch near the top of an otherwise empty canvas. The stored geometry has
  /// to stay that way for layering to work; these let the shop tile and the
  /// preview crop to the artwork instead of rendering mostly nothing.
  final double? boundsLeft;
  final double? boundsTop;
  final double? boundsRight;
  final double? boundsBottom;

  /// The catalog row's server timestamp. An admin replacing the artwork keeps
  /// the same URL, so this is what tells us the cached [svgSource] is stale.
  final DateTime? serverUpdatedAt;
  final DateTime updatedAt;
  const AvatarItemsTableData({
    required this.code,
    required this.name,
    required this.slot,
    required this.layer,
    required this.url,
    required this.rarity,
    required this.price,
    required this.isDefault,
    this.svgSource,
    this.boundsLeft,
    this.boundsTop,
    this.boundsRight,
    this.boundsBottom,
    this.serverUpdatedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['slot'] = Variable<String>(slot);
    map['layer'] = Variable<int>(layer);
    map['url'] = Variable<String>(url);
    map['rarity'] = Variable<String>(rarity);
    map['price'] = Variable<int>(price);
    map['is_default'] = Variable<bool>(isDefault);
    if (!nullToAbsent || svgSource != null) {
      map['svg_source'] = Variable<String>(svgSource);
    }
    if (!nullToAbsent || boundsLeft != null) {
      map['bounds_left'] = Variable<double>(boundsLeft);
    }
    if (!nullToAbsent || boundsTop != null) {
      map['bounds_top'] = Variable<double>(boundsTop);
    }
    if (!nullToAbsent || boundsRight != null) {
      map['bounds_right'] = Variable<double>(boundsRight);
    }
    if (!nullToAbsent || boundsBottom != null) {
      map['bounds_bottom'] = Variable<double>(boundsBottom);
    }
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AvatarItemsTableCompanion toCompanion(bool nullToAbsent) {
    return AvatarItemsTableCompanion(
      code: Value(code),
      name: Value(name),
      slot: Value(slot),
      layer: Value(layer),
      url: Value(url),
      rarity: Value(rarity),
      price: Value(price),
      isDefault: Value(isDefault),
      svgSource: svgSource == null && nullToAbsent
          ? const Value.absent()
          : Value(svgSource),
      boundsLeft: boundsLeft == null && nullToAbsent
          ? const Value.absent()
          : Value(boundsLeft),
      boundsTop: boundsTop == null && nullToAbsent
          ? const Value.absent()
          : Value(boundsTop),
      boundsRight: boundsRight == null && nullToAbsent
          ? const Value.absent()
          : Value(boundsRight),
      boundsBottom: boundsBottom == null && nullToAbsent
          ? const Value.absent()
          : Value(boundsBottom),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AvatarItemsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AvatarItemsTableData(
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      slot: serializer.fromJson<String>(json['slot']),
      layer: serializer.fromJson<int>(json['layer']),
      url: serializer.fromJson<String>(json['url']),
      rarity: serializer.fromJson<String>(json['rarity']),
      price: serializer.fromJson<int>(json['price']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      svgSource: serializer.fromJson<String?>(json['svgSource']),
      boundsLeft: serializer.fromJson<double?>(json['boundsLeft']),
      boundsTop: serializer.fromJson<double?>(json['boundsTop']),
      boundsRight: serializer.fromJson<double?>(json['boundsRight']),
      boundsBottom: serializer.fromJson<double?>(json['boundsBottom']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'slot': serializer.toJson<String>(slot),
      'layer': serializer.toJson<int>(layer),
      'url': serializer.toJson<String>(url),
      'rarity': serializer.toJson<String>(rarity),
      'price': serializer.toJson<int>(price),
      'isDefault': serializer.toJson<bool>(isDefault),
      'svgSource': serializer.toJson<String?>(svgSource),
      'boundsLeft': serializer.toJson<double?>(boundsLeft),
      'boundsTop': serializer.toJson<double?>(boundsTop),
      'boundsRight': serializer.toJson<double?>(boundsRight),
      'boundsBottom': serializer.toJson<double?>(boundsBottom),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AvatarItemsTableData copyWith({
    String? code,
    String? name,
    String? slot,
    int? layer,
    String? url,
    String? rarity,
    int? price,
    bool? isDefault,
    Value<String?> svgSource = const Value.absent(),
    Value<double?> boundsLeft = const Value.absent(),
    Value<double?> boundsTop = const Value.absent(),
    Value<double?> boundsRight = const Value.absent(),
    Value<double?> boundsBottom = const Value.absent(),
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => AvatarItemsTableData(
    code: code ?? this.code,
    name: name ?? this.name,
    slot: slot ?? this.slot,
    layer: layer ?? this.layer,
    url: url ?? this.url,
    rarity: rarity ?? this.rarity,
    price: price ?? this.price,
    isDefault: isDefault ?? this.isDefault,
    svgSource: svgSource.present ? svgSource.value : this.svgSource,
    boundsLeft: boundsLeft.present ? boundsLeft.value : this.boundsLeft,
    boundsTop: boundsTop.present ? boundsTop.value : this.boundsTop,
    boundsRight: boundsRight.present ? boundsRight.value : this.boundsRight,
    boundsBottom: boundsBottom.present ? boundsBottom.value : this.boundsBottom,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AvatarItemsTableData copyWithCompanion(AvatarItemsTableCompanion data) {
    return AvatarItemsTableData(
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      slot: data.slot.present ? data.slot.value : this.slot,
      layer: data.layer.present ? data.layer.value : this.layer,
      url: data.url.present ? data.url.value : this.url,
      rarity: data.rarity.present ? data.rarity.value : this.rarity,
      price: data.price.present ? data.price.value : this.price,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      svgSource: data.svgSource.present ? data.svgSource.value : this.svgSource,
      boundsLeft: data.boundsLeft.present
          ? data.boundsLeft.value
          : this.boundsLeft,
      boundsTop: data.boundsTop.present ? data.boundsTop.value : this.boundsTop,
      boundsRight: data.boundsRight.present
          ? data.boundsRight.value
          : this.boundsRight,
      boundsBottom: data.boundsBottom.present
          ? data.boundsBottom.value
          : this.boundsBottom,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AvatarItemsTableData(')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('slot: $slot, ')
          ..write('layer: $layer, ')
          ..write('url: $url, ')
          ..write('rarity: $rarity, ')
          ..write('price: $price, ')
          ..write('isDefault: $isDefault, ')
          ..write('svgSource: $svgSource, ')
          ..write('boundsLeft: $boundsLeft, ')
          ..write('boundsTop: $boundsTop, ')
          ..write('boundsRight: $boundsRight, ')
          ..write('boundsBottom: $boundsBottom, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    code,
    name,
    slot,
    layer,
    url,
    rarity,
    price,
    isDefault,
    svgSource,
    boundsLeft,
    boundsTop,
    boundsRight,
    boundsBottom,
    serverUpdatedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AvatarItemsTableData &&
          other.code == this.code &&
          other.name == this.name &&
          other.slot == this.slot &&
          other.layer == this.layer &&
          other.url == this.url &&
          other.rarity == this.rarity &&
          other.price == this.price &&
          other.isDefault == this.isDefault &&
          other.svgSource == this.svgSource &&
          other.boundsLeft == this.boundsLeft &&
          other.boundsTop == this.boundsTop &&
          other.boundsRight == this.boundsRight &&
          other.boundsBottom == this.boundsBottom &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.updatedAt == this.updatedAt);
}

class AvatarItemsTableCompanion extends UpdateCompanion<AvatarItemsTableData> {
  final Value<String> code;
  final Value<String> name;
  final Value<String> slot;
  final Value<int> layer;
  final Value<String> url;
  final Value<String> rarity;
  final Value<int> price;
  final Value<bool> isDefault;
  final Value<String?> svgSource;
  final Value<double?> boundsLeft;
  final Value<double?> boundsTop;
  final Value<double?> boundsRight;
  final Value<double?> boundsBottom;
  final Value<DateTime?> serverUpdatedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AvatarItemsTableCompanion({
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.slot = const Value.absent(),
    this.layer = const Value.absent(),
    this.url = const Value.absent(),
    this.rarity = const Value.absent(),
    this.price = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.svgSource = const Value.absent(),
    this.boundsLeft = const Value.absent(),
    this.boundsTop = const Value.absent(),
    this.boundsRight = const Value.absent(),
    this.boundsBottom = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AvatarItemsTableCompanion.insert({
    required String code,
    required String name,
    required String slot,
    required int layer,
    required String url,
    this.rarity = const Value.absent(),
    this.price = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.svgSource = const Value.absent(),
    this.boundsLeft = const Value.absent(),
    this.boundsTop = const Value.absent(),
    this.boundsRight = const Value.absent(),
    this.boundsBottom = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : code = Value(code),
       name = Value(name),
       slot = Value(slot),
       layer = Value(layer),
       url = Value(url);
  static Insertable<AvatarItemsTableData> custom({
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? slot,
    Expression<int>? layer,
    Expression<String>? url,
    Expression<String>? rarity,
    Expression<int>? price,
    Expression<bool>? isDefault,
    Expression<String>? svgSource,
    Expression<double>? boundsLeft,
    Expression<double>? boundsTop,
    Expression<double>? boundsRight,
    Expression<double>? boundsBottom,
    Expression<DateTime>? serverUpdatedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (slot != null) 'slot': slot,
      if (layer != null) 'layer': layer,
      if (url != null) 'url': url,
      if (rarity != null) 'rarity': rarity,
      if (price != null) 'price': price,
      if (isDefault != null) 'is_default': isDefault,
      if (svgSource != null) 'svg_source': svgSource,
      if (boundsLeft != null) 'bounds_left': boundsLeft,
      if (boundsTop != null) 'bounds_top': boundsTop,
      if (boundsRight != null) 'bounds_right': boundsRight,
      if (boundsBottom != null) 'bounds_bottom': boundsBottom,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AvatarItemsTableCompanion copyWith({
    Value<String>? code,
    Value<String>? name,
    Value<String>? slot,
    Value<int>? layer,
    Value<String>? url,
    Value<String>? rarity,
    Value<int>? price,
    Value<bool>? isDefault,
    Value<String?>? svgSource,
    Value<double?>? boundsLeft,
    Value<double?>? boundsTop,
    Value<double?>? boundsRight,
    Value<double?>? boundsBottom,
    Value<DateTime?>? serverUpdatedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AvatarItemsTableCompanion(
      code: code ?? this.code,
      name: name ?? this.name,
      slot: slot ?? this.slot,
      layer: layer ?? this.layer,
      url: url ?? this.url,
      rarity: rarity ?? this.rarity,
      price: price ?? this.price,
      isDefault: isDefault ?? this.isDefault,
      svgSource: svgSource ?? this.svgSource,
      boundsLeft: boundsLeft ?? this.boundsLeft,
      boundsTop: boundsTop ?? this.boundsTop,
      boundsRight: boundsRight ?? this.boundsRight,
      boundsBottom: boundsBottom ?? this.boundsBottom,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (layer.present) {
      map['layer'] = Variable<int>(layer.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (rarity.present) {
      map['rarity'] = Variable<String>(rarity.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (svgSource.present) {
      map['svg_source'] = Variable<String>(svgSource.value);
    }
    if (boundsLeft.present) {
      map['bounds_left'] = Variable<double>(boundsLeft.value);
    }
    if (boundsTop.present) {
      map['bounds_top'] = Variable<double>(boundsTop.value);
    }
    if (boundsRight.present) {
      map['bounds_right'] = Variable<double>(boundsRight.value);
    }
    if (boundsBottom.present) {
      map['bounds_bottom'] = Variable<double>(boundsBottom.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AvatarItemsTableCompanion(')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('slot: $slot, ')
          ..write('layer: $layer, ')
          ..write('url: $url, ')
          ..write('rarity: $rarity, ')
          ..write('price: $price, ')
          ..write('isDefault: $isDefault, ')
          ..write('svgSource: $svgSource, ')
          ..write('boundsLeft: $boundsLeft, ')
          ..write('boundsTop: $boundsTop, ')
          ..write('boundsRight: $boundsRight, ')
          ..write('boundsBottom: $boundsBottom, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserAvatarTableTable extends UserAvatarTable
    with TableInfo<$UserAvatarTableTable, UserAvatarTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserAvatarTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _equippedMeta = const VerificationMeta(
    'equipped',
  );
  @override
  late final GeneratedColumn<String> equipped = GeneratedColumn<String>(
    'equipped',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _ownedCodesMeta = const VerificationMeta(
    'ownedCodes',
  );
  @override
  late final GeneratedColumn<String> ownedCodes = GeneratedColumn<String>(
    'owned_codes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    equipped,
    ownedCodes,
    syncStatus,
    updatedAt,
    serverUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_avatar';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserAvatarTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('equipped')) {
      context.handle(
        _equippedMeta,
        equipped.isAcceptableOrUnknown(data['equipped']!, _equippedMeta),
      );
    }
    if (data.containsKey('owned_codes')) {
      context.handle(
        _ownedCodesMeta,
        ownedCodes.isAcceptableOrUnknown(data['owned_codes']!, _ownedCodesMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  UserAvatarTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserAvatarTableData(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      equipped: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipped'],
      )!,
      ownedCodes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owned_codes'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
    );
  }

  @override
  $UserAvatarTableTable createAlias(String alias) {
    return $UserAvatarTableTable(attachedDatabase, alias);
  }
}

class UserAvatarTableData extends DataClass
    implements Insertable<UserAvatarTableData> {
  /// Local user id (`users.id`).
  final String userId;

  /// JSON object, slot => item code (`{"head":"head_zlata_korunka"}`). A slot
  /// that is absent or null is simply not worn.
  final String equipped;

  /// JSON array of owned item codes. Default items are included by the server
  /// so the app never has to special-case them.
  final String ownedCodes;

  /// Sync status: 0=synced, 1=pending, 2=conflict.
  final int syncStatus;
  final DateTime updatedAt;

  /// Server's last write, for conflict detection on pull.
  final DateTime? serverUpdatedAt;
  const UserAvatarTableData({
    required this.userId,
    required this.equipped,
    required this.ownedCodes,
    required this.syncStatus,
    required this.updatedAt,
    this.serverUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['equipped'] = Variable<String>(equipped);
    map['owned_codes'] = Variable<String>(ownedCodes);
    map['sync_status'] = Variable<int>(syncStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    return map;
  }

  UserAvatarTableCompanion toCompanion(bool nullToAbsent) {
    return UserAvatarTableCompanion(
      userId: Value(userId),
      equipped: Value(equipped),
      ownedCodes: Value(ownedCodes),
      syncStatus: Value(syncStatus),
      updatedAt: Value(updatedAt),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
    );
  }

  factory UserAvatarTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserAvatarTableData(
      userId: serializer.fromJson<String>(json['userId']),
      equipped: serializer.fromJson<String>(json['equipped']),
      ownedCodes: serializer.fromJson<String>(json['ownedCodes']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'equipped': serializer.toJson<String>(equipped),
      'ownedCodes': serializer.toJson<String>(ownedCodes),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
    };
  }

  UserAvatarTableData copyWith({
    String? userId,
    String? equipped,
    String? ownedCodes,
    int? syncStatus,
    DateTime? updatedAt,
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
  }) => UserAvatarTableData(
    userId: userId ?? this.userId,
    equipped: equipped ?? this.equipped,
    ownedCodes: ownedCodes ?? this.ownedCodes,
    syncStatus: syncStatus ?? this.syncStatus,
    updatedAt: updatedAt ?? this.updatedAt,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
  );
  UserAvatarTableData copyWithCompanion(UserAvatarTableCompanion data) {
    return UserAvatarTableData(
      userId: data.userId.present ? data.userId.value : this.userId,
      equipped: data.equipped.present ? data.equipped.value : this.equipped,
      ownedCodes: data.ownedCodes.present
          ? data.ownedCodes.value
          : this.ownedCodes,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserAvatarTableData(')
          ..write('userId: $userId, ')
          ..write('equipped: $equipped, ')
          ..write('ownedCodes: $ownedCodes, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    equipped,
    ownedCodes,
    syncStatus,
    updatedAt,
    serverUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserAvatarTableData &&
          other.userId == this.userId &&
          other.equipped == this.equipped &&
          other.ownedCodes == this.ownedCodes &&
          other.syncStatus == this.syncStatus &&
          other.updatedAt == this.updatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt);
}

class UserAvatarTableCompanion extends UpdateCompanion<UserAvatarTableData> {
  final Value<String> userId;
  final Value<String> equipped;
  final Value<String> ownedCodes;
  final Value<int> syncStatus;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> serverUpdatedAt;
  final Value<int> rowid;
  const UserAvatarTableCompanion({
    this.userId = const Value.absent(),
    this.equipped = const Value.absent(),
    this.ownedCodes = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserAvatarTableCompanion.insert({
    required String userId,
    this.equipped = const Value.absent(),
    this.ownedCodes = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId);
  static Insertable<UserAvatarTableData> custom({
    Expression<String>? userId,
    Expression<String>? equipped,
    Expression<String>? ownedCodes,
    Expression<int>? syncStatus,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (equipped != null) 'equipped': equipped,
      if (ownedCodes != null) 'owned_codes': ownedCodes,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserAvatarTableCompanion copyWith({
    Value<String>? userId,
    Value<String>? equipped,
    Value<String>? ownedCodes,
    Value<int>? syncStatus,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? serverUpdatedAt,
    Value<int>? rowid,
  }) {
    return UserAvatarTableCompanion(
      userId: userId ?? this.userId,
      equipped: equipped ?? this.equipped,
      ownedCodes: ownedCodes ?? this.ownedCodes,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (equipped.present) {
      map['equipped'] = Variable<String>(equipped.value);
    }
    if (ownedCodes.present) {
      map['owned_codes'] = Variable<String>(ownedCodes.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserAvatarTableCompanion(')
          ..write('userId: $userId, ')
          ..write('equipped: $equipped, ')
          ..write('ownedCodes: $ownedCodes, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CoursesTableTable coursesTable = $CoursesTableTable(this);
  late final $LessonsTableTable lessonsTable = $LessonsTableTable(this);
  late final $UserProgressTableTable userProgressTable =
      $UserProgressTableTable(this);
  late final $SyncQueueTableTable syncQueueTable = $SyncQueueTableTable(this);
  late final $UsersTableTable usersTable = $UsersTableTable(this);
  late final $UserCoursesTableTable userCoursesTable = $UserCoursesTableTable(
    this,
  );
  late final $UserStatsTableTable userStatsTable = $UserStatsTableTable(this);
  late final $BookmarksTableTable bookmarksTable = $BookmarksTableTable(this);
  late final $UserEloProfileTableTable userEloProfileTable =
      $UserEloProfileTableTable(this);
  late final $GamificationConfigTableTable gamificationConfigTable =
      $GamificationConfigTableTable(this);
  late final $UserAchievementsTableTable userAchievementsTable =
      $UserAchievementsTableTable(this);
  late final $BlockStatsTableTable blockStatsTable = $BlockStatsTableTable(
    this,
  );
  late final $ChatSessionsTableTable chatSessionsTable =
      $ChatSessionsTableTable(this);
  late final $ChatMessagesTableTable chatMessagesTable =
      $ChatMessagesTableTable(this);
  late final $PracticeCardsTableTable practiceCardsTable =
      $PracticeCardsTableTable(this);
  late final $ReviewLogsTableTable reviewLogsTable = $ReviewLogsTableTable(
    this,
  );
  late final $StudentFsrsProfilesTableTable studentFsrsProfilesTable =
      $StudentFsrsProfilesTableTable(this);
  late final $WorkHeartbeatsTableTable workHeartbeatsTable =
      $WorkHeartbeatsTableTable(this);
  late final $GpfDimensionsTableTable gpfDimensionsTable =
      $GpfDimensionsTableTable(this);
  late final $AvatarItemsTableTable avatarItemsTable = $AvatarItemsTableTable(
    this,
  );
  late final $UserAvatarTableTable userAvatarTable = $UserAvatarTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    coursesTable,
    lessonsTable,
    userProgressTable,
    syncQueueTable,
    usersTable,
    userCoursesTable,
    userStatsTable,
    bookmarksTable,
    userEloProfileTable,
    gamificationConfigTable,
    userAchievementsTable,
    blockStatsTable,
    chatSessionsTable,
    chatMessagesTable,
    practiceCardsTable,
    reviewLogsTable,
    studentFsrsProfilesTable,
    workHeartbeatsTable,
    gpfDimensionsTable,
    avatarItemsTable,
    userAvatarTable,
  ];
}

typedef $$CoursesTableTableCreateCompanionBuilder =
    CoursesTableCompanion Function({
      required String id,
      Value<int?> serverId,
      required String courseId,
      required String name,
      Value<int> version,
      Value<String> status,
      Value<String> language,
      Value<String> data,
      Value<bool> onlyOnce,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<int> rowid,
    });
typedef $$CoursesTableTableUpdateCompanionBuilder =
    CoursesTableCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> courseId,
      Value<String> name,
      Value<int> version,
      Value<String> status,
      Value<String> language,
      Value<String> data,
      Value<bool> onlyOnce,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<int> rowid,
    });

class $$CoursesTableTableFilterComposer
    extends Composer<_$AppDatabase, $CoursesTableTable> {
  $$CoursesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onlyOnce => $composableBuilder(
    column: $table.onlyOnce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoursesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CoursesTableTable> {
  $$CoursesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onlyOnce => $composableBuilder(
    column: $table.onlyOnce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoursesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoursesTableTable> {
  $$CoursesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<bool> get onlyOnce =>
      $composableBuilder(column: $table.onlyOnce, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );
}

class $$CoursesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoursesTableTable,
          CoursesTableData,
          $$CoursesTableTableFilterComposer,
          $$CoursesTableTableOrderingComposer,
          $$CoursesTableTableAnnotationComposer,
          $$CoursesTableTableCreateCompanionBuilder,
          $$CoursesTableTableUpdateCompanionBuilder,
          (
            CoursesTableData,
            BaseReferences<_$AppDatabase, $CoursesTableTable, CoursesTableData>,
          ),
          CoursesTableData,
          PrefetchHooks Function()
        > {
  $$CoursesTableTableTableManager(_$AppDatabase db, $CoursesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoursesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoursesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoursesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<bool> onlyOnce = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoursesTableCompanion(
                id: id,
                serverId: serverId,
                courseId: courseId,
                name: name,
                version: version,
                status: status,
                language: language,
                data: data,
                onlyOnce: onlyOnce,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String courseId,
                required String name,
                Value<int> version = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<bool> onlyOnce = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoursesTableCompanion.insert(
                id: id,
                serverId: serverId,
                courseId: courseId,
                name: name,
                version: version,
                status: status,
                language: language,
                data: data,
                onlyOnce: onlyOnce,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoursesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoursesTableTable,
      CoursesTableData,
      $$CoursesTableTableFilterComposer,
      $$CoursesTableTableOrderingComposer,
      $$CoursesTableTableAnnotationComposer,
      $$CoursesTableTableCreateCompanionBuilder,
      $$CoursesTableTableUpdateCompanionBuilder,
      (
        CoursesTableData,
        BaseReferences<_$AppDatabase, $CoursesTableTable, CoursesTableData>,
      ),
      CoursesTableData,
      PrefetchHooks Function()
    >;
typedef $$LessonsTableTableCreateCompanionBuilder =
    LessonsTableCompanion Function({
      required String id,
      Value<int?> serverId,
      required String courseId,
      required String lessonId,
      required String title,
      Value<String> description,
      Value<int> orderIndex,
      Value<String> content,
      Value<int> durationMinutes,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$LessonsTableTableUpdateCompanionBuilder =
    LessonsTableCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> courseId,
      Value<String> lessonId,
      Value<String> title,
      Value<String> description,
      Value<int> orderIndex,
      Value<String> content,
      Value<int> durationMinutes,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LessonsTableTableFilterComposer
    extends Composer<_$AppDatabase, $LessonsTableTable> {
  $$LessonsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LessonsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonsTableTable> {
  $$LessonsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LessonsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonsTableTable> {
  $$LessonsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LessonsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LessonsTableTable,
          LessonsTableData,
          $$LessonsTableTableFilterComposer,
          $$LessonsTableTableOrderingComposer,
          $$LessonsTableTableAnnotationComposer,
          $$LessonsTableTableCreateCompanionBuilder,
          $$LessonsTableTableUpdateCompanionBuilder,
          (
            LessonsTableData,
            BaseReferences<_$AppDatabase, $LessonsTableTable, LessonsTableData>,
          ),
          LessonsTableData,
          PrefetchHooks Function()
        > {
  $$LessonsTableTableTableManager(_$AppDatabase db, $LessonsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LessonsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LessonsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LessonsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> lessonId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LessonsTableCompanion(
                id: id,
                serverId: serverId,
                courseId: courseId,
                lessonId: lessonId,
                title: title,
                description: description,
                orderIndex: orderIndex,
                content: content,
                durationMinutes: durationMinutes,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String courseId,
                required String lessonId,
                required String title,
                Value<String> description = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LessonsTableCompanion.insert(
                id: id,
                serverId: serverId,
                courseId: courseId,
                lessonId: lessonId,
                title: title,
                description: description,
                orderIndex: orderIndex,
                content: content,
                durationMinutes: durationMinutes,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LessonsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LessonsTableTable,
      LessonsTableData,
      $$LessonsTableTableFilterComposer,
      $$LessonsTableTableOrderingComposer,
      $$LessonsTableTableAnnotationComposer,
      $$LessonsTableTableCreateCompanionBuilder,
      $$LessonsTableTableUpdateCompanionBuilder,
      (
        LessonsTableData,
        BaseReferences<_$AppDatabase, $LessonsTableTable, LessonsTableData>,
      ),
      LessonsTableData,
      PrefetchHooks Function()
    >;
typedef $$UserProgressTableTableCreateCompanionBuilder =
    UserProgressTableCompanion Function({
      required String id,
      Value<int?> serverId,
      required String userId,
      required String courseId,
      Value<String?> lessonId,
      Value<int> progressPercent,
      Value<bool> isCompleted,
      Value<int> lastPosition,
      Value<String> progressData,
      Value<int> timeSpentSeconds,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$UserProgressTableTableUpdateCompanionBuilder =
    UserProgressTableCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> userId,
      Value<String> courseId,
      Value<String?> lessonId,
      Value<int> progressPercent,
      Value<bool> isCompleted,
      Value<int> lastPosition,
      Value<String> progressData,
      Value<int> timeSpentSeconds,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UserProgressTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserProgressTableTable> {
  $$UserProgressTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPosition => $composableBuilder(
    column: $table.lastPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get progressData => $composableBuilder(
    column: $table.progressData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeSpentSeconds => $composableBuilder(
    column: $table.timeSpentSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProgressTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProgressTableTable> {
  $$UserProgressTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPosition => $composableBuilder(
    column: $table.lastPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get progressData => $composableBuilder(
    column: $table.progressData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeSpentSeconds => $composableBuilder(
    column: $table.timeSpentSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProgressTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProgressTableTable> {
  $$UserProgressTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<int> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPosition => $composableBuilder(
    column: $table.lastPosition,
    builder: (column) => column,
  );

  GeneratedColumn<String> get progressData => $composableBuilder(
    column: $table.progressData,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timeSpentSeconds => $composableBuilder(
    column: $table.timeSpentSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserProgressTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProgressTableTable,
          UserProgressTableData,
          $$UserProgressTableTableFilterComposer,
          $$UserProgressTableTableOrderingComposer,
          $$UserProgressTableTableAnnotationComposer,
          $$UserProgressTableTableCreateCompanionBuilder,
          $$UserProgressTableTableUpdateCompanionBuilder,
          (
            UserProgressTableData,
            BaseReferences<
              _$AppDatabase,
              $UserProgressTableTable,
              UserProgressTableData
            >,
          ),
          UserProgressTableData,
          PrefetchHooks Function()
        > {
  $$UserProgressTableTableTableManager(
    _$AppDatabase db,
    $UserProgressTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProgressTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProgressTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProgressTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String?> lessonId = const Value.absent(),
                Value<int> progressPercent = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<int> lastPosition = const Value.absent(),
                Value<String> progressData = const Value.absent(),
                Value<int> timeSpentSeconds = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProgressTableCompanion(
                id: id,
                serverId: serverId,
                userId: userId,
                courseId: courseId,
                lessonId: lessonId,
                progressPercent: progressPercent,
                isCompleted: isCompleted,
                lastPosition: lastPosition,
                progressData: progressData,
                timeSpentSeconds: timeSpentSeconds,
                startedAt: startedAt,
                completedAt: completedAt,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String userId,
                required String courseId,
                Value<String?> lessonId = const Value.absent(),
                Value<int> progressPercent = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<int> lastPosition = const Value.absent(),
                Value<String> progressData = const Value.absent(),
                Value<int> timeSpentSeconds = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProgressTableCompanion.insert(
                id: id,
                serverId: serverId,
                userId: userId,
                courseId: courseId,
                lessonId: lessonId,
                progressPercent: progressPercent,
                isCompleted: isCompleted,
                lastPosition: lastPosition,
                progressData: progressData,
                timeSpentSeconds: timeSpentSeconds,
                startedAt: startedAt,
                completedAt: completedAt,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProgressTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProgressTableTable,
      UserProgressTableData,
      $$UserProgressTableTableFilterComposer,
      $$UserProgressTableTableOrderingComposer,
      $$UserProgressTableTableAnnotationComposer,
      $$UserProgressTableTableCreateCompanionBuilder,
      $$UserProgressTableTableUpdateCompanionBuilder,
      (
        UserProgressTableData,
        BaseReferences<
          _$AppDatabase,
          $UserProgressTableTable,
          UserProgressTableData
        >,
      ),
      UserProgressTableData,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableTableCreateCompanionBuilder =
    SyncQueueTableCompanion Function({
      Value<int> id,
      required String tableName_,
      required String recordId,
      required String operation,
      required String payload,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<int> priority,
      Value<DateTime> createdAt,
      Value<DateTime> scheduledAt,
    });
typedef $$SyncQueueTableTableUpdateCompanionBuilder =
    SyncQueueTableCompanion Function({
      Value<int> id,
      Value<String> tableName_,
      Value<String> recordId,
      Value<String> operation,
      Value<String> payload,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<int> priority,
      Value<DateTime> createdAt,
      Value<DateTime> scheduledAt,
    });

class $$SyncQueueTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tableName_ => $composableBuilder(
    column: $table.tableName_,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tableName_ => $composableBuilder(
    column: $table.tableName_,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTableTable> {
  $$SyncQueueTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tableName_ => $composableBuilder(
    column: $table.tableName_,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => column,
  );
}

class $$SyncQueueTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTableTable,
          SyncQueueTableData,
          $$SyncQueueTableTableFilterComposer,
          $$SyncQueueTableTableOrderingComposer,
          $$SyncQueueTableTableAnnotationComposer,
          $$SyncQueueTableTableCreateCompanionBuilder,
          $$SyncQueueTableTableUpdateCompanionBuilder,
          (
            SyncQueueTableData,
            BaseReferences<
              _$AppDatabase,
              $SyncQueueTableTable,
              SyncQueueTableData
            >,
          ),
          SyncQueueTableData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableTableManager(
    _$AppDatabase db,
    $SyncQueueTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> tableName_ = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> scheduledAt = const Value.absent(),
              }) => SyncQueueTableCompanion(
                id: id,
                tableName_: tableName_,
                recordId: recordId,
                operation: operation,
                payload: payload,
                retryCount: retryCount,
                lastError: lastError,
                priority: priority,
                createdAt: createdAt,
                scheduledAt: scheduledAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String tableName_,
                required String recordId,
                required String operation,
                required String payload,
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> scheduledAt = const Value.absent(),
              }) => SyncQueueTableCompanion.insert(
                id: id,
                tableName_: tableName_,
                recordId: recordId,
                operation: operation,
                payload: payload,
                retryCount: retryCount,
                lastError: lastError,
                priority: priority,
                createdAt: createdAt,
                scheduledAt: scheduledAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTableTable,
      SyncQueueTableData,
      $$SyncQueueTableTableFilterComposer,
      $$SyncQueueTableTableOrderingComposer,
      $$SyncQueueTableTableAnnotationComposer,
      $$SyncQueueTableTableCreateCompanionBuilder,
      $$SyncQueueTableTableUpdateCompanionBuilder,
      (
        SyncQueueTableData,
        BaseReferences<_$AppDatabase, $SyncQueueTableTable, SyncQueueTableData>,
      ),
      SyncQueueTableData,
      PrefetchHooks Function()
    >;
typedef $$UsersTableTableCreateCompanionBuilder =
    UsersTableCompanion Function({
      required String id,
      required String email,
      required String name,
      Value<int> avatarIndex,
      Value<String> selectedSubjects,
      Value<bool> isEmailValidated,
      Value<bool> isActive,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$UsersTableTableUpdateCompanionBuilder =
    UsersTableCompanion Function({
      Value<String> id,
      Value<String> email,
      Value<String> name,
      Value<int> avatarIndex,
      Value<String> selectedSubjects,
      Value<bool> isEmailValidated,
      Value<bool> isActive,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UsersTableTableFilterComposer
    extends Composer<_$AppDatabase, $UsersTableTable> {
  $$UsersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avatarIndex => $composableBuilder(
    column: $table.avatarIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedSubjects => $composableBuilder(
    column: $table.selectedSubjects,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEmailValidated => $composableBuilder(
    column: $table.isEmailValidated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTableTable> {
  $$UsersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avatarIndex => $composableBuilder(
    column: $table.avatarIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedSubjects => $composableBuilder(
    column: $table.selectedSubjects,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEmailValidated => $composableBuilder(
    column: $table.isEmailValidated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTableTable> {
  $$UsersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get avatarIndex => $composableBuilder(
    column: $table.avatarIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedSubjects => $composableBuilder(
    column: $table.selectedSubjects,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEmailValidated => $composableBuilder(
    column: $table.isEmailValidated,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UsersTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTableTable,
          UsersTableData,
          $$UsersTableTableFilterComposer,
          $$UsersTableTableOrderingComposer,
          $$UsersTableTableAnnotationComposer,
          $$UsersTableTableCreateCompanionBuilder,
          $$UsersTableTableUpdateCompanionBuilder,
          (
            UsersTableData,
            BaseReferences<_$AppDatabase, $UsersTableTable, UsersTableData>,
          ),
          UsersTableData,
          PrefetchHooks Function()
        > {
  $$UsersTableTableTableManager(_$AppDatabase db, $UsersTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> avatarIndex = const Value.absent(),
                Value<String> selectedSubjects = const Value.absent(),
                Value<bool> isEmailValidated = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersTableCompanion(
                id: id,
                email: email,
                name: name,
                avatarIndex: avatarIndex,
                selectedSubjects: selectedSubjects,
                isEmailValidated: isEmailValidated,
                isActive: isActive,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String email,
                required String name,
                Value<int> avatarIndex = const Value.absent(),
                Value<String> selectedSubjects = const Value.absent(),
                Value<bool> isEmailValidated = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersTableCompanion.insert(
                id: id,
                email: email,
                name: name,
                avatarIndex: avatarIndex,
                selectedSubjects: selectedSubjects,
                isEmailValidated: isEmailValidated,
                isActive: isActive,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsersTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTableTable,
      UsersTableData,
      $$UsersTableTableFilterComposer,
      $$UsersTableTableOrderingComposer,
      $$UsersTableTableAnnotationComposer,
      $$UsersTableTableCreateCompanionBuilder,
      $$UsersTableTableUpdateCompanionBuilder,
      (
        UsersTableData,
        BaseReferences<_$AppDatabase, $UsersTableTable, UsersTableData>,
      ),
      UsersTableData,
      PrefetchHooks Function()
    >;
typedef $$UserCoursesTableTableCreateCompanionBuilder =
    UserCoursesTableCompanion Function({
      required String id,
      Value<int?> serverId,
      required String userId,
      required String courseId,
      Value<String> status,
      Value<int> progressPercent,
      Value<int> completedLessons,
      Value<int> totalLessons,
      Value<int> currentLessonIndex,
      Value<int> timeSpentSeconds,
      Value<String> progressDataJson,
      Value<int> downloadedVersion,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<int> rowid,
    });
typedef $$UserCoursesTableTableUpdateCompanionBuilder =
    UserCoursesTableCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> userId,
      Value<String> courseId,
      Value<String> status,
      Value<int> progressPercent,
      Value<int> completedLessons,
      Value<int> totalLessons,
      Value<int> currentLessonIndex,
      Value<int> timeSpentSeconds,
      Value<String> progressDataJson,
      Value<int> downloadedVersion,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<int> rowid,
    });

class $$UserCoursesTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserCoursesTableTable> {
  $$UserCoursesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedLessons => $composableBuilder(
    column: $table.completedLessons,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalLessons => $composableBuilder(
    column: $table.totalLessons,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentLessonIndex => $composableBuilder(
    column: $table.currentLessonIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeSpentSeconds => $composableBuilder(
    column: $table.timeSpentSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get progressDataJson => $composableBuilder(
    column: $table.progressDataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedVersion => $composableBuilder(
    column: $table.downloadedVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserCoursesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserCoursesTableTable> {
  $$UserCoursesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedLessons => $composableBuilder(
    column: $table.completedLessons,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalLessons => $composableBuilder(
    column: $table.totalLessons,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentLessonIndex => $composableBuilder(
    column: $table.currentLessonIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeSpentSeconds => $composableBuilder(
    column: $table.timeSpentSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get progressDataJson => $composableBuilder(
    column: $table.progressDataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedVersion => $composableBuilder(
    column: $table.downloadedVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserCoursesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserCoursesTableTable> {
  $$UserCoursesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedLessons => $composableBuilder(
    column: $table.completedLessons,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalLessons => $composableBuilder(
    column: $table.totalLessons,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentLessonIndex => $composableBuilder(
    column: $table.currentLessonIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timeSpentSeconds => $composableBuilder(
    column: $table.timeSpentSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get progressDataJson => $composableBuilder(
    column: $table.progressDataJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadedVersion => $composableBuilder(
    column: $table.downloadedVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );
}

class $$UserCoursesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserCoursesTableTable,
          UserCoursesTableData,
          $$UserCoursesTableTableFilterComposer,
          $$UserCoursesTableTableOrderingComposer,
          $$UserCoursesTableTableAnnotationComposer,
          $$UserCoursesTableTableCreateCompanionBuilder,
          $$UserCoursesTableTableUpdateCompanionBuilder,
          (
            UserCoursesTableData,
            BaseReferences<
              _$AppDatabase,
              $UserCoursesTableTable,
              UserCoursesTableData
            >,
          ),
          UserCoursesTableData,
          PrefetchHooks Function()
        > {
  $$UserCoursesTableTableTableManager(
    _$AppDatabase db,
    $UserCoursesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserCoursesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserCoursesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserCoursesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> progressPercent = const Value.absent(),
                Value<int> completedLessons = const Value.absent(),
                Value<int> totalLessons = const Value.absent(),
                Value<int> currentLessonIndex = const Value.absent(),
                Value<int> timeSpentSeconds = const Value.absent(),
                Value<String> progressDataJson = const Value.absent(),
                Value<int> downloadedVersion = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserCoursesTableCompanion(
                id: id,
                serverId: serverId,
                userId: userId,
                courseId: courseId,
                status: status,
                progressPercent: progressPercent,
                completedLessons: completedLessons,
                totalLessons: totalLessons,
                currentLessonIndex: currentLessonIndex,
                timeSpentSeconds: timeSpentSeconds,
                progressDataJson: progressDataJson,
                downloadedVersion: downloadedVersion,
                startedAt: startedAt,
                completedAt: completedAt,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String userId,
                required String courseId,
                Value<String> status = const Value.absent(),
                Value<int> progressPercent = const Value.absent(),
                Value<int> completedLessons = const Value.absent(),
                Value<int> totalLessons = const Value.absent(),
                Value<int> currentLessonIndex = const Value.absent(),
                Value<int> timeSpentSeconds = const Value.absent(),
                Value<String> progressDataJson = const Value.absent(),
                Value<int> downloadedVersion = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserCoursesTableCompanion.insert(
                id: id,
                serverId: serverId,
                userId: userId,
                courseId: courseId,
                status: status,
                progressPercent: progressPercent,
                completedLessons: completedLessons,
                totalLessons: totalLessons,
                currentLessonIndex: currentLessonIndex,
                timeSpentSeconds: timeSpentSeconds,
                progressDataJson: progressDataJson,
                downloadedVersion: downloadedVersion,
                startedAt: startedAt,
                completedAt: completedAt,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserCoursesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserCoursesTableTable,
      UserCoursesTableData,
      $$UserCoursesTableTableFilterComposer,
      $$UserCoursesTableTableOrderingComposer,
      $$UserCoursesTableTableAnnotationComposer,
      $$UserCoursesTableTableCreateCompanionBuilder,
      $$UserCoursesTableTableUpdateCompanionBuilder,
      (
        UserCoursesTableData,
        BaseReferences<
          _$AppDatabase,
          $UserCoursesTableTable,
          UserCoursesTableData
        >,
      ),
      UserCoursesTableData,
      PrefetchHooks Function()
    >;
typedef $$UserStatsTableTableCreateCompanionBuilder =
    UserStatsTableCompanion Function({
      required String id,
      Value<int?> serverId,
      required String userId,
      Value<int> level,
      Value<int> xpPoints,
      Value<int> coursesCount,
      Value<int> streakDays,
      Value<int> achievementsCount,
      Value<DateTime?> lastStreakDate,
      Value<DateTime?> dailyXpDate,
      Value<int> dailyXpAmount,
      Value<int> coinsEarned,
      Value<int> coinsBalance,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<int> rowid,
    });
typedef $$UserStatsTableTableUpdateCompanionBuilder =
    UserStatsTableCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<String> userId,
      Value<int> level,
      Value<int> xpPoints,
      Value<int> coursesCount,
      Value<int> streakDays,
      Value<int> achievementsCount,
      Value<DateTime?> lastStreakDate,
      Value<DateTime?> dailyXpDate,
      Value<int> dailyXpAmount,
      Value<int> coinsEarned,
      Value<int> coinsBalance,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<int> rowid,
    });

class $$UserStatsTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserStatsTableTable> {
  $$UserStatsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xpPoints => $composableBuilder(
    column: $table.xpPoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coursesCount => $composableBuilder(
    column: $table.coursesCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streakDays => $composableBuilder(
    column: $table.streakDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get achievementsCount => $composableBuilder(
    column: $table.achievementsCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastStreakDate => $composableBuilder(
    column: $table.lastStreakDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dailyXpDate => $composableBuilder(
    column: $table.dailyXpDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyXpAmount => $composableBuilder(
    column: $table.dailyXpAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coinsEarned => $composableBuilder(
    column: $table.coinsEarned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coinsBalance => $composableBuilder(
    column: $table.coinsBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserStatsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserStatsTableTable> {
  $$UserStatsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xpPoints => $composableBuilder(
    column: $table.xpPoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coursesCount => $composableBuilder(
    column: $table.coursesCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streakDays => $composableBuilder(
    column: $table.streakDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get achievementsCount => $composableBuilder(
    column: $table.achievementsCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastStreakDate => $composableBuilder(
    column: $table.lastStreakDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dailyXpDate => $composableBuilder(
    column: $table.dailyXpDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyXpAmount => $composableBuilder(
    column: $table.dailyXpAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coinsEarned => $composableBuilder(
    column: $table.coinsEarned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coinsBalance => $composableBuilder(
    column: $table.coinsBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserStatsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserStatsTableTable> {
  $$UserStatsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get xpPoints =>
      $composableBuilder(column: $table.xpPoints, builder: (column) => column);

  GeneratedColumn<int> get coursesCount => $composableBuilder(
    column: $table.coursesCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get streakDays => $composableBuilder(
    column: $table.streakDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get achievementsCount => $composableBuilder(
    column: $table.achievementsCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastStreakDate => $composableBuilder(
    column: $table.lastStreakDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dailyXpDate => $composableBuilder(
    column: $table.dailyXpDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dailyXpAmount => $composableBuilder(
    column: $table.dailyXpAmount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get coinsEarned => $composableBuilder(
    column: $table.coinsEarned,
    builder: (column) => column,
  );

  GeneratedColumn<int> get coinsBalance => $composableBuilder(
    column: $table.coinsBalance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );
}

class $$UserStatsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserStatsTableTable,
          UserStatsTableData,
          $$UserStatsTableTableFilterComposer,
          $$UserStatsTableTableOrderingComposer,
          $$UserStatsTableTableAnnotationComposer,
          $$UserStatsTableTableCreateCompanionBuilder,
          $$UserStatsTableTableUpdateCompanionBuilder,
          (
            UserStatsTableData,
            BaseReferences<
              _$AppDatabase,
              $UserStatsTableTable,
              UserStatsTableData
            >,
          ),
          UserStatsTableData,
          PrefetchHooks Function()
        > {
  $$UserStatsTableTableTableManager(
    _$AppDatabase db,
    $UserStatsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserStatsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserStatsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserStatsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<int> xpPoints = const Value.absent(),
                Value<int> coursesCount = const Value.absent(),
                Value<int> streakDays = const Value.absent(),
                Value<int> achievementsCount = const Value.absent(),
                Value<DateTime?> lastStreakDate = const Value.absent(),
                Value<DateTime?> dailyXpDate = const Value.absent(),
                Value<int> dailyXpAmount = const Value.absent(),
                Value<int> coinsEarned = const Value.absent(),
                Value<int> coinsBalance = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserStatsTableCompanion(
                id: id,
                serverId: serverId,
                userId: userId,
                level: level,
                xpPoints: xpPoints,
                coursesCount: coursesCount,
                streakDays: streakDays,
                achievementsCount: achievementsCount,
                lastStreakDate: lastStreakDate,
                dailyXpDate: dailyXpDate,
                dailyXpAmount: dailyXpAmount,
                coinsEarned: coinsEarned,
                coinsBalance: coinsBalance,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required String userId,
                Value<int> level = const Value.absent(),
                Value<int> xpPoints = const Value.absent(),
                Value<int> coursesCount = const Value.absent(),
                Value<int> streakDays = const Value.absent(),
                Value<int> achievementsCount = const Value.absent(),
                Value<DateTime?> lastStreakDate = const Value.absent(),
                Value<DateTime?> dailyXpDate = const Value.absent(),
                Value<int> dailyXpAmount = const Value.absent(),
                Value<int> coinsEarned = const Value.absent(),
                Value<int> coinsBalance = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserStatsTableCompanion.insert(
                id: id,
                serverId: serverId,
                userId: userId,
                level: level,
                xpPoints: xpPoints,
                coursesCount: coursesCount,
                streakDays: streakDays,
                achievementsCount: achievementsCount,
                lastStreakDate: lastStreakDate,
                dailyXpDate: dailyXpDate,
                dailyXpAmount: dailyXpAmount,
                coinsEarned: coinsEarned,
                coinsBalance: coinsBalance,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserStatsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserStatsTableTable,
      UserStatsTableData,
      $$UserStatsTableTableFilterComposer,
      $$UserStatsTableTableOrderingComposer,
      $$UserStatsTableTableAnnotationComposer,
      $$UserStatsTableTableCreateCompanionBuilder,
      $$UserStatsTableTableUpdateCompanionBuilder,
      (
        UserStatsTableData,
        BaseReferences<_$AppDatabase, $UserStatsTableTable, UserStatsTableData>,
      ),
      UserStatsTableData,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableTableCreateCompanionBuilder =
    BookmarksTableCompanion Function({
      required String id,
      required String userId,
      required String courseId,
      required String blockId,
      Value<String> lessonId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$BookmarksTableTableUpdateCompanionBuilder =
    BookmarksTableCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> courseId,
      Value<String> blockId,
      Value<String> lessonId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$BookmarksTableTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTableTable> {
  $$BookmarksTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTableTable> {
  $$BookmarksTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTableTable> {
  $$BookmarksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get blockId =>
      $composableBuilder(column: $table.blockId, builder: (column) => column);

  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BookmarksTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTableTable,
          BookmarksTableData,
          $$BookmarksTableTableFilterComposer,
          $$BookmarksTableTableOrderingComposer,
          $$BookmarksTableTableAnnotationComposer,
          $$BookmarksTableTableCreateCompanionBuilder,
          $$BookmarksTableTableUpdateCompanionBuilder,
          (
            BookmarksTableData,
            BaseReferences<
              _$AppDatabase,
              $BookmarksTableTable,
              BookmarksTableData
            >,
          ),
          BookmarksTableData,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableTableManager(
    _$AppDatabase db,
    $BookmarksTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> blockId = const Value.absent(),
                Value<String> lessonId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksTableCompanion(
                id: id,
                userId: userId,
                courseId: courseId,
                blockId: blockId,
                lessonId: lessonId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String courseId,
                required String blockId,
                Value<String> lessonId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksTableCompanion.insert(
                id: id,
                userId: userId,
                courseId: courseId,
                blockId: blockId,
                lessonId: lessonId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTableTable,
      BookmarksTableData,
      $$BookmarksTableTableFilterComposer,
      $$BookmarksTableTableOrderingComposer,
      $$BookmarksTableTableAnnotationComposer,
      $$BookmarksTableTableCreateCompanionBuilder,
      $$BookmarksTableTableUpdateCompanionBuilder,
      (
        BookmarksTableData,
        BaseReferences<_$AppDatabase, $BookmarksTableTable, BookmarksTableData>,
      ),
      BookmarksTableData,
      PrefetchHooks Function()
    >;
typedef $$UserEloProfileTableTableCreateCompanionBuilder =
    UserEloProfileTableCompanion Function({
      required String id,
      required String userId,
      required String profilElo,
      required String profilPocet,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$UserEloProfileTableTableUpdateCompanionBuilder =
    UserEloProfileTableCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> profilElo,
      Value<String> profilPocet,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UserEloProfileTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserEloProfileTableTable> {
  $$UserEloProfileTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profilElo => $composableBuilder(
    column: $table.profilElo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profilPocet => $composableBuilder(
    column: $table.profilPocet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserEloProfileTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserEloProfileTableTable> {
  $$UserEloProfileTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profilElo => $composableBuilder(
    column: $table.profilElo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profilPocet => $composableBuilder(
    column: $table.profilPocet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserEloProfileTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserEloProfileTableTable> {
  $$UserEloProfileTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get profilElo =>
      $composableBuilder(column: $table.profilElo, builder: (column) => column);

  GeneratedColumn<String> get profilPocet => $composableBuilder(
    column: $table.profilPocet,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserEloProfileTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserEloProfileTableTable,
          UserEloProfileTableData,
          $$UserEloProfileTableTableFilterComposer,
          $$UserEloProfileTableTableOrderingComposer,
          $$UserEloProfileTableTableAnnotationComposer,
          $$UserEloProfileTableTableCreateCompanionBuilder,
          $$UserEloProfileTableTableUpdateCompanionBuilder,
          (
            UserEloProfileTableData,
            BaseReferences<
              _$AppDatabase,
              $UserEloProfileTableTable,
              UserEloProfileTableData
            >,
          ),
          UserEloProfileTableData,
          PrefetchHooks Function()
        > {
  $$UserEloProfileTableTableTableManager(
    _$AppDatabase db,
    $UserEloProfileTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserEloProfileTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserEloProfileTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$UserEloProfileTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> profilElo = const Value.absent(),
                Value<String> profilPocet = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserEloProfileTableCompanion(
                id: id,
                userId: userId,
                profilElo: profilElo,
                profilPocet: profilPocet,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String profilElo,
                required String profilPocet,
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserEloProfileTableCompanion.insert(
                id: id,
                userId: userId,
                profilElo: profilElo,
                profilPocet: profilPocet,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserEloProfileTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserEloProfileTableTable,
      UserEloProfileTableData,
      $$UserEloProfileTableTableFilterComposer,
      $$UserEloProfileTableTableOrderingComposer,
      $$UserEloProfileTableTableAnnotationComposer,
      $$UserEloProfileTableTableCreateCompanionBuilder,
      $$UserEloProfileTableTableUpdateCompanionBuilder,
      (
        UserEloProfileTableData,
        BaseReferences<
          _$AppDatabase,
          $UserEloProfileTableTable,
          UserEloProfileTableData
        >,
      ),
      UserEloProfileTableData,
      PrefetchHooks Function()
    >;
typedef $$GamificationConfigTableTableCreateCompanionBuilder =
    GamificationConfigTableCompanion Function({
      required String id,
      Value<int> version,
      Value<String> configJson,
      Value<DateTime> downloadedAt,
      Value<int> rowid,
    });
typedef $$GamificationConfigTableTableUpdateCompanionBuilder =
    GamificationConfigTableCompanion Function({
      Value<String> id,
      Value<int> version,
      Value<String> configJson,
      Value<DateTime> downloadedAt,
      Value<int> rowid,
    });

class $$GamificationConfigTableTableFilterComposer
    extends Composer<_$AppDatabase, $GamificationConfigTableTable> {
  $$GamificationConfigTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GamificationConfigTableTableOrderingComposer
    extends Composer<_$AppDatabase, $GamificationConfigTableTable> {
  $$GamificationConfigTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GamificationConfigTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $GamificationConfigTableTable> {
  $$GamificationConfigTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );
}

class $$GamificationConfigTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GamificationConfigTableTable,
          GamificationConfigTableData,
          $$GamificationConfigTableTableFilterComposer,
          $$GamificationConfigTableTableOrderingComposer,
          $$GamificationConfigTableTableAnnotationComposer,
          $$GamificationConfigTableTableCreateCompanionBuilder,
          $$GamificationConfigTableTableUpdateCompanionBuilder,
          (
            GamificationConfigTableData,
            BaseReferences<
              _$AppDatabase,
              $GamificationConfigTableTable,
              GamificationConfigTableData
            >,
          ),
          GamificationConfigTableData,
          PrefetchHooks Function()
        > {
  $$GamificationConfigTableTableTableManager(
    _$AppDatabase db,
    $GamificationConfigTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GamificationConfigTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$GamificationConfigTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GamificationConfigTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<DateTime> downloadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GamificationConfigTableCompanion(
                id: id,
                version: version,
                configJson: configJson,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> version = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<DateTime> downloadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GamificationConfigTableCompanion.insert(
                id: id,
                version: version,
                configJson: configJson,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GamificationConfigTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GamificationConfigTableTable,
      GamificationConfigTableData,
      $$GamificationConfigTableTableFilterComposer,
      $$GamificationConfigTableTableOrderingComposer,
      $$GamificationConfigTableTableAnnotationComposer,
      $$GamificationConfigTableTableCreateCompanionBuilder,
      $$GamificationConfigTableTableUpdateCompanionBuilder,
      (
        GamificationConfigTableData,
        BaseReferences<
          _$AppDatabase,
          $GamificationConfigTableTable,
          GamificationConfigTableData
        >,
      ),
      GamificationConfigTableData,
      PrefetchHooks Function()
    >;
typedef $$UserAchievementsTableTableCreateCompanionBuilder =
    UserAchievementsTableCompanion Function({
      required String id,
      required String userId,
      required String achievementId,
      Value<DateTime> earnedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });
typedef $$UserAchievementsTableTableUpdateCompanionBuilder =
    UserAchievementsTableCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> achievementId,
      Value<DateTime> earnedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });

class $$UserAchievementsTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserAchievementsTableTable> {
  $$UserAchievementsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get achievementId => $composableBuilder(
    column: $table.achievementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get earnedAt => $composableBuilder(
    column: $table.earnedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserAchievementsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserAchievementsTableTable> {
  $$UserAchievementsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get achievementId => $composableBuilder(
    column: $table.achievementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get earnedAt => $composableBuilder(
    column: $table.earnedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserAchievementsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserAchievementsTableTable> {
  $$UserAchievementsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get achievementId => $composableBuilder(
    column: $table.achievementId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get earnedAt =>
      $composableBuilder(column: $table.earnedAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$UserAchievementsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserAchievementsTableTable,
          UserAchievementsTableData,
          $$UserAchievementsTableTableFilterComposer,
          $$UserAchievementsTableTableOrderingComposer,
          $$UserAchievementsTableTableAnnotationComposer,
          $$UserAchievementsTableTableCreateCompanionBuilder,
          $$UserAchievementsTableTableUpdateCompanionBuilder,
          (
            UserAchievementsTableData,
            BaseReferences<
              _$AppDatabase,
              $UserAchievementsTableTable,
              UserAchievementsTableData
            >,
          ),
          UserAchievementsTableData,
          PrefetchHooks Function()
        > {
  $$UserAchievementsTableTableTableManager(
    _$AppDatabase db,
    $UserAchievementsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserAchievementsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$UserAchievementsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$UserAchievementsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> achievementId = const Value.absent(),
                Value<DateTime> earnedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserAchievementsTableCompanion(
                id: id,
                userId: userId,
                achievementId: achievementId,
                earnedAt: earnedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String achievementId,
                Value<DateTime> earnedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserAchievementsTableCompanion.insert(
                id: id,
                userId: userId,
                achievementId: achievementId,
                earnedAt: earnedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserAchievementsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserAchievementsTableTable,
      UserAchievementsTableData,
      $$UserAchievementsTableTableFilterComposer,
      $$UserAchievementsTableTableOrderingComposer,
      $$UserAchievementsTableTableAnnotationComposer,
      $$UserAchievementsTableTableCreateCompanionBuilder,
      $$UserAchievementsTableTableUpdateCompanionBuilder,
      (
        UserAchievementsTableData,
        BaseReferences<
          _$AppDatabase,
          $UserAchievementsTableTable,
          UserAchievementsTableData
        >,
      ),
      UserAchievementsTableData,
      PrefetchHooks Function()
    >;
typedef $$BlockStatsTableTableCreateCompanionBuilder =
    BlockStatsTableCompanion Function({
      required String blockId,
      required String itemPocet,
      required String eloVector,
      Value<String?> courseId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$BlockStatsTableTableUpdateCompanionBuilder =
    BlockStatsTableCompanion Function({
      Value<String> blockId,
      Value<String> itemPocet,
      Value<String> eloVector,
      Value<String?> courseId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BlockStatsTableTableFilterComposer
    extends Composer<_$AppDatabase, $BlockStatsTableTable> {
  $$BlockStatsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemPocet => $composableBuilder(
    column: $table.itemPocet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eloVector => $composableBuilder(
    column: $table.eloVector,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlockStatsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BlockStatsTableTable> {
  $$BlockStatsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemPocet => $composableBuilder(
    column: $table.itemPocet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eloVector => $composableBuilder(
    column: $table.eloVector,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlockStatsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlockStatsTableTable> {
  $$BlockStatsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get blockId =>
      $composableBuilder(column: $table.blockId, builder: (column) => column);

  GeneratedColumn<String> get itemPocet =>
      $composableBuilder(column: $table.itemPocet, builder: (column) => column);

  GeneratedColumn<String> get eloVector =>
      $composableBuilder(column: $table.eloVector, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BlockStatsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlockStatsTableTable,
          BlockStatsTableData,
          $$BlockStatsTableTableFilterComposer,
          $$BlockStatsTableTableOrderingComposer,
          $$BlockStatsTableTableAnnotationComposer,
          $$BlockStatsTableTableCreateCompanionBuilder,
          $$BlockStatsTableTableUpdateCompanionBuilder,
          (
            BlockStatsTableData,
            BaseReferences<
              _$AppDatabase,
              $BlockStatsTableTable,
              BlockStatsTableData
            >,
          ),
          BlockStatsTableData,
          PrefetchHooks Function()
        > {
  $$BlockStatsTableTableTableManager(
    _$AppDatabase db,
    $BlockStatsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlockStatsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlockStatsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlockStatsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> blockId = const Value.absent(),
                Value<String> itemPocet = const Value.absent(),
                Value<String> eloVector = const Value.absent(),
                Value<String?> courseId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlockStatsTableCompanion(
                blockId: blockId,
                itemPocet: itemPocet,
                eloVector: eloVector,
                courseId: courseId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String blockId,
                required String itemPocet,
                required String eloVector,
                Value<String?> courseId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlockStatsTableCompanion.insert(
                blockId: blockId,
                itemPocet: itemPocet,
                eloVector: eloVector,
                courseId: courseId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlockStatsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlockStatsTableTable,
      BlockStatsTableData,
      $$BlockStatsTableTableFilterComposer,
      $$BlockStatsTableTableOrderingComposer,
      $$BlockStatsTableTableAnnotationComposer,
      $$BlockStatsTableTableCreateCompanionBuilder,
      $$BlockStatsTableTableUpdateCompanionBuilder,
      (
        BlockStatsTableData,
        BaseReferences<
          _$AppDatabase,
          $BlockStatsTableTable,
          BlockStatsTableData
        >,
      ),
      BlockStatsTableData,
      PrefetchHooks Function()
    >;
typedef $$ChatSessionsTableTableCreateCompanionBuilder =
    ChatSessionsTableCompanion Function({
      required String id,
      required String userId,
      Value<int?> serverId,
      Value<String> title,
      Value<String> persona,
      Value<DateTime> lastMessageAt,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ChatSessionsTableTableUpdateCompanionBuilder =
    ChatSessionsTableCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<int?> serverId,
      Value<String> title,
      Value<String> persona,
      Value<DateTime> lastMessageAt,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ChatSessionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ChatSessionsTableTable> {
  $$ChatSessionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get persona => $composableBuilder(
    column: $table.persona,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatSessionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatSessionsTableTable> {
  $$ChatSessionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get persona => $composableBuilder(
    column: $table.persona,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatSessionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatSessionsTableTable> {
  $$ChatSessionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get persona =>
      $composableBuilder(column: $table.persona, builder: (column) => column);

  GeneratedColumn<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ChatSessionsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatSessionsTableTable,
          ChatSessionsTableData,
          $$ChatSessionsTableTableFilterComposer,
          $$ChatSessionsTableTableOrderingComposer,
          $$ChatSessionsTableTableAnnotationComposer,
          $$ChatSessionsTableTableCreateCompanionBuilder,
          $$ChatSessionsTableTableUpdateCompanionBuilder,
          (
            ChatSessionsTableData,
            BaseReferences<
              _$AppDatabase,
              $ChatSessionsTableTable,
              ChatSessionsTableData
            >,
          ),
          ChatSessionsTableData,
          PrefetchHooks Function()
        > {
  $$ChatSessionsTableTableTableManager(
    _$AppDatabase db,
    $ChatSessionsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatSessionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatSessionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatSessionsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> persona = const Value.absent(),
                Value<DateTime> lastMessageAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatSessionsTableCompanion(
                id: id,
                userId: userId,
                serverId: serverId,
                title: title,
                persona: persona,
                lastMessageAt: lastMessageAt,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<int?> serverId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> persona = const Value.absent(),
                Value<DateTime> lastMessageAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatSessionsTableCompanion.insert(
                id: id,
                userId: userId,
                serverId: serverId,
                title: title,
                persona: persona,
                lastMessageAt: lastMessageAt,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatSessionsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatSessionsTableTable,
      ChatSessionsTableData,
      $$ChatSessionsTableTableFilterComposer,
      $$ChatSessionsTableTableOrderingComposer,
      $$ChatSessionsTableTableAnnotationComposer,
      $$ChatSessionsTableTableCreateCompanionBuilder,
      $$ChatSessionsTableTableUpdateCompanionBuilder,
      (
        ChatSessionsTableData,
        BaseReferences<
          _$AppDatabase,
          $ChatSessionsTableTable,
          ChatSessionsTableData
        >,
      ),
      ChatSessionsTableData,
      PrefetchHooks Function()
    >;
typedef $$ChatMessagesTableTableCreateCompanionBuilder =
    ChatMessagesTableCompanion Function({
      required String id,
      required String sessionId,
      Value<int?> serverId,
      required String role,
      required String content,
      Value<String> messageType,
      Value<String> metadata,
      Value<String?> feedbackType,
      Value<String?> feedbackDetail,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ChatMessagesTableTableUpdateCompanionBuilder =
    ChatMessagesTableCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<int?> serverId,
      Value<String> role,
      Value<String> content,
      Value<String> messageType,
      Value<String> metadata,
      Value<String?> feedbackType,
      Value<String?> feedbackDetail,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ChatMessagesTableTableFilterComposer
    extends Composer<_$AppDatabase, $ChatMessagesTableTable> {
  $$ChatMessagesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedbackType => $composableBuilder(
    column: $table.feedbackType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedbackDetail => $composableBuilder(
    column: $table.feedbackDetail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatMessagesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatMessagesTableTable> {
  $$ChatMessagesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedbackType => $composableBuilder(
    column: $table.feedbackType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedbackDetail => $composableBuilder(
    column: $table.feedbackDetail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatMessagesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatMessagesTableTable> {
  $$ChatMessagesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<String> get feedbackType => $composableBuilder(
    column: $table.feedbackType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get feedbackDetail => $composableBuilder(
    column: $table.feedbackDetail,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ChatMessagesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatMessagesTableTable,
          ChatMessagesTableData,
          $$ChatMessagesTableTableFilterComposer,
          $$ChatMessagesTableTableOrderingComposer,
          $$ChatMessagesTableTableAnnotationComposer,
          $$ChatMessagesTableTableCreateCompanionBuilder,
          $$ChatMessagesTableTableUpdateCompanionBuilder,
          (
            ChatMessagesTableData,
            BaseReferences<
              _$AppDatabase,
              $ChatMessagesTableTable,
              ChatMessagesTableData
            >,
          ),
          ChatMessagesTableData,
          PrefetchHooks Function()
        > {
  $$ChatMessagesTableTableTableManager(
    _$AppDatabase db,
    $ChatMessagesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> messageType = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<String?> feedbackType = const Value.absent(),
                Value<String?> feedbackDetail = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesTableCompanion(
                id: id,
                sessionId: sessionId,
                serverId: serverId,
                role: role,
                content: content,
                messageType: messageType,
                metadata: metadata,
                feedbackType: feedbackType,
                feedbackDetail: feedbackDetail,
                syncStatus: syncStatus,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                Value<int?> serverId = const Value.absent(),
                required String role,
                required String content,
                Value<String> messageType = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<String?> feedbackType = const Value.absent(),
                Value<String?> feedbackDetail = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesTableCompanion.insert(
                id: id,
                sessionId: sessionId,
                serverId: serverId,
                role: role,
                content: content,
                messageType: messageType,
                metadata: metadata,
                feedbackType: feedbackType,
                feedbackDetail: feedbackDetail,
                syncStatus: syncStatus,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatMessagesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatMessagesTableTable,
      ChatMessagesTableData,
      $$ChatMessagesTableTableFilterComposer,
      $$ChatMessagesTableTableOrderingComposer,
      $$ChatMessagesTableTableAnnotationComposer,
      $$ChatMessagesTableTableCreateCompanionBuilder,
      $$ChatMessagesTableTableUpdateCompanionBuilder,
      (
        ChatMessagesTableData,
        BaseReferences<
          _$AppDatabase,
          $ChatMessagesTableTable,
          ChatMessagesTableData
        >,
      ),
      ChatMessagesTableData,
      PrefetchHooks Function()
    >;
typedef $$PracticeCardsTableTableCreateCompanionBuilder =
    PracticeCardsTableCompanion Function({
      required String id,
      Value<String?> serverId,
      required String userId,
      required String courseId,
      required String lessonId,
      required String blockId,
      required String sourceType,
      Value<int> state,
      Value<DateTime> dueDate,
      Value<double> stability,
      Value<double> difficulty,
      Value<int> reps,
      Value<int> lapses,
      Value<int> scheduledDays,
      Value<int> elapsedDays,
      Value<DateTime?> lastReview,
      Value<double> weight,
      Value<int> avgTimeSec,
      Value<String?> skipCondition,
      Value<bool> isActive,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PracticeCardsTableTableUpdateCompanionBuilder =
    PracticeCardsTableCompanion Function({
      Value<String> id,
      Value<String?> serverId,
      Value<String> userId,
      Value<String> courseId,
      Value<String> lessonId,
      Value<String> blockId,
      Value<String> sourceType,
      Value<int> state,
      Value<DateTime> dueDate,
      Value<double> stability,
      Value<double> difficulty,
      Value<int> reps,
      Value<int> lapses,
      Value<int> scheduledDays,
      Value<int> elapsedDays,
      Value<DateTime?> lastReview,
      Value<double> weight,
      Value<int> avgTimeSec,
      Value<String?> skipCondition,
      Value<bool> isActive,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PracticeCardsTableTableFilterComposer
    extends Composer<_$AppDatabase, $PracticeCardsTableTable> {
  $$PracticeCardsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avgTimeSec => $composableBuilder(
    column: $table.avgTimeSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skipCondition => $composableBuilder(
    column: $table.skipCondition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PracticeCardsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticeCardsTableTable> {
  $$PracticeCardsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avgTimeSec => $composableBuilder(
    column: $table.avgTimeSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skipCondition => $composableBuilder(
    column: $table.skipCondition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PracticeCardsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticeCardsTableTable> {
  $$PracticeCardsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<String> get blockId =>
      $composableBuilder(column: $table.blockId, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<int> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<int> get avgTimeSec => $composableBuilder(
    column: $table.avgTimeSec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get skipCondition => $composableBuilder(
    column: $table.skipCondition,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PracticeCardsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PracticeCardsTableTable,
          PracticeCardsTableData,
          $$PracticeCardsTableTableFilterComposer,
          $$PracticeCardsTableTableOrderingComposer,
          $$PracticeCardsTableTableAnnotationComposer,
          $$PracticeCardsTableTableCreateCompanionBuilder,
          $$PracticeCardsTableTableUpdateCompanionBuilder,
          (
            PracticeCardsTableData,
            BaseReferences<
              _$AppDatabase,
              $PracticeCardsTableTable,
              PracticeCardsTableData
            >,
          ),
          PracticeCardsTableData,
          PrefetchHooks Function()
        > {
  $$PracticeCardsTableTableTableManager(
    _$AppDatabase db,
    $PracticeCardsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeCardsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeCardsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeCardsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> lessonId = const Value.absent(),
                Value<String> blockId = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<int> state = const Value.absent(),
                Value<DateTime> dueDate = const Value.absent(),
                Value<double> stability = const Value.absent(),
                Value<double> difficulty = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<int> scheduledDays = const Value.absent(),
                Value<int> elapsedDays = const Value.absent(),
                Value<DateTime?> lastReview = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<int> avgTimeSec = const Value.absent(),
                Value<String?> skipCondition = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PracticeCardsTableCompanion(
                id: id,
                serverId: serverId,
                userId: userId,
                courseId: courseId,
                lessonId: lessonId,
                blockId: blockId,
                sourceType: sourceType,
                state: state,
                dueDate: dueDate,
                stability: stability,
                difficulty: difficulty,
                reps: reps,
                lapses: lapses,
                scheduledDays: scheduledDays,
                elapsedDays: elapsedDays,
                lastReview: lastReview,
                weight: weight,
                avgTimeSec: avgTimeSec,
                skipCondition: skipCondition,
                isActive: isActive,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> serverId = const Value.absent(),
                required String userId,
                required String courseId,
                required String lessonId,
                required String blockId,
                required String sourceType,
                Value<int> state = const Value.absent(),
                Value<DateTime> dueDate = const Value.absent(),
                Value<double> stability = const Value.absent(),
                Value<double> difficulty = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<int> scheduledDays = const Value.absent(),
                Value<int> elapsedDays = const Value.absent(),
                Value<DateTime?> lastReview = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<int> avgTimeSec = const Value.absent(),
                Value<String?> skipCondition = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PracticeCardsTableCompanion.insert(
                id: id,
                serverId: serverId,
                userId: userId,
                courseId: courseId,
                lessonId: lessonId,
                blockId: blockId,
                sourceType: sourceType,
                state: state,
                dueDate: dueDate,
                stability: stability,
                difficulty: difficulty,
                reps: reps,
                lapses: lapses,
                scheduledDays: scheduledDays,
                elapsedDays: elapsedDays,
                lastReview: lastReview,
                weight: weight,
                avgTimeSec: avgTimeSec,
                skipCondition: skipCondition,
                isActive: isActive,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PracticeCardsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PracticeCardsTableTable,
      PracticeCardsTableData,
      $$PracticeCardsTableTableFilterComposer,
      $$PracticeCardsTableTableOrderingComposer,
      $$PracticeCardsTableTableAnnotationComposer,
      $$PracticeCardsTableTableCreateCompanionBuilder,
      $$PracticeCardsTableTableUpdateCompanionBuilder,
      (
        PracticeCardsTableData,
        BaseReferences<
          _$AppDatabase,
          $PracticeCardsTableTable,
          PracticeCardsTableData
        >,
      ),
      PracticeCardsTableData,
      PrefetchHooks Function()
    >;
typedef $$ReviewLogsTableTableCreateCompanionBuilder =
    ReviewLogsTableCompanion Function({
      required String id,
      Value<String?> serverId,
      required String cardId,
      required String userId,
      required int rating,
      required DateTime shownAt,
      required DateTime reviewedAt,
      required int responseTimeSec,
      required int repetitionNumber,
      required double stabilityAfter,
      required double difficultyAfter,
      required DateTime nextDueDate,
      required int intervalDays,
      Value<String?> userFeedback,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ReviewLogsTableTableUpdateCompanionBuilder =
    ReviewLogsTableCompanion Function({
      Value<String> id,
      Value<String?> serverId,
      Value<String> cardId,
      Value<String> userId,
      Value<int> rating,
      Value<DateTime> shownAt,
      Value<DateTime> reviewedAt,
      Value<int> responseTimeSec,
      Value<int> repetitionNumber,
      Value<double> stabilityAfter,
      Value<double> difficultyAfter,
      Value<DateTime> nextDueDate,
      Value<int> intervalDays,
      Value<String?> userFeedback,
      Value<int> syncStatus,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ReviewLogsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewLogsTableTable> {
  $$ReviewLogsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get shownAt => $composableBuilder(
    column: $table.shownAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get responseTimeSec => $composableBuilder(
    column: $table.responseTimeSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repetitionNumber => $composableBuilder(
    column: $table.repetitionNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stabilityAfter => $composableBuilder(
    column: $table.stabilityAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficultyAfter => $composableBuilder(
    column: $table.difficultyAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userFeedback => $composableBuilder(
    column: $table.userFeedback,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReviewLogsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewLogsTableTable> {
  $$ReviewLogsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardId => $composableBuilder(
    column: $table.cardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get shownAt => $composableBuilder(
    column: $table.shownAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get responseTimeSec => $composableBuilder(
    column: $table.responseTimeSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repetitionNumber => $composableBuilder(
    column: $table.repetitionNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stabilityAfter => $composableBuilder(
    column: $table.stabilityAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficultyAfter => $composableBuilder(
    column: $table.difficultyAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userFeedback => $composableBuilder(
    column: $table.userFeedback,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReviewLogsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewLogsTableTable> {
  $$ReviewLogsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<DateTime> get shownAt =>
      $composableBuilder(column: $table.shownAt, builder: (column) => column);

  GeneratedColumn<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get responseTimeSec => $composableBuilder(
    column: $table.responseTimeSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repetitionNumber => $composableBuilder(
    column: $table.repetitionNumber,
    builder: (column) => column,
  );

  GeneratedColumn<double> get stabilityAfter => $composableBuilder(
    column: $table.stabilityAfter,
    builder: (column) => column,
  );

  GeneratedColumn<double> get difficultyAfter => $composableBuilder(
    column: $table.difficultyAfter,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userFeedback => $composableBuilder(
    column: $table.userFeedback,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ReviewLogsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewLogsTableTable,
          ReviewLogsTableData,
          $$ReviewLogsTableTableFilterComposer,
          $$ReviewLogsTableTableOrderingComposer,
          $$ReviewLogsTableTableAnnotationComposer,
          $$ReviewLogsTableTableCreateCompanionBuilder,
          $$ReviewLogsTableTableUpdateCompanionBuilder,
          (
            ReviewLogsTableData,
            BaseReferences<
              _$AppDatabase,
              $ReviewLogsTableTable,
              ReviewLogsTableData
            >,
          ),
          ReviewLogsTableData,
          PrefetchHooks Function()
        > {
  $$ReviewLogsTableTableTableManager(
    _$AppDatabase db,
    $ReviewLogsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewLogsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewLogsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewLogsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> cardId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<int> rating = const Value.absent(),
                Value<DateTime> shownAt = const Value.absent(),
                Value<DateTime> reviewedAt = const Value.absent(),
                Value<int> responseTimeSec = const Value.absent(),
                Value<int> repetitionNumber = const Value.absent(),
                Value<double> stabilityAfter = const Value.absent(),
                Value<double> difficultyAfter = const Value.absent(),
                Value<DateTime> nextDueDate = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<String?> userFeedback = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewLogsTableCompanion(
                id: id,
                serverId: serverId,
                cardId: cardId,
                userId: userId,
                rating: rating,
                shownAt: shownAt,
                reviewedAt: reviewedAt,
                responseTimeSec: responseTimeSec,
                repetitionNumber: repetitionNumber,
                stabilityAfter: stabilityAfter,
                difficultyAfter: difficultyAfter,
                nextDueDate: nextDueDate,
                intervalDays: intervalDays,
                userFeedback: userFeedback,
                syncStatus: syncStatus,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> serverId = const Value.absent(),
                required String cardId,
                required String userId,
                required int rating,
                required DateTime shownAt,
                required DateTime reviewedAt,
                required int responseTimeSec,
                required int repetitionNumber,
                required double stabilityAfter,
                required double difficultyAfter,
                required DateTime nextDueDate,
                required int intervalDays,
                Value<String?> userFeedback = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewLogsTableCompanion.insert(
                id: id,
                serverId: serverId,
                cardId: cardId,
                userId: userId,
                rating: rating,
                shownAt: shownAt,
                reviewedAt: reviewedAt,
                responseTimeSec: responseTimeSec,
                repetitionNumber: repetitionNumber,
                stabilityAfter: stabilityAfter,
                difficultyAfter: difficultyAfter,
                nextDueDate: nextDueDate,
                intervalDays: intervalDays,
                userFeedback: userFeedback,
                syncStatus: syncStatus,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReviewLogsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewLogsTableTable,
      ReviewLogsTableData,
      $$ReviewLogsTableTableFilterComposer,
      $$ReviewLogsTableTableOrderingComposer,
      $$ReviewLogsTableTableAnnotationComposer,
      $$ReviewLogsTableTableCreateCompanionBuilder,
      $$ReviewLogsTableTableUpdateCompanionBuilder,
      (
        ReviewLogsTableData,
        BaseReferences<
          _$AppDatabase,
          $ReviewLogsTableTable,
          ReviewLogsTableData
        >,
      ),
      ReviewLogsTableData,
      PrefetchHooks Function()
    >;
typedef $$StudentFsrsProfilesTableTableCreateCompanionBuilder =
    StudentFsrsProfilesTableCompanion Function({
      required String id,
      required String userId,
      Value<double> desiredRetention,
      Value<int> maximumInterval,
      Value<bool> enableFuzz,
      Value<bool> enableShortTerm,
      Value<String> learningSteps,
      Value<String> relearningSteps,
      Value<String> fsrsWeights,
      Value<int> profileVersion,
      Value<int> dailyNewLimit,
      Value<int> dailyReviewLimit,
      Value<int> sessionExpirationSec,
      Value<int> syncStatus,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StudentFsrsProfilesTableTableUpdateCompanionBuilder =
    StudentFsrsProfilesTableCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<double> desiredRetention,
      Value<int> maximumInterval,
      Value<bool> enableFuzz,
      Value<bool> enableShortTerm,
      Value<String> learningSteps,
      Value<String> relearningSteps,
      Value<String> fsrsWeights,
      Value<int> profileVersion,
      Value<int> dailyNewLimit,
      Value<int> dailyReviewLimit,
      Value<int> sessionExpirationSec,
      Value<int> syncStatus,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StudentFsrsProfilesTableTableFilterComposer
    extends Composer<_$AppDatabase, $StudentFsrsProfilesTableTable> {
  $$StudentFsrsProfilesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get desiredRetention => $composableBuilder(
    column: $table.desiredRetention,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maximumInterval => $composableBuilder(
    column: $table.maximumInterval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enableFuzz => $composableBuilder(
    column: $table.enableFuzz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enableShortTerm => $composableBuilder(
    column: $table.enableShortTerm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get learningSteps => $composableBuilder(
    column: $table.learningSteps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relearningSteps => $composableBuilder(
    column: $table.relearningSteps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fsrsWeights => $composableBuilder(
    column: $table.fsrsWeights,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileVersion => $composableBuilder(
    column: $table.profileVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyNewLimit => $composableBuilder(
    column: $table.dailyNewLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyReviewLimit => $composableBuilder(
    column: $table.dailyReviewLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionExpirationSec => $composableBuilder(
    column: $table.sessionExpirationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudentFsrsProfilesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $StudentFsrsProfilesTableTable> {
  $$StudentFsrsProfilesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get desiredRetention => $composableBuilder(
    column: $table.desiredRetention,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maximumInterval => $composableBuilder(
    column: $table.maximumInterval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enableFuzz => $composableBuilder(
    column: $table.enableFuzz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enableShortTerm => $composableBuilder(
    column: $table.enableShortTerm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get learningSteps => $composableBuilder(
    column: $table.learningSteps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relearningSteps => $composableBuilder(
    column: $table.relearningSteps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fsrsWeights => $composableBuilder(
    column: $table.fsrsWeights,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileVersion => $composableBuilder(
    column: $table.profileVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyNewLimit => $composableBuilder(
    column: $table.dailyNewLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyReviewLimit => $composableBuilder(
    column: $table.dailyReviewLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionExpirationSec => $composableBuilder(
    column: $table.sessionExpirationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudentFsrsProfilesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudentFsrsProfilesTableTable> {
  $$StudentFsrsProfilesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<double> get desiredRetention => $composableBuilder(
    column: $table.desiredRetention,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maximumInterval => $composableBuilder(
    column: $table.maximumInterval,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enableFuzz => $composableBuilder(
    column: $table.enableFuzz,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enableShortTerm => $composableBuilder(
    column: $table.enableShortTerm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get learningSteps => $composableBuilder(
    column: $table.learningSteps,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relearningSteps => $composableBuilder(
    column: $table.relearningSteps,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fsrsWeights => $composableBuilder(
    column: $table.fsrsWeights,
    builder: (column) => column,
  );

  GeneratedColumn<int> get profileVersion => $composableBuilder(
    column: $table.profileVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dailyNewLimit => $composableBuilder(
    column: $table.dailyNewLimit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dailyReviewLimit => $composableBuilder(
    column: $table.dailyReviewLimit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sessionExpirationSec => $composableBuilder(
    column: $table.sessionExpirationSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StudentFsrsProfilesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudentFsrsProfilesTableTable,
          StudentFsrsProfilesTableData,
          $$StudentFsrsProfilesTableTableFilterComposer,
          $$StudentFsrsProfilesTableTableOrderingComposer,
          $$StudentFsrsProfilesTableTableAnnotationComposer,
          $$StudentFsrsProfilesTableTableCreateCompanionBuilder,
          $$StudentFsrsProfilesTableTableUpdateCompanionBuilder,
          (
            StudentFsrsProfilesTableData,
            BaseReferences<
              _$AppDatabase,
              $StudentFsrsProfilesTableTable,
              StudentFsrsProfilesTableData
            >,
          ),
          StudentFsrsProfilesTableData,
          PrefetchHooks Function()
        > {
  $$StudentFsrsProfilesTableTableTableManager(
    _$AppDatabase db,
    $StudentFsrsProfilesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudentFsrsProfilesTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$StudentFsrsProfilesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$StudentFsrsProfilesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<double> desiredRetention = const Value.absent(),
                Value<int> maximumInterval = const Value.absent(),
                Value<bool> enableFuzz = const Value.absent(),
                Value<bool> enableShortTerm = const Value.absent(),
                Value<String> learningSteps = const Value.absent(),
                Value<String> relearningSteps = const Value.absent(),
                Value<String> fsrsWeights = const Value.absent(),
                Value<int> profileVersion = const Value.absent(),
                Value<int> dailyNewLimit = const Value.absent(),
                Value<int> dailyReviewLimit = const Value.absent(),
                Value<int> sessionExpirationSec = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudentFsrsProfilesTableCompanion(
                id: id,
                userId: userId,
                desiredRetention: desiredRetention,
                maximumInterval: maximumInterval,
                enableFuzz: enableFuzz,
                enableShortTerm: enableShortTerm,
                learningSteps: learningSteps,
                relearningSteps: relearningSteps,
                fsrsWeights: fsrsWeights,
                profileVersion: profileVersion,
                dailyNewLimit: dailyNewLimit,
                dailyReviewLimit: dailyReviewLimit,
                sessionExpirationSec: sessionExpirationSec,
                syncStatus: syncStatus,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<double> desiredRetention = const Value.absent(),
                Value<int> maximumInterval = const Value.absent(),
                Value<bool> enableFuzz = const Value.absent(),
                Value<bool> enableShortTerm = const Value.absent(),
                Value<String> learningSteps = const Value.absent(),
                Value<String> relearningSteps = const Value.absent(),
                Value<String> fsrsWeights = const Value.absent(),
                Value<int> profileVersion = const Value.absent(),
                Value<int> dailyNewLimit = const Value.absent(),
                Value<int> dailyReviewLimit = const Value.absent(),
                Value<int> sessionExpirationSec = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudentFsrsProfilesTableCompanion.insert(
                id: id,
                userId: userId,
                desiredRetention: desiredRetention,
                maximumInterval: maximumInterval,
                enableFuzz: enableFuzz,
                enableShortTerm: enableShortTerm,
                learningSteps: learningSteps,
                relearningSteps: relearningSteps,
                fsrsWeights: fsrsWeights,
                profileVersion: profileVersion,
                dailyNewLimit: dailyNewLimit,
                dailyReviewLimit: dailyReviewLimit,
                sessionExpirationSec: sessionExpirationSec,
                syncStatus: syncStatus,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudentFsrsProfilesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudentFsrsProfilesTableTable,
      StudentFsrsProfilesTableData,
      $$StudentFsrsProfilesTableTableFilterComposer,
      $$StudentFsrsProfilesTableTableOrderingComposer,
      $$StudentFsrsProfilesTableTableAnnotationComposer,
      $$StudentFsrsProfilesTableTableCreateCompanionBuilder,
      $$StudentFsrsProfilesTableTableUpdateCompanionBuilder,
      (
        StudentFsrsProfilesTableData,
        BaseReferences<
          _$AppDatabase,
          $StudentFsrsProfilesTableTable,
          StudentFsrsProfilesTableData
        >,
      ),
      StudentFsrsProfilesTableData,
      PrefetchHooks Function()
    >;
typedef $$WorkHeartbeatsTableTableCreateCompanionBuilder =
    WorkHeartbeatsTableCompanion Function({
      required String clientUuid,
      required String courseId,
      Value<String?> lessonId,
      Value<String?> context,
      required DateTime occurredAt,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$WorkHeartbeatsTableTableUpdateCompanionBuilder =
    WorkHeartbeatsTableCompanion Function({
      Value<String> clientUuid,
      Value<String> courseId,
      Value<String?> lessonId,
      Value<String?> context,
      Value<DateTime> occurredAt,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$WorkHeartbeatsTableTableFilterComposer
    extends Composer<_$AppDatabase, $WorkHeartbeatsTableTable> {
  $$WorkHeartbeatsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkHeartbeatsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkHeartbeatsTableTable> {
  $$WorkHeartbeatsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkHeartbeatsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkHeartbeatsTableTable> {
  $$WorkHeartbeatsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<String> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$WorkHeartbeatsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkHeartbeatsTableTable,
          WorkHeartbeatsTableData,
          $$WorkHeartbeatsTableTableFilterComposer,
          $$WorkHeartbeatsTableTableOrderingComposer,
          $$WorkHeartbeatsTableTableAnnotationComposer,
          $$WorkHeartbeatsTableTableCreateCompanionBuilder,
          $$WorkHeartbeatsTableTableUpdateCompanionBuilder,
          (
            WorkHeartbeatsTableData,
            BaseReferences<
              _$AppDatabase,
              $WorkHeartbeatsTableTable,
              WorkHeartbeatsTableData
            >,
          ),
          WorkHeartbeatsTableData,
          PrefetchHooks Function()
        > {
  $$WorkHeartbeatsTableTableTableManager(
    _$AppDatabase db,
    $WorkHeartbeatsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkHeartbeatsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkHeartbeatsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorkHeartbeatsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> clientUuid = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String?> lessonId = const Value.absent(),
                Value<String?> context = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkHeartbeatsTableCompanion(
                clientUuid: clientUuid,
                courseId: courseId,
                lessonId: lessonId,
                context: context,
                occurredAt: occurredAt,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String clientUuid,
                required String courseId,
                Value<String?> lessonId = const Value.absent(),
                Value<String?> context = const Value.absent(),
                required DateTime occurredAt,
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkHeartbeatsTableCompanion.insert(
                clientUuid: clientUuid,
                courseId: courseId,
                lessonId: lessonId,
                context: context,
                occurredAt: occurredAt,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkHeartbeatsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkHeartbeatsTableTable,
      WorkHeartbeatsTableData,
      $$WorkHeartbeatsTableTableFilterComposer,
      $$WorkHeartbeatsTableTableOrderingComposer,
      $$WorkHeartbeatsTableTableAnnotationComposer,
      $$WorkHeartbeatsTableTableCreateCompanionBuilder,
      $$WorkHeartbeatsTableTableUpdateCompanionBuilder,
      (
        WorkHeartbeatsTableData,
        BaseReferences<
          _$AppDatabase,
          $WorkHeartbeatsTableTable,
          WorkHeartbeatsTableData
        >,
      ),
      WorkHeartbeatsTableData,
      PrefetchHooks Function()
    >;
typedef $$GpfDimensionsTableTableCreateCompanionBuilder =
    GpfDimensionsTableCompanion Function({
      Value<int> dimensionIndex,
      required String code,
      required String domainCode,
      required String domainName,
      required String constructName,
      required String name,
    });
typedef $$GpfDimensionsTableTableUpdateCompanionBuilder =
    GpfDimensionsTableCompanion Function({
      Value<int> dimensionIndex,
      Value<String> code,
      Value<String> domainCode,
      Value<String> domainName,
      Value<String> constructName,
      Value<String> name,
    });

class $$GpfDimensionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $GpfDimensionsTableTable> {
  $$GpfDimensionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get dimensionIndex => $composableBuilder(
    column: $table.dimensionIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get domainCode => $composableBuilder(
    column: $table.domainCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get domainName => $composableBuilder(
    column: $table.domainName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get constructName => $composableBuilder(
    column: $table.constructName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GpfDimensionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $GpfDimensionsTableTable> {
  $$GpfDimensionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get dimensionIndex => $composableBuilder(
    column: $table.dimensionIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get domainCode => $composableBuilder(
    column: $table.domainCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get domainName => $composableBuilder(
    column: $table.domainName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get constructName => $composableBuilder(
    column: $table.constructName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GpfDimensionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $GpfDimensionsTableTable> {
  $$GpfDimensionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get dimensionIndex => $composableBuilder(
    column: $table.dimensionIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get domainCode => $composableBuilder(
    column: $table.domainCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get domainName => $composableBuilder(
    column: $table.domainName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get constructName => $composableBuilder(
    column: $table.constructName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$GpfDimensionsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GpfDimensionsTableTable,
          GpfDimensionsTableData,
          $$GpfDimensionsTableTableFilterComposer,
          $$GpfDimensionsTableTableOrderingComposer,
          $$GpfDimensionsTableTableAnnotationComposer,
          $$GpfDimensionsTableTableCreateCompanionBuilder,
          $$GpfDimensionsTableTableUpdateCompanionBuilder,
          (
            GpfDimensionsTableData,
            BaseReferences<
              _$AppDatabase,
              $GpfDimensionsTableTable,
              GpfDimensionsTableData
            >,
          ),
          GpfDimensionsTableData,
          PrefetchHooks Function()
        > {
  $$GpfDimensionsTableTableTableManager(
    _$AppDatabase db,
    $GpfDimensionsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GpfDimensionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GpfDimensionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GpfDimensionsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> dimensionIndex = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> domainCode = const Value.absent(),
                Value<String> domainName = const Value.absent(),
                Value<String> constructName = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => GpfDimensionsTableCompanion(
                dimensionIndex: dimensionIndex,
                code: code,
                domainCode: domainCode,
                domainName: domainName,
                constructName: constructName,
                name: name,
              ),
          createCompanionCallback:
              ({
                Value<int> dimensionIndex = const Value.absent(),
                required String code,
                required String domainCode,
                required String domainName,
                required String constructName,
                required String name,
              }) => GpfDimensionsTableCompanion.insert(
                dimensionIndex: dimensionIndex,
                code: code,
                domainCode: domainCode,
                domainName: domainName,
                constructName: constructName,
                name: name,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GpfDimensionsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GpfDimensionsTableTable,
      GpfDimensionsTableData,
      $$GpfDimensionsTableTableFilterComposer,
      $$GpfDimensionsTableTableOrderingComposer,
      $$GpfDimensionsTableTableAnnotationComposer,
      $$GpfDimensionsTableTableCreateCompanionBuilder,
      $$GpfDimensionsTableTableUpdateCompanionBuilder,
      (
        GpfDimensionsTableData,
        BaseReferences<
          _$AppDatabase,
          $GpfDimensionsTableTable,
          GpfDimensionsTableData
        >,
      ),
      GpfDimensionsTableData,
      PrefetchHooks Function()
    >;
typedef $$AvatarItemsTableTableCreateCompanionBuilder =
    AvatarItemsTableCompanion Function({
      required String code,
      required String name,
      required String slot,
      required int layer,
      required String url,
      Value<String> rarity,
      Value<int> price,
      Value<bool> isDefault,
      Value<String?> svgSource,
      Value<double?> boundsLeft,
      Value<double?> boundsTop,
      Value<double?> boundsRight,
      Value<double?> boundsBottom,
      Value<DateTime?> serverUpdatedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AvatarItemsTableTableUpdateCompanionBuilder =
    AvatarItemsTableCompanion Function({
      Value<String> code,
      Value<String> name,
      Value<String> slot,
      Value<int> layer,
      Value<String> url,
      Value<String> rarity,
      Value<int> price,
      Value<bool> isDefault,
      Value<String?> svgSource,
      Value<double?> boundsLeft,
      Value<double?> boundsTop,
      Value<double?> boundsRight,
      Value<double?> boundsBottom,
      Value<DateTime?> serverUpdatedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AvatarItemsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AvatarItemsTableTable> {
  $$AvatarItemsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get svgSource => $composableBuilder(
    column: $table.svgSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get boundsLeft => $composableBuilder(
    column: $table.boundsLeft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get boundsTop => $composableBuilder(
    column: $table.boundsTop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get boundsRight => $composableBuilder(
    column: $table.boundsRight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get boundsBottom => $composableBuilder(
    column: $table.boundsBottom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AvatarItemsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AvatarItemsTableTable> {
  $$AvatarItemsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get svgSource => $composableBuilder(
    column: $table.svgSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get boundsLeft => $composableBuilder(
    column: $table.boundsLeft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get boundsTop => $composableBuilder(
    column: $table.boundsTop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get boundsRight => $composableBuilder(
    column: $table.boundsRight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get boundsBottom => $composableBuilder(
    column: $table.boundsBottom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AvatarItemsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AvatarItemsTableTable> {
  $$AvatarItemsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<int> get layer =>
      $composableBuilder(column: $table.layer, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get rarity =>
      $composableBuilder(column: $table.rarity, builder: (column) => column);

  GeneratedColumn<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<String> get svgSource =>
      $composableBuilder(column: $table.svgSource, builder: (column) => column);

  GeneratedColumn<double> get boundsLeft => $composableBuilder(
    column: $table.boundsLeft,
    builder: (column) => column,
  );

  GeneratedColumn<double> get boundsTop =>
      $composableBuilder(column: $table.boundsTop, builder: (column) => column);

  GeneratedColumn<double> get boundsRight => $composableBuilder(
    column: $table.boundsRight,
    builder: (column) => column,
  );

  GeneratedColumn<double> get boundsBottom => $composableBuilder(
    column: $table.boundsBottom,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AvatarItemsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AvatarItemsTableTable,
          AvatarItemsTableData,
          $$AvatarItemsTableTableFilterComposer,
          $$AvatarItemsTableTableOrderingComposer,
          $$AvatarItemsTableTableAnnotationComposer,
          $$AvatarItemsTableTableCreateCompanionBuilder,
          $$AvatarItemsTableTableUpdateCompanionBuilder,
          (
            AvatarItemsTableData,
            BaseReferences<
              _$AppDatabase,
              $AvatarItemsTableTable,
              AvatarItemsTableData
            >,
          ),
          AvatarItemsTableData,
          PrefetchHooks Function()
        > {
  $$AvatarItemsTableTableTableManager(
    _$AppDatabase db,
    $AvatarItemsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AvatarItemsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AvatarItemsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AvatarItemsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> slot = const Value.absent(),
                Value<int> layer = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> rarity = const Value.absent(),
                Value<int> price = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<String?> svgSource = const Value.absent(),
                Value<double?> boundsLeft = const Value.absent(),
                Value<double?> boundsTop = const Value.absent(),
                Value<double?> boundsRight = const Value.absent(),
                Value<double?> boundsBottom = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AvatarItemsTableCompanion(
                code: code,
                name: name,
                slot: slot,
                layer: layer,
                url: url,
                rarity: rarity,
                price: price,
                isDefault: isDefault,
                svgSource: svgSource,
                boundsLeft: boundsLeft,
                boundsTop: boundsTop,
                boundsRight: boundsRight,
                boundsBottom: boundsBottom,
                serverUpdatedAt: serverUpdatedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String code,
                required String name,
                required String slot,
                required int layer,
                required String url,
                Value<String> rarity = const Value.absent(),
                Value<int> price = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<String?> svgSource = const Value.absent(),
                Value<double?> boundsLeft = const Value.absent(),
                Value<double?> boundsTop = const Value.absent(),
                Value<double?> boundsRight = const Value.absent(),
                Value<double?> boundsBottom = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AvatarItemsTableCompanion.insert(
                code: code,
                name: name,
                slot: slot,
                layer: layer,
                url: url,
                rarity: rarity,
                price: price,
                isDefault: isDefault,
                svgSource: svgSource,
                boundsLeft: boundsLeft,
                boundsTop: boundsTop,
                boundsRight: boundsRight,
                boundsBottom: boundsBottom,
                serverUpdatedAt: serverUpdatedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AvatarItemsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AvatarItemsTableTable,
      AvatarItemsTableData,
      $$AvatarItemsTableTableFilterComposer,
      $$AvatarItemsTableTableOrderingComposer,
      $$AvatarItemsTableTableAnnotationComposer,
      $$AvatarItemsTableTableCreateCompanionBuilder,
      $$AvatarItemsTableTableUpdateCompanionBuilder,
      (
        AvatarItemsTableData,
        BaseReferences<
          _$AppDatabase,
          $AvatarItemsTableTable,
          AvatarItemsTableData
        >,
      ),
      AvatarItemsTableData,
      PrefetchHooks Function()
    >;
typedef $$UserAvatarTableTableCreateCompanionBuilder =
    UserAvatarTableCompanion Function({
      required String userId,
      Value<String> equipped,
      Value<String> ownedCodes,
      Value<int> syncStatus,
      Value<DateTime> updatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<int> rowid,
    });
typedef $$UserAvatarTableTableUpdateCompanionBuilder =
    UserAvatarTableCompanion Function({
      Value<String> userId,
      Value<String> equipped,
      Value<String> ownedCodes,
      Value<int> syncStatus,
      Value<DateTime> updatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<int> rowid,
    });

class $$UserAvatarTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserAvatarTableTable> {
  $$UserAvatarTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipped => $composableBuilder(
    column: $table.equipped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownedCodes => $composableBuilder(
    column: $table.ownedCodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserAvatarTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserAvatarTableTable> {
  $$UserAvatarTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipped => $composableBuilder(
    column: $table.equipped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownedCodes => $composableBuilder(
    column: $table.ownedCodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserAvatarTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserAvatarTableTable> {
  $$UserAvatarTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get equipped =>
      $composableBuilder(column: $table.equipped, builder: (column) => column);

  GeneratedColumn<String> get ownedCodes => $composableBuilder(
    column: $table.ownedCodes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );
}

class $$UserAvatarTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserAvatarTableTable,
          UserAvatarTableData,
          $$UserAvatarTableTableFilterComposer,
          $$UserAvatarTableTableOrderingComposer,
          $$UserAvatarTableTableAnnotationComposer,
          $$UserAvatarTableTableCreateCompanionBuilder,
          $$UserAvatarTableTableUpdateCompanionBuilder,
          (
            UserAvatarTableData,
            BaseReferences<
              _$AppDatabase,
              $UserAvatarTableTable,
              UserAvatarTableData
            >,
          ),
          UserAvatarTableData,
          PrefetchHooks Function()
        > {
  $$UserAvatarTableTableTableManager(
    _$AppDatabase db,
    $UserAvatarTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserAvatarTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserAvatarTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserAvatarTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> equipped = const Value.absent(),
                Value<String> ownedCodes = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserAvatarTableCompanion(
                userId: userId,
                equipped: equipped,
                ownedCodes: ownedCodes,
                syncStatus: syncStatus,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                Value<String> equipped = const Value.absent(),
                Value<String> ownedCodes = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserAvatarTableCompanion.insert(
                userId: userId,
                equipped: equipped,
                ownedCodes: ownedCodes,
                syncStatus: syncStatus,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserAvatarTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserAvatarTableTable,
      UserAvatarTableData,
      $$UserAvatarTableTableFilterComposer,
      $$UserAvatarTableTableOrderingComposer,
      $$UserAvatarTableTableAnnotationComposer,
      $$UserAvatarTableTableCreateCompanionBuilder,
      $$UserAvatarTableTableUpdateCompanionBuilder,
      (
        UserAvatarTableData,
        BaseReferences<
          _$AppDatabase,
          $UserAvatarTableTable,
          UserAvatarTableData
        >,
      ),
      UserAvatarTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CoursesTableTableTableManager get coursesTable =>
      $$CoursesTableTableTableManager(_db, _db.coursesTable);
  $$LessonsTableTableTableManager get lessonsTable =>
      $$LessonsTableTableTableManager(_db, _db.lessonsTable);
  $$UserProgressTableTableTableManager get userProgressTable =>
      $$UserProgressTableTableTableManager(_db, _db.userProgressTable);
  $$SyncQueueTableTableTableManager get syncQueueTable =>
      $$SyncQueueTableTableTableManager(_db, _db.syncQueueTable);
  $$UsersTableTableTableManager get usersTable =>
      $$UsersTableTableTableManager(_db, _db.usersTable);
  $$UserCoursesTableTableTableManager get userCoursesTable =>
      $$UserCoursesTableTableTableManager(_db, _db.userCoursesTable);
  $$UserStatsTableTableTableManager get userStatsTable =>
      $$UserStatsTableTableTableManager(_db, _db.userStatsTable);
  $$BookmarksTableTableTableManager get bookmarksTable =>
      $$BookmarksTableTableTableManager(_db, _db.bookmarksTable);
  $$UserEloProfileTableTableTableManager get userEloProfileTable =>
      $$UserEloProfileTableTableTableManager(_db, _db.userEloProfileTable);
  $$GamificationConfigTableTableTableManager get gamificationConfigTable =>
      $$GamificationConfigTableTableTableManager(
        _db,
        _db.gamificationConfigTable,
      );
  $$UserAchievementsTableTableTableManager get userAchievementsTable =>
      $$UserAchievementsTableTableTableManager(_db, _db.userAchievementsTable);
  $$BlockStatsTableTableTableManager get blockStatsTable =>
      $$BlockStatsTableTableTableManager(_db, _db.blockStatsTable);
  $$ChatSessionsTableTableTableManager get chatSessionsTable =>
      $$ChatSessionsTableTableTableManager(_db, _db.chatSessionsTable);
  $$ChatMessagesTableTableTableManager get chatMessagesTable =>
      $$ChatMessagesTableTableTableManager(_db, _db.chatMessagesTable);
  $$PracticeCardsTableTableTableManager get practiceCardsTable =>
      $$PracticeCardsTableTableTableManager(_db, _db.practiceCardsTable);
  $$ReviewLogsTableTableTableManager get reviewLogsTable =>
      $$ReviewLogsTableTableTableManager(_db, _db.reviewLogsTable);
  $$StudentFsrsProfilesTableTableTableManager get studentFsrsProfilesTable =>
      $$StudentFsrsProfilesTableTableTableManager(
        _db,
        _db.studentFsrsProfilesTable,
      );
  $$WorkHeartbeatsTableTableTableManager get workHeartbeatsTable =>
      $$WorkHeartbeatsTableTableTableManager(_db, _db.workHeartbeatsTable);
  $$GpfDimensionsTableTableTableManager get gpfDimensionsTable =>
      $$GpfDimensionsTableTableTableManager(_db, _db.gpfDimensionsTable);
  $$AvatarItemsTableTableTableManager get avatarItemsTable =>
      $$AvatarItemsTableTableTableManager(_db, _db.avatarItemsTable);
  $$UserAvatarTableTableTableManager get userAvatarTable =>
      $$UserAvatarTableTableTableManager(_db, _db.userAvatarTable);
}
