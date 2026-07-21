// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schemas.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetUserProfileEntityCollection on Isar {
  IsarCollection<UserProfileEntity> get userProfileEntitys => this.collection();
}

const UserProfileEntitySchema = CollectionSchema(
  name: r'UserProfileEntity',
  id: -588086384777568406,
  properties: {
    r'birthDate': PropertySchema(
      id: 0,
      name: r'birthDate',
      type: IsarType.dateTime,
    ),
    r'genderIndex': PropertySchema(
      id: 1,
      name: r'genderIndex',
      type: IsarType.long,
    ),
    r'heightCm': PropertySchema(
      id: 2,
      name: r'heightCm',
      type: IsarType.double,
    ),
    r'weightKg': PropertySchema(
      id: 3,
      name: r'weightKg',
      type: IsarType.double,
    ),
  },
  estimateSize: _userProfileEntityEstimateSize,
  serialize: _userProfileEntitySerialize,
  deserialize: _userProfileEntityDeserialize,
  deserializeProp: _userProfileEntityDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _userProfileEntityGetId,
  getLinks: _userProfileEntityGetLinks,
  attach: _userProfileEntityAttach,
  version: '3.1.0+1',
);

int _userProfileEntityEstimateSize(
  UserProfileEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _userProfileEntitySerialize(
  UserProfileEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.birthDate);
  writer.writeLong(offsets[1], object.genderIndex);
  writer.writeDouble(offsets[2], object.heightCm);
  writer.writeDouble(offsets[3], object.weightKg);
}

UserProfileEntity _userProfileEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = UserProfileEntity();
  object.birthDate = reader.readDateTime(offsets[0]);
  object.genderIndex = reader.readLong(offsets[1]);
  object.heightCm = reader.readDouble(offsets[2]);
  object.id = id;
  object.weightKg = reader.readDouble(offsets[3]);
  return object;
}

P _userProfileEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _userProfileEntityGetId(UserProfileEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _userProfileEntityGetLinks(
  UserProfileEntity object,
) {
  return [];
}

void _userProfileEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  UserProfileEntity object,
) {
  object.id = id;
}

extension UserProfileEntityQueryWhereSort
    on QueryBuilder<UserProfileEntity, UserProfileEntity, QWhere> {
  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension UserProfileEntityQueryWhere
    on QueryBuilder<UserProfileEntity, UserProfileEntity, QWhereClause> {
  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterWhereClause>
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

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension UserProfileEntityQueryFilter
    on QueryBuilder<UserProfileEntity, UserProfileEntity, QFilterCondition> {
  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  birthDateEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'birthDate', value: value),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  birthDateGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'birthDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  birthDateLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'birthDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  birthDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'birthDate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  genderIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'genderIndex', value: value),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  genderIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'genderIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  genderIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'genderIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  genderIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'genderIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  heightCmEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'heightCm',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  heightCmGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'heightCm',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  heightCmLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'heightCm',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  heightCmBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'heightCm',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  weightKgEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'weightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  weightKgGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'weightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  weightKgLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'weightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterFilterCondition>
  weightKgBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'weightKg',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }
}

extension UserProfileEntityQueryObject
    on QueryBuilder<UserProfileEntity, UserProfileEntity, QFilterCondition> {}

extension UserProfileEntityQueryLinks
    on QueryBuilder<UserProfileEntity, UserProfileEntity, QFilterCondition> {}

extension UserProfileEntityQuerySortBy
    on QueryBuilder<UserProfileEntity, UserProfileEntity, QSortBy> {
  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  sortByBirthDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'birthDate', Sort.asc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  sortByBirthDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'birthDate', Sort.desc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  sortByGenderIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genderIndex', Sort.asc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  sortByGenderIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genderIndex', Sort.desc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  sortByHeightCm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heightCm', Sort.asc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  sortByHeightCmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heightCm', Sort.desc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  sortByWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.asc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  sortByWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.desc);
    });
  }
}

extension UserProfileEntityQuerySortThenBy
    on QueryBuilder<UserProfileEntity, UserProfileEntity, QSortThenBy> {
  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  thenByBirthDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'birthDate', Sort.asc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  thenByBirthDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'birthDate', Sort.desc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  thenByGenderIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genderIndex', Sort.asc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  thenByGenderIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genderIndex', Sort.desc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  thenByHeightCm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heightCm', Sort.asc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  thenByHeightCmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heightCm', Sort.desc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  thenByWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.asc);
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QAfterSortBy>
  thenByWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.desc);
    });
  }
}

extension UserProfileEntityQueryWhereDistinct
    on QueryBuilder<UserProfileEntity, UserProfileEntity, QDistinct> {
  QueryBuilder<UserProfileEntity, UserProfileEntity, QDistinct>
  distinctByBirthDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'birthDate');
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QDistinct>
  distinctByGenderIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'genderIndex');
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QDistinct>
  distinctByHeightCm() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'heightCm');
    });
  }

  QueryBuilder<UserProfileEntity, UserProfileEntity, QDistinct>
  distinctByWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'weightKg');
    });
  }
}

extension UserProfileEntityQueryProperty
    on QueryBuilder<UserProfileEntity, UserProfileEntity, QQueryProperty> {
  QueryBuilder<UserProfileEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<UserProfileEntity, DateTime, QQueryOperations>
  birthDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'birthDate');
    });
  }

  QueryBuilder<UserProfileEntity, int, QQueryOperations> genderIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'genderIndex');
    });
  }

  QueryBuilder<UserProfileEntity, double, QQueryOperations> heightCmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'heightCm');
    });
  }

  QueryBuilder<UserProfileEntity, double, QQueryOperations> weightKgProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'weightKg');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetGoalEntityCollection on Isar {
  IsarCollection<GoalEntity> get goalEntitys => this.collection();
}

const GoalEntitySchema = CollectionSchema(
  name: r'GoalEntity',
  id: -5725872661757418951,
  properties: {
    r'goalTypeIndex': PropertySchema(
      id: 0,
      name: r'goalTypeIndex',
      type: IsarType.long,
    ),
    r'targetDate': PropertySchema(
      id: 1,
      name: r'targetDate',
      type: IsarType.dateTime,
    ),
    r'targetWeightKg': PropertySchema(
      id: 2,
      name: r'targetWeightKg',
      type: IsarType.double,
    ),
  },
  estimateSize: _goalEntityEstimateSize,
  serialize: _goalEntitySerialize,
  deserialize: _goalEntityDeserialize,
  deserializeProp: _goalEntityDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _goalEntityGetId,
  getLinks: _goalEntityGetLinks,
  attach: _goalEntityAttach,
  version: '3.1.0+1',
);

int _goalEntityEstimateSize(
  GoalEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _goalEntitySerialize(
  GoalEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.goalTypeIndex);
  writer.writeDateTime(offsets[1], object.targetDate);
  writer.writeDouble(offsets[2], object.targetWeightKg);
}

GoalEntity _goalEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = GoalEntity();
  object.goalTypeIndex = reader.readLong(offsets[0]);
  object.id = id;
  object.targetDate = reader.readDateTime(offsets[1]);
  object.targetWeightKg = reader.readDouble(offsets[2]);
  return object;
}

