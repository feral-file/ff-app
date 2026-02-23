// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PublishersTable extends Publishers
    with TableInfo<$PublishersTable, PublisherData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PublishersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUsMeta = const VerificationMeta(
    'createdAtUs',
  );
  @override
  late final GeneratedColumn<BigInt> createdAtUs = GeneratedColumn<BigInt>(
    'created_at_us',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUsMeta = const VerificationMeta(
    'updatedAtUs',
  );
  @override
  late final GeneratedColumn<BigInt> updatedAtUs = GeneratedColumn<BigInt>(
    'updated_at_us',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, createdAtUs, updatedAtUs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'publishers';
  @override
  VerificationContext validateIntegrity(
    Insertable<PublisherData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at_us')) {
      context.handle(
        _createdAtUsMeta,
        createdAtUs.isAcceptableOrUnknown(
          data['created_at_us']!,
          _createdAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUsMeta);
    }
    if (data.containsKey('updated_at_us')) {
      context.handle(
        _updatedAtUsMeta,
        updatedAtUs.isAcceptableOrUnknown(
          data['updated_at_us']!,
          _updatedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PublisherData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PublisherData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}created_at_us'],
      )!,
      updatedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}updated_at_us'],
      )!,
    );
  }

  @override
  $PublishersTable createAlias(String alias) {
    return $PublishersTable(attachedDatabase, alias);
  }
}

class PublisherData extends DataClass implements Insertable<PublisherData> {
  /// Publisher identifier.
  final int id;

  /// Publisher display name.
  final String title;

  /// Creation timestamp in microseconds.
  final BigInt createdAtUs;

  /// Last update timestamp in microseconds.
  final BigInt updatedAtUs;
  const PublisherData({
    required this.id,
    required this.title,
    required this.createdAtUs,
    required this.updatedAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['created_at_us'] = Variable<BigInt>(createdAtUs);
    map['updated_at_us'] = Variable<BigInt>(updatedAtUs);
    return map;
  }

  PublishersCompanion toCompanion(bool nullToAbsent) {
    return PublishersCompanion(
      id: Value(id),
      title: Value(title),
      createdAtUs: Value(createdAtUs),
      updatedAtUs: Value(updatedAtUs),
    );
  }

  factory PublisherData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PublisherData(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAtUs: serializer.fromJson<BigInt>(json['createdAtUs']),
      updatedAtUs: serializer.fromJson<BigInt>(json['updatedAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'createdAtUs': serializer.toJson<BigInt>(createdAtUs),
      'updatedAtUs': serializer.toJson<BigInt>(updatedAtUs),
    };
  }

  PublisherData copyWith({
    int? id,
    String? title,
    BigInt? createdAtUs,
    BigInt? updatedAtUs,
  }) => PublisherData(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAtUs: createdAtUs ?? this.createdAtUs,
    updatedAtUs: updatedAtUs ?? this.updatedAtUs,
  );
  PublisherData copyWithCompanion(PublishersCompanion data) {
    return PublisherData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAtUs: data.createdAtUs.present
          ? data.createdAtUs.value
          : this.createdAtUs,
      updatedAtUs: data.updatedAtUs.present
          ? data.updatedAtUs.value
          : this.updatedAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PublisherData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, createdAtUs, updatedAtUs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PublisherData &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAtUs == this.createdAtUs &&
          other.updatedAtUs == this.updatedAtUs);
}

class PublishersCompanion extends UpdateCompanion<PublisherData> {
  final Value<int> id;
  final Value<String> title;
  final Value<BigInt> createdAtUs;
  final Value<BigInt> updatedAtUs;
  const PublishersCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAtUs = const Value.absent(),
    this.updatedAtUs = const Value.absent(),
  });
  PublishersCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required BigInt createdAtUs,
    required BigInt updatedAtUs,
  }) : title = Value(title),
       createdAtUs = Value(createdAtUs),
       updatedAtUs = Value(updatedAtUs);
  static Insertable<PublisherData> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<BigInt>? createdAtUs,
    Expression<BigInt>? updatedAtUs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAtUs != null) 'created_at_us': createdAtUs,
      if (updatedAtUs != null) 'updated_at_us': updatedAtUs,
    });
  }

  PublishersCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<BigInt>? createdAtUs,
    Value<BigInt>? updatedAtUs,
  }) {
    return PublishersCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAtUs: createdAtUs ?? this.createdAtUs,
      updatedAtUs: updatedAtUs ?? this.updatedAtUs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAtUs.present) {
      map['created_at_us'] = Variable<BigInt>(createdAtUs.value);
    }
    if (updatedAtUs.present) {
      map['updated_at_us'] = Variable<BigInt>(updatedAtUs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PublishersCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs')
          ..write(')'))
        .toString();
  }
}

class $ChannelsTable extends Channels
    with TableInfo<$ChannelsTable, ChannelData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publisherIdMeta = const VerificationMeta(
    'publisherId',
  );
  @override
  late final GeneratedColumn<int> publisherId = GeneratedColumn<int>(
    'publisher_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES publishers (id)',
    ),
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
  static const VerificationMeta _curatorMeta = const VerificationMeta(
    'curator',
  );
  @override
  late final GeneratedColumn<String> curator = GeneratedColumn<String>(
    'curator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverImageUriMeta = const VerificationMeta(
    'coverImageUri',
  );
  @override
  late final GeneratedColumn<String> coverImageUri = GeneratedColumn<String>(
    'cover_image_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUsMeta = const VerificationMeta(
    'createdAtUs',
  );
  @override
  late final GeneratedColumn<BigInt> createdAtUs = GeneratedColumn<BigInt>(
    'created_at_us',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUsMeta = const VerificationMeta(
    'updatedAtUs',
  );
  @override
  late final GeneratedColumn<BigInt> updatedAtUs = GeneratedColumn<BigInt>(
    'updated_at_us',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    baseUrl,
    slug,
    publisherId,
    title,
    curator,
    summary,
    coverImageUri,
    createdAtUs,
    updatedAtUs,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChannelData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    }
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    }
    if (data.containsKey('publisher_id')) {
      context.handle(
        _publisherIdMeta,
        publisherId.isAcceptableOrUnknown(
          data['publisher_id']!,
          _publisherIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('curator')) {
      context.handle(
        _curatorMeta,
        curator.isAcceptableOrUnknown(data['curator']!, _curatorMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('cover_image_uri')) {
      context.handle(
        _coverImageUriMeta,
        coverImageUri.isAcceptableOrUnknown(
          data['cover_image_uri']!,
          _coverImageUriMeta,
        ),
      );
    }
    if (data.containsKey('created_at_us')) {
      context.handle(
        _createdAtUsMeta,
        createdAtUs.isAcceptableOrUnknown(
          data['created_at_us']!,
          _createdAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUsMeta);
    }
    if (data.containsKey('updated_at_us')) {
      context.handle(
        _updatedAtUsMeta,
        updatedAtUs.isAcceptableOrUnknown(
          data['updated_at_us']!,
          _updatedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUsMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChannelData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChannelData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      ),
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      ),
      publisherId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}publisher_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      curator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curator'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      coverImageUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_image_uri'],
      ),
      createdAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}created_at_us'],
      )!,
      updatedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}updated_at_us'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      ),
    );
  }

  @override
  $ChannelsTable createAlias(String alias) {
    return $ChannelsTable(attachedDatabase, alias);
  }
}

class ChannelData extends DataClass implements Insertable<ChannelData> {
  /// Channel identifier (DP-1 ID like ch_*).
  final String id;

  /// Channel type: 0 = DP1, 1 = local virtual.
  final int type;

  /// Feed server base URL for DP1 channels.
  final String? baseUrl;

  /// URL-friendly identifier.
  final String? slug;

  /// Publisher reference.
  final int? publisherId;

  /// Channel title.
  final String title;

  /// Curator name.
  final String? curator;

  /// Channel description.
  final String? summary;

  /// Cover image URL.
  final String? coverImageUri;

  /// Creation timestamp in microseconds.
  final BigInt createdAtUs;

  /// Last update timestamp in microseconds.
  final BigInt updatedAtUs;

