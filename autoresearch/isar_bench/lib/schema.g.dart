// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarChannelCollection on Isar {
  IsarCollection<IsarChannel> get isarChannels => this.collection();
}

const IsarChannelSchema = CollectionSchema(
  name: r'IsarChannel',
  id: 6559311121825661033,
  properties: {
    r'channelId': PropertySchema(
      id: 0,
      name: r'channelId',
      type: IsarType.string,
    ),
    r'createdAtUs': PropertySchema(
      id: 1,
      name: r'createdAtUs',
      type: IsarType.long,
    ),
    r'dataJson': PropertySchema(
      id: 2,
      name: r'dataJson',
      type: IsarType.string,
    ),
    r'publisherOrder': PropertySchema(
      id: 3,
      name: r'publisherOrder',
      type: IsarType.long,
    ),
    r'sortOrderNorm': PropertySchema(
      id: 4,
      name: r'sortOrderNorm',
      type: IsarType.long,
    ),
    r'title': PropertySchema(
      id: 5,
      name: r'title',
      type: IsarType.string,
    ),
    r'titleWords': PropertySchema(
      id: 6,
      name: r'titleWords',
      type: IsarType.stringList,
    ),
    r'type': PropertySchema(
      id: 7,
      name: r'type',
      type: IsarType.long,
    )
  },
  estimateSize: _isarChannelEstimateSize,
  serialize: _isarChannelSerialize,
  deserialize: _isarChannelDeserialize,
  deserializeProp: _isarChannelDeserializeProp,
  idName: r'id',
  indexes: {
    r'channelId': IndexSchema(
      id: -8352446570702114471,
      name: r'channelId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'channelId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'publisherOrder': IndexSchema(
      id: -7202460343303205451,
      name: r'publisherOrder',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'publisherOrder',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'titleWords': IndexSchema(
      id: 80481505061976672,
      name: r'titleWords',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'titleWords',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _isarChannelGetId,
  getLinks: _isarChannelGetLinks,
  attach: _isarChannelAttach,
  version: '3.1.0+1',
);

int _isarChannelEstimateSize(
  IsarChannel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.channelId.length * 3;
  bytesCount += 3 + object.dataJson.length * 3;
  bytesCount += 3 + object.title.length * 3;
  bytesCount += 3 + object.titleWords.length * 3;
  {
    for (var i = 0; i < object.titleWords.length; i++) {
      final value = object.titleWords[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _isarChannelSerialize(
  IsarChannel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.channelId);
  writer.writeLong(offsets[1], object.createdAtUs);
  writer.writeString(offsets[2], object.dataJson);
  writer.writeLong(offsets[3], object.publisherOrder);
  writer.writeLong(offsets[4], object.sortOrderNorm);
  writer.writeString(offsets[5], object.title);
  writer.writeStringList(offsets[6], object.titleWords);
  writer.writeLong(offsets[7], object.type);
}

IsarChannel _isarChannelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarChannel();
  object.channelId = reader.readString(offsets[0]);
  object.createdAtUs = reader.readLongOrNull(offsets[1]);
  object.dataJson = reader.readString(offsets[2]);
  object.id = id;
  object.publisherOrder = reader.readLong(offsets[3]);
  object.sortOrderNorm = reader.readLong(offsets[4]);
  object.title = reader.readString(offsets[5]);
  object.type = reader.readLong(offsets[7]);
  return object;
}

P _isarChannelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readStringList(offset) ?? []) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _isarChannelGetId(IsarChannel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _isarChannelGetLinks(IsarChannel object) {
  return [];
}

void _isarChannelAttach(
    IsarCollection<dynamic> col, Id id, IsarChannel object) {
  object.id = id;
}

extension IsarChannelByIndex on IsarCollection<IsarChannel> {
  Future<IsarChannel?> getByChannelId(String channelId) {
    return getByIndex(r'channelId', [channelId]);
  }

  IsarChannel? getByChannelIdSync(String channelId) {
    return getByIndexSync(r'channelId', [channelId]);
  }

  Future<bool> deleteByChannelId(String channelId) {
    return deleteByIndex(r'channelId', [channelId]);
  }

  bool deleteByChannelIdSync(String channelId) {
    return deleteByIndexSync(r'channelId', [channelId]);
  }

  Future<List<IsarChannel?>> getAllByChannelId(List<String> channelIdValues) {
    final values = channelIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'channelId', values);
  }

  List<IsarChannel?> getAllByChannelIdSync(List<String> channelIdValues) {
    final values = channelIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'channelId', values);
  }

  Future<int> deleteAllByChannelId(List<String> channelIdValues) {
    final values = channelIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'channelId', values);
  }

  int deleteAllByChannelIdSync(List<String> channelIdValues) {
    final values = channelIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'channelId', values);
  }

  Future<Id> putByChannelId(IsarChannel object) {
    return putByIndex(r'channelId', object);
  }

  Id putByChannelIdSync(IsarChannel object, {bool saveLinks = true}) {
    return putByIndexSync(r'channelId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByChannelId(List<IsarChannel> objects) {
    return putAllByIndex(r'channelId', objects);
  }

  List<Id> putAllByChannelIdSync(List<IsarChannel> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'channelId', objects, saveLinks: saveLinks);
  }
}

extension IsarChannelQueryWhereSort
    on QueryBuilder<IsarChannel, IsarChannel, QWhere> {
  QueryBuilder<IsarChannel, IsarChannel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhere> anyPublisherOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'publisherOrder'),
      );
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhere> anyTitleWordsElement() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'titleWords'),
      );
    });
  }
}