P _goalEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _goalEntityGetId(GoalEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _goalEntityGetLinks(GoalEntity object) {
  return [];
}

void _goalEntityAttach(IsarCollection<dynamic> col, Id id, GoalEntity object) {
  object.id = id;
}

extension GoalEntityQueryWhereSort
    on QueryBuilder<GoalEntity, GoalEntity, QWhere> {
  QueryBuilder<GoalEntity, GoalEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension GoalEntityQueryWhere
    on QueryBuilder<GoalEntity, GoalEntity, QWhereClause> {
  QueryBuilder<GoalEntity, GoalEntity, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<GoalEntity, GoalEntity, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension GoalEntityQueryFilter
    on QueryBuilder<GoalEntity, GoalEntity, QFilterCondition> {
  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition>
  goalTypeIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'goalTypeIndex', value: value),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition>
  goalTypeIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'goalTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition>
  goalTypeIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'goalTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition>
  goalTypeIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'goalTypeIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition> targetDateEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'targetDate', value: value),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition>
  targetDateGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'targetDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition>
  targetDateLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'targetDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition> targetDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'targetDate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition>
  targetWeightKgEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'targetWeightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition>
  targetWeightKgGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'targetWeightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition>
  targetWeightKgLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'targetWeightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterFilterCondition>
  targetWeightKgBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'targetWeightKg',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }
}

extension GoalEntityQueryObject
    on QueryBuilder<GoalEntity, GoalEntity, QFilterCondition> {}

extension GoalEntityQueryLinks
    on QueryBuilder<GoalEntity, GoalEntity, QFilterCondition> {}

extension GoalEntityQuerySortBy
    on QueryBuilder<GoalEntity, GoalEntity, QSortBy> {
  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy> sortByGoalTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'goalTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy> sortByGoalTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'goalTypeIndex', Sort.desc);
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy> sortByTargetDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetDate', Sort.asc);
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy> sortByTargetDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetDate', Sort.desc);
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy> sortByTargetWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetWeightKg', Sort.asc);
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy>
  sortByTargetWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetWeightKg', Sort.desc);
    });
  }
}

extension GoalEntityQuerySortThenBy
    on QueryBuilder<GoalEntity, GoalEntity, QSortThenBy> {
  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy> thenByGoalTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'goalTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy> thenByGoalTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'goalTypeIndex', Sort.desc);
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy> thenByTargetDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetDate', Sort.asc);
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy> thenByTargetDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetDate', Sort.desc);
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy> thenByTargetWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetWeightKg', Sort.asc);
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QAfterSortBy>
  thenByTargetWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetWeightKg', Sort.desc);
    });
  }
}

extension GoalEntityQueryWhereDistinct
    on QueryBuilder<GoalEntity, GoalEntity, QDistinct> {
  QueryBuilder<GoalEntity, GoalEntity, QDistinct> distinctByGoalTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'goalTypeIndex');
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QDistinct> distinctByTargetDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetDate');
    });
  }

  QueryBuilder<GoalEntity, GoalEntity, QDistinct> distinctByTargetWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetWeightKg');
    });
  }
}

extension GoalEntityQueryProperty
    on QueryBuilder<GoalEntity, GoalEntity, QQueryProperty> {
  QueryBuilder<GoalEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<GoalEntity, int, QQueryOperations> goalTypeIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'goalTypeIndex');
    });
  }

  QueryBuilder<GoalEntity, DateTime, QQueryOperations> targetDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetDate');
    });
  }

  QueryBuilder<GoalEntity, double, QQueryOperations> targetWeightKgProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetWeightKg');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetNutritionSettingsEntityCollection on Isar {
  IsarCollection<NutritionSettingsEntity> get nutritionSettingsEntitys =>
      this.collection();
}

const NutritionSettingsEntitySchema = CollectionSchema(
  name: r'NutritionSettingsEntity',
  id: -4789369540577977385,
  properties: {
    r'activityLevelIndex': PropertySchema(
      id: 0,
      name: r'activityLevelIndex',
      type: IsarType.long,
    ),
    r'useHealthIntegration': PropertySchema(
      id: 1,
      name: r'useHealthIntegration',
      type: IsarType.bool,
    ),
  },
  estimateSize: _nutritionSettingsEntityEstimateSize,
  serialize: _nutritionSettingsEntitySerialize,
  deserialize: _nutritionSettingsEntityDeserialize,
  deserializeProp: _nutritionSettingsEntityDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _nutritionSettingsEntityGetId,
  getLinks: _nutritionSettingsEntityGetLinks,
  attach: _nutritionSettingsEntityAttach,
  version: '3.1.0+1',
);

int _nutritionSettingsEntityEstimateSize(
  NutritionSettingsEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _nutritionSettingsEntitySerialize(
  NutritionSettingsEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.activityLevelIndex);
  writer.writeBool(offsets[1], object.useHealthIntegration);
}

NutritionSettingsEntity _nutritionSettingsEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = NutritionSettingsEntity();
  object.activityLevelIndex = reader.readLongOrNull(offsets[0]);
  object.id = id;
  object.useHealthIntegration = reader.readBool(offsets[1]);
  return object;
}

P _nutritionSettingsEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _nutritionSettingsEntityGetId(NutritionSettingsEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _nutritionSettingsEntityGetLinks(
  NutritionSettingsEntity object,
) {
  return [];
}

void _nutritionSettingsEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  NutritionSettingsEntity object,
) {
  object.id = id;
}

extension NutritionSettingsEntityQueryWhereSort
    on QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QWhere> {
  QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension NutritionSettingsEntityQueryWhere
    on
        QueryBuilder<
          NutritionSettingsEntity,
          NutritionSettingsEntity,
          QWhereClause
        > {
  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterWhereClause
  >
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

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterWhereClause
  >
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension NutritionSettingsEntityQueryFilter
    on
        QueryBuilder<
          NutritionSettingsEntity,
          NutritionSettingsEntity,
          QFilterCondition
        > {
  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterFilterCondition
  >
  activityLevelIndexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'activityLevelIndex'),
      );
    });
  }

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterFilterCondition
  >
  activityLevelIndexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'activityLevelIndex'),
      );
    });
  }

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterFilterCondition
  >
  activityLevelIndexEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'activityLevelIndex', value: value),
      );
    });
  }

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterFilterCondition
  >
  activityLevelIndexGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'activityLevelIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterFilterCondition
  >
  activityLevelIndexLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'activityLevelIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterFilterCondition
  >
  activityLevelIndexBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'activityLevelIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    NutritionSettingsEntity,
    NutritionSettingsEntity,
    QAfterFilterCondition
  >
  useHealthIntegrationEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'useHealthIntegration',
          value: value,
        ),
      );
    });
  }
}

extension NutritionSettingsEntityQueryObject
    on
        QueryBuilder<
          NutritionSettingsEntity,
          NutritionSettingsEntity,
          QFilterCondition
        > {}

extension NutritionSettingsEntityQueryLinks
    on
        QueryBuilder<
          NutritionSettingsEntity,
          NutritionSettingsEntity,
          QFilterCondition
        > {}

extension NutritionSettingsEntityQuerySortBy
    on QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QSortBy> {
  QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QAfterSortBy>
  sortByActivityLevelIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityLevelIndex', Sort.asc);
    });
  }

  QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QAfterSortBy>
  sortByActivityLevelIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityLevelIndex', Sort.desc);
    });
  }

  QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QAfterSortBy>
  sortByUseHealthIntegration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useHealthIntegration', Sort.asc);
    });
  }

  QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QAfterSortBy>
  sortByUseHealthIntegrationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useHealthIntegration', Sort.desc);
    });
  }
}