  /// Display order.
  final int? sortOrder;
  const ChannelData({
    required this.id,
    required this.type,
    this.baseUrl,
    this.slug,
    this.publisherId,
    required this.title,
    this.curator,
    this.summary,
    this.coverImageUri,
    required this.createdAtUs,
    required this.updatedAtUs,
    this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<int>(type);
    if (!nullToAbsent || baseUrl != null) {
      map['base_url'] = Variable<String>(baseUrl);
    }
    if (!nullToAbsent || slug != null) {
      map['slug'] = Variable<String>(slug);
    }
    if (!nullToAbsent || publisherId != null) {
      map['publisher_id'] = Variable<int>(publisherId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || curator != null) {
      map['curator'] = Variable<String>(curator);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || coverImageUri != null) {
      map['cover_image_uri'] = Variable<String>(coverImageUri);
    }
    map['created_at_us'] = Variable<BigInt>(createdAtUs);
    map['updated_at_us'] = Variable<BigInt>(updatedAtUs);
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    return map;
  }

  ChannelsCompanion toCompanion(bool nullToAbsent) {
    return ChannelsCompanion(
      id: Value(id),
      type: Value(type),
      baseUrl: baseUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(baseUrl),
      slug: slug == null && nullToAbsent ? const Value.absent() : Value(slug),
      publisherId: publisherId == null && nullToAbsent
          ? const Value.absent()
          : Value(publisherId),
      title: Value(title),
      curator: curator == null && nullToAbsent
          ? const Value.absent()
          : Value(curator),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      coverImageUri: coverImageUri == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImageUri),
      createdAtUs: Value(createdAtUs),
      updatedAtUs: Value(updatedAtUs),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
    );
  }

  factory ChannelData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChannelData(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<int>(json['type']),
      baseUrl: serializer.fromJson<String?>(json['baseUrl']),
      slug: serializer.fromJson<String?>(json['slug']),
      publisherId: serializer.fromJson<int?>(json['publisherId']),
      title: serializer.fromJson<String>(json['title']),
      curator: serializer.fromJson<String?>(json['curator']),
      summary: serializer.fromJson<String?>(json['summary']),
      coverImageUri: serializer.fromJson<String?>(json['coverImageUri']),
      createdAtUs: serializer.fromJson<BigInt>(json['createdAtUs']),
      updatedAtUs: serializer.fromJson<BigInt>(json['updatedAtUs']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<int>(type),
      'baseUrl': serializer.toJson<String?>(baseUrl),
      'slug': serializer.toJson<String?>(slug),
      'publisherId': serializer.toJson<int?>(publisherId),
      'title': serializer.toJson<String>(title),
      'curator': serializer.toJson<String?>(curator),
      'summary': serializer.toJson<String?>(summary),
      'coverImageUri': serializer.toJson<String?>(coverImageUri),
      'createdAtUs': serializer.toJson<BigInt>(createdAtUs),
      'updatedAtUs': serializer.toJson<BigInt>(updatedAtUs),
      'sortOrder': serializer.toJson<int?>(sortOrder),
    };
  }

  ChannelData copyWith({
    String? id,
    int? type,
    Value<String?> baseUrl = const Value.absent(),
    Value<String?> slug = const Value.absent(),
    Value<int?> publisherId = const Value.absent(),
    String? title,
    Value<String?> curator = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    Value<String?> coverImageUri = const Value.absent(),
    BigInt? createdAtUs,
    BigInt? updatedAtUs,
    Value<int?> sortOrder = const Value.absent(),
  }) => ChannelData(
    id: id ?? this.id,
    type: type ?? this.type,
    baseUrl: baseUrl.present ? baseUrl.value : this.baseUrl,
    slug: slug.present ? slug.value : this.slug,
    publisherId: publisherId.present ? publisherId.value : this.publisherId,
    title: title ?? this.title,
    curator: curator.present ? curator.value : this.curator,
    summary: summary.present ? summary.value : this.summary,
    coverImageUri: coverImageUri.present
        ? coverImageUri.value
        : this.coverImageUri,
    createdAtUs: createdAtUs ?? this.createdAtUs,
    updatedAtUs: updatedAtUs ?? this.updatedAtUs,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
  );
  ChannelData copyWithCompanion(ChannelsCompanion data) {
    return ChannelData(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      slug: data.slug.present ? data.slug.value : this.slug,
      publisherId: data.publisherId.present
          ? data.publisherId.value
          : this.publisherId,
      title: data.title.present ? data.title.value : this.title,
      curator: data.curator.present ? data.curator.value : this.curator,
      summary: data.summary.present ? data.summary.value : this.summary,
      coverImageUri: data.coverImageUri.present
          ? data.coverImageUri.value
          : this.coverImageUri,
      createdAtUs: data.createdAtUs.present
          ? data.createdAtUs.value
          : this.createdAtUs,
      updatedAtUs: data.updatedAtUs.present
          ? data.updatedAtUs.value
          : this.updatedAtUs,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChannelData(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('slug: $slug, ')
          ..write('publisherId: $publisherId, ')
          ..write('title: $title, ')
          ..write('curator: $curator, ')
          ..write('summary: $summary, ')
          ..write('coverImageUri: $coverImageUri, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    baseUrl,
    slug,
    publisherId,
    title,
    curator,
    summary,
    coverImageUri,
    createdAtUs,
    updatedAtUs,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChannelData &&
          other.id == this.id &&
          other.type == this.type &&
          other.baseUrl == this.baseUrl &&
          other.slug == this.slug &&
          other.publisherId == this.publisherId &&
          other.title == this.title &&
          other.curator == this.curator &&
          other.summary == this.summary &&
          other.coverImageUri == this.coverImageUri &&
          other.createdAtUs == this.createdAtUs &&
          other.updatedAtUs == this.updatedAtUs &&
          other.sortOrder == this.sortOrder);
}

class ChannelsCompanion extends UpdateCompanion<ChannelData> {
  final Value<String> id;
  final Value<int> type;
  final Value<String?> baseUrl;
  final Value<String?> slug;
  final Value<int?> publisherId;
  final Value<String> title;
  final Value<String?> curator;
  final Value<String?> summary;
  final Value<String?> coverImageUri;
  final Value<BigInt> createdAtUs;
  final Value<BigInt> updatedAtUs;
  final Value<int?> sortOrder;
  final Value<int> rowid;
  const ChannelsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.slug = const Value.absent(),
    this.publisherId = const Value.absent(),
    this.title = const Value.absent(),
    this.curator = const Value.absent(),
    this.summary = const Value.absent(),
    this.coverImageUri = const Value.absent(),
    this.createdAtUs = const Value.absent(),
    this.updatedAtUs = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChannelsCompanion.insert({
    required String id,
    required int type,
    this.baseUrl = const Value.absent(),
    this.slug = const Value.absent(),
    this.publisherId = const Value.absent(),
    required String title,
    this.curator = const Value.absent(),
    this.summary = const Value.absent(),
    this.coverImageUri = const Value.absent(),
    required BigInt createdAtUs,
    required BigInt updatedAtUs,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       title = Value(title),
       createdAtUs = Value(createdAtUs),
       updatedAtUs = Value(updatedAtUs);
  static Insertable<ChannelData> custom({
    Expression<String>? id,
    Expression<int>? type,
    Expression<String>? baseUrl,
    Expression<String>? slug,
    Expression<int>? publisherId,
    Expression<String>? title,
    Expression<String>? curator,
    Expression<String>? summary,
    Expression<String>? coverImageUri,
    Expression<BigInt>? createdAtUs,
    Expression<BigInt>? updatedAtUs,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (baseUrl != null) 'base_url': baseUrl,
      if (slug != null) 'slug': slug,
      if (publisherId != null) 'publisher_id': publisherId,
      if (title != null) 'title': title,
      if (curator != null) 'curator': curator,
      if (summary != null) 'summary': summary,
      if (coverImageUri != null) 'cover_image_uri': coverImageUri,
      if (createdAtUs != null) 'created_at_us': createdAtUs,
      if (updatedAtUs != null) 'updated_at_us': updatedAtUs,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChannelsCompanion copyWith({
    Value<String>? id,
    Value<int>? type,
    Value<String?>? baseUrl,
    Value<String?>? slug,
    Value<int?>? publisherId,
    Value<String>? title,
    Value<String?>? curator,
    Value<String?>? summary,
    Value<String?>? coverImageUri,
    Value<BigInt>? createdAtUs,
    Value<BigInt>? updatedAtUs,
    Value<int?>? sortOrder,
    Value<int>? rowid,
  }) {
    return ChannelsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      slug: slug ?? this.slug,
      publisherId: publisherId ?? this.publisherId,
      title: title ?? this.title,
      curator: curator ?? this.curator,
      summary: summary ?? this.summary,
      coverImageUri: coverImageUri ?? this.coverImageUri,
      createdAtUs: createdAtUs ?? this.createdAtUs,
      updatedAtUs: updatedAtUs ?? this.updatedAtUs,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (publisherId.present) {
      map['publisher_id'] = Variable<int>(publisherId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (curator.present) {
      map['curator'] = Variable<String>(curator.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (coverImageUri.present) {
      map['cover_image_uri'] = Variable<String>(coverImageUri.value);
    }
    if (createdAtUs.present) {
      map['created_at_us'] = Variable<BigInt>(createdAtUs.value);
    }
    if (updatedAtUs.present) {
      map['updated_at_us'] = Variable<BigInt>(updatedAtUs.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChannelsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('slug: $slug, ')
          ..write('publisherId: $publisherId, ')
          ..write('title: $title, ')
          ..write('curator: $curator, ')
          ..write('summary: $summary, ')
          ..write('coverImageUri: $coverImageUri, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, PlaylistData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dpVersionMeta = const VerificationMeta(
    'dpVersion',
  );
  @override
  late final GeneratedColumn<String> dpVersion = GeneratedColumn<String>(
    'dp_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _createdAtUsMeta = const VerificationMeta(
    'createdAtUs',
  );
  @override
  late final GeneratedColumn<BigInt> createdAtUs = GeneratedColumn<BigInt>(
    'created_at_us',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUsMeta = const VerificationMeta(
    'updatedAtUs',
  );
  @override
  late final GeneratedColumn<BigInt> updatedAtUs = GeneratedColumn<BigInt>(
    'updated_at_us',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signaturesJsonMeta = const VerificationMeta(
    'signaturesJson',
  );
  @override
  late final GeneratedColumn<String> signaturesJson = GeneratedColumn<String>(
    'signatures_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultsJsonMeta = const VerificationMeta(
    'defaultsJson',
  );
  @override
  late final GeneratedColumn<String> defaultsJson = GeneratedColumn<String>(
    'defaults_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dynamicQueriesJsonMeta =
      const VerificationMeta('dynamicQueriesJson');
  @override
  late final GeneratedColumn<String> dynamicQueriesJson =
      GeneratedColumn<String>(
        'dynamic_queries_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _ownerAddressMeta = const VerificationMeta(
    'ownerAddress',
  );
  @override
  late final GeneratedColumn<String> ownerAddress = GeneratedColumn<String>(
    'owner_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerChainMeta = const VerificationMeta(
    'ownerChain',
  );
  @override
  late final GeneratedColumn<String> ownerChain = GeneratedColumn<String>(
    'owner_chain',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortModeMeta = const VerificationMeta(
    'sortMode',
  );
  @override
  late final GeneratedColumn<int> sortMode = GeneratedColumn<int>(
    'sort_mode',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemCountMeta = const VerificationMeta(
    'itemCount',
  );
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
    'item_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    channelId,
    type,
    baseUrl,
    dpVersion,
    slug,
    title,
    createdAtUs,
    updatedAtUs,
    signaturesJson,
    defaultsJson,
    dynamicQueriesJson,
    ownerAddress,
    ownerChain,
    sortMode,
    itemCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    }
    if (data.containsKey('dp_version')) {
      context.handle(
        _dpVersionMeta,
        dpVersion.isAcceptableOrUnknown(data['dp_version']!, _dpVersionMeta),
      );
    }
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at_us')) {
      context.handle(
        _createdAtUsMeta,
        createdAtUs.isAcceptableOrUnknown(
          data['created_at_us']!,
          _createdAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUsMeta);
    }
    if (data.containsKey('updated_at_us')) {
      context.handle(
        _updatedAtUsMeta,
        updatedAtUs.isAcceptableOrUnknown(
          data['updated_at_us']!,
          _updatedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUsMeta);
    }
    if (data.containsKey('signatures_json')) {
      context.handle(
        _signaturesJsonMeta,
        signaturesJson.isAcceptableOrUnknown(
          data['signatures_json']!,
          _signaturesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_signaturesJsonMeta);
    }
    if (data.containsKey('defaults_json')) {
      context.handle(
        _defaultsJsonMeta,
        defaultsJson.isAcceptableOrUnknown(
          data['defaults_json']!,
          _defaultsJsonMeta,
        ),
      );
    }
    if (data.containsKey('dynamic_queries_json')) {
      context.handle(
        _dynamicQueriesJsonMeta,
        dynamicQueriesJson.isAcceptableOrUnknown(
          data['dynamic_queries_json']!,
          _dynamicQueriesJsonMeta,
        ),
      );
    }
    if (data.containsKey('owner_address')) {
      context.handle(
        _ownerAddressMeta,
        ownerAddress.isAcceptableOrUnknown(
          data['owner_address']!,
          _ownerAddressMeta,
        ),
      );
    }
    if (data.containsKey('owner_chain')) {
      context.handle(
        _ownerChainMeta,
        ownerChain.isAcceptableOrUnknown(data['owner_chain']!, _ownerChainMeta),
      );
    }
    if (data.containsKey('sort_mode')) {
      context.handle(
        _sortModeMeta,
        sortMode.isAcceptableOrUnknown(data['sort_mode']!, _sortModeMeta),
      );
    } else if (isInserting) {
      context.missing(_sortModeMeta);
    }
    if (data.containsKey('item_count')) {
      context.handle(
        _itemCountMeta,
        itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      ),
      dpVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dp_version'],
      ),
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}created_at_us'],
      )!,
      updatedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}updated_at_us'],
      )!,
      signaturesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signatures_json'],
      )!,
      defaultsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}defaults_json'],
      ),
      dynamicQueriesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dynamic_queries_json'],
      ),
      ownerAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_address'],
      ),
      ownerChain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_chain'],
      ),
      sortMode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_mode'],
      )!,
      itemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_count'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class PlaylistData extends DataClass implements Insertable<PlaylistData> {
  /// Playlist identifier (DP-1 ID like pl_*).
  final String id;

  /// Reference to Channels table.
  final String? channelId;

  /// Playlist type: 0 = DP1, 1 = address-based.
  final int type;

  /// Feed server base URL for DP1 playlists.
  final String? baseUrl;

  /// DP1 protocol version.
  final String? dpVersion;

  /// URL-friendly identifier.
  final String? slug;

  /// Playlist title.
  final String title;

  /// Creation timestamp in microseconds.
  final BigInt createdAtUs;

  /// Last update timestamp in microseconds.
  final BigInt updatedAtUs;

  /// DP1 signatures stored as JSON array.
  final String signaturesJson;

  /// DP1 defaults configuration.
  final String? defaultsJson;

  /// Dynamic query configuration for fetching tokens.
  final String? dynamicQueriesJson;

  /// Owner address for address-based playlists (uppercase).
  final String? ownerAddress;

  /// Blockchain type (e.g., "ETH", "BTC").
  final String? ownerChain;

  /// Sort mode: 0 = position-based, 1 = provenance-based.
  final int sortMode;

  /// Number of items in the playlist.
  final int itemCount;
  const PlaylistData({
    required this.id,
    this.channelId,
    required this.type,
    this.baseUrl,
    this.dpVersion,
    this.slug,
    required this.title,
    required this.createdAtUs,
    required this.updatedAtUs,
    required this.signaturesJson,
    this.defaultsJson,
    this.dynamicQueriesJson,
    this.ownerAddress,
    this.ownerChain,
    required this.sortMode,
    required this.itemCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || channelId != null) {
      map['channel_id'] = Variable<String>(channelId);
    }
    map['type'] = Variable<int>(type);
    if (!nullToAbsent || baseUrl != null) {
      map['base_url'] = Variable<String>(baseUrl);
    }
    if (!nullToAbsent || dpVersion != null) {
      map['dp_version'] = Variable<String>(dpVersion);
    }
    if (!nullToAbsent || slug != null) {
      map['slug'] = Variable<String>(slug);
    }
    map['title'] = Variable<String>(title);
    map['created_at_us'] = Variable<BigInt>(createdAtUs);
    map['updated_at_us'] = Variable<BigInt>(updatedAtUs);
    map['signatures_json'] = Variable<String>(signaturesJson);
    if (!nullToAbsent || defaultsJson != null) {
      map['defaults_json'] = Variable<String>(defaultsJson);
    }
    if (!nullToAbsent || dynamicQueriesJson != null) {
      map['dynamic_queries_json'] = Variable<String>(dynamicQueriesJson);
    }
    if (!nullToAbsent || ownerAddress != null) {
      map['owner_address'] = Variable<String>(ownerAddress);
    }
    if (!nullToAbsent || ownerChain != null) {
      map['owner_chain'] = Variable<String>(ownerChain);
    }
    map['sort_mode'] = Variable<int>(sortMode);
    map['item_count'] = Variable<int>(itemCount);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      channelId: channelId == null && nullToAbsent
          ? const Value.absent()
          : Value(channelId),
      type: Value(type),
      baseUrl: baseUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(baseUrl),
      dpVersion: dpVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(dpVersion),
      slug: slug == null && nullToAbsent ? const Value.absent() : Value(slug),
      title: Value(title),
      createdAtUs: Value(createdAtUs),
      updatedAtUs: Value(updatedAtUs),
      signaturesJson: Value(signaturesJson),
      defaultsJson: defaultsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultsJson),
      dynamicQueriesJson: dynamicQueriesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(dynamicQueriesJson),
      ownerAddress: ownerAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerAddress),
      ownerChain: ownerChain == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerChain),
      sortMode: Value(sortMode),
      itemCount: Value(itemCount),
    );
  }

  factory PlaylistData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistData(
      id: serializer.fromJson<String>(json['id']),
      channelId: serializer.fromJson<String?>(json['channelId']),
      type: serializer.fromJson<int>(json['type']),
      baseUrl: serializer.fromJson<String?>(json['baseUrl']),
      dpVersion: serializer.fromJson<String?>(json['dpVersion']),
      slug: serializer.fromJson<String?>(json['slug']),
      title: serializer.fromJson<String>(json['title']),
      createdAtUs: serializer.fromJson<BigInt>(json['createdAtUs']),
      updatedAtUs: serializer.fromJson<BigInt>(json['updatedAtUs']),
      signaturesJson: serializer.fromJson<String>(json['signaturesJson']),
      defaultsJson: serializer.fromJson<String?>(json['defaultsJson']),
      dynamicQueriesJson: serializer.fromJson<String?>(
        json['dynamicQueriesJson'],
      ),
      ownerAddress: serializer.fromJson<String?>(json['ownerAddress']),
      ownerChain: serializer.fromJson<String?>(json['ownerChain']),
      sortMode: serializer.fromJson<int>(json['sortMode']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'channelId': serializer.toJson<String?>(channelId),
      'type': serializer.toJson<int>(type),
      'baseUrl': serializer.toJson<String?>(baseUrl),
      'dpVersion': serializer.toJson<String?>(dpVersion),
      'slug': serializer.toJson<String?>(slug),
      'title': serializer.toJson<String>(title),
      'createdAtUs': serializer.toJson<BigInt>(createdAtUs),
      'updatedAtUs': serializer.toJson<BigInt>(updatedAtUs),
      'signaturesJson': serializer.toJson<String>(signaturesJson),
      'defaultsJson': serializer.toJson<String?>(defaultsJson),
      'dynamicQueriesJson': serializer.toJson<String?>(dynamicQueriesJson),
      'ownerAddress': serializer.toJson<String?>(ownerAddress),
      'ownerChain': serializer.toJson<String?>(ownerChain),
      'sortMode': serializer.toJson<int>(sortMode),
      'itemCount': serializer.toJson<int>(itemCount),
    };
  }

  PlaylistData copyWith({
    String? id,
    Value<String?> channelId = const Value.absent(),
    int? type,
    Value<String?> baseUrl = const Value.absent(),
    Value<String?> dpVersion = const Value.absent(),
    Value<String?> slug = const Value.absent(),
    String? title,
    BigInt? createdAtUs,
    BigInt? updatedAtUs,
    String? signaturesJson,
    Value<String?> defaultsJson = const Value.absent(),
    Value<String?> dynamicQueriesJson = const Value.absent(),
    Value<String?> ownerAddress = const Value.absent(),
    Value<String?> ownerChain = const Value.absent(),
    int? sortMode,
    int? itemCount,
  }) => PlaylistData(
    id: id ?? this.id,
    channelId: channelId.present ? channelId.value : this.channelId,
    type: type ?? this.type,
    baseUrl: baseUrl.present ? baseUrl.value : this.baseUrl,
    dpVersion: dpVersion.present ? dpVersion.value : this.dpVersion,
    slug: slug.present ? slug.value : this.slug,
    title: title ?? this.title,
    createdAtUs: createdAtUs ?? this.createdAtUs,
    updatedAtUs: updatedAtUs ?? this.updatedAtUs,
    signaturesJson: signaturesJson ?? this.signaturesJson,
    defaultsJson: defaultsJson.present ? defaultsJson.value : this.defaultsJson,
    dynamicQueriesJson: dynamicQueriesJson.present
        ? dynamicQueriesJson.value
        : this.dynamicQueriesJson,
    ownerAddress: ownerAddress.present ? ownerAddress.value : this.ownerAddress,
    ownerChain: ownerChain.present ? ownerChain.value : this.ownerChain,
    sortMode: sortMode ?? this.sortMode,
    itemCount: itemCount ?? this.itemCount,
  );
  PlaylistData copyWithCompanion(PlaylistsCompanion data) {
    return PlaylistData(
      id: data.id.present ? data.id.value : this.id,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      type: data.type.present ? data.type.value : this.type,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      dpVersion: data.dpVersion.present ? data.dpVersion.value : this.dpVersion,
      slug: data.slug.present ? data.slug.value : this.slug,
      title: data.title.present ? data.title.value : this.title,
      createdAtUs: data.createdAtUs.present
          ? data.createdAtUs.value
          : this.createdAtUs,
      updatedAtUs: data.updatedAtUs.present
          ? data.updatedAtUs.value
          : this.updatedAtUs,
      signaturesJson: data.signaturesJson.present
          ? data.signaturesJson.value
          : this.signaturesJson,
      defaultsJson: data.defaultsJson.present
          ? data.defaultsJson.value
          : this.defaultsJson,
      dynamicQueriesJson: data.dynamicQueriesJson.present
          ? data.dynamicQueriesJson.value
          : this.dynamicQueriesJson,
      ownerAddress: data.ownerAddress.present
          ? data.ownerAddress.value
          : this.ownerAddress,
      ownerChain: data.ownerChain.present
          ? data.ownerChain.value
          : this.ownerChain,
      sortMode: data.sortMode.present ? data.sortMode.value : this.sortMode,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistData(')
          ..write('id: $id, ')
          ..write('channelId: $channelId, ')
          ..write('type: $type, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('dpVersion: $dpVersion, ')
          ..write('slug: $slug, ')
          ..write('title: $title, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('signaturesJson: $signaturesJson, ')
          ..write('defaultsJson: $defaultsJson, ')
          ..write('dynamicQueriesJson: $dynamicQueriesJson, ')
          ..write('ownerAddress: $ownerAddress, ')
          ..write('ownerChain: $ownerChain, ')
          ..write('sortMode: $sortMode, ')
          ..write('itemCount: $itemCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    channelId,
    type,
    baseUrl,
    dpVersion,
    slug,
    title,
    createdAtUs,
    updatedAtUs,
    signaturesJson,
    defaultsJson,
    dynamicQueriesJson,
    ownerAddress,
    ownerChain,
    sortMode,
    itemCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistData &&
          other.id == this.id &&
          other.channelId == this.channelId &&
          other.type == this.type &&
          other.baseUrl == this.baseUrl &&
          other.dpVersion == this.dpVersion &&
          other.slug == this.slug &&
          other.title == this.title &&
          other.createdAtUs == this.createdAtUs &&
          other.updatedAtUs == this.updatedAtUs &&
          other.signaturesJson == this.signaturesJson &&
          other.defaultsJson == this.defaultsJson &&
          other.dynamicQueriesJson == this.dynamicQueriesJson &&
          other.ownerAddress == this.ownerAddress &&
          other.ownerChain == this.ownerChain &&
          other.sortMode == this.sortMode &&
          other.itemCount == this.itemCount);
}

class PlaylistsCompanion extends UpdateCompanion<PlaylistData> {
  final Value<String> id;
  final Value<String?> channelId;
  final Value<int> type;
  final Value<String?> baseUrl;
  final Value<String?> dpVersion;
  final Value<String?> slug;
  final Value<String> title;
  final Value<BigInt> createdAtUs;
  final Value<BigInt> updatedAtUs;
  final Value<String> signaturesJson;
  final Value<String?> defaultsJson;
  final Value<String?> dynamicQueriesJson;
  final Value<String?> ownerAddress;
  final Value<String?> ownerChain;
  final Value<int> sortMode;
  final Value<int> itemCount;
  final Value<int> rowid;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.channelId = const Value.absent(),
    this.type = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.dpVersion = const Value.absent(),
    this.slug = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAtUs = const Value.absent(),
    this.updatedAtUs = const Value.absent(),
    this.signaturesJson = const Value.absent(),
    this.defaultsJson = const Value.absent(),
    this.dynamicQueriesJson = const Value.absent(),
    this.ownerAddress = const Value.absent(),
    this.ownerChain = const Value.absent(),
    this.sortMode = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    required String id,
    this.channelId = const Value.absent(),
    required int type,
    this.baseUrl = const Value.absent(),
    this.dpVersion = const Value.absent(),
    this.slug = const Value.absent(),
    required String title,
    required BigInt createdAtUs,
    required BigInt updatedAtUs,
    required String signaturesJson,
    this.defaultsJson = const Value.absent(),
    this.dynamicQueriesJson = const Value.absent(),
    this.ownerAddress = const Value.absent(),
    this.ownerChain = const Value.absent(),
    required int sortMode,
    this.itemCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       title = Value(title),
       createdAtUs = Value(createdAtUs),
       updatedAtUs = Value(updatedAtUs),
       signaturesJson = Value(signaturesJson),
       sortMode = Value(sortMode);
  static Insertable<PlaylistData> custom({
    Expression<String>? id,
    Expression<String>? channelId,
    Expression<int>? type,
    Expression<String>? baseUrl,
    Expression<String>? dpVersion,
    Expression<String>? slug,
    Expression<String>? title,
    Expression<BigInt>? createdAtUs,
    Expression<BigInt>? updatedAtUs,
    Expression<String>? signaturesJson,
    Expression<String>? defaultsJson,
    Expression<String>? dynamicQueriesJson,
    Expression<String>? ownerAddress,
    Expression<String>? ownerChain,
    Expression<int>? sortMode,
    Expression<int>? itemCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (channelId != null) 'channel_id': channelId,
      if (type != null) 'type': type,
      if (baseUrl != null) 'base_url': baseUrl,
      if (dpVersion != null) 'dp_version': dpVersion,
      if (slug != null) 'slug': slug,
      if (title != null) 'title': title,
      if (createdAtUs != null) 'created_at_us': createdAtUs,
      if (updatedAtUs != null) 'updated_at_us': updatedAtUs,
      if (signaturesJson != null) 'signatures_json': signaturesJson,
      if (defaultsJson != null) 'defaults_json': defaultsJson,
      if (dynamicQueriesJson != null)
        'dynamic_queries_json': dynamicQueriesJson,
      if (ownerAddress != null) 'owner_address': ownerAddress,
      if (ownerChain != null) 'owner_chain': ownerChain,
      if (sortMode != null) 'sort_mode': sortMode,
      if (itemCount != null) 'item_count': itemCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistsCompanion copyWith({
    Value<String>? id,
    Value<String?>? channelId,
    Value<int>? type,
    Value<String?>? baseUrl,
    Value<String?>? dpVersion,
    Value<String?>? slug,
    Value<String>? title,
    Value<BigInt>? createdAtUs,
    Value<BigInt>? updatedAtUs,
    Value<String>? signaturesJson,
    Value<String?>? defaultsJson,
    Value<String?>? dynamicQueriesJson,
    Value<String?>? ownerAddress,
    Value<String?>? ownerChain,
    Value<int>? sortMode,
    Value<int>? itemCount,
    Value<int>? rowid,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      dpVersion: dpVersion ?? this.dpVersion,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      createdAtUs: createdAtUs ?? this.createdAtUs,
      updatedAtUs: updatedAtUs ?? this.updatedAtUs,
      signaturesJson: signaturesJson ?? this.signaturesJson,
      defaultsJson: defaultsJson ?? this.defaultsJson,
      dynamicQueriesJson: dynamicQueriesJson ?? this.dynamicQueriesJson,
      ownerAddress: ownerAddress ?? this.ownerAddress,
      ownerChain: ownerChain ?? this.ownerChain,
      sortMode: sortMode ?? this.sortMode,
      itemCount: itemCount ?? this.itemCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (dpVersion.present) {
      map['dp_version'] = Variable<String>(dpVersion.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAtUs.present) {
      map['created_at_us'] = Variable<BigInt>(createdAtUs.value);
    }
    if (updatedAtUs.present) {
      map['updated_at_us'] = Variable<BigInt>(updatedAtUs.value);
    }
    if (signaturesJson.present) {
      map['signatures_json'] = Variable<String>(signaturesJson.value);
    }
    if (defaultsJson.present) {
      map['defaults_json'] = Variable<String>(defaultsJson.value);
    }
    if (dynamicQueriesJson.present) {
      map['dynamic_queries_json'] = Variable<String>(dynamicQueriesJson.value);
    }
    if (ownerAddress.present) {
      map['owner_address'] = Variable<String>(ownerAddress.value);
    }
    if (ownerChain.present) {
      map['owner_chain'] = Variable<String>(ownerChain.value);
    }
    if (sortMode.present) {
      map['sort_mode'] = Variable<int>(sortMode.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('channelId: $channelId, ')
          ..write('type: $type, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('dpVersion: $dpVersion, ')
          ..write('slug: $slug, ')
          ..write('title: $title, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('signaturesJson: $signaturesJson, ')
          ..write('defaultsJson: $defaultsJson, ')
          ..write('dynamicQueriesJson: $dynamicQueriesJson, ')
          ..write('ownerAddress: $ownerAddress, ')
          ..write('ownerChain: $ownerChain, ')
          ..write('sortMode: $sortMode, ')
          ..write('itemCount: $itemCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemsTable extends Items with TableInfo<$ItemsTable, ItemData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subtitleMeta = const VerificationMeta(
    'subtitle',
  );
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailUriMeta = const VerificationMeta(
    'thumbnailUri',
  );
  @override
  late final GeneratedColumn<String> thumbnailUri = GeneratedColumn<String>(
    'thumbnail_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _provenanceJsonMeta = const VerificationMeta(
    'provenanceJson',
  );
  @override
  late final GeneratedColumn<String> provenanceJson = GeneratedColumn<String>(
    'provenance_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUriMeta = const VerificationMeta(
    'sourceUri',
  );
  @override
  late final GeneratedColumn<String> sourceUri = GeneratedColumn<String>(
    'source_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refUriMeta = const VerificationMeta('refUri');
  @override
  late final GeneratedColumn<String> refUri = GeneratedColumn<String>(
    'ref_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _licenseMeta = const VerificationMeta(
    'license',
  );
  @override
  late final GeneratedColumn<String> license = GeneratedColumn<String>(
    'license',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reproJsonMeta = const VerificationMeta(
    'reproJson',
  );
  @override
  late final GeneratedColumn<String> reproJson = GeneratedColumn<String>(
    'repro_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _overrideJsonMeta = const VerificationMeta(
    'overrideJson',
  );
  @override
  late final GeneratedColumn<String> overrideJson = GeneratedColumn<String>(
    'override_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayJsonMeta = const VerificationMeta(
    'displayJson',
  );
  @override
  late final GeneratedColumn<String> displayJson = GeneratedColumn<String>(
    'display_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tokenDataJsonMeta = const VerificationMeta(
    'tokenDataJson',
  );
  @override
  late final GeneratedColumn<String> tokenDataJson = GeneratedColumn<String>(
    'token_data_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _listArtistJsonMeta = const VerificationMeta(
    'listArtistJson',
  );
  @override
  late final GeneratedColumn<String> listArtistJson = GeneratedColumn<String>(
    'list_artist_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enrichmentStatusMeta = const VerificationMeta(
    'enrichmentStatus',
  );
  @override
  late final GeneratedColumn<int> enrichmentStatus = GeneratedColumn<int>(
    'enrichment_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtUsMeta = const VerificationMeta(
    'updatedAtUs',
  );
  @override
  late final GeneratedColumn<BigInt> updatedAtUs = GeneratedColumn<BigInt>(
    'updated_at_us',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    title,
    subtitle,
    thumbnailUri,
    durationSec,
    provenanceJson,
    sourceUri,
    refUri,
    license,
    reproJson,
    overrideJson,
    displayJson,
    tokenDataJson,
    listArtistJson,
    enrichmentStatus,
    updatedAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
      );
    }
    if (data.containsKey('thumbnail_uri')) {
      context.handle(
        _thumbnailUriMeta,
        thumbnailUri.isAcceptableOrUnknown(
          data['thumbnail_uri']!,
          _thumbnailUriMeta,
        ),
      );
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('provenance_json')) {
      context.handle(
        _provenanceJsonMeta,
        provenanceJson.isAcceptableOrUnknown(
          data['provenance_json']!,
          _provenanceJsonMeta,
        ),
      );
    }
    if (data.containsKey('source_uri')) {
      context.handle(
        _sourceUriMeta,
        sourceUri.isAcceptableOrUnknown(data['source_uri']!, _sourceUriMeta),
      );
    }
    if (data.containsKey('ref_uri')) {
      context.handle(
        _refUriMeta,
        refUri.isAcceptableOrUnknown(data['ref_uri']!, _refUriMeta),
      );
    }
    if (data.containsKey('license')) {
      context.handle(
        _licenseMeta,
        license.isAcceptableOrUnknown(data['license']!, _licenseMeta),
      );
    }
    if (data.containsKey('repro_json')) {
      context.handle(
        _reproJsonMeta,
        reproJson.isAcceptableOrUnknown(data['repro_json']!, _reproJsonMeta),
      );
    }
    if (data.containsKey('override_json')) {
      context.handle(
        _overrideJsonMeta,
        overrideJson.isAcceptableOrUnknown(
          data['override_json']!,
          _overrideJsonMeta,
        ),
      );
    }
    if (data.containsKey('display_json')) {
      context.handle(
        _displayJsonMeta,
        displayJson.isAcceptableOrUnknown(
          data['display_json']!,
          _displayJsonMeta,
        ),
      );
    }
    if (data.containsKey('token_data_json')) {
      context.handle(
        _tokenDataJsonMeta,
        tokenDataJson.isAcceptableOrUnknown(
          data['token_data_json']!,
          _tokenDataJsonMeta,
        ),
      );
    }
    if (data.containsKey('list_artist_json')) {
      context.handle(
        _listArtistJsonMeta,
        listArtistJson.isAcceptableOrUnknown(
          data['list_artist_json']!,
          _listArtistJsonMeta,
        ),
      );
    }
    if (data.containsKey('enrichment_status')) {
      context.handle(
        _enrichmentStatusMeta,
        enrichmentStatus.isAcceptableOrUnknown(
          data['enrichment_status']!,
          _enrichmentStatusMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_us')) {
      context.handle(
        _updatedAtUsMeta,
        updatedAtUs.isAcceptableOrUnknown(
          data['updated_at_us']!,
          _updatedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      ),
      thumbnailUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_uri'],
      ),
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      ),
      provenanceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provenance_json'],
      ),
      sourceUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_uri'],
      ),
      refUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_uri'],
      ),
      license: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license'],
      ),
      reproJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repro_json'],
      ),
      overrideJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}override_json'],
      ),
      displayJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_json'],
      ),
      tokenDataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token_data_json'],
      ),
      listArtistJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_artist_json'],
      ),
      enrichmentStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enrichment_status'],
      )!,
      updatedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}updated_at_us'],
      )!,
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class ItemData extends DataClass implements Insertable<ItemData> {
  /// Item identifier (CID for tokens, DP1 item ID for DP1 items).
  final String id;

  /// Item kind: 0 = DP1 item, 1 = indexer token.
  final int kind;

  /// Display title.
  final String? title;

  /// Artists string (subtitle).
  final String? subtitle;

  /// Thumbnail image URL.
  final String? thumbnailUri;

  /// Duration in seconds.
  final int? durationSec;

  /// Provenance data as JSON.
  final String? provenanceJson;

  /// Source URI.
  final String? sourceUri;

  /// Reference URI.
  final String? refUri;

  /// License information.
  final String? license;

  /// Reproduction data as JSON.
  final String? reproJson;

  /// Override configuration as JSON.
  final String? overrideJson;

  /// Display configuration as JSON.
  final String? displayJson;

  /// Complete token JSON for reconstruction (indexer tokens).
  final String? tokenDataJson;

  /// List of artists as JSON (List<DP1Artist>).
  final String? listArtistJson;

  /// Enrichment status: 0 = pending, 1 = enriched, 2 = failed.
  final int enrichmentStatus;

  /// Last update timestamp in microseconds.
  final BigInt updatedAtUs;
  const ItemData({
    required this.id,
    required this.kind,
    this.title,
    this.subtitle,
    this.thumbnailUri,
    this.durationSec,
    this.provenanceJson,
    this.sourceUri,
    this.refUri,
    this.license,
    this.reproJson,
    this.overrideJson,
    this.displayJson,
    this.tokenDataJson,
    this.listArtistJson,
    required this.enrichmentStatus,
    required this.updatedAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<int>(kind);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || subtitle != null) {
      map['subtitle'] = Variable<String>(subtitle);
    }
    if (!nullToAbsent || thumbnailUri != null) {
      map['thumbnail_uri'] = Variable<String>(thumbnailUri);
    }
    if (!nullToAbsent || durationSec != null) {
      map['duration_sec'] = Variable<int>(durationSec);
    }
    if (!nullToAbsent || provenanceJson != null) {
      map['provenance_json'] = Variable<String>(provenanceJson);
    }
    if (!nullToAbsent || sourceUri != null) {
      map['source_uri'] = Variable<String>(sourceUri);
    }
    if (!nullToAbsent || refUri != null) {
      map['ref_uri'] = Variable<String>(refUri);
    }
    if (!nullToAbsent || license != null) {
      map['license'] = Variable<String>(license);
    }
    if (!nullToAbsent || reproJson != null) {
      map['repro_json'] = Variable<String>(reproJson);
    }
    if (!nullToAbsent || overrideJson != null) {
      map['override_json'] = Variable<String>(overrideJson);
    }
    if (!nullToAbsent || displayJson != null) {
      map['display_json'] = Variable<String>(displayJson);
    }
    if (!nullToAbsent || tokenDataJson != null) {
      map['token_data_json'] = Variable<String>(tokenDataJson);
    }
    if (!nullToAbsent || listArtistJson != null) {
      map['list_artist_json'] = Variable<String>(listArtistJson);
    }
    map['enrichment_status'] = Variable<int>(enrichmentStatus);
    map['updated_at_us'] = Variable<BigInt>(updatedAtUs);
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      kind: Value(kind),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      subtitle: subtitle == null && nullToAbsent
          ? const Value.absent()
          : Value(subtitle),
      thumbnailUri: thumbnailUri == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUri),
      durationSec: durationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSec),
      provenanceJson: provenanceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(provenanceJson),
      sourceUri: sourceUri == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUri),
      refUri: refUri == null && nullToAbsent
          ? const Value.absent()
          : Value(refUri),
      license: license == null && nullToAbsent
          ? const Value.absent()
          : Value(license),
      reproJson: reproJson == null && nullToAbsent
          ? const Value.absent()
          : Value(reproJson),
      overrideJson: overrideJson == null && nullToAbsent
          ? const Value.absent()
          : Value(overrideJson),
      displayJson: displayJson == null && nullToAbsent
          ? const Value.absent()
          : Value(displayJson),
      tokenDataJson: tokenDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(tokenDataJson),
      listArtistJson: listArtistJson == null && nullToAbsent
          ? const Value.absent()
          : Value(listArtistJson),
      enrichmentStatus: Value(enrichmentStatus),
      updatedAtUs: Value(updatedAtUs),
    );
  }

  factory ItemData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemData(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<int>(json['kind']),
      title: serializer.fromJson<String?>(json['title']),
      subtitle: serializer.fromJson<String?>(json['subtitle']),
      thumbnailUri: serializer.fromJson<String?>(json['thumbnailUri']),
      durationSec: serializer.fromJson<int?>(json['durationSec']),
      provenanceJson: serializer.fromJson<String?>(json['provenanceJson']),
      sourceUri: serializer.fromJson<String?>(json['sourceUri']),
      refUri: serializer.fromJson<String?>(json['refUri']),
      license: serializer.fromJson<String?>(json['license']),
      reproJson: serializer.fromJson<String?>(json['reproJson']),
      overrideJson: serializer.fromJson<String?>(json['overrideJson']),
      displayJson: serializer.fromJson<String?>(json['displayJson']),
      tokenDataJson: serializer.fromJson<String?>(json['tokenDataJson']),
      listArtistJson: serializer.fromJson<String?>(json['listArtistJson']),
      enrichmentStatus: serializer.fromJson<int>(json['enrichmentStatus']),
      updatedAtUs: serializer.fromJson<BigInt>(json['updatedAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<int>(kind),
      'title': serializer.toJson<String?>(title),
      'subtitle': serializer.toJson<String?>(subtitle),
      'thumbnailUri': serializer.toJson<String?>(thumbnailUri),
      'durationSec': serializer.toJson<int?>(durationSec),
      'provenanceJson': serializer.toJson<String?>(provenanceJson),
      'sourceUri': serializer.toJson<String?>(sourceUri),
      'refUri': serializer.toJson<String?>(refUri),
      'license': serializer.toJson<String?>(license),
      'reproJson': serializer.toJson<String?>(reproJson),
      'overrideJson': serializer.toJson<String?>(overrideJson),
      'displayJson': serializer.toJson<String?>(displayJson),
      'tokenDataJson': serializer.toJson<String?>(tokenDataJson),
      'listArtistJson': serializer.toJson<String?>(listArtistJson),
      'enrichmentStatus': serializer.toJson<int>(enrichmentStatus),
      'updatedAtUs': serializer.toJson<BigInt>(updatedAtUs),
    };
  }

  ItemData copyWith({
    String? id,
    int? kind,
    Value<String?> title = const Value.absent(),
    Value<String?> subtitle = const Value.absent(),
    Value<String?> thumbnailUri = const Value.absent(),
    Value<int?> durationSec = const Value.absent(),
    Value<String?> provenanceJson = const Value.absent(),
    Value<String?> sourceUri = const Value.absent(),
    Value<String?> refUri = const Value.absent(),
    Value<String?> license = const Value.absent(),
    Value<String?> reproJson = const Value.absent(),
    Value<String?> overrideJson = const Value.absent(),
    Value<String?> displayJson = const Value.absent(),
    Value<String?> tokenDataJson = const Value.absent(),
    Value<String?> listArtistJson = const Value.absent(),
    int? enrichmentStatus,
    BigInt? updatedAtUs,
  }) => ItemData(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title.present ? title.value : this.title,
    subtitle: subtitle.present ? subtitle.value : this.subtitle,
    thumbnailUri: thumbnailUri.present ? thumbnailUri.value : this.thumbnailUri,
    durationSec: durationSec.present ? durationSec.value : this.durationSec,
    provenanceJson: provenanceJson.present
        ? provenanceJson.value
        : this.provenanceJson,
    sourceUri: sourceUri.present ? sourceUri.value : this.sourceUri,
    refUri: refUri.present ? refUri.value : this.refUri,
    license: license.present ? license.value : this.license,
    reproJson: reproJson.present ? reproJson.value : this.reproJson,
    overrideJson: overrideJson.present ? overrideJson.value : this.overrideJson,
    displayJson: displayJson.present ? displayJson.value : this.displayJson,
    tokenDataJson: tokenDataJson.present
        ? tokenDataJson.value
        : this.tokenDataJson,
    listArtistJson: listArtistJson.present
        ? listArtistJson.value
        : this.listArtistJson,
    enrichmentStatus: enrichmentStatus ?? this.enrichmentStatus,
    updatedAtUs: updatedAtUs ?? this.updatedAtUs,
  );
  ItemData copyWithCompanion(ItemsCompanion data) {
    return ItemData(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      thumbnailUri: data.thumbnailUri.present
          ? data.thumbnailUri.value
          : this.thumbnailUri,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      provenanceJson: data.provenanceJson.present
          ? data.provenanceJson.value
          : this.provenanceJson,
      sourceUri: data.sourceUri.present ? data.sourceUri.value : this.sourceUri,
      refUri: data.refUri.present ? data.refUri.value : this.refUri,
      license: data.license.present ? data.license.value : this.license,
      reproJson: data.reproJson.present ? data.reproJson.value : this.reproJson,
      overrideJson: data.overrideJson.present
          ? data.overrideJson.value
          : this.overrideJson,
      displayJson: data.displayJson.present
          ? data.displayJson.value
          : this.displayJson,
      tokenDataJson: data.tokenDataJson.present
          ? data.tokenDataJson.value
          : this.tokenDataJson,
      listArtistJson: data.listArtistJson.present
          ? data.listArtistJson.value
          : this.listArtistJson,
      enrichmentStatus: data.enrichmentStatus.present
          ? data.enrichmentStatus.value
          : this.enrichmentStatus,
      updatedAtUs: data.updatedAtUs.present
          ? data.updatedAtUs.value
          : this.updatedAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemData(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('thumbnailUri: $thumbnailUri, ')
          ..write('durationSec: $durationSec, ')
          ..write('provenanceJson: $provenanceJson, ')
          ..write('sourceUri: $sourceUri, ')
          ..write('refUri: $refUri, ')
          ..write('license: $license, ')
          ..write('reproJson: $reproJson, ')
          ..write('overrideJson: $overrideJson, ')
          ..write('displayJson: $displayJson, ')
          ..write('tokenDataJson: $tokenDataJson, ')
          ..write('listArtistJson: $listArtistJson, ')
          ..write('enrichmentStatus: $enrichmentStatus, ')
          ..write('updatedAtUs: $updatedAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    title,
    subtitle,
    thumbnailUri,
    durationSec,
    provenanceJson,
    sourceUri,
    refUri,
    license,
    reproJson,
    overrideJson,
    displayJson,
    tokenDataJson,
    listArtistJson,
    enrichmentStatus,
    updatedAtUs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemData &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.subtitle == this.subtitle &&
          other.thumbnailUri == this.thumbnailUri &&
          other.durationSec == this.durationSec &&
          other.provenanceJson == this.provenanceJson &&
          other.sourceUri == this.sourceUri &&
          other.refUri == this.refUri &&
          other.license == this.license &&
          other.reproJson == this.reproJson &&
          other.overrideJson == this.overrideJson &&
          other.displayJson == this.displayJson &&
          other.tokenDataJson == this.tokenDataJson &&
          other.listArtistJson == this.listArtistJson &&
          other.enrichmentStatus == this.enrichmentStatus &&
          other.updatedAtUs == this.updatedAtUs);
}

class ItemsCompanion extends UpdateCompanion<ItemData> {
  final Value<String> id;
  final Value<int> kind;
  final Value<String?> title;
  final Value<String?> subtitle;
  final Value<String?> thumbnailUri;
  final Value<int?> durationSec;
  final Value<String?> provenanceJson;
  final Value<String?> sourceUri;
  final Value<String?> refUri;
  final Value<String?> license;
  final Value<String?> reproJson;
  final Value<String?> overrideJson;
  final Value<String?> displayJson;
  final Value<String?> tokenDataJson;
  final Value<String?> listArtistJson;
  final Value<int> enrichmentStatus;
  final Value<BigInt> updatedAtUs;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.thumbnailUri = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.provenanceJson = const Value.absent(),
    this.sourceUri = const Value.absent(),
    this.refUri = const Value.absent(),
    this.license = const Value.absent(),
    this.reproJson = const Value.absent(),
    this.overrideJson = const Value.absent(),
    this.displayJson = const Value.absent(),
    this.tokenDataJson = const Value.absent(),
    this.listArtistJson = const Value.absent(),
    this.enrichmentStatus = const Value.absent(),
    this.updatedAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    required int kind,
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.thumbnailUri = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.provenanceJson = const Value.absent(),
    this.sourceUri = const Value.absent(),
    this.refUri = const Value.absent(),
    this.license = const Value.absent(),
    this.reproJson = const Value.absent(),
    this.overrideJson = const Value.absent(),
    this.displayJson = const Value.absent(),
    this.tokenDataJson = const Value.absent(),
    this.listArtistJson = const Value.absent(),
    this.enrichmentStatus = const Value.absent(),
    required BigInt updatedAtUs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       updatedAtUs = Value(updatedAtUs);
  static Insertable<ItemData> custom({
    Expression<String>? id,
    Expression<int>? kind,
    Expression<String>? title,
    Expression<String>? subtitle,
    Expression<String>? thumbnailUri,
    Expression<int>? durationSec,
    Expression<String>? provenanceJson,
    Expression<String>? sourceUri,
    Expression<String>? refUri,
    Expression<String>? license,
    Expression<String>? reproJson,
    Expression<String>? overrideJson,
    Expression<String>? displayJson,
    Expression<String>? tokenDataJson,
    Expression<String>? listArtistJson,
    Expression<int>? enrichmentStatus,
    Expression<BigInt>? updatedAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (thumbnailUri != null) 'thumbnail_uri': thumbnailUri,
      if (durationSec != null) 'duration_sec': durationSec,
      if (provenanceJson != null) 'provenance_json': provenanceJson,
      if (sourceUri != null) 'source_uri': sourceUri,
      if (refUri != null) 'ref_uri': refUri,
      if (license != null) 'license': license,
      if (reproJson != null) 'repro_json': reproJson,
      if (overrideJson != null) 'override_json': overrideJson,
      if (displayJson != null) 'display_json': displayJson,
      if (tokenDataJson != null) 'token_data_json': tokenDataJson,
      if (listArtistJson != null) 'list_artist_json': listArtistJson,
      if (enrichmentStatus != null) 'enrichment_status': enrichmentStatus,
      if (updatedAtUs != null) 'updated_at_us': updatedAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith({
    Value<String>? id,
    Value<int>? kind,
    Value<String?>? title,
    Value<String?>? subtitle,
    Value<String?>? thumbnailUri,
    Value<int?>? durationSec,
    Value<String?>? provenanceJson,
    Value<String?>? sourceUri,
    Value<String?>? refUri,
    Value<String?>? license,
    Value<String?>? reproJson,
    Value<String?>? overrideJson,
    Value<String?>? displayJson,
    Value<String?>? tokenDataJson,
    Value<String?>? listArtistJson,
    Value<int>? enrichmentStatus,
    Value<BigInt>? updatedAtUs,
    Value<int>? rowid,
  }) {
    return ItemsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      thumbnailUri: thumbnailUri ?? this.thumbnailUri,
      durationSec: durationSec ?? this.durationSec,
      provenanceJson: provenanceJson ?? this.provenanceJson,
      sourceUri: sourceUri ?? this.sourceUri,
      refUri: refUri ?? this.refUri,
      license: license ?? this.license,
      reproJson: reproJson ?? this.reproJson,
      overrideJson: overrideJson ?? this.overrideJson,
      displayJson: displayJson ?? this.displayJson,
      tokenDataJson: tokenDataJson ?? this.tokenDataJson,
      listArtistJson: listArtistJson ?? this.listArtistJson,
      enrichmentStatus: enrichmentStatus ?? this.enrichmentStatus,
      updatedAtUs: updatedAtUs ?? this.updatedAtUs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (thumbnailUri.present) {
      map['thumbnail_uri'] = Variable<String>(thumbnailUri.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (provenanceJson.present) {
      map['provenance_json'] = Variable<String>(provenanceJson.value);
    }
    if (sourceUri.present) {
      map['source_uri'] = Variable<String>(sourceUri.value);
    }
    if (refUri.present) {
      map['ref_uri'] = Variable<String>(refUri.value);
    }
    if (license.present) {
      map['license'] = Variable<String>(license.value);
    }
    if (reproJson.present) {
      map['repro_json'] = Variable<String>(reproJson.value);
    }
    if (overrideJson.present) {
      map['override_json'] = Variable<String>(overrideJson.value);
    }
    if (displayJson.present) {
      map['display_json'] = Variable<String>(displayJson.value);
    }
    if (tokenDataJson.present) {
      map['token_data_json'] = Variable<String>(tokenDataJson.value);
    }
    if (listArtistJson.present) {
      map['list_artist_json'] = Variable<String>(listArtistJson.value);
    }
    if (enrichmentStatus.present) {
      map['enrichment_status'] = Variable<int>(enrichmentStatus.value);
    }
    if (updatedAtUs.present) {
      map['updated_at_us'] = Variable<BigInt>(updatedAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('thumbnailUri: $thumbnailUri, ')
          ..write('durationSec: $durationSec, ')
          ..write('provenanceJson: $provenanceJson, ')
          ..write('sourceUri: $sourceUri, ')
          ..write('refUri: $refUri, ')
          ..write('license: $license, ')
          ..write('reproJson: $reproJson, ')
          ..write('overrideJson: $overrideJson, ')
          ..write('displayJson: $displayJson, ')
          ..write('tokenDataJson: $tokenDataJson, ')
          ..write('listArtistJson: $listArtistJson, ')
          ..write('enrichmentStatus: $enrichmentStatus, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistEntriesTable extends PlaylistEntries
    with TableInfo<$PlaylistEntriesTable, PlaylistEntryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortKeyUsMeta = const VerificationMeta(
    'sortKeyUs',
  );
  @override
  late final GeneratedColumn<BigInt> sortKeyUs = GeneratedColumn<BigInt>(
    'sort_key_us',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUsMeta = const VerificationMeta(
    'updatedAtUs',
  );
  @override
  late final GeneratedColumn<BigInt> updatedAtUs = GeneratedColumn<BigInt>(
    'updated_at_us',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playlistId,
    itemId,
    position,
    sortKeyUs,
    updatedAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistEntryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('sort_key_us')) {
      context.handle(
        _sortKeyUsMeta,
        sortKeyUs.isAcceptableOrUnknown(data['sort_key_us']!, _sortKeyUsMeta),
      );
    } else if (isInserting) {
      context.missing(_sortKeyUsMeta);
    }
    if (data.containsKey('updated_at_us')) {
      context.handle(
        _updatedAtUsMeta,
        updatedAtUs.isAcceptableOrUnknown(
          data['updated_at_us']!,
          _updatedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, itemId};
  @override
  PlaylistEntryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistEntryData(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      ),
      sortKeyUs: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}sort_key_us'],
      )!,
      updatedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}updated_at_us'],
      )!,
    );
  }

  @override
  $PlaylistEntriesTable createAlias(String alias) {
    return $PlaylistEntriesTable(attachedDatabase, alias);
  }
}

class PlaylistEntryData extends DataClass
    implements Insertable<PlaylistEntryData> {
  /// Reference to Playlists table.
  final String playlistId;

  /// Reference to Items table.
  final String itemId;

  /// Position in playlist (for position-based sorting).
  final int? position;

  /// Sort key in microseconds (for provenance-based sorting).
  final BigInt sortKeyUs;

  /// Last update timestamp in microseconds.
  final BigInt updatedAtUs;
  const PlaylistEntryData({
    required this.playlistId,
    required this.itemId,
    this.position,
    required this.sortKeyUs,
    required this.updatedAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<String>(playlistId);
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || position != null) {
      map['position'] = Variable<int>(position);
    }
    map['sort_key_us'] = Variable<BigInt>(sortKeyUs);
    map['updated_at_us'] = Variable<BigInt>(updatedAtUs);
    return map;
  }

  PlaylistEntriesCompanion toCompanion(bool nullToAbsent) {
    return PlaylistEntriesCompanion(
      playlistId: Value(playlistId),
      itemId: Value(itemId),
      position: position == null && nullToAbsent
          ? const Value.absent()
          : Value(position),
      sortKeyUs: Value(sortKeyUs),
      updatedAtUs: Value(updatedAtUs),
    );
  }

  factory PlaylistEntryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistEntryData(
      playlistId: serializer.fromJson<String>(json['playlistId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      position: serializer.fromJson<int?>(json['position']),
      sortKeyUs: serializer.fromJson<BigInt>(json['sortKeyUs']),
      updatedAtUs: serializer.fromJson<BigInt>(json['updatedAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<String>(playlistId),
      'itemId': serializer.toJson<String>(itemId),
      'position': serializer.toJson<int?>(position),
      'sortKeyUs': serializer.toJson<BigInt>(sortKeyUs),
      'updatedAtUs': serializer.toJson<BigInt>(updatedAtUs),
    };
  }

  PlaylistEntryData copyWith({
    String? playlistId,
    String? itemId,
    Value<int?> position = const Value.absent(),
    BigInt? sortKeyUs,
    BigInt? updatedAtUs,
  }) => PlaylistEntryData(
    playlistId: playlistId ?? this.playlistId,
    itemId: itemId ?? this.itemId,
    position: position.present ? position.value : this.position,
    sortKeyUs: sortKeyUs ?? this.sortKeyUs,
    updatedAtUs: updatedAtUs ?? this.updatedAtUs,
  );
  PlaylistEntryData copyWithCompanion(PlaylistEntriesCompanion data) {
    return PlaylistEntryData(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      position: data.position.present ? data.position.value : this.position,
      sortKeyUs: data.sortKeyUs.present ? data.sortKeyUs.value : this.sortKeyUs,
      updatedAtUs: data.updatedAtUs.present
          ? data.updatedAtUs.value
          : this.updatedAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEntryData(')
          ..write('playlistId: $playlistId, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position, ')
          ..write('sortKeyUs: $sortKeyUs, ')
          ..write('updatedAtUs: $updatedAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(playlistId, itemId, position, sortKeyUs, updatedAtUs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistEntryData &&
          other.playlistId == this.playlistId &&
          other.itemId == this.itemId &&
          other.position == this.position &&
          other.sortKeyUs == this.sortKeyUs &&
          other.updatedAtUs == this.updatedAtUs);
}

class PlaylistEntriesCompanion extends UpdateCompanion<PlaylistEntryData> {
  final Value<String> playlistId;
  final Value<String> itemId;
  final Value<int?> position;
  final Value<BigInt> sortKeyUs;
  final Value<BigInt> updatedAtUs;
  final Value<int> rowid;
  const PlaylistEntriesCompanion({
    this.playlistId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.position = const Value.absent(),
    this.sortKeyUs = const Value.absent(),
    this.updatedAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistEntriesCompanion.insert({
    required String playlistId,
    required String itemId,
    this.position = const Value.absent(),
    required BigInt sortKeyUs,
    required BigInt updatedAtUs,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       itemId = Value(itemId),
       sortKeyUs = Value(sortKeyUs),
       updatedAtUs = Value(updatedAtUs);
  static Insertable<PlaylistEntryData> custom({
    Expression<String>? playlistId,
    Expression<String>? itemId,
    Expression<int>? position,
    Expression<BigInt>? sortKeyUs,
    Expression<BigInt>? updatedAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (itemId != null) 'item_id': itemId,
      if (position != null) 'position': position,
      if (sortKeyUs != null) 'sort_key_us': sortKeyUs,
      if (updatedAtUs != null) 'updated_at_us': updatedAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistEntriesCompanion copyWith({
    Value<String>? playlistId,
    Value<String>? itemId,
    Value<int?>? position,
    Value<BigInt>? sortKeyUs,
    Value<BigInt>? updatedAtUs,
    Value<int>? rowid,
  }) {
    return PlaylistEntriesCompanion(
      playlistId: playlistId ?? this.playlistId,
      itemId: itemId ?? this.itemId,
      position: position ?? this.position,
      sortKeyUs: sortKeyUs ?? this.sortKeyUs,
      updatedAtUs: updatedAtUs ?? this.updatedAtUs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (sortKeyUs.present) {
      map['sort_key_us'] = Variable<BigInt>(sortKeyUs.value);
    }
    if (updatedAtUs.present) {
      map['updated_at_us'] = Variable<BigInt>(updatedAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEntriesCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position, ')
          ..write('sortKeyUs: $sortKeyUs, ')
          ..write('updatedAtUs: $updatedAtUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PublishersTable publishers = $PublishersTable(this);
  late final $ChannelsTable channels = $ChannelsTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $PlaylistEntriesTable playlistEntries = $PlaylistEntriesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    publishers,
    channels,
    playlists,
    items,
    playlistEntries,
  ];
}

typedef $$PublishersTableCreateCompanionBuilder =
    PublishersCompanion Function({
      Value<int> id,
      required String title,
      required BigInt createdAtUs,
      required BigInt updatedAtUs,
    });
typedef $$PublishersTableUpdateCompanionBuilder =
    PublishersCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<BigInt> createdAtUs,
      Value<BigInt> updatedAtUs,
    });

final class $$PublishersTableReferences
    extends BaseReferences<_$AppDatabase, $PublishersTable, PublisherData> {
  $$PublishersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ChannelsTable, List<ChannelData>>
  _channelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.channels,
    aliasName: $_aliasNameGenerator(db.publishers.id, db.channels.publisherId),
  );

  $$ChannelsTableProcessedTableManager get channelsRefs {
    final manager = $$ChannelsTableTableManager(
      $_db,
      $_db.channels,
    ).filter((f) => f.publisherId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_channelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PublishersTableFilterComposer
    extends Composer<_$AppDatabase, $PublishersTable> {
  $$PublishersTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> channelsRefs(
    Expression<bool> Function($$ChannelsTableFilterComposer f) f,
  ) {
    final $$ChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.publisherId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableFilterComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PublishersTableOrderingComposer
    extends Composer<_$AppDatabase, $PublishersTable> {
  $$PublishersTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PublishersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PublishersTable> {
  $$PublishersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<BigInt> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => column,
  );

  Expression<T> channelsRefs<T extends Object>(
    Expression<T> Function($$ChannelsTableAnnotationComposer a) f,
  ) {
    final $$ChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.publisherId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PublishersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PublishersTable,
          PublisherData,
          $$PublishersTableFilterComposer,
          $$PublishersTableOrderingComposer,
          $$PublishersTableAnnotationComposer,
          $$PublishersTableCreateCompanionBuilder,
          $$PublishersTableUpdateCompanionBuilder,
          (PublisherData, $$PublishersTableReferences),
          PublisherData,
          PrefetchHooks Function({bool channelsRefs})
        > {
  $$PublishersTableTableManager(_$AppDatabase db, $PublishersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PublishersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PublishersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PublishersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<BigInt> createdAtUs = const Value.absent(),
                Value<BigInt> updatedAtUs = const Value.absent(),
              }) => PublishersCompanion(
                id: id,
                title: title,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required BigInt createdAtUs,
                required BigInt updatedAtUs,
              }) => PublishersCompanion.insert(
                id: id,
                title: title,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PublishersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({channelsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (channelsRefs) db.channels],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (channelsRefs)
                    await $_getPrefetchedData<
                      PublisherData,
                      $PublishersTable,
                      ChannelData
                    >(
                      currentTable: table,
                      referencedTable: $$PublishersTableReferences
                          ._channelsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PublishersTableReferences(
                            db,
                            table,
                            p0,
                          ).channelsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.publisherId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PublishersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PublishersTable,
      PublisherData,
      $$PublishersTableFilterComposer,
      $$PublishersTableOrderingComposer,
      $$PublishersTableAnnotationComposer,
      $$PublishersTableCreateCompanionBuilder,
      $$PublishersTableUpdateCompanionBuilder,
      (PublisherData, $$PublishersTableReferences),
      PublisherData,
      PrefetchHooks Function({bool channelsRefs})
    >;
typedef $$ChannelsTableCreateCompanionBuilder =
    ChannelsCompanion Function({
      required String id,
      required int type,
      Value<String?> baseUrl,
      Value<String?> slug,
      Value<int?> publisherId,
      required String title,
      Value<String?> curator,
      Value<String?> summary,
      Value<String?> coverImageUri,
      required BigInt createdAtUs,
      required BigInt updatedAtUs,
      Value<int?> sortOrder,
      Value<int> rowid,
    });
typedef $$ChannelsTableUpdateCompanionBuilder =
    ChannelsCompanion Function({
      Value<String> id,
      Value<int> type,
      Value<String?> baseUrl,
      Value<String?> slug,
      Value<int?> publisherId,
      Value<String> title,
      Value<String?> curator,
      Value<String?> summary,
      Value<String?> coverImageUri,
      Value<BigInt> createdAtUs,
      Value<BigInt> updatedAtUs,
      Value<int?> sortOrder,
      Value<int> rowid,
    });

final class $$ChannelsTableReferences
    extends BaseReferences<_$AppDatabase, $ChannelsTable, ChannelData> {
  $$ChannelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PublishersTable _publisherIdTable(_$AppDatabase db) =>
      db.publishers.createAlias(
        $_aliasNameGenerator(db.channels.publisherId, db.publishers.id),
      );

  $$PublishersTableProcessedTableManager? get publisherId {
    final $_column = $_itemColumn<int>('publisher_id');
    if ($_column == null) return null;
    final manager = $$PublishersTableTableManager(
      $_db,
      $_db.publishers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_publisherIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableFilterComposer({
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

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curator => $composableBuilder(
    column: $table.curator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImageUri => $composableBuilder(
    column: $table.coverImageUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$PublishersTableFilterComposer get publisherId {
    final $$PublishersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publisherId,
      referencedTable: $db.publishers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PublishersTableFilterComposer(
            $db: $db,
            $table: $db.publishers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableOrderingComposer({
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

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curator => $composableBuilder(
    column: $table.curator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImageUri => $composableBuilder(
    column: $table.coverImageUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$PublishersTableOrderingComposer get publisherId {
    final $$PublishersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publisherId,
      referencedTable: $db.publishers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PublishersTableOrderingComposer(
            $db: $db,
            $table: $db.publishers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get curator =>
      $composableBuilder(column: $table.curator, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get coverImageUri => $composableBuilder(
    column: $table.coverImageUri,
    builder: (column) => column,
  );

  GeneratedColumn<BigInt> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$PublishersTableAnnotationComposer get publisherId {
    final $$PublishersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.publisherId,
      referencedTable: $db.publishers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PublishersTableAnnotationComposer(
            $db: $db,
            $table: $db.publishers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChannelsTable,
          ChannelData,
          $$ChannelsTableFilterComposer,
          $$ChannelsTableOrderingComposer,
          $$ChannelsTableAnnotationComposer,
          $$ChannelsTableCreateCompanionBuilder,
          $$ChannelsTableUpdateCompanionBuilder,
          (ChannelData, $$ChannelsTableReferences),
          ChannelData,
          PrefetchHooks Function({bool publisherId})
        > {
  $$ChannelsTableTableManager(_$AppDatabase db, $ChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String?> baseUrl = const Value.absent(),
                Value<String?> slug = const Value.absent(),
                Value<int?> publisherId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> curator = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> coverImageUri = const Value.absent(),
                Value<BigInt> createdAtUs = const Value.absent(),
                Value<BigInt> updatedAtUs = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChannelsCompanion(
                id: id,
                type: type,
                baseUrl: baseUrl,
                slug: slug,
                publisherId: publisherId,
                title: title,
                curator: curator,
                summary: summary,
                coverImageUri: coverImageUri,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int type,
                Value<String?> baseUrl = const Value.absent(),
                Value<String?> slug = const Value.absent(),
                Value<int?> publisherId = const Value.absent(),
                required String title,
                Value<String?> curator = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> coverImageUri = const Value.absent(),
                required BigInt createdAtUs,
                required BigInt updatedAtUs,
                Value<int?> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChannelsCompanion.insert(
                id: id,
                type: type,
                baseUrl: baseUrl,
                slug: slug,
                publisherId: publisherId,
                title: title,
                curator: curator,
                summary: summary,
                coverImageUri: coverImageUri,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChannelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({publisherId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (publisherId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.publisherId,
                                referencedTable: $$ChannelsTableReferences
                                    ._publisherIdTable(db),
                                referencedColumn: $$ChannelsTableReferences
                                    ._publisherIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChannelsTable,
      ChannelData,
      $$ChannelsTableFilterComposer,
      $$ChannelsTableOrderingComposer,
      $$ChannelsTableAnnotationComposer,
      $$ChannelsTableCreateCompanionBuilder,
      $$ChannelsTableUpdateCompanionBuilder,
      (ChannelData, $$ChannelsTableReferences),
      ChannelData,
      PrefetchHooks Function({bool publisherId})
    >;
typedef $$PlaylistsTableCreateCompanionBuilder =
    PlaylistsCompanion Function({
      required String id,
      Value<String?> channelId,
      required int type,
      Value<String?> baseUrl,
      Value<String?> dpVersion,
      Value<String?> slug,
      required String title,
      required BigInt createdAtUs,
      required BigInt updatedAtUs,
      required String signaturesJson,
      Value<String?> defaultsJson,
      Value<String?> dynamicQueriesJson,
      Value<String?> ownerAddress,
      Value<String?> ownerChain,
      required int sortMode,
      Value<int> itemCount,
      Value<int> rowid,
    });
typedef $$PlaylistsTableUpdateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<String> id,
      Value<String?> channelId,
      Value<int> type,
      Value<String?> baseUrl,
      Value<String?> dpVersion,
      Value<String?> slug,
      Value<String> title,
      Value<BigInt> createdAtUs,
      Value<BigInt> updatedAtUs,
      Value<String> signaturesJson,
      Value<String?> defaultsJson,
      Value<String?> dynamicQueriesJson,
      Value<String?> ownerAddress,
      Value<String?> ownerChain,
      Value<int> sortMode,
      Value<int> itemCount,
      Value<int> rowid,
    });

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
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

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dpVersion => $composableBuilder(
    column: $table.dpVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signaturesJson => $composableBuilder(
    column: $table.signaturesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultsJson => $composableBuilder(
    column: $table.defaultsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dynamicQueriesJson => $composableBuilder(
    column: $table.dynamicQueriesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerAddress => $composableBuilder(
    column: $table.ownerAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerChain => $composableBuilder(
    column: $table.ownerChain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortMode => $composableBuilder(
    column: $table.sortMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
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

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dpVersion => $composableBuilder(
    column: $table.dpVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signaturesJson => $composableBuilder(
    column: $table.signaturesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultsJson => $composableBuilder(
    column: $table.defaultsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dynamicQueriesJson => $composableBuilder(
    column: $table.dynamicQueriesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerAddress => $composableBuilder(
    column: $table.ownerAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerChain => $composableBuilder(
    column: $table.ownerChain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortMode => $composableBuilder(
    column: $table.sortMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get dpVersion =>
      $composableBuilder(column: $table.dpVersion, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<BigInt> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signaturesJson => $composableBuilder(
    column: $table.signaturesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultsJson => $composableBuilder(
    column: $table.defaultsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dynamicQueriesJson => $composableBuilder(
    column: $table.dynamicQueriesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerAddress => $composableBuilder(
    column: $table.ownerAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerChain => $composableBuilder(
    column: $table.ownerChain,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortMode =>
      $composableBuilder(column: $table.sortMode, builder: (column) => column);

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTable,
          PlaylistData,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (
            PlaylistData,
            BaseReferences<_$AppDatabase, $PlaylistsTable, PlaylistData>,
          ),
          PlaylistData,
          PrefetchHooks Function()
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> channelId = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String?> baseUrl = const Value.absent(),
                Value<String?> dpVersion = const Value.absent(),
                Value<String?> slug = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<BigInt> createdAtUs = const Value.absent(),
                Value<BigInt> updatedAtUs = const Value.absent(),
                Value<String> signaturesJson = const Value.absent(),
                Value<String?> defaultsJson = const Value.absent(),
                Value<String?> dynamicQueriesJson = const Value.absent(),
                Value<String?> ownerAddress = const Value.absent(),
                Value<String?> ownerChain = const Value.absent(),
                Value<int> sortMode = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                channelId: channelId,
                type: type,
                baseUrl: baseUrl,
                dpVersion: dpVersion,
                slug: slug,
                title: title,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
                signaturesJson: signaturesJson,
                defaultsJson: defaultsJson,
                dynamicQueriesJson: dynamicQueriesJson,
                ownerAddress: ownerAddress,
                ownerChain: ownerChain,
                sortMode: sortMode,
                itemCount: itemCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> channelId = const Value.absent(),
                required int type,
                Value<String?> baseUrl = const Value.absent(),
                Value<String?> dpVersion = const Value.absent(),
                Value<String?> slug = const Value.absent(),
                required String title,
                required BigInt createdAtUs,
                required BigInt updatedAtUs,
                required String signaturesJson,
                Value<String?> defaultsJson = const Value.absent(),
                Value<String?> dynamicQueriesJson = const Value.absent(),
                Value<String?> ownerAddress = const Value.absent(),
                Value<String?> ownerChain = const Value.absent(),
                required int sortMode,
                Value<int> itemCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                id: id,
                channelId: channelId,
                type: type,
                baseUrl: baseUrl,
                dpVersion: dpVersion,
                slug: slug,
                title: title,
                createdAtUs: createdAtUs,
                updatedAtUs: updatedAtUs,
                signaturesJson: signaturesJson,
                defaultsJson: defaultsJson,
                dynamicQueriesJson: dynamicQueriesJson,
                ownerAddress: ownerAddress,
                ownerChain: ownerChain,
                sortMode: sortMode,
                itemCount: itemCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTable,
      PlaylistData,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (
        PlaylistData,
        BaseReferences<_$AppDatabase, $PlaylistsTable, PlaylistData>,
      ),
      PlaylistData,
      PrefetchHooks Function()
    >;
typedef $$ItemsTableCreateCompanionBuilder =
    ItemsCompanion Function({
      required String id,
      required int kind,
      Value<String?> title,
      Value<String?> subtitle,
      Value<String?> thumbnailUri,
      Value<int?> durationSec,
      Value<String?> provenanceJson,
      Value<String?> sourceUri,
      Value<String?> refUri,
      Value<String?> license,
      Value<String?> reproJson,
      Value<String?> overrideJson,
      Value<String?> displayJson,
      Value<String?> tokenDataJson,
      Value<String?> listArtistJson,
      Value<int> enrichmentStatus,
      required BigInt updatedAtUs,
      Value<int> rowid,
    });
typedef $$ItemsTableUpdateCompanionBuilder =
    ItemsCompanion Function({
      Value<String> id,
      Value<int> kind,
      Value<String?> title,
      Value<String?> subtitle,
      Value<String?> thumbnailUri,
      Value<int?> durationSec,
      Value<String?> provenanceJson,
      Value<String?> sourceUri,
      Value<String?> refUri,
      Value<String?> license,
      Value<String?> reproJson,
      Value<String?> overrideJson,
      Value<String?> displayJson,
      Value<String?> tokenDataJson,
      Value<String?> listArtistJson,
      Value<int> enrichmentStatus,
      Value<BigInt> updatedAtUs,
      Value<int> rowid,
    });

class $$ItemsTableFilterComposer extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
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

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUri => $composableBuilder(
    column: $table.thumbnailUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provenanceJson => $composableBuilder(
    column: $table.provenanceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUri => $composableBuilder(
    column: $table.sourceUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refUri => $composableBuilder(
    column: $table.refUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reproJson => $composableBuilder(
    column: $table.reproJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overrideJson => $composableBuilder(
    column: $table.overrideJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayJson => $composableBuilder(
    column: $table.displayJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tokenDataJson => $composableBuilder(
    column: $table.tokenDataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listArtistJson => $composableBuilder(
    column: $table.listArtistJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enrichmentStatus => $composableBuilder(
    column: $table.enrichmentStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
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

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUri => $composableBuilder(
    column: $table.thumbnailUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provenanceJson => $composableBuilder(
    column: $table.provenanceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUri => $composableBuilder(
    column: $table.sourceUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refUri => $composableBuilder(
    column: $table.refUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reproJson => $composableBuilder(
    column: $table.reproJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overrideJson => $composableBuilder(
    column: $table.overrideJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayJson => $composableBuilder(
    column: $table.displayJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokenDataJson => $composableBuilder(
    column: $table.tokenDataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listArtistJson => $composableBuilder(
    column: $table.listArtistJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enrichmentStatus => $composableBuilder(
    column: $table.enrichmentStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUri => $composableBuilder(
    column: $table.thumbnailUri,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get provenanceJson => $composableBuilder(
    column: $table.provenanceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUri =>
      $composableBuilder(column: $table.sourceUri, builder: (column) => column);

  GeneratedColumn<String> get refUri =>
      $composableBuilder(column: $table.refUri, builder: (column) => column);

  GeneratedColumn<String> get license =>
      $composableBuilder(column: $table.license, builder: (column) => column);

  GeneratedColumn<String> get reproJson =>
      $composableBuilder(column: $table.reproJson, builder: (column) => column);

  GeneratedColumn<String> get overrideJson => $composableBuilder(
    column: $table.overrideJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayJson => $composableBuilder(
    column: $table.displayJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tokenDataJson => $composableBuilder(
    column: $table.tokenDataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get listArtistJson => $composableBuilder(
    column: $table.listArtistJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get enrichmentStatus => $composableBuilder(
    column: $table.enrichmentStatus,
    builder: (column) => column,
  );

  GeneratedColumn<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => column,
  );
}

class $$ItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemsTable,
          ItemData,
          $$ItemsTableFilterComposer,
          $$ItemsTableOrderingComposer,
          $$ItemsTableAnnotationComposer,
          $$ItemsTableCreateCompanionBuilder,
          $$ItemsTableUpdateCompanionBuilder,
          (ItemData, BaseReferences<_$AppDatabase, $ItemsTable, ItemData>),
          ItemData,
          PrefetchHooks Function()
        > {
  $$ItemsTableTableManager(_$AppDatabase db, $ItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> subtitle = const Value.absent(),
                Value<String?> thumbnailUri = const Value.absent(),
                Value<int?> durationSec = const Value.absent(),
                Value<String?> provenanceJson = const Value.absent(),
                Value<String?> sourceUri = const Value.absent(),
                Value<String?> refUri = const Value.absent(),
                Value<String?> license = const Value.absent(),
                Value<String?> reproJson = const Value.absent(),
                Value<String?> overrideJson = const Value.absent(),
                Value<String?> displayJson = const Value.absent(),
                Value<String?> tokenDataJson = const Value.absent(),
                Value<String?> listArtistJson = const Value.absent(),
                Value<int> enrichmentStatus = const Value.absent(),
                Value<BigInt> updatedAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion(
                id: id,
                kind: kind,
                title: title,
                subtitle: subtitle,
                thumbnailUri: thumbnailUri,
                durationSec: durationSec,
                provenanceJson: provenanceJson,
                sourceUri: sourceUri,
                refUri: refUri,
                license: license,
                reproJson: reproJson,
                overrideJson: overrideJson,
                displayJson: displayJson,
                tokenDataJson: tokenDataJson,
                listArtistJson: listArtistJson,
                enrichmentStatus: enrichmentStatus,
                updatedAtUs: updatedAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int kind,
                Value<String?> title = const Value.absent(),
                Value<String?> subtitle = const Value.absent(),
                Value<String?> thumbnailUri = const Value.absent(),
                Value<int?> durationSec = const Value.absent(),
                Value<String?> provenanceJson = const Value.absent(),
                Value<String?> sourceUri = const Value.absent(),
                Value<String?> refUri = const Value.absent(),
                Value<String?> license = const Value.absent(),
                Value<String?> reproJson = const Value.absent(),
                Value<String?> overrideJson = const Value.absent(),
                Value<String?> displayJson = const Value.absent(),
                Value<String?> tokenDataJson = const Value.absent(),
                Value<String?> listArtistJson = const Value.absent(),
                Value<int> enrichmentStatus = const Value.absent(),
                required BigInt updatedAtUs,
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion.insert(
                id: id,
                kind: kind,
                title: title,
                subtitle: subtitle,
                thumbnailUri: thumbnailUri,
                durationSec: durationSec,
                provenanceJson: provenanceJson,
                sourceUri: sourceUri,
                refUri: refUri,
                license: license,
                reproJson: reproJson,
                overrideJson: overrideJson,
                displayJson: displayJson,
                tokenDataJson: tokenDataJson,
                listArtistJson: listArtistJson,
                enrichmentStatus: enrichmentStatus,
                updatedAtUs: updatedAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemsTable,
      ItemData,
      $$ItemsTableFilterComposer,
      $$ItemsTableOrderingComposer,
      $$ItemsTableAnnotationComposer,
      $$ItemsTableCreateCompanionBuilder,
      $$ItemsTableUpdateCompanionBuilder,
      (ItemData, BaseReferences<_$AppDatabase, $ItemsTable, ItemData>),
      ItemData,
      PrefetchHooks Function()
    >;
typedef $$PlaylistEntriesTableCreateCompanionBuilder =
    PlaylistEntriesCompanion Function({
      required String playlistId,
      required String itemId,
      Value<int?> position,
      required BigInt sortKeyUs,
      required BigInt updatedAtUs,
      Value<int> rowid,
    });
typedef $$PlaylistEntriesTableUpdateCompanionBuilder =
    PlaylistEntriesCompanion Function({
      Value<String> playlistId,
      Value<String> itemId,
      Value<int?> position,
      Value<BigInt> sortKeyUs,
      Value<BigInt> updatedAtUs,
      Value<int> rowid,
    });

class $$PlaylistEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get sortKeyUs => $composableBuilder(
    column: $table.sortKeyUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaylistEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get sortKeyUs => $composableBuilder(
    column: $table.sortKeyUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<BigInt> get sortKeyUs =>
      $composableBuilder(column: $table.sortKeyUs, builder: (column) => column);

  GeneratedColumn<BigInt> get updatedAtUs => $composableBuilder(
    column: $table.updatedAtUs,
    builder: (column) => column,
  );
}

class $$PlaylistEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistEntriesTable,
          PlaylistEntryData,
          $$PlaylistEntriesTableFilterComposer,
          $$PlaylistEntriesTableOrderingComposer,
          $$PlaylistEntriesTableAnnotationComposer,
          $$PlaylistEntriesTableCreateCompanionBuilder,
          $$PlaylistEntriesTableUpdateCompanionBuilder,
          (
            PlaylistEntryData,
            BaseReferences<
              _$AppDatabase,
              $PlaylistEntriesTable,
              PlaylistEntryData
            >,
          ),
          PlaylistEntryData,
          PrefetchHooks Function()
        > {
  $$PlaylistEntriesTableTableManager(
    _$AppDatabase db,
    $PlaylistEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playlistId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int?> position = const Value.absent(),
                Value<BigInt> sortKeyUs = const Value.absent(),
                Value<BigInt> updatedAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistEntriesCompanion(
                playlistId: playlistId,
                itemId: itemId,
                position: position,
                sortKeyUs: sortKeyUs,
                updatedAtUs: updatedAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playlistId,
                required String itemId,
                Value<int?> position = const Value.absent(),
                required BigInt sortKeyUs,
                required BigInt updatedAtUs,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistEntriesCompanion.insert(
                playlistId: playlistId,
                itemId: itemId,
                position: position,
                sortKeyUs: sortKeyUs,
                updatedAtUs: updatedAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaylistEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistEntriesTable,
      PlaylistEntryData,
      $$PlaylistEntriesTableFilterComposer,
      $$PlaylistEntriesTableOrderingComposer,
      $$PlaylistEntriesTableAnnotationComposer,
      $$PlaylistEntriesTableCreateCompanionBuilder,
      $$PlaylistEntriesTableUpdateCompanionBuilder,
      (
        PlaylistEntryData,
        BaseReferences<_$AppDatabase, $PlaylistEntriesTable, PlaylistEntryData>,
      ),
      PlaylistEntryData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PublishersTableTableManager get publishers =>
      $$PublishersTableTableManager(_db, _db.publishers);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db, _db.channels);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$PlaylistEntriesTableTableManager get playlistEntries =>
      $$PlaylistEntriesTableTableManager(_db, _db.playlistEntries);
}