extension IsarChannelQueryWhere
    on QueryBuilder<IsarChannel, IsarChannel, QWhereClause> {
  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause> channelIdEqualTo(
      String channelId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'channelId',
        value: [channelId],
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause> channelIdNotEqualTo(
      String channelId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'channelId',
              lower: [],
              upper: [channelId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'channelId',
              lower: [channelId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'channelId',
              lower: [channelId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'channelId',
              lower: [],
              upper: [channelId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause>
      publisherOrderEqualTo(int publisherOrder) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'publisherOrder',
        value: [publisherOrder],
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause>
      publisherOrderNotEqualTo(int publisherOrder) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'publisherOrder',
              lower: [],
              upper: [publisherOrder],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'publisherOrder',
              lower: [publisherOrder],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'publisherOrder',
              lower: [publisherOrder],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'publisherOrder',
              lower: [],
              upper: [publisherOrder],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause>
      publisherOrderGreaterThan(
    int publisherOrder, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'publisherOrder',
        lower: [publisherOrder],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause>
      publisherOrderLessThan(
    int publisherOrder, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'publisherOrder',
        lower: [],
        upper: [publisherOrder],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause>
      publisherOrderBetween(
    int lowerPublisherOrder,
    int upperPublisherOrder, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'publisherOrder',
        lower: [lowerPublisherOrder],
        includeLower: includeLower,
        upper: [upperPublisherOrder],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause>
      titleWordsElementEqualTo(String titleWordsElement) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'titleWords',
        value: [titleWordsElement],
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause>
      titleWordsElementNotEqualTo(String titleWordsElement) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleWords',
              lower: [],
              upper: [titleWordsElement],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleWords',
              lower: [titleWordsElement],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleWords',
              lower: [titleWordsElement],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleWords',
              lower: [],
              upper: [titleWordsElement],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause>
      titleWordsElementGreaterThan(
    String titleWordsElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleWords',
        lower: [titleWordsElement],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause>
      titleWordsElementLessThan(
    String titleWordsElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleWords',
        lower: [],
        upper: [titleWordsElement],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause>
      titleWordsElementBetween(
    String lowerTitleWordsElement,
    String upperTitleWordsElement, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleWords',
        lower: [lowerTitleWordsElement],
        includeLower: includeLower,
        upper: [upperTitleWordsElement],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause>
      titleWordsElementStartsWith(String TitleWordsElementPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleWords',
        lower: [TitleWordsElementPrefix],
        upper: ['$TitleWordsElementPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause>
      titleWordsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'titleWords',
        value: [''],
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterWhereClause>
      titleWordsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'titleWords',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'titleWords',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'titleWords',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'titleWords',
              upper: [''],
            ));
      }
    });
  }
}

extension IsarChannelQueryFilter
    on QueryBuilder<IsarChannel, IsarChannel, QFilterCondition> {
  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      channelIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'channelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      channelIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'channelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      channelIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'channelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      channelIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'channelId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      channelIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'channelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      channelIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'channelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      channelIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'channelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      channelIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'channelId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      channelIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'channelId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      channelIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'channelId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      createdAtUsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdAtUs',
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      createdAtUsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdAtUs',
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      createdAtUsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAtUs',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      createdAtUsGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAtUs',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      createdAtUsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAtUs',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      createdAtUsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAtUs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> dataJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      dataJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      dataJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> dataJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dataJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      dataJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      dataJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      dataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> dataJsonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'dataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      dataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      dataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'dataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      publisherOrderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publisherOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      publisherOrderGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'publisherOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      publisherOrderLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'publisherOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      publisherOrderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'publisherOrder',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      sortOrderNormEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sortOrderNorm',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      sortOrderNormGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sortOrderNorm',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      sortOrderNormLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sortOrderNorm',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      sortOrderNormBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sortOrderNorm',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> titleContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> titleMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'titleWords',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'titleWords',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'titleWords',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'titleWords',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition>
      titleWordsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> typeEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> typeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> typeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterFilterCondition> typeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'type',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension IsarChannelQueryObject
    on QueryBuilder<IsarChannel, IsarChannel, QFilterCondition> {}

extension IsarChannelQueryLinks
    on QueryBuilder<IsarChannel, IsarChannel, QFilterCondition> {}

extension IsarChannelQuerySortBy
    on QueryBuilder<IsarChannel, IsarChannel, QSortBy> {
  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> sortByChannelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> sortByChannelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.desc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> sortByCreatedAtUs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtUs', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> sortByCreatedAtUsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtUs', Sort.desc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> sortByDataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> sortByDataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.desc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> sortByPublisherOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisherOrder', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy>
      sortByPublisherOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisherOrder', Sort.desc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> sortBySortOrderNorm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrderNorm', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy>
      sortBySortOrderNormDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrderNorm', Sort.desc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension IsarChannelQuerySortThenBy
    on QueryBuilder<IsarChannel, IsarChannel, QSortThenBy> {
  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenByChannelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenByChannelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.desc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenByCreatedAtUs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtUs', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenByCreatedAtUsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtUs', Sort.desc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenByDataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenByDataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.desc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenByPublisherOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisherOrder', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy>
      thenByPublisherOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisherOrder', Sort.desc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenBySortOrderNorm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrderNorm', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy>
      thenBySortOrderNormDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrderNorm', Sort.desc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension IsarChannelQueryWhereDistinct
    on QueryBuilder<IsarChannel, IsarChannel, QDistinct> {
  QueryBuilder<IsarChannel, IsarChannel, QDistinct> distinctByChannelId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'channelId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QDistinct> distinctByCreatedAtUs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAtUs');
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QDistinct> distinctByDataJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QDistinct> distinctByPublisherOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'publisherOrder');
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QDistinct> distinctBySortOrderNorm() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sortOrderNorm');
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QDistinct> distinctByTitleWords() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'titleWords');
    });
  }

  QueryBuilder<IsarChannel, IsarChannel, QDistinct> distinctByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type');
    });
  }
}

extension IsarChannelQueryProperty
    on QueryBuilder<IsarChannel, IsarChannel, QQueryProperty> {
  QueryBuilder<IsarChannel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarChannel, String, QQueryOperations> channelIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'channelId');
    });
  }

  QueryBuilder<IsarChannel, int?, QQueryOperations> createdAtUsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAtUs');
    });
  }

  QueryBuilder<IsarChannel, String, QQueryOperations> dataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dataJson');
    });
  }

  QueryBuilder<IsarChannel, int, QQueryOperations> publisherOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'publisherOrder');
    });
  }

  QueryBuilder<IsarChannel, int, QQueryOperations> sortOrderNormProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sortOrderNorm');
    });
  }

  QueryBuilder<IsarChannel, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<IsarChannel, List<String>, QQueryOperations>
      titleWordsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'titleWords');
    });
  }

  QueryBuilder<IsarChannel, int, QQueryOperations> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarPlaylistCollection on Isar {
  IsarCollection<IsarPlaylist> get isarPlaylists => this.collection();
}