extension NutritionSettingsEntityQuerySortThenBy
    on
        QueryBuilder<
          NutritionSettingsEntity,
          NutritionSettingsEntity,
          QSortThenBy
        > {
  QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QAfterSortBy>
  thenByActivityLevelIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityLevelIndex', Sort.asc);
    });
  }

  QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QAfterSortBy>
  thenByActivityLevelIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityLevelIndex', Sort.desc);
    });
  }

  QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QAfterSortBy>
  thenByUseHealthIntegration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useHealthIntegration', Sort.asc);
    });
  }

  QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QAfterSortBy>
  thenByUseHealthIntegrationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useHealthIntegration', Sort.desc);
    });
  }
}

extension NutritionSettingsEntityQueryWhereDistinct
    on
        QueryBuilder<
          NutritionSettingsEntity,
          NutritionSettingsEntity,
          QDistinct
        > {
  QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QDistinct>
  distinctByActivityLevelIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activityLevelIndex');
    });
  }

  QueryBuilder<NutritionSettingsEntity, NutritionSettingsEntity, QDistinct>
  distinctByUseHealthIntegration() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'useHealthIntegration');
    });
  }
}

extension NutritionSettingsEntityQueryProperty
    on
        QueryBuilder<
          NutritionSettingsEntity,
          NutritionSettingsEntity,
          QQueryProperty
        > {
  QueryBuilder<NutritionSettingsEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<NutritionSettingsEntity, int?, QQueryOperations>
  activityLevelIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activityLevelIndex');
    });
  }

  QueryBuilder<NutritionSettingsEntity, bool, QQueryOperations>
  useHealthIntegrationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'useHealthIntegration');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetFoodEntryEntityCollection on Isar {
  IsarCollection<FoodEntryEntity> get foodEntryEntitys => this.collection();
}

const FoodEntryEntitySchema = CollectionSchema(
  name: r'FoodEntryEntity',
  id: 4572810750514421801,
  properties: {
    r'carbPerUnit': PropertySchema(
      id: 0,
      name: r'carbPerUnit',
      type: IsarType.double,
    ),
    r'entryId': PropertySchema(id: 1, name: r'entryId', type: IsarType.string),
    r'fatPerUnit': PropertySchema(
      id: 2,
      name: r'fatPerUnit',
      type: IsarType.double,
    ),
    r'kcalPerUnit': PropertySchema(
      id: 3,
      name: r'kcalPerUnit',
      type: IsarType.double,
    ),
    r'loggedAt': PropertySchema(
      id: 4,
      name: r'loggedAt',
      type: IsarType.dateTime,
    ),
    r'name': PropertySchema(id: 5, name: r'name', type: IsarType.string),
    r'proteinPerUnit': PropertySchema(
      id: 6,
      name: r'proteinPerUnit',
      type: IsarType.double,
    ),
    r'quantity': PropertySchema(
      id: 7,
      name: r'quantity',
      type: IsarType.double,
    ),
  },
  estimateSize: _foodEntryEntityEstimateSize,
  serialize: _foodEntryEntitySerialize,
  deserialize: _foodEntryEntityDeserialize,
  deserializeProp: _foodEntryEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'entryId': IndexSchema(
      id: 3733379884318738402,
      name: r'entryId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'entryId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _foodEntryEntityGetId,
  getLinks: _foodEntryEntityGetLinks,
  attach: _foodEntryEntityAttach,
  version: '3.1.0+1',
);

int _foodEntryEntityEstimateSize(
  FoodEntryEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.entryId.length * 3;
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _foodEntryEntitySerialize(
  FoodEntryEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.carbPerUnit);
  writer.writeString(offsets[1], object.entryId);
  writer.writeDouble(offsets[2], object.fatPerUnit);
  writer.writeDouble(offsets[3], object.kcalPerUnit);
  writer.writeDateTime(offsets[4], object.loggedAt);
  writer.writeString(offsets[5], object.name);
  writer.writeDouble(offsets[6], object.proteinPerUnit);
  writer.writeDouble(offsets[7], object.quantity);
}

FoodEntryEntity _foodEntryEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = FoodEntryEntity();
  object.carbPerUnit = reader.readDoubleOrNull(offsets[0]);
  object.entryId = reader.readString(offsets[1]);
  object.fatPerUnit = reader.readDoubleOrNull(offsets[2]);
  object.id = id;
  object.kcalPerUnit = reader.readDoubleOrNull(offsets[3]);
  object.loggedAt = reader.readDateTime(offsets[4]);
  object.name = reader.readString(offsets[5]);
  object.proteinPerUnit = reader.readDoubleOrNull(offsets[6]);
  object.quantity = reader.readDouble(offsets[7]);
  return object;
}

P _foodEntryEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDoubleOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readDoubleOrNull(offset)) as P;
    case 3:
      return (reader.readDoubleOrNull(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDoubleOrNull(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _foodEntryEntityGetId(FoodEntryEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _foodEntryEntityGetLinks(FoodEntryEntity object) {
  return [];
}

void _foodEntryEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  FoodEntryEntity object,
) {
  object.id = id;
}

extension FoodEntryEntityByIndex on IsarCollection<FoodEntryEntity> {
  Future<FoodEntryEntity?> getByEntryId(String entryId) {
    return getByIndex(r'entryId', [entryId]);
  }

  FoodEntryEntity? getByEntryIdSync(String entryId) {
    return getByIndexSync(r'entryId', [entryId]);
  }

  Future<bool> deleteByEntryId(String entryId) {
    return deleteByIndex(r'entryId', [entryId]);
  }

  bool deleteByEntryIdSync(String entryId) {
    return deleteByIndexSync(r'entryId', [entryId]);
  }

  Future<List<FoodEntryEntity?>> getAllByEntryId(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'entryId', values);
  }

  List<FoodEntryEntity?> getAllByEntryIdSync(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'entryId', values);
  }

  Future<int> deleteAllByEntryId(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'entryId', values);
  }

  int deleteAllByEntryIdSync(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'entryId', values);
  }

  Future<Id> putByEntryId(FoodEntryEntity object) {
    return putByIndex(r'entryId', object);
  }

  Id putByEntryIdSync(FoodEntryEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'entryId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByEntryId(List<FoodEntryEntity> objects) {
    return putAllByIndex(r'entryId', objects);
  }

  List<Id> putAllByEntryIdSync(
    List<FoodEntryEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'entryId', objects, saveLinks: saveLinks);
  }
}