const IsarPlaylistSchema = CollectionSchema(
  name: r'IsarPlaylist',
  id: 596231180705832295,
  properties: {
    r'channelId': PropertySchema(
      id: 0,
      name: r'channelId',
      type: IsarType.string,
    ),
    r'createdAtUs': PropertySchema(
      id: 1,
      name: r'createdAtUs',
      type: IsarType.long,
    ),
    r'dataJson': PropertySchema(
      id: 2,
      name: r'dataJson',
      type: IsarType.string,
    ),
    r'itemCount': PropertySchema(
      id: 3,
      name: r'itemCount',
      type: IsarType.long,
    ),
    r'playlistId': PropertySchema(
      id: 4,
      name: r'playlistId',
      type: IsarType.string,
    ),
    r'publisherOrder': PropertySchema(
      id: 5,
      name: r'publisherOrder',
      type: IsarType.long,
    ),
    r'sortMode': PropertySchema(
      id: 6,
      name: r'sortMode',
      type: IsarType.long,
    ),
    r'title': PropertySchema(
      id: 7,
      name: r'title',
      type: IsarType.string,
    ),
    r'titleWords': PropertySchema(
      id: 8,
      name: r'titleWords',
      type: IsarType.stringList,
    ),
    r'type': PropertySchema(
      id: 9,
      name: r'type',
      type: IsarType.long,
    )
  },
  estimateSize: _isarPlaylistEstimateSize,
  serialize: _isarPlaylistSerialize,
  deserialize: _isarPlaylistDeserialize,
  deserializeProp: _isarPlaylistDeserializeProp,
  idName: r'id',
  indexes: {
    r'playlistId': IndexSchema(
      id: 7921918076105486368,
      name: r'playlistId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'playlistId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'publisherOrder': IndexSchema(
      id: -7202460343303205451,
      name: r'publisherOrder',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'publisherOrder',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'titleWords': IndexSchema(
      id: 80481505061976672,
      name: r'titleWords',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'titleWords',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _isarPlaylistGetId,
  getLinks: _isarPlaylistGetLinks,
  attach: _isarPlaylistAttach,
  version: '3.1.0+1',
);

int _isarPlaylistEstimateSize(
  IsarPlaylist object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.channelId.length * 3;
  bytesCount += 3 + object.dataJson.length * 3;
  bytesCount += 3 + object.playlistId.length * 3;
  bytesCount += 3 + object.title.length * 3;
  bytesCount += 3 + object.titleWords.length * 3;
  {
    for (var i = 0; i < object.titleWords.length; i++) {
      final value = object.titleWords[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _isarPlaylistSerialize(
  IsarPlaylist object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.channelId);
  writer.writeLong(offsets[1], object.createdAtUs);
  writer.writeString(offsets[2], object.dataJson);
  writer.writeLong(offsets[3], object.itemCount);
  writer.writeString(offsets[4], object.playlistId);
  writer.writeLong(offsets[5], object.publisherOrder);
  writer.writeLong(offsets[6], object.sortMode);
  writer.writeString(offsets[7], object.title);
  writer.writeStringList(offsets[8], object.titleWords);
  writer.writeLong(offsets[9], object.type);
}

IsarPlaylist _isarPlaylistDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarPlaylist();
  object.channelId = reader.readString(offsets[0]);
  object.createdAtUs = reader.readLong(offsets[1]);
  object.dataJson = reader.readString(offsets[2]);
  object.id = id;
  object.itemCount = reader.readLong(offsets[3]);
  object.playlistId = reader.readString(offsets[4]);
  object.publisherOrder = reader.readLong(offsets[5]);
  object.sortMode = reader.readLong(offsets[6]);
  object.title = reader.readString(offsets[7]);
  object.type = reader.readLong(offsets[9]);
  return object;
}

P _isarPlaylistDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readStringList(offset) ?? []) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _isarPlaylistGetId(IsarPlaylist object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _isarPlaylistGetLinks(IsarPlaylist object) {
  return [];
}

void _isarPlaylistAttach(
    IsarCollection<dynamic> col, Id id, IsarPlaylist object) {
  object.id = id;
}

extension IsarPlaylistByIndex on IsarCollection<IsarPlaylist> {
  Future<IsarPlaylist?> getByPlaylistId(String playlistId) {
    return getByIndex(r'playlistId', [playlistId]);
  }

  IsarPlaylist? getByPlaylistIdSync(String playlistId) {
    return getByIndexSync(r'playlistId', [playlistId]);
  }

  Future<bool> deleteByPlaylistId(String playlistId) {
    return deleteByIndex(r'playlistId', [playlistId]);
  }

  bool deleteByPlaylistIdSync(String playlistId) {
    return deleteByIndexSync(r'playlistId', [playlistId]);
  }

  Future<List<IsarPlaylist?>> getAllByPlaylistId(
      List<String> playlistIdValues) {
    final values = playlistIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'playlistId', values);
  }

  List<IsarPlaylist?> getAllByPlaylistIdSync(List<String> playlistIdValues) {
    final values = playlistIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'playlistId', values);
  }

  Future<int> deleteAllByPlaylistId(List<String> playlistIdValues) {
    final values = playlistIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'playlistId', values);
  }

  int deleteAllByPlaylistIdSync(List<String> playlistIdValues) {
    final values = playlistIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'playlistId', values);
  }

  Future<Id> putByPlaylistId(IsarPlaylist object) {
    return putByIndex(r'playlistId', object);
  }

  Id putByPlaylistIdSync(IsarPlaylist object, {bool saveLinks = true}) {
    return putByIndexSync(r'playlistId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPlaylistId(List<IsarPlaylist> objects) {
    return putAllByIndex(r'playlistId', objects);
  }

  List<Id> putAllByPlaylistIdSync(List<IsarPlaylist> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'playlistId', objects, saveLinks: saveLinks);
  }
}

extension IsarPlaylistQueryWhereSort
    on QueryBuilder<IsarPlaylist, IsarPlaylist, QWhere> {
  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhere> anyPublisherOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'publisherOrder'),
      );
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhere> anyTitleWordsElement() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'titleWords'),
      );
    });
  }
}