extension FoodEntryEntityQueryWhereSort
    on QueryBuilder<FoodEntryEntity, FoodEntryEntity, QWhere> {
  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension FoodEntryEntityQueryWhere
    on QueryBuilder<FoodEntryEntity, FoodEntryEntity, QWhereClause> {
  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterWhereClause>
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

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterWhereClause>
  entryIdEqualTo(String entryId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'entryId', value: [entryId]),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterWhereClause>
  entryIdNotEqualTo(String entryId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'entryId',
                lower: [],
                upper: [entryId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'entryId',
                lower: [entryId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'entryId',
                lower: [entryId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'entryId',
                lower: [],
                upper: [entryId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension FoodEntryEntityQueryFilter
    on QueryBuilder<FoodEntryEntity, FoodEntryEntity, QFilterCondition> {
  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  carbPerUnitIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'carbPerUnit'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  carbPerUnitIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'carbPerUnit'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  carbPerUnitEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'carbPerUnit',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  carbPerUnitGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'carbPerUnit',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  carbPerUnitLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'carbPerUnit',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  carbPerUnitBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'carbPerUnit',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  entryIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  entryIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  entryIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  entryIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'entryId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  entryIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  entryIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  entryIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  entryIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'entryId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  entryIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'entryId', value: ''),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  entryIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'entryId', value: ''),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  fatPerUnitIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'fatPerUnit'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  fatPerUnitIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'fatPerUnit'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  fatPerUnitEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fatPerUnit',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  fatPerUnitGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fatPerUnit',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  fatPerUnitLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fatPerUnit',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  fatPerUnitBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fatPerUnit',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  kcalPerUnitIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'kcalPerUnit'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  kcalPerUnitIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'kcalPerUnit'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  kcalPerUnitEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'kcalPerUnit',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  kcalPerUnitGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'kcalPerUnit',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  kcalPerUnitLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'kcalPerUnit',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  kcalPerUnitBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'kcalPerUnit',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  loggedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'loggedAt', value: value),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  loggedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'loggedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  loggedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'loggedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  loggedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'loggedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  nameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  proteinPerUnitIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'proteinPerUnit'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  proteinPerUnitIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'proteinPerUnit'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  proteinPerUnitEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'proteinPerUnit',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  proteinPerUnitGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'proteinPerUnit',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  proteinPerUnitLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'proteinPerUnit',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  proteinPerUnitBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'proteinPerUnit',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  quantityEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'quantity',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  quantityGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'quantity',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  quantityLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'quantity',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  quantityBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'quantity',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }
}

extension FoodEntryEntityQueryObject
    on QueryBuilder<FoodEntryEntity, FoodEntryEntity, QFilterCondition> {}

extension FoodEntryEntityQueryLinks
    on QueryBuilder<FoodEntryEntity, FoodEntryEntity, QFilterCondition> {}

extension FoodEntryEntityQuerySortBy
    on QueryBuilder<FoodEntryEntity, FoodEntryEntity, QSortBy> {
  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByCarbPerUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbPerUnit', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByCarbPerUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbPerUnit', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy> sortByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByFatPerUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatPerUnit', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByFatPerUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatPerUnit', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByKcalPerUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kcalPerUnit', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByKcalPerUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kcalPerUnit', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByLoggedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedAt', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByLoggedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedAt', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByProteinPerUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinPerUnit', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByProteinPerUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinPerUnit', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.desc);
    });
  }
}

extension FoodEntryEntityQuerySortThenBy
    on QueryBuilder<FoodEntryEntity, FoodEntryEntity, QSortThenBy> {
  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByCarbPerUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbPerUnit', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByCarbPerUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbPerUnit', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy> thenByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByFatPerUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatPerUnit', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByFatPerUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatPerUnit', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByKcalPerUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kcalPerUnit', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByKcalPerUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kcalPerUnit', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByLoggedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedAt', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByLoggedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedAt', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByProteinPerUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinPerUnit', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByProteinPerUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinPerUnit', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.desc);
    });
  }
}

extension FoodEntryEntityQueryWhereDistinct
    on QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct> {
  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctByCarbPerUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'carbPerUnit');
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct> distinctByEntryId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entryId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctByFatPerUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fatPerUnit');
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctByKcalPerUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kcalPerUnit');
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctByLoggedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'loggedAt');
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctByProteinPerUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'proteinPerUnit');
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'quantity');
    });
  }
}

extension FoodEntryEntityQueryProperty
    on QueryBuilder<FoodEntryEntity, FoodEntryEntity, QQueryProperty> {
  QueryBuilder<FoodEntryEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<FoodEntryEntity, double?, QQueryOperations>
  carbPerUnitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'carbPerUnit');
    });
  }

  QueryBuilder<FoodEntryEntity, String, QQueryOperations> entryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entryId');
    });
  }

  QueryBuilder<FoodEntryEntity, double?, QQueryOperations>
  fatPerUnitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fatPerUnit');
    });
  }

  QueryBuilder<FoodEntryEntity, double?, QQueryOperations>
  kcalPerUnitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kcalPerUnit');
    });
  }

  QueryBuilder<FoodEntryEntity, DateTime, QQueryOperations> loggedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'loggedAt');
    });
  }

  QueryBuilder<FoodEntryEntity, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<FoodEntryEntity, double?, QQueryOperations>
  proteinPerUnitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'proteinPerUnit');
    });
  }

  QueryBuilder<FoodEntryEntity, double, QQueryOperations> quantityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'quantity');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetExerciseEntryEntityCollection on Isar {
  IsarCollection<ExerciseEntryEntity> get exerciseEntryEntitys =>
      this.collection();
}

const ExerciseEntryEntitySchema = CollectionSchema(
  name: r'ExerciseEntryEntity',
  id: -824924797514527953,
  properties: {
    r'burnedKcal': PropertySchema(
      id: 0,
      name: r'burnedKcal',
      type: IsarType.double,
    ),
    r'durationMin': PropertySchema(
      id: 1,
      name: r'durationMin',
      type: IsarType.long,
    ),
    r'entryId': PropertySchema(id: 2, name: r'entryId', type: IsarType.string),
    r'loggedAt': PropertySchema(
      id: 3,
      name: r'loggedAt',
      type: IsarType.dateTime,
    ),
    r'name': PropertySchema(id: 4, name: r'name', type: IsarType.string),
  },
  estimateSize: _exerciseEntryEntityEstimateSize,
  serialize: _exerciseEntryEntitySerialize,
  deserialize: _exerciseEntryEntityDeserialize,
  deserializeProp: _exerciseEntryEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'entryId': IndexSchema(
      id: 3733379884318738402,
      name: r'entryId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'entryId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _exerciseEntryEntityGetId,
  getLinks: _exerciseEntryEntityGetLinks,
  attach: _exerciseEntryEntityAttach,
  version: '3.1.0+1',
);

int _exerciseEntryEntityEstimateSize(
  ExerciseEntryEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.entryId.length * 3;
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _exerciseEntryEntitySerialize(
  ExerciseEntryEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.burnedKcal);
  writer.writeLong(offsets[1], object.durationMin);
  writer.writeString(offsets[2], object.entryId);
  writer.writeDateTime(offsets[3], object.loggedAt);
  writer.writeString(offsets[4], object.name);
}

ExerciseEntryEntity _exerciseEntryEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ExerciseEntryEntity();
  object.burnedKcal = reader.readDouble(offsets[0]);
  object.durationMin = reader.readLong(offsets[1]);
  object.entryId = reader.readString(offsets[2]);
  object.id = id;
  object.loggedAt = reader.readDateTime(offsets[3]);
  object.name = reader.readString(offsets[4]);
  return object;
}

P _exerciseEntryEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _exerciseEntryEntityGetId(ExerciseEntryEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _exerciseEntryEntityGetLinks(
  ExerciseEntryEntity object,
) {
  return [];
}

void _exerciseEntryEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ExerciseEntryEntity object,
) {
  object.id = id;
}

extension ExerciseEntryEntityByIndex on IsarCollection<ExerciseEntryEntity> {
  Future<ExerciseEntryEntity?> getByEntryId(String entryId) {
    return getByIndex(r'entryId', [entryId]);
  }

  ExerciseEntryEntity? getByEntryIdSync(String entryId) {
    return getByIndexSync(r'entryId', [entryId]);
  }

  Future<bool> deleteByEntryId(String entryId) {
    return deleteByIndex(r'entryId', [entryId]);
  }

  bool deleteByEntryIdSync(String entryId) {
    return deleteByIndexSync(r'entryId', [entryId]);
  }