extension IsarPlaylistQueryWhere
    on QueryBuilder<IsarPlaylist, IsarPlaylist, QWhereClause> {
  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause> playlistIdEqualTo(
      String playlistId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'playlistId',
        value: [playlistId],
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      playlistIdNotEqualTo(String playlistId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'playlistId',
              lower: [],
              upper: [playlistId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'playlistId',
              lower: [playlistId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'playlistId',
              lower: [playlistId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'playlistId',
              lower: [],
              upper: [playlistId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      publisherOrderEqualTo(int publisherOrder) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'publisherOrder',
        value: [publisherOrder],
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      publisherOrderNotEqualTo(int publisherOrder) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'publisherOrder',
              lower: [],
              upper: [publisherOrder],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'publisherOrder',
              lower: [publisherOrder],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'publisherOrder',
              lower: [publisherOrder],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'publisherOrder',
              lower: [],
              upper: [publisherOrder],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      publisherOrderGreaterThan(
    int publisherOrder, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'publisherOrder',
        lower: [publisherOrder],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      publisherOrderLessThan(
    int publisherOrder, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'publisherOrder',
        lower: [],
        upper: [publisherOrder],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      publisherOrderBetween(
    int lowerPublisherOrder,
    int upperPublisherOrder, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'publisherOrder',
        lower: [lowerPublisherOrder],
        includeLower: includeLower,
        upper: [upperPublisherOrder],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      titleWordsElementEqualTo(String titleWordsElement) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'titleWords',
        value: [titleWordsElement],
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      titleWordsElementNotEqualTo(String titleWordsElement) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleWords',
              lower: [],
              upper: [titleWordsElement],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleWords',
              lower: [titleWordsElement],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleWords',
              lower: [titleWordsElement],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleWords',
              lower: [],
              upper: [titleWordsElement],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      titleWordsElementGreaterThan(
    String titleWordsElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleWords',
        lower: [titleWordsElement],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      titleWordsElementLessThan(
    String titleWordsElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleWords',
        lower: [],
        upper: [titleWordsElement],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      titleWordsElementBetween(
    String lowerTitleWordsElement,
    String upperTitleWordsElement, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleWords',
        lower: [lowerTitleWordsElement],
        includeLower: includeLower,
        upper: [upperTitleWordsElement],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      titleWordsElementStartsWith(String TitleWordsElementPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleWords',
        lower: [TitleWordsElementPrefix],
        upper: ['$TitleWordsElementPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      titleWordsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'titleWords',
        value: [''],
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterWhereClause>
      titleWordsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'titleWords',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'titleWords',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'titleWords',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'titleWords',
              upper: [''],
            ));
      }
    });
  }
}

extension IsarPlaylistQueryFilter
    on QueryBuilder<IsarPlaylist, IsarPlaylist, QFilterCondition> {
  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      channelIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'channelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      channelIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'channelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      channelIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'channelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      channelIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'channelId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      channelIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'channelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      channelIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'channelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      channelIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'channelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      channelIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'channelId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      channelIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'channelId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      channelIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'channelId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      createdAtUsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAtUs',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      createdAtUsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAtUs',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      createdAtUsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAtUs',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      createdAtUsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAtUs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      dataJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      dataJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      dataJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      dataJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dataJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      dataJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      dataJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      dataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      dataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'dataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      dataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      dataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'dataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      itemCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'itemCount',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      itemCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'itemCount',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      itemCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'itemCount',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      itemCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'itemCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      playlistIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'playlistId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      playlistIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'playlistId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      playlistIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'playlistId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      playlistIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'playlistId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      playlistIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'playlistId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      playlistIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'playlistId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      playlistIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'playlistId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      playlistIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'playlistId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      playlistIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'playlistId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      playlistIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'playlistId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      publisherOrderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publisherOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      publisherOrderGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'publisherOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      publisherOrderLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'publisherOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      publisherOrderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'publisherOrder',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      sortModeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sortMode',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      sortModeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sortMode',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      sortModeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sortMode',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      sortModeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sortMode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition> titleContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition> titleMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'titleWords',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'titleWords',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'titleWords',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'titleWords',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      titleWordsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition> typeEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition>
      typeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition> typeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'type',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterFilterCondition> typeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'type',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension IsarPlaylistQueryObject
    on QueryBuilder<IsarPlaylist, IsarPlaylist, QFilterCondition> {}

extension IsarPlaylistQueryLinks
    on QueryBuilder<IsarPlaylist, IsarPlaylist, QFilterCondition> {}

extension IsarPlaylistQuerySortBy
    on QueryBuilder<IsarPlaylist, IsarPlaylist, QSortBy> {
  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortByChannelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortByChannelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortByCreatedAtUs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtUs', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy>
      sortByCreatedAtUsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtUs', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortByDataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortByDataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortByItemCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemCount', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortByItemCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemCount', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortByPlaylistId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playlistId', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy>
      sortByPlaylistIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playlistId', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy>
      sortByPublisherOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisherOrder', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy>
      sortByPublisherOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisherOrder', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortBySortMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortMode', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortBySortModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortMode', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension IsarPlaylistQuerySortThenBy
    on QueryBuilder<IsarPlaylist, IsarPlaylist, QSortThenBy> {
  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenByChannelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenByChannelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelId', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenByCreatedAtUs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtUs', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy>
      thenByCreatedAtUsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtUs', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenByDataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenByDataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenByItemCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemCount', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenByItemCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemCount', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenByPlaylistId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playlistId', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy>
      thenByPlaylistIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playlistId', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy>
      thenByPublisherOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisherOrder', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy>
      thenByPublisherOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisherOrder', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenBySortMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortMode', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenBySortModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortMode', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension IsarPlaylistQueryWhereDistinct
    on QueryBuilder<IsarPlaylist, IsarPlaylist, QDistinct> {
  QueryBuilder<IsarPlaylist, IsarPlaylist, QDistinct> distinctByChannelId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'channelId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QDistinct> distinctByCreatedAtUs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAtUs');
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QDistinct> distinctByDataJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QDistinct> distinctByItemCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemCount');
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QDistinct> distinctByPlaylistId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'playlistId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QDistinct>
      distinctByPublisherOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'publisherOrder');
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QDistinct> distinctBySortMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sortMode');
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QDistinct> distinctByTitleWords() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'titleWords');
    });
  }

  QueryBuilder<IsarPlaylist, IsarPlaylist, QDistinct> distinctByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type');
    });
  }
}

extension IsarPlaylistQueryProperty
    on QueryBuilder<IsarPlaylist, IsarPlaylist, QQueryProperty> {
  QueryBuilder<IsarPlaylist, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarPlaylist, String, QQueryOperations> channelIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'channelId');
    });
  }

  QueryBuilder<IsarPlaylist, int, QQueryOperations> createdAtUsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAtUs');
    });
  }

  QueryBuilder<IsarPlaylist, String, QQueryOperations> dataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dataJson');
    });
  }

  QueryBuilder<IsarPlaylist, int, QQueryOperations> itemCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemCount');
    });
  }

  QueryBuilder<IsarPlaylist, String, QQueryOperations> playlistIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'playlistId');
    });
  }

  QueryBuilder<IsarPlaylist, int, QQueryOperations> publisherOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'publisherOrder');
    });
  }

  QueryBuilder<IsarPlaylist, int, QQueryOperations> sortModeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sortMode');
    });
  }

  QueryBuilder<IsarPlaylist, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<IsarPlaylist, List<String>, QQueryOperations>
      titleWordsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'titleWords');
    });
  }

  QueryBuilder<IsarPlaylist, int, QQueryOperations> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarWorkCollection on Isar {
  IsarCollection<IsarWork> get isarWorks => this.collection();
}