  Future<List<ExerciseEntryEntity?>> getAllByEntryId(
    List<String> entryIdValues,
  ) {
    final values = entryIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'entryId', values);
  }

  List<ExerciseEntryEntity?> getAllByEntryIdSync(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'entryId', values);
  }

  Future<int> deleteAllByEntryId(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'entryId', values);
  }

  int deleteAllByEntryIdSync(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'entryId', values);
  }

  Future<Id> putByEntryId(ExerciseEntryEntity object) {
    return putByIndex(r'entryId', object);
  }

  Id putByEntryIdSync(ExerciseEntryEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'entryId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByEntryId(List<ExerciseEntryEntity> objects) {
    return putAllByIndex(r'entryId', objects);
  }

  List<Id> putAllByEntryIdSync(
    List<ExerciseEntryEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'entryId', objects, saveLinks: saveLinks);
  }
}

extension ExerciseEntryEntityQueryWhereSort
    on QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QWhere> {
  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ExerciseEntryEntityQueryWhere
    on QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QWhereClause> {
  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterWhereClause>
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

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterWhereClause>
  entryIdEqualTo(String entryId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'entryId', value: [entryId]),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterWhereClause>
  entryIdNotEqualTo(String entryId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'entryId',
                lower: [],
                upper: [entryId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'entryId',
                lower: [entryId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'entryId',
                lower: [entryId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'entryId',
                lower: [],
                upper: [entryId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ExerciseEntryEntityQueryFilter
    on
        QueryBuilder<
          ExerciseEntryEntity,
          ExerciseEntryEntity,
          QFilterCondition
        > {
  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  burnedKcalEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'burnedKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  burnedKcalGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'burnedKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  burnedKcalLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'burnedKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  burnedKcalBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'burnedKcal',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  durationMinEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'durationMin', value: value),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  durationMinGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'durationMin',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  durationMinLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'durationMin',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  durationMinBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'durationMin',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  entryIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  entryIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  entryIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  entryIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'entryId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  entryIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  entryIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  entryIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  entryIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'entryId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  entryIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'entryId', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  entryIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'entryId', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  loggedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'loggedAt', value: value),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  loggedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'loggedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  loggedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'loggedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  loggedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'loggedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  nameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }
}

extension ExerciseEntryEntityQueryObject
    on
        QueryBuilder<
          ExerciseEntryEntity,
          ExerciseEntryEntity,
          QFilterCondition
        > {}

extension ExerciseEntryEntityQueryLinks
    on
        QueryBuilder<
          ExerciseEntryEntity,
          ExerciseEntryEntity,
          QFilterCondition
        > {}

extension ExerciseEntryEntityQuerySortBy
    on QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QSortBy> {
  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByBurnedKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'burnedKcal', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByBurnedKcalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'burnedKcal', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByDurationMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMin', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByDurationMinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMin', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByLoggedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedAt', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByLoggedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedAt', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }
}

extension ExerciseEntryEntityQuerySortThenBy
    on QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QSortThenBy> {
  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByBurnedKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'burnedKcal', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByBurnedKcalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'burnedKcal', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByDurationMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMin', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByDurationMinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMin', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByLoggedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedAt', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByLoggedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'loggedAt', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }
}

extension ExerciseEntryEntityQueryWhereDistinct
    on QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct> {
  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByBurnedKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'burnedKcal');
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByDurationMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'durationMin');
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByEntryId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entryId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByLoggedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'loggedAt');
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }
}

extension ExerciseEntryEntityQueryProperty
    on QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QQueryProperty> {
  QueryBuilder<ExerciseEntryEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ExerciseEntryEntity, double, QQueryOperations>
  burnedKcalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'burnedKcal');
    });
  }

  QueryBuilder<ExerciseEntryEntity, int, QQueryOperations>
  durationMinProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'durationMin');
    });
  }

  QueryBuilder<ExerciseEntryEntity, String, QQueryOperations>
  entryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entryId');
    });
  }

  QueryBuilder<ExerciseEntryEntity, DateTime, QQueryOperations>
  loggedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'loggedAt');
    });
  }

  QueryBuilder<ExerciseEntryEntity, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetWeightEntryEntityCollection on Isar {
  IsarCollection<WeightEntryEntity> get weightEntryEntitys => this.collection();
}

const WeightEntryEntitySchema = CollectionSchema(
  name: r'WeightEntryEntity',
  id: -321166145757496281,
  properties: {
    r'entryId': PropertySchema(id: 0, name: r'entryId', type: IsarType.string),
    r'recordedAt': PropertySchema(
      id: 1,
      name: r'recordedAt',
      type: IsarType.dateTime,
    ),
    r'sourceIndex': PropertySchema(
      id: 2,
      name: r'sourceIndex',
      type: IsarType.long,
    ),
    r'weightKg': PropertySchema(
      id: 3,
      name: r'weightKg',
      type: IsarType.double,
    ),
  },
  estimateSize: _weightEntryEntityEstimateSize,
  serialize: _weightEntryEntitySerialize,
  deserialize: _weightEntryEntityDeserialize,
  deserializeProp: _weightEntryEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'entryId': IndexSchema(
      id: 3733379884318738402,
      name: r'entryId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'entryId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _weightEntryEntityGetId,
  getLinks: _weightEntryEntityGetLinks,
  attach: _weightEntryEntityAttach,
  version: '3.1.0+1',
);

int _weightEntryEntityEstimateSize(
  WeightEntryEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.entryId.length * 3;
  return bytesCount;
}

void _weightEntryEntitySerialize(
  WeightEntryEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.entryId);
  writer.writeDateTime(offsets[1], object.recordedAt);
  writer.writeLong(offsets[2], object.sourceIndex);
  writer.writeDouble(offsets[3], object.weightKg);
}

WeightEntryEntity _weightEntryEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WeightEntryEntity();
  object.entryId = reader.readString(offsets[0]);
  object.id = id;
  object.recordedAt = reader.readDateTime(offsets[1]);
  object.sourceIndex = reader.readLong(offsets[2]);
  object.weightKg = reader.readDouble(offsets[3]);
  return object;
}

P _weightEntryEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _weightEntryEntityGetId(WeightEntryEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _weightEntryEntityGetLinks(
  WeightEntryEntity object,
) {
  return [];
}

void _weightEntryEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  WeightEntryEntity object,
) {
  object.id = id;
}

extension WeightEntryEntityByIndex on IsarCollection<WeightEntryEntity> {
  Future<WeightEntryEntity?> getByEntryId(String entryId) {
    return getByIndex(r'entryId', [entryId]);
  }

  WeightEntryEntity? getByEntryIdSync(String entryId) {
    return getByIndexSync(r'entryId', [entryId]);
  }

  Future<bool> deleteByEntryId(String entryId) {
    return deleteByIndex(r'entryId', [entryId]);
  }

  bool deleteByEntryIdSync(String entryId) {
    return deleteByIndexSync(r'entryId', [entryId]);
  }

  Future<List<WeightEntryEntity?>> getAllByEntryId(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'entryId', values);
  }

  List<WeightEntryEntity?> getAllByEntryIdSync(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'entryId', values);
  }

  Future<int> deleteAllByEntryId(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'entryId', values);
  }

  int deleteAllByEntryIdSync(List<String> entryIdValues) {
    final values = entryIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'entryId', values);
  }

  Future<Id> putByEntryId(WeightEntryEntity object) {
    return putByIndex(r'entryId', object);
  }

  Id putByEntryIdSync(WeightEntryEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'entryId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByEntryId(List<WeightEntryEntity> objects) {
    return putAllByIndex(r'entryId', objects);
  }

  List<Id> putAllByEntryIdSync(
    List<WeightEntryEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'entryId', objects, saveLinks: saveLinks);
  }
}