const IsarWorkSchema = CollectionSchema(
  name: r'IsarWork',
  id: 8690487333005604284,
  properties: {
    r'artistWords': PropertySchema(
      id: 0,
      name: r'artistWords',
      type: IsarType.stringList,
    ),
    r'channelCreatedAtOrder': PropertySchema(
      id: 1,
      name: r'channelCreatedAtOrder',
      type: IsarType.long,
    ),
    r'dataJson': PropertySchema(
      id: 2,
      name: r'dataJson',
      type: IsarType.string,
    ),
    r'durationSec': PropertySchema(
      id: 3,
      name: r'durationSec',
      type: IsarType.long,
    ),
    r'enrichmentStatus': PropertySchema(
      id: 4,
      name: r'enrichmentStatus',
      type: IsarType.long,
    ),
    r'headJson': PropertySchema(
      id: 5,
      name: r'headJson',
      type: IsarType.string,
    ),
    r'kind': PropertySchema(
      id: 6,
      name: r'kind',
      type: IsarType.long,
    ),
    r'listArtistJson': PropertySchema(
      id: 7,
      name: r'listArtistJson',
      type: IsarType.string,
    ),
    r'playlistCreatedAtOrder': PropertySchema(
      id: 8,
      name: r'playlistCreatedAtOrder',
      type: IsarType.long,
    ),
    r'publisherOrder': PropertySchema(
      id: 9,
      name: r'publisherOrder',
      type: IsarType.long,
    ),
    r'subtitle': PropertySchema(
      id: 10,
      name: r'subtitle',
      type: IsarType.string,
    ),
    r'thumbnailUri': PropertySchema(
      id: 11,
      name: r'thumbnailUri',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 12,
      name: r'title',
      type: IsarType.string,
    ),
    r'titleWords': PropertySchema(
      id: 13,
      name: r'titleWords',
      type: IsarType.stringList,
    ),
    r'updatedAtUs': PropertySchema(
      id: 14,
      name: r'updatedAtUs',
      type: IsarType.long,
    ),
    r'workId': PropertySchema(
      id: 15,
      name: r'workId',
      type: IsarType.string,
    )
  },
  estimateSize: _isarWorkEstimateSize,
  serialize: _isarWorkSerialize,
  deserialize: _isarWorkDeserialize,
  deserializeProp: _isarWorkDeserializeProp,
  idName: r'id',
  indexes: {
    r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder': IndexSchema(
      id: 2582793817061389388,
      name: r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'publisherOrder',
          type: IndexType.value,
          caseSensitive: false,
        ),
        IndexPropertySchema(
          name: r'channelCreatedAtOrder',
          type: IndexType.value,
          caseSensitive: false,
        ),
        IndexPropertySchema(
          name: r'playlistCreatedAtOrder',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'titleWords': IndexSchema(
      id: 80481505061976672,
      name: r'titleWords',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'titleWords',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'artistWords': IndexSchema(
      id: -8156117922864765137,
      name: r'artistWords',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'artistWords',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _isarWorkGetId,
  getLinks: _isarWorkGetLinks,
  attach: _isarWorkAttach,
  version: '3.1.0+1',
);

int _isarWorkEstimateSize(
  IsarWork object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.artistWords.length * 3;
  {
    for (var i = 0; i < object.artistWords.length; i++) {
      final value = object.artistWords[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.dataJson.length * 3;
  bytesCount += 3 + object.headJson.length * 3;
  {
    final value = object.listArtistJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.subtitle;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.thumbnailUri;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  bytesCount += 3 + object.titleWords.length * 3;
  {
    for (var i = 0; i < object.titleWords.length; i++) {
      final value = object.titleWords[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.workId.length * 3;
  return bytesCount;
}

void _isarWorkSerialize(
  IsarWork object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeStringList(offsets[0], object.artistWords);
  writer.writeLong(offsets[1], object.channelCreatedAtOrder);
  writer.writeString(offsets[2], object.dataJson);
  writer.writeLong(offsets[3], object.durationSec);
  writer.writeLong(offsets[4], object.enrichmentStatus);
  writer.writeString(offsets[5], object.headJson);
  writer.writeLong(offsets[6], object.kind);
  writer.writeString(offsets[7], object.listArtistJson);
  writer.writeLong(offsets[8], object.playlistCreatedAtOrder);
  writer.writeLong(offsets[9], object.publisherOrder);
  writer.writeString(offsets[10], object.subtitle);
  writer.writeString(offsets[11], object.thumbnailUri);
  writer.writeString(offsets[12], object.title);
  writer.writeStringList(offsets[13], object.titleWords);
  writer.writeLong(offsets[14], object.updatedAtUs);
  writer.writeString(offsets[15], object.workId);
}

IsarWork _isarWorkDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarWork();
  object.channelCreatedAtOrder = reader.readLong(offsets[1]);
  object.dataJson = reader.readString(offsets[2]);
  object.durationSec = reader.readLongOrNull(offsets[3]);
  object.enrichmentStatus = reader.readLongOrNull(offsets[4]);
  object.headJson = reader.readString(offsets[5]);
  object.kind = reader.readLong(offsets[6]);
  object.listArtistJson = reader.readStringOrNull(offsets[7]);
  object.playlistCreatedAtOrder = reader.readLong(offsets[8]);
  object.publisherOrder = reader.readLong(offsets[9]);
  object.subtitle = reader.readStringOrNull(offsets[10]);
  object.thumbnailUri = reader.readStringOrNull(offsets[11]);
  object.title = reader.readString(offsets[12]);
  object.updatedAtUs = reader.readLongOrNull(offsets[14]);
  object.workId = reader.readString(offsets[15]);
  return object;
}

P _isarWorkDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringList(offset) ?? []) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readStringList(offset) ?? []) as P;
    case 14:
      return (reader.readLongOrNull(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _isarWorkGetId(IsarWork object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _isarWorkGetLinks(IsarWork object) {
  return [];
}

void _isarWorkAttach(IsarCollection<dynamic> col, Id id, IsarWork object) {}

extension IsarWorkQueryWhereSort on QueryBuilder<IsarWork, IsarWork, QWhere> {
  QueryBuilder<IsarWork, IsarWork, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhere>
      anyPublisherOrderChannelCreatedAtOrderPlaylistCreatedAtOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(
            indexName:
                r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder'),
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhere> anyTitleWordsElement() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'titleWords'),
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhere> anyArtistWordsElement() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'artistWords'),
      );
    });
  }
}

extension IsarWorkQueryWhere on QueryBuilder<IsarWork, IsarWork, QWhereClause> {
  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderEqualToAnyChannelCreatedAtOrderPlaylistCreatedAtOrder(
          int publisherOrder) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName:
            r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
        value: [publisherOrder],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderNotEqualToAnyChannelCreatedAtOrderPlaylistCreatedAtOrder(
          int publisherOrder) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName:
                  r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
              lower: [],
              upper: [publisherOrder],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName:
                  r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
              lower: [publisherOrder],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName:
                  r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
              lower: [publisherOrder],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName:
                  r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
              lower: [],
              upper: [publisherOrder],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderGreaterThanAnyChannelCreatedAtOrderPlaylistCreatedAtOrder(
    int publisherOrder, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName:
            r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
        lower: [publisherOrder],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderLessThanAnyChannelCreatedAtOrderPlaylistCreatedAtOrder(
    int publisherOrder, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName:
            r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
        lower: [],
        upper: [publisherOrder],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderBetweenAnyChannelCreatedAtOrderPlaylistCreatedAtOrder(
    int lowerPublisherOrder,
    int upperPublisherOrder, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName:
            r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
        lower: [lowerPublisherOrder],
        includeLower: includeLower,
        upper: [upperPublisherOrder],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderChannelCreatedAtOrderEqualToAnyPlaylistCreatedAtOrder(
          int publisherOrder, int channelCreatedAtOrder) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName:
            r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
        value: [publisherOrder, channelCreatedAtOrder],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderEqualToChannelCreatedAtOrderNotEqualToAnyPlaylistCreatedAtOrder(
          int publisherOrder, int channelCreatedAtOrder) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName:
                  r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
              lower: [publisherOrder],
              upper: [publisherOrder, channelCreatedAtOrder],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName:
                  r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
              lower: [publisherOrder, channelCreatedAtOrder],
              includeLower: false,
              upper: [publisherOrder],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName:
                  r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
              lower: [publisherOrder, channelCreatedAtOrder],
              includeLower: false,
              upper: [publisherOrder],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName:
                  r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
              lower: [publisherOrder],
              upper: [publisherOrder, channelCreatedAtOrder],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderEqualToChannelCreatedAtOrderGreaterThanAnyPlaylistCreatedAtOrder(
    int publisherOrder,
    int channelCreatedAtOrder, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName:
            r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
        lower: [publisherOrder, channelCreatedAtOrder],
        includeLower: include,
        upper: [publisherOrder],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderEqualToChannelCreatedAtOrderLessThanAnyPlaylistCreatedAtOrder(
    int publisherOrder,
    int channelCreatedAtOrder, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName:
            r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
        lower: [publisherOrder],
        upper: [publisherOrder, channelCreatedAtOrder],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderEqualToChannelCreatedAtOrderBetweenAnyPlaylistCreatedAtOrder(
    int publisherOrder,
    int lowerChannelCreatedAtOrder,
    int upperChannelCreatedAtOrder, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName:
            r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
        lower: [publisherOrder, lowerChannelCreatedAtOrder],
        includeLower: includeLower,
        upper: [publisherOrder, upperChannelCreatedAtOrder],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderChannelCreatedAtOrderPlaylistCreatedAtOrderEqualTo(
          int publisherOrder,
          int channelCreatedAtOrder,
          int playlistCreatedAtOrder) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName:
            r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
        value: [publisherOrder, channelCreatedAtOrder, playlistCreatedAtOrder],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderChannelCreatedAtOrderEqualToPlaylistCreatedAtOrderNotEqualTo(
          int publisherOrder,
          int channelCreatedAtOrder,
          int playlistCreatedAtOrder) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName:
                  r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
              lower: [publisherOrder, channelCreatedAtOrder],
              upper: [
                publisherOrder,
                channelCreatedAtOrder,
                playlistCreatedAtOrder
              ],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName:
                  r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
              lower: [
                publisherOrder,
                channelCreatedAtOrder,
                playlistCreatedAtOrder
              ],
              includeLower: false,
              upper: [publisherOrder, channelCreatedAtOrder],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName:
                  r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
              lower: [
                publisherOrder,
                channelCreatedAtOrder,
                playlistCreatedAtOrder
              ],
              includeLower: false,
              upper: [publisherOrder, channelCreatedAtOrder],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName:
                  r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
              lower: [publisherOrder, channelCreatedAtOrder],
              upper: [
                publisherOrder,
                channelCreatedAtOrder,
                playlistCreatedAtOrder
              ],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderChannelCreatedAtOrderEqualToPlaylistCreatedAtOrderGreaterThan(
    int publisherOrder,
    int channelCreatedAtOrder,
    int playlistCreatedAtOrder, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName:
            r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
        lower: [publisherOrder, channelCreatedAtOrder, playlistCreatedAtOrder],
        includeLower: include,
        upper: [publisherOrder, channelCreatedAtOrder],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderChannelCreatedAtOrderEqualToPlaylistCreatedAtOrderLessThan(
    int publisherOrder,
    int channelCreatedAtOrder,
    int playlistCreatedAtOrder, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName:
            r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
        lower: [publisherOrder, channelCreatedAtOrder],
        upper: [publisherOrder, channelCreatedAtOrder, playlistCreatedAtOrder],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      publisherOrderChannelCreatedAtOrderEqualToPlaylistCreatedAtOrderBetween(
    int publisherOrder,
    int channelCreatedAtOrder,
    int lowerPlaylistCreatedAtOrder,
    int upperPlaylistCreatedAtOrder, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName:
            r'publisherOrder_channelCreatedAtOrder_playlistCreatedAtOrder',
        lower: [
          publisherOrder,
          channelCreatedAtOrder,
          lowerPlaylistCreatedAtOrder
        ],
        includeLower: includeLower,
        upper: [
          publisherOrder,
          channelCreatedAtOrder,
          upperPlaylistCreatedAtOrder
        ],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause> titleWordsElementEqualTo(
      String titleWordsElement) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'titleWords',
        value: [titleWordsElement],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      titleWordsElementNotEqualTo(String titleWordsElement) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleWords',
              lower: [],
              upper: [titleWordsElement],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleWords',
              lower: [titleWordsElement],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleWords',
              lower: [titleWordsElement],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'titleWords',
              lower: [],
              upper: [titleWordsElement],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      titleWordsElementGreaterThan(
    String titleWordsElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleWords',
        lower: [titleWordsElement],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause> titleWordsElementLessThan(
    String titleWordsElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleWords',
        lower: [],
        upper: [titleWordsElement],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause> titleWordsElementBetween(
    String lowerTitleWordsElement,
    String upperTitleWordsElement, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleWords',
        lower: [lowerTitleWordsElement],
        includeLower: includeLower,
        upper: [upperTitleWordsElement],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      titleWordsElementStartsWith(String TitleWordsElementPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'titleWords',
        lower: [TitleWordsElementPrefix],
        upper: ['$TitleWordsElementPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      titleWordsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'titleWords',
        value: [''],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      titleWordsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'titleWords',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'titleWords',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'titleWords',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'titleWords',
              upper: [''],
            ));
      }
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause> artistWordsElementEqualTo(
      String artistWordsElement) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'artistWords',
        value: [artistWordsElement],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      artistWordsElementNotEqualTo(String artistWordsElement) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'artistWords',
              lower: [],
              upper: [artistWordsElement],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'artistWords',
              lower: [artistWordsElement],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'artistWords',
              lower: [artistWordsElement],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'artistWords',
              lower: [],
              upper: [artistWordsElement],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      artistWordsElementGreaterThan(
    String artistWordsElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'artistWords',
        lower: [artistWordsElement],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      artistWordsElementLessThan(
    String artistWordsElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'artistWords',
        lower: [],
        upper: [artistWordsElement],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause> artistWordsElementBetween(
    String lowerArtistWordsElement,
    String upperArtistWordsElement, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'artistWords',
        lower: [lowerArtistWordsElement],
        includeLower: includeLower,
        upper: [upperArtistWordsElement],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      artistWordsElementStartsWith(String ArtistWordsElementPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'artistWords',
        lower: [ArtistWordsElementPrefix],
        upper: ['$ArtistWordsElementPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      artistWordsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'artistWords',
        value: [''],
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterWhereClause>
      artistWordsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'artistWords',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'artistWords',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'artistWords',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'artistWords',
              upper: [''],
            ));
      }
    });
  }
}

extension IsarWorkQueryFilter
    on QueryBuilder<IsarWork, IsarWork, QFilterCondition> {
  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'artistWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'artistWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'artistWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'artistWords',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'artistWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'artistWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'artistWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'artistWords',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'artistWords',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'artistWords',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'artistWords',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> artistWordsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'artistWords',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'artistWords',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'artistWords',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'artistWords',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      artistWordsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'artistWords',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      channelCreatedAtOrderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'channelCreatedAtOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      channelCreatedAtOrderGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'channelCreatedAtOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      channelCreatedAtOrderLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'channelCreatedAtOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      channelCreatedAtOrderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'channelCreatedAtOrder',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> dataJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> dataJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> dataJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> dataJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dataJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> dataJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> dataJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> dataJsonContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'dataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> dataJsonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'dataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> dataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> dataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'dataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> durationSecIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'durationSec',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      durationSecIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'durationSec',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> durationSecEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'durationSec',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      durationSecGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'durationSec',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> durationSecLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'durationSec',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> durationSecBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'durationSec',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      enrichmentStatusIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'enrichmentStatus',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      enrichmentStatusIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'enrichmentStatus',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      enrichmentStatusEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'enrichmentStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      enrichmentStatusGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'enrichmentStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      enrichmentStatusLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'enrichmentStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      enrichmentStatusBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'enrichmentStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> headJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'headJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> headJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'headJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> headJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'headJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> headJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'headJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> headJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'headJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> headJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'headJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> headJsonContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'headJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> headJsonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'headJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> headJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'headJson',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> headJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'headJson',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> kindEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'kind',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> kindGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'kind',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> kindLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'kind',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> kindBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'kind',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      listArtistJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'listArtistJson',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      listArtistJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'listArtistJson',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> listArtistJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'listArtistJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      listArtistJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'listArtistJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      listArtistJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'listArtistJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> listArtistJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'listArtistJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      listArtistJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'listArtistJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      listArtistJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'listArtistJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      listArtistJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'listArtistJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> listArtistJsonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'listArtistJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      listArtistJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'listArtistJson',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      listArtistJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'listArtistJson',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      playlistCreatedAtOrderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'playlistCreatedAtOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      playlistCreatedAtOrderGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'playlistCreatedAtOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      playlistCreatedAtOrderLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'playlistCreatedAtOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      playlistCreatedAtOrderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'playlistCreatedAtOrder',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> publisherOrderEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publisherOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      publisherOrderGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'publisherOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      publisherOrderLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'publisherOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> publisherOrderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'publisherOrder',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> subtitleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'subtitle',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> subtitleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'subtitle',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> subtitleEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'subtitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> subtitleGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'subtitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> subtitleLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'subtitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> subtitleBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'subtitle',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> subtitleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'subtitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> subtitleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'subtitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> subtitleContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'subtitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> subtitleMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'subtitle',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> subtitleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'subtitle',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> subtitleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'subtitle',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> thumbnailUriIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'thumbnailUri',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      thumbnailUriIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'thumbnailUri',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> thumbnailUriEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'thumbnailUri',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      thumbnailUriGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'thumbnailUri',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> thumbnailUriLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'thumbnailUri',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> thumbnailUriBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'thumbnailUri',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      thumbnailUriStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'thumbnailUri',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> thumbnailUriEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'thumbnailUri',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> thumbnailUriContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'thumbnailUri',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> thumbnailUriMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'thumbnailUri',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      thumbnailUriIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'thumbnailUri',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      thumbnailUriIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'thumbnailUri',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> titleContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> titleMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'titleWords',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'titleWords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'titleWords',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'titleWords',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'titleWords',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> titleWordsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      titleWordsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'titleWords',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> updatedAtUsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedAtUs',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      updatedAtUsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedAtUs',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> updatedAtUsEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAtUs',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition>
      updatedAtUsGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAtUs',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> updatedAtUsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAtUs',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> updatedAtUsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAtUs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> workIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> workIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> workIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> workIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> workIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> workIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> workIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> workIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> workIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterFilterCondition> workIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workId',
        value: '',
      ));
    });
  }
}

extension IsarWorkQueryObject
    on QueryBuilder<IsarWork, IsarWork, QFilterCondition> {}

extension IsarWorkQueryLinks
    on QueryBuilder<IsarWork, IsarWork, QFilterCondition> {}

extension IsarWorkQuerySortBy on QueryBuilder<IsarWork, IsarWork, QSortBy> {
  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByChannelCreatedAtOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelCreatedAtOrder', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy>
      sortByChannelCreatedAtOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelCreatedAtOrder', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByDataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByDataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByDurationSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationSec', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByDurationSecDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationSec', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByEnrichmentStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enrichmentStatus', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByEnrichmentStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enrichmentStatus', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByHeadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'headJson', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByHeadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'headJson', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByListArtistJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'listArtistJson', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByListArtistJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'listArtistJson', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy>
      sortByPlaylistCreatedAtOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playlistCreatedAtOrder', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy>
      sortByPlaylistCreatedAtOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playlistCreatedAtOrder', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByPublisherOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisherOrder', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByPublisherOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisherOrder', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortBySubtitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subtitle', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortBySubtitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subtitle', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByThumbnailUri() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbnailUri', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByThumbnailUriDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbnailUri', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByUpdatedAtUs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtUs', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByUpdatedAtUsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtUs', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByWorkId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workId', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> sortByWorkIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workId', Sort.desc);
    });
  }
}

extension IsarWorkQuerySortThenBy
    on QueryBuilder<IsarWork, IsarWork, QSortThenBy> {
  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByChannelCreatedAtOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelCreatedAtOrder', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy>
      thenByChannelCreatedAtOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channelCreatedAtOrder', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByDataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByDataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataJson', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByDurationSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationSec', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByDurationSecDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationSec', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByEnrichmentStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enrichmentStatus', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByEnrichmentStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enrichmentStatus', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByHeadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'headJson', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByHeadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'headJson', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByListArtistJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'listArtistJson', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByListArtistJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'listArtistJson', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy>
      thenByPlaylistCreatedAtOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playlistCreatedAtOrder', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy>
      thenByPlaylistCreatedAtOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playlistCreatedAtOrder', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByPublisherOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisherOrder', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByPublisherOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisherOrder', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenBySubtitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subtitle', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenBySubtitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subtitle', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByThumbnailUri() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbnailUri', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByThumbnailUriDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbnailUri', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByUpdatedAtUs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtUs', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByUpdatedAtUsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtUs', Sort.desc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByWorkId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workId', Sort.asc);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QAfterSortBy> thenByWorkIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workId', Sort.desc);
    });
  }
}

extension IsarWorkQueryWhereDistinct
    on QueryBuilder<IsarWork, IsarWork, QDistinct> {
  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctByArtistWords() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'artistWords');
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct>
      distinctByChannelCreatedAtOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'channelCreatedAtOrder');
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctByDataJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctByDurationSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'durationSec');
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctByEnrichmentStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'enrichmentStatus');
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctByHeadJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'headJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind');
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctByListArtistJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'listArtistJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct>
      distinctByPlaylistCreatedAtOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'playlistCreatedAtOrder');
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctByPublisherOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'publisherOrder');
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctBySubtitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'subtitle', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctByThumbnailUri(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'thumbnailUri', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctByTitleWords() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'titleWords');
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctByUpdatedAtUs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAtUs');
    });
  }

  QueryBuilder<IsarWork, IsarWork, QDistinct> distinctByWorkId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workId', caseSensitive: caseSensitive);
    });
  }
}