extension WeightEntryEntityQueryWhereSort
    on QueryBuilder<WeightEntryEntity, WeightEntryEntity, QWhere> {
  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension WeightEntryEntityQueryWhere
    on QueryBuilder<WeightEntryEntity, WeightEntryEntity, QWhereClause> {
  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterWhereClause>
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

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterWhereClause>
  entryIdEqualTo(String entryId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'entryId', value: [entryId]),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterWhereClause>
  entryIdNotEqualTo(String entryId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'entryId',
                lower: [],
                upper: [entryId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'entryId',
                lower: [entryId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'entryId',
                lower: [entryId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'entryId',
                lower: [],
                upper: [entryId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension WeightEntryEntityQueryFilter
    on QueryBuilder<WeightEntryEntity, WeightEntryEntity, QFilterCondition> {
  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  entryIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  entryIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  entryIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  entryIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'entryId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  entryIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  entryIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  entryIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'entryId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  entryIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'entryId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  entryIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'entryId', value: ''),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  entryIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'entryId', value: ''),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  recordedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'recordedAt', value: value),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  recordedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'recordedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  recordedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'recordedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  recordedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'recordedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  sourceIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceIndex', value: value),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  sourceIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  sourceIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  sourceIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  weightKgEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'weightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  weightKgGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'weightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  weightKgLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'weightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterFilterCondition>
  weightKgBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'weightKg',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }
}

extension WeightEntryEntityQueryObject
    on QueryBuilder<WeightEntryEntity, WeightEntryEntity, QFilterCondition> {}

extension WeightEntryEntityQueryLinks
    on QueryBuilder<WeightEntryEntity, WeightEntryEntity, QFilterCondition> {}

extension WeightEntryEntityQuerySortBy
    on QueryBuilder<WeightEntryEntity, WeightEntryEntity, QSortBy> {
  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  sortByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  sortByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  sortByRecordedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordedAt', Sort.asc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  sortByRecordedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordedAt', Sort.desc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  sortBySourceIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceIndex', Sort.asc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  sortBySourceIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceIndex', Sort.desc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  sortByWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.asc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  sortByWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.desc);
    });
  }
}

extension WeightEntryEntityQuerySortThenBy
    on QueryBuilder<WeightEntryEntity, WeightEntryEntity, QSortThenBy> {
  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  thenByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  thenByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  thenByRecordedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordedAt', Sort.asc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  thenByRecordedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordedAt', Sort.desc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  thenBySourceIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceIndex', Sort.asc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  thenBySourceIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceIndex', Sort.desc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  thenByWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.asc);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QAfterSortBy>
  thenByWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.desc);
    });
  }
}

extension WeightEntryEntityQueryWhereDistinct
    on QueryBuilder<WeightEntryEntity, WeightEntryEntity, QDistinct> {
  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QDistinct>
  distinctByEntryId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entryId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QDistinct>
  distinctByRecordedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recordedAt');
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QDistinct>
  distinctBySourceIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceIndex');
    });
  }

  QueryBuilder<WeightEntryEntity, WeightEntryEntity, QDistinct>
  distinctByWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'weightKg');
    });
  }
}

extension WeightEntryEntityQueryProperty
    on QueryBuilder<WeightEntryEntity, WeightEntryEntity, QQueryProperty> {
  QueryBuilder<WeightEntryEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WeightEntryEntity, String, QQueryOperations> entryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entryId');
    });
  }

  QueryBuilder<WeightEntryEntity, DateTime, QQueryOperations>
  recordedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recordedAt');
    });
  }

  QueryBuilder<WeightEntryEntity, int, QQueryOperations> sourceIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceIndex');
    });
  }

  QueryBuilder<WeightEntryEntity, double, QQueryOperations> weightKgProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'weightKg');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetHealthSnapshotEntityCollection on Isar {
  IsarCollection<HealthSnapshotEntity> get healthSnapshotEntitys =>
      this.collection();
}

const HealthSnapshotEntitySchema = CollectionSchema(
  name: r'HealthSnapshotEntity',
  id: 5108493460057173550,
  properties: {
    r'activeEnergyBurnedKcal': PropertySchema(
      id: 0,
      name: r'activeEnergyBurnedKcal',
      type: IsarType.double,
    ),
    r'updatedAt': PropertySchema(
      id: 1,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'weightKg': PropertySchema(
      id: 2,
      name: r'weightKg',
      type: IsarType.double,
    ),
  },
  estimateSize: _healthSnapshotEntityEstimateSize,
  serialize: _healthSnapshotEntitySerialize,
  deserialize: _healthSnapshotEntityDeserialize,
  deserializeProp: _healthSnapshotEntityDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _healthSnapshotEntityGetId,
  getLinks: _healthSnapshotEntityGetLinks,
  attach: _healthSnapshotEntityAttach,
  version: '3.1.0+1',
);

int _healthSnapshotEntityEstimateSize(
  HealthSnapshotEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _healthSnapshotEntitySerialize(
  HealthSnapshotEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.activeEnergyBurnedKcal);
  writer.writeDateTime(offsets[1], object.updatedAt);
  writer.writeDouble(offsets[2], object.weightKg);
}

HealthSnapshotEntity _healthSnapshotEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = HealthSnapshotEntity();
  object.activeEnergyBurnedKcal = reader.readDoubleOrNull(offsets[0]);
  object.id = id;
  object.updatedAt = reader.readDateTime(offsets[1]);
  object.weightKg = reader.readDoubleOrNull(offsets[2]);
  return object;
}

P _healthSnapshotEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDoubleOrNull(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readDoubleOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _healthSnapshotEntityGetId(HealthSnapshotEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _healthSnapshotEntityGetLinks(
  HealthSnapshotEntity object,
) {
  return [];
}

void _healthSnapshotEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  HealthSnapshotEntity object,
) {
  object.id = id;
}

extension HealthSnapshotEntityQueryWhereSort
    on QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QWhere> {
  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension HealthSnapshotEntityQueryWhere
    on QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QWhereClause> {
  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterWhereClause>
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

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension HealthSnapshotEntityQueryFilter
    on
        QueryBuilder<
          HealthSnapshotEntity,
          HealthSnapshotEntity,
          QFilterCondition
        > {
  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  activeEnergyBurnedKcalIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'activeEnergyBurnedKcal'),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  activeEnergyBurnedKcalIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'activeEnergyBurnedKcal'),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  activeEnergyBurnedKcalEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'activeEnergyBurnedKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  activeEnergyBurnedKcalGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'activeEnergyBurnedKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  activeEnergyBurnedKcalLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'activeEnergyBurnedKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  activeEnergyBurnedKcalBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'activeEnergyBurnedKcal',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  updatedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  weightKgIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'weightKg'),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  weightKgIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'weightKg'),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  weightKgEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'weightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  weightKgGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'weightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  weightKgLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'weightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    HealthSnapshotEntity,
    HealthSnapshotEntity,
    QAfterFilterCondition
  >
  weightKgBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'weightKg',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }
}

extension HealthSnapshotEntityQueryObject
    on
        QueryBuilder<
          HealthSnapshotEntity,
          HealthSnapshotEntity,
          QFilterCondition
        > {}