extension IsarWorkQueryProperty
    on QueryBuilder<IsarWork, IsarWork, QQueryProperty> {
  QueryBuilder<IsarWork, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarWork, List<String>, QQueryOperations> artistWordsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'artistWords');
    });
  }

  QueryBuilder<IsarWork, int, QQueryOperations>
      channelCreatedAtOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'channelCreatedAtOrder');
    });
  }

  QueryBuilder<IsarWork, String, QQueryOperations> dataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dataJson');
    });
  }

  QueryBuilder<IsarWork, int?, QQueryOperations> durationSecProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'durationSec');
    });
  }

  QueryBuilder<IsarWork, int?, QQueryOperations> enrichmentStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'enrichmentStatus');
    });
  }

  QueryBuilder<IsarWork, String, QQueryOperations> headJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'headJson');
    });
  }

  QueryBuilder<IsarWork, int, QQueryOperations> kindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<IsarWork, String?, QQueryOperations> listArtistJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'listArtistJson');
    });
  }

  QueryBuilder<IsarWork, int, QQueryOperations>
      playlistCreatedAtOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'playlistCreatedAtOrder');
    });
  }

  QueryBuilder<IsarWork, int, QQueryOperations> publisherOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'publisherOrder');
    });
  }

  QueryBuilder<IsarWork, String?, QQueryOperations> subtitleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'subtitle');
    });
  }

  QueryBuilder<IsarWork, String?, QQueryOperations> thumbnailUriProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'thumbnailUri');
    });
  }

  QueryBuilder<IsarWork, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<IsarWork, List<String>, QQueryOperations> titleWordsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'titleWords');
    });
  }

  QueryBuilder<IsarWork, int?, QQueryOperations> updatedAtUsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAtUs');
    });
  }

  QueryBuilder<IsarWork, String, QQueryOperations> workIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workId');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarPlaylistEntryCollection on Isar {
  IsarCollection<IsarPlaylistEntry> get isarPlaylistEntrys => this.collection();
}

const IsarPlaylistEntrySchema = CollectionSchema(
  name: r'IsarPlaylistEntry',
  id: 4125353220352760007,
  properties: {
    r'playlistId': PropertySchema(
      id: 0,
      name: r'playlistId',
      type: IsarType.string,
    ),
    r'position': PropertySchema(
      id: 1,
      name: r'position',
      type: IsarType.long,
    ),
    r'sortKeyUs': PropertySchema(
      id: 2,
      name: r'sortKeyUs',
      type: IsarType.long,
    ),
    r'workId': PropertySchema(
      id: 3,
      name: r'workId',
      type: IsarType.string,
    )
  },
  estimateSize: _isarPlaylistEntryEstimateSize,
  serialize: _isarPlaylistEntrySerialize,
  deserialize: _isarPlaylistEntryDeserialize,
  deserializeProp: _isarPlaylistEntryDeserializeProp,
  idName: r'id',
  indexes: {
    r'playlistId': IndexSchema(
      id: 7921918076105486368,
      name: r'playlistId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'playlistId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _isarPlaylistEntryGetId,
  getLinks: _isarPlaylistEntryGetLinks,
  attach: _isarPlaylistEntryAttach,
  version: '3.1.0+1',
);

int _isarPlaylistEntryEstimateSize(
  IsarPlaylistEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.playlistId.length * 3;
  bytesCount += 3 + object.workId.length * 3;
  return bytesCount;
}

void _isarPlaylistEntrySerialize(
  IsarPlaylistEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.playlistId);
  writer.writeLong(offsets[1], object.position);
  writer.writeLong(offsets[2], object.sortKeyUs);
  writer.writeString(offsets[3], object.workId);
}

IsarPlaylistEntry _isarPlaylistEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarPlaylistEntry();
  object.id = id;
  object.playlistId = reader.readString(offsets[0]);
  object.position = reader.readLongOrNull(offsets[1]);
  object.sortKeyUs = reader.readLongOrNull(offsets[2]);
  object.workId = reader.readString(offsets[3]);
  return object;
}