extension HealthSnapshotEntityQueryLinks
    on
        QueryBuilder<
          HealthSnapshotEntity,
          HealthSnapshotEntity,
          QFilterCondition
        > {}

extension HealthSnapshotEntityQuerySortBy
    on QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QSortBy> {
  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  sortByActiveEnergyBurnedKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeEnergyBurnedKcal', Sort.asc);
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  sortByActiveEnergyBurnedKcalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeEnergyBurnedKcal', Sort.desc);
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  sortByWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.asc);
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  sortByWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.desc);
    });
  }
}

extension HealthSnapshotEntityQuerySortThenBy
    on QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QSortThenBy> {
  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  thenByActiveEnergyBurnedKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeEnergyBurnedKcal', Sort.asc);
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  thenByActiveEnergyBurnedKcalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeEnergyBurnedKcal', Sort.desc);
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  thenByWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.asc);
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QAfterSortBy>
  thenByWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKg', Sort.desc);
    });
  }
}

extension HealthSnapshotEntityQueryWhereDistinct
    on QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QDistinct> {
  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QDistinct>
  distinctByActiveEnergyBurnedKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activeEnergyBurnedKcal');
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<HealthSnapshotEntity, HealthSnapshotEntity, QDistinct>
  distinctByWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'weightKg');
    });
  }
}

extension HealthSnapshotEntityQueryProperty
    on
        QueryBuilder<
          HealthSnapshotEntity,
          HealthSnapshotEntity,
          QQueryProperty
        > {
  QueryBuilder<HealthSnapshotEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<HealthSnapshotEntity, double?, QQueryOperations>
  activeEnergyBurnedKcalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activeEnergyBurnedKcal');
    });
  }

  QueryBuilder<HealthSnapshotEntity, DateTime, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<HealthSnapshotEntity, double?, QQueryOperations>
  weightKgProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'weightKg');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAppSettingsEntityCollection on Isar {
  IsarCollection<AppSettingsEntity> get appSettingsEntitys => this.collection();
}

const AppSettingsEntitySchema = CollectionSchema(
  name: r'AppSettingsEntity',
  id: 5506238605616873742,
  properties: {
    r'onboardingComplete': PropertySchema(
      id: 0,
      name: r'onboardingComplete',
      type: IsarType.bool,
    ),
  },
  estimateSize: _appSettingsEntityEstimateSize,
  serialize: _appSettingsEntitySerialize,
  deserialize: _appSettingsEntityDeserialize,
  deserializeProp: _appSettingsEntityDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _appSettingsEntityGetId,
  getLinks: _appSettingsEntityGetLinks,
  attach: _appSettingsEntityAttach,
  version: '3.1.0+1',
);

int _appSettingsEntityEstimateSize(
  AppSettingsEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _appSettingsEntitySerialize(
  AppSettingsEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.onboardingComplete);
}

AppSettingsEntity _appSettingsEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AppSettingsEntity();
  object.id = id;
  object.onboardingComplete = reader.readBool(offsets[0]);
  return object;
}

P _appSettingsEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _appSettingsEntityGetId(AppSettingsEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _appSettingsEntityGetLinks(
  AppSettingsEntity object,
) {
  return [];
}

void _appSettingsEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  AppSettingsEntity object,
) {
  object.id = id;
}

extension AppSettingsEntityQueryWhereSort
    on QueryBuilder<AppSettingsEntity, AppSettingsEntity, QWhere> {
  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AppSettingsEntityQueryWhere
    on QueryBuilder<AppSettingsEntity, AppSettingsEntity, QWhereClause> {
  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterWhereClause>
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

  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension AppSettingsEntityQueryFilter
    on QueryBuilder<AppSettingsEntity, AppSettingsEntity, QFilterCondition> {
  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterFilterCondition>
  onboardingCompleteEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'onboardingComplete', value: value),
      );
    });
  }
}

extension AppSettingsEntityQueryObject
    on QueryBuilder<AppSettingsEntity, AppSettingsEntity, QFilterCondition> {}

extension AppSettingsEntityQueryLinks
    on QueryBuilder<AppSettingsEntity, AppSettingsEntity, QFilterCondition> {}

extension AppSettingsEntityQuerySortBy
    on QueryBuilder<AppSettingsEntity, AppSettingsEntity, QSortBy> {
  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterSortBy>
  sortByOnboardingComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onboardingComplete', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterSortBy>
  sortByOnboardingCompleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onboardingComplete', Sort.desc);
    });
  }
}

extension AppSettingsEntityQuerySortThenBy
    on QueryBuilder<AppSettingsEntity, AppSettingsEntity, QSortThenBy> {
  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterSortBy>
  thenByOnboardingComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onboardingComplete', Sort.asc);
    });
  }

  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QAfterSortBy>
  thenByOnboardingCompleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'onboardingComplete', Sort.desc);
    });
  }
}

extension AppSettingsEntityQueryWhereDistinct
    on QueryBuilder<AppSettingsEntity, AppSettingsEntity, QDistinct> {
  QueryBuilder<AppSettingsEntity, AppSettingsEntity, QDistinct>
  distinctByOnboardingComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'onboardingComplete');
    });
  }
}

extension AppSettingsEntityQueryProperty
    on QueryBuilder<AppSettingsEntity, AppSettingsEntity, QQueryProperty> {
  QueryBuilder<AppSettingsEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AppSettingsEntity, bool, QQueryOperations>
  onboardingCompleteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'onboardingComplete');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetHealthWorkoutEntityCollection on Isar {
  IsarCollection<HealthWorkoutEntity> get healthWorkoutEntitys =>
      this.collection();
}

const HealthWorkoutEntitySchema = CollectionSchema(
  name: r'HealthWorkoutEntity',
  id: -6534043864236786925,
  properties: {
    r'activityType': PropertySchema(
      id: 0,
      name: r'activityType',
      type: IsarType.string,
    ),
    r'caloriesBurned': PropertySchema(
      id: 1,
      name: r'caloriesBurned',
      type: IsarType.double,
    ),
    r'endTime': PropertySchema(
      id: 2,
      name: r'endTime',
      type: IsarType.dateTime,
    ),
    r'startTime': PropertySchema(
      id: 3,
      name: r'startTime',
      type: IsarType.dateTime,
    ),
    r'workoutId': PropertySchema(
      id: 4,
      name: r'workoutId',
      type: IsarType.string,
    ),
  },
  estimateSize: _healthWorkoutEntityEstimateSize,
  serialize: _healthWorkoutEntitySerialize,
  deserialize: _healthWorkoutEntityDeserialize,
  deserializeProp: _healthWorkoutEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'workoutId': IndexSchema(
      id: -2481575602404730374,
      name: r'workoutId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'workoutId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _healthWorkoutEntityGetId,
  getLinks: _healthWorkoutEntityGetLinks,
  attach: _healthWorkoutEntityAttach,
  version: '3.1.0+1',
);

int _healthWorkoutEntityEstimateSize(
  HealthWorkoutEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.activityType.length * 3;
  bytesCount += 3 + object.workoutId.length * 3;
  return bytesCount;
}

void _healthWorkoutEntitySerialize(
  HealthWorkoutEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.activityType);
  writer.writeDouble(offsets[1], object.caloriesBurned);
  writer.writeDateTime(offsets[2], object.endTime);
  writer.writeDateTime(offsets[3], object.startTime);
  writer.writeString(offsets[4], object.workoutId);
}