P _isarPlaylistEntryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _isarPlaylistEntryGetId(IsarPlaylistEntry object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _isarPlaylistEntryGetLinks(
    IsarPlaylistEntry object) {
  return [];
}

void _isarPlaylistEntryAttach(
    IsarCollection<dynamic> col, Id id, IsarPlaylistEntry object) {
  object.id = id;
}

extension IsarPlaylistEntryQueryWhereSort
    on QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QWhere> {
  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension IsarPlaylistEntryQueryWhere
    on QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QWhereClause> {
  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterWhereClause>
      playlistIdEqualTo(String playlistId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'playlistId',
        value: [playlistId],
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterWhereClause>
      playlistIdNotEqualTo(String playlistId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'playlistId',
              lower: [],
              upper: [playlistId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'playlistId',
              lower: [playlistId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'playlistId',
              lower: [playlistId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'playlistId',
              lower: [],
              upper: [playlistId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension IsarPlaylistEntryQueryFilter
    on QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QFilterCondition> {
  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      playlistIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'playlistId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      playlistIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'playlistId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      playlistIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'playlistId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      playlistIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'playlistId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      playlistIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'playlistId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      playlistIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'playlistId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      playlistIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'playlistId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      playlistIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'playlistId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      playlistIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'playlistId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      playlistIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'playlistId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      positionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'position',
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      positionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'position',
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      positionEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'position',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      positionGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'position',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      positionLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'position',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      positionBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'position',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      sortKeyUsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'sortKeyUs',
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      sortKeyUsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'sortKeyUs',
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      sortKeyUsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sortKeyUs',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      sortKeyUsGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sortKeyUs',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      sortKeyUsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sortKeyUs',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      sortKeyUsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sortKeyUs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      workIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      workIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      workIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      workIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      workIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      workIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      workIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      workIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      workIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterFilterCondition>
      workIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workId',
        value: '',
      ));
    });
  }
}

extension IsarPlaylistEntryQueryObject
    on QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QFilterCondition> {}

extension IsarPlaylistEntryQueryLinks
    on QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QFilterCondition> {}

extension IsarPlaylistEntryQuerySortBy
    on QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QSortBy> {
  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      sortByPlaylistId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playlistId', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      sortByPlaylistIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playlistId', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      sortByPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      sortByPositionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      sortBySortKeyUs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortKeyUs', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      sortBySortKeyUsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortKeyUs', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      sortByWorkId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workId', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      sortByWorkIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workId', Sort.desc);
    });
  }
}

extension IsarPlaylistEntryQuerySortThenBy
    on QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QSortThenBy> {
  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      thenByPlaylistId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playlistId', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      thenByPlaylistIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playlistId', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      thenByPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      thenByPositionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      thenBySortKeyUs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortKeyUs', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      thenBySortKeyUsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortKeyUs', Sort.desc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      thenByWorkId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workId', Sort.asc);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QAfterSortBy>
      thenByWorkIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workId', Sort.desc);
    });
  }
}

extension IsarPlaylistEntryQueryWhereDistinct
    on QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QDistinct> {
  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QDistinct>
      distinctByPlaylistId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'playlistId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QDistinct>
      distinctByPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'position');
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QDistinct>
      distinctBySortKeyUs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sortKeyUs');
    });
  }

  QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QDistinct>
      distinctByWorkId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workId', caseSensitive: caseSensitive);
    });
  }
}

extension IsarPlaylistEntryQueryProperty
    on QueryBuilder<IsarPlaylistEntry, IsarPlaylistEntry, QQueryProperty> {
  QueryBuilder<IsarPlaylistEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarPlaylistEntry, String, QQueryOperations>
      playlistIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'playlistId');
    });
  }

  QueryBuilder<IsarPlaylistEntry, int?, QQueryOperations> positionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'position');
    });
  }

  QueryBuilder<IsarPlaylistEntry, int?, QQueryOperations> sortKeyUsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sortKeyUs');
    });
  }

  QueryBuilder<IsarPlaylistEntry, String, QQueryOperations> workIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workId');
    });
  }
}