HealthWorkoutEntity _healthWorkoutEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = HealthWorkoutEntity();
  object.activityType = reader.readString(offsets[0]);
  object.caloriesBurned = reader.readDoubleOrNull(offsets[1]);
  object.endTime = reader.readDateTime(offsets[2]);
  object.id = id;
  object.startTime = reader.readDateTime(offsets[3]);
  object.workoutId = reader.readString(offsets[4]);
  return object;
}

P _healthWorkoutEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _healthWorkoutEntityGetId(HealthWorkoutEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _healthWorkoutEntityGetLinks(
  HealthWorkoutEntity object,
) {
  return [];
}

void _healthWorkoutEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  HealthWorkoutEntity object,
) {
  object.id = id;
}

extension HealthWorkoutEntityByIndex on IsarCollection<HealthWorkoutEntity> {
  Future<HealthWorkoutEntity?> getByWorkoutId(String workoutId) {
    return getByIndex(r'workoutId', [workoutId]);
  }

  HealthWorkoutEntity? getByWorkoutIdSync(String workoutId) {
    return getByIndexSync(r'workoutId', [workoutId]);
  }

  Future<bool> deleteByWorkoutId(String workoutId) {
    return deleteByIndex(r'workoutId', [workoutId]);
  }

  bool deleteByWorkoutIdSync(String workoutId) {
    return deleteByIndexSync(r'workoutId', [workoutId]);
  }

  Future<List<HealthWorkoutEntity?>> getAllByWorkoutId(
    List<String> workoutIdValues,
  ) {
    final values = workoutIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'workoutId', values);
  }

  List<HealthWorkoutEntity?> getAllByWorkoutIdSync(
    List<String> workoutIdValues,
  ) {
    final values = workoutIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'workoutId', values);
  }

  Future<int> deleteAllByWorkoutId(List<String> workoutIdValues) {
    final values = workoutIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'workoutId', values);
  }

  int deleteAllByWorkoutIdSync(List<String> workoutIdValues) {
    final values = workoutIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'workoutId', values);
  }

  Future<Id> putByWorkoutId(HealthWorkoutEntity object) {
    return putByIndex(r'workoutId', object);
  }

  Id putByWorkoutIdSync(HealthWorkoutEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'workoutId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByWorkoutId(List<HealthWorkoutEntity> objects) {
    return putAllByIndex(r'workoutId', objects);
  }

  List<Id> putAllByWorkoutIdSync(
    List<HealthWorkoutEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'workoutId', objects, saveLinks: saveLinks);
  }
}

extension HealthWorkoutEntityQueryWhereSort
    on QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QWhere> {
  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension HealthWorkoutEntityQueryWhere
    on QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QWhereClause> {
  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterWhereClause>
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

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterWhereClause>
  workoutIdEqualTo(String workoutId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'workoutId', value: [workoutId]),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterWhereClause>
  workoutIdNotEqualTo(String workoutId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'workoutId',
                lower: [],
                upper: [workoutId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'workoutId',
                lower: [workoutId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'workoutId',
                lower: [workoutId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'workoutId',
                lower: [],
                upper: [workoutId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension HealthWorkoutEntityQueryFilter
    on
        QueryBuilder<
          HealthWorkoutEntity,
          HealthWorkoutEntity,
          QFilterCondition
        > {
  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  activityTypeEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'activityType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  activityTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'activityType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  activityTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'activityType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  activityTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'activityType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  activityTypeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'activityType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  activityTypeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'activityType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  activityTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'activityType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  activityTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'activityType',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  activityTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'activityType', value: ''),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  activityTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'activityType', value: ''),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  caloriesBurnedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'caloriesBurned'),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  caloriesBurnedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'caloriesBurned'),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  caloriesBurnedEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'caloriesBurned',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  caloriesBurnedGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'caloriesBurned',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  caloriesBurnedLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'caloriesBurned',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  caloriesBurnedBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'caloriesBurned',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  endTimeEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'endTime', value: value),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  endTimeGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'endTime',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  endTimeLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'endTime',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  endTimeBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'endTime',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  startTimeEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'startTime', value: value),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  startTimeGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'startTime',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  startTimeLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'startTime',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  startTimeBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'startTime',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  workoutIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'workoutId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  workoutIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'workoutId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  workoutIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'workoutId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  workoutIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'workoutId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  workoutIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'workoutId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  workoutIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'workoutId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  workoutIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'workoutId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  workoutIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'workoutId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  workoutIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'workoutId', value: ''),
      );
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterFilterCondition>
  workoutIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'workoutId', value: ''),
      );
    });
  }
}

extension HealthWorkoutEntityQueryObject
    on
        QueryBuilder<
          HealthWorkoutEntity,
          HealthWorkoutEntity,
          QFilterCondition
        > {}

extension HealthWorkoutEntityQueryLinks
    on
        QueryBuilder<
          HealthWorkoutEntity,
          HealthWorkoutEntity,
          QFilterCondition
        > {}

extension HealthWorkoutEntityQuerySortBy
    on QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QSortBy> {
  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  sortByActivityType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityType', Sort.asc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  sortByActivityTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityType', Sort.desc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  sortByCaloriesBurned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caloriesBurned', Sort.asc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  sortByCaloriesBurnedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caloriesBurned', Sort.desc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  sortByEndTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.asc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  sortByEndTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.desc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  sortByStartTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.asc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  sortByStartTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.desc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  sortByWorkoutId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workoutId', Sort.asc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  sortByWorkoutIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workoutId', Sort.desc);
    });
  }
}

extension HealthWorkoutEntityQuerySortThenBy
    on QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QSortThenBy> {
  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  thenByActivityType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityType', Sort.asc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  thenByActivityTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityType', Sort.desc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  thenByCaloriesBurned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caloriesBurned', Sort.asc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  thenByCaloriesBurnedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caloriesBurned', Sort.desc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  thenByEndTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.asc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  thenByEndTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.desc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  thenByStartTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.asc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  thenByStartTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.desc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  thenByWorkoutId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workoutId', Sort.asc);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QAfterSortBy>
  thenByWorkoutIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workoutId', Sort.desc);
    });
  }
}

extension HealthWorkoutEntityQueryWhereDistinct
    on QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QDistinct> {
  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QDistinct>
  distinctByActivityType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activityType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QDistinct>
  distinctByCaloriesBurned() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'caloriesBurned');
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QDistinct>
  distinctByEndTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endTime');
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QDistinct>
  distinctByStartTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startTime');
    });
  }

  QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QDistinct>
  distinctByWorkoutId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workoutId', caseSensitive: caseSensitive);
    });
  }
}

extension HealthWorkoutEntityQueryProperty
    on QueryBuilder<HealthWorkoutEntity, HealthWorkoutEntity, QQueryProperty> {
  QueryBuilder<HealthWorkoutEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<HealthWorkoutEntity, String, QQueryOperations>
  activityTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activityType');
    });
  }

  QueryBuilder<HealthWorkoutEntity, double?, QQueryOperations>
  caloriesBurnedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'caloriesBurned');
    });
  }

  QueryBuilder<HealthWorkoutEntity, DateTime, QQueryOperations>
  endTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endTime');
    });
  }

  QueryBuilder<HealthWorkoutEntity, DateTime, QQueryOperations>
  startTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startTime');
    });
  }

  QueryBuilder<HealthWorkoutEntity, String, QQueryOperations>
  workoutIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workoutId');
    });
  }
}
