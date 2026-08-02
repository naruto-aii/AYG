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
    r'baseAmount': PropertySchema(
      id: 0,
      name: r'baseAmount',
      type: IsarType.double,
    ),
    r'carbPerUnit': PropertySchema(
      id: 1,
      name: r'carbPerUnit',
      type: IsarType.double,
    ),
    r'consumedAmount': PropertySchema(
      id: 2,
      name: r'consumedAmount',
      type: IsarType.double,
    ),
    r'entryId': PropertySchema(id: 3, name: r'entryId', type: IsarType.string),
    r'fatPerUnit': PropertySchema(
      id: 4,
      name: r'fatPerUnit',
      type: IsarType.double,
    ),
    r'kcalPerUnit': PropertySchema(
      id: 5,
      name: r'kcalPerUnit',
      type: IsarType.double,
    ),
    r'loggedAt': PropertySchema(
      id: 6,
      name: r'loggedAt',
      type: IsarType.dateTime,
    ),
    r'mealGroupId': PropertySchema(
      id: 7,
      name: r'mealGroupId',
      type: IsarType.string,
    ),
    r'mealGroupName': PropertySchema(
      id: 8,
      name: r'mealGroupName',
      type: IsarType.string,
    ),
    r'name': PropertySchema(id: 9, name: r'name', type: IsarType.string),
    r'proteinPerUnit': PropertySchema(
      id: 10,
      name: r'proteinPerUnit',
      type: IsarType.double,
    ),
    r'quantity': PropertySchema(
      id: 11,
      name: r'quantity',
      type: IsarType.double,
    ),
    r'savedFoodId': PropertySchema(
      id: 12,
      name: r'savedFoodId',
      type: IsarType.string,
    ),
    r'sortOrder': PropertySchema(
      id: 13,
      name: r'sortOrder',
      type: IsarType.long,
    ),
    r'sourceFoodOwnerUserId': PropertySchema(
      id: 14,
      name: r'sourceFoodOwnerUserId',
      type: IsarType.string,
    ),
    r'sourceSavedFoodVersion': PropertySchema(
      id: 15,
      name: r'sourceSavedFoodVersion',
      type: IsarType.long,
    ),
    r'sourceTypeIndex': PropertySchema(
      id: 16,
      name: r'sourceTypeIndex',
      type: IsarType.long,
    ),
    r'unitTypeIndex': PropertySchema(
      id: 17,
      name: r'unitTypeIndex',
      type: IsarType.long,
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
  {
    final value = object.mealGroupId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.mealGroupName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  {
    final value = object.savedFoodId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.sourceFoodOwnerUserId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _foodEntryEntitySerialize(
  FoodEntryEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.baseAmount);
  writer.writeDouble(offsets[1], object.carbPerUnit);
  writer.writeDouble(offsets[2], object.consumedAmount);
  writer.writeString(offsets[3], object.entryId);
  writer.writeDouble(offsets[4], object.fatPerUnit);
  writer.writeDouble(offsets[5], object.kcalPerUnit);
  writer.writeDateTime(offsets[6], object.loggedAt);
  writer.writeString(offsets[7], object.mealGroupId);
  writer.writeString(offsets[8], object.mealGroupName);
  writer.writeString(offsets[9], object.name);
  writer.writeDouble(offsets[10], object.proteinPerUnit);
  writer.writeDouble(offsets[11], object.quantity);
  writer.writeString(offsets[12], object.savedFoodId);
  writer.writeLong(offsets[13], object.sortOrder);
  writer.writeString(offsets[14], object.sourceFoodOwnerUserId);
  writer.writeLong(offsets[15], object.sourceSavedFoodVersion);
  writer.writeLong(offsets[16], object.sourceTypeIndex);
  writer.writeLong(offsets[17], object.unitTypeIndex);
}

FoodEntryEntity _foodEntryEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = FoodEntryEntity();
  object.baseAmount = reader.readDoubleOrNull(offsets[0]);
  object.carbPerUnit = reader.readDoubleOrNull(offsets[1]);
  object.consumedAmount = reader.readDoubleOrNull(offsets[2]);
  object.entryId = reader.readString(offsets[3]);
  object.fatPerUnit = reader.readDoubleOrNull(offsets[4]);
  object.id = id;
  object.kcalPerUnit = reader.readDoubleOrNull(offsets[5]);
  object.loggedAt = reader.readDateTime(offsets[6]);
  object.mealGroupId = reader.readStringOrNull(offsets[7]);
  object.mealGroupName = reader.readStringOrNull(offsets[8]);
  object.name = reader.readString(offsets[9]);
  object.proteinPerUnit = reader.readDoubleOrNull(offsets[10]);
  object.quantity = reader.readDouble(offsets[11]);
  object.savedFoodId = reader.readStringOrNull(offsets[12]);
  object.sortOrder = reader.readLongOrNull(offsets[13]);
  object.sourceFoodOwnerUserId = reader.readStringOrNull(offsets[14]);
  object.sourceSavedFoodVersion = reader.readLongOrNull(offsets[15]);
  object.sourceTypeIndex = reader.readLongOrNull(offsets[16]);
  object.unitTypeIndex = reader.readLongOrNull(offsets[17]);
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
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readDoubleOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDoubleOrNull(offset)) as P;
    case 5:
      return (reader.readDoubleOrNull(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readDoubleOrNull(offset)) as P;
    case 11:
      return (reader.readDouble(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readLongOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readLongOrNull(offset)) as P;
    case 16:
      return (reader.readLongOrNull(offset)) as P;
    case 17:
      return (reader.readLongOrNull(offset)) as P;
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
  baseAmountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'baseAmount'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  baseAmountIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'baseAmount'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  baseAmountEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'baseAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  baseAmountGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'baseAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  baseAmountLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'baseAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  baseAmountBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'baseAmount',
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
  consumedAmountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'consumedAmount'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  consumedAmountIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'consumedAmount'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  consumedAmountEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'consumedAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  consumedAmountGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'consumedAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  consumedAmountLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'consumedAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  consumedAmountBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'consumedAmount',
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
  mealGroupIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'mealGroupId'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'mealGroupId'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'mealGroupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'mealGroupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'mealGroupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'mealGroupId',
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
  mealGroupIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'mealGroupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'mealGroupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'mealGroupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'mealGroupId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'mealGroupId', value: ''),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'mealGroupId', value: ''),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'mealGroupName'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'mealGroupName'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupNameEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'mealGroupName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'mealGroupName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'mealGroupName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'mealGroupName',
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
  mealGroupNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'mealGroupName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'mealGroupName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'mealGroupName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'mealGroupName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'mealGroupName', value: ''),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  mealGroupNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'mealGroupName', value: ''),
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

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  savedFoodIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'savedFoodId'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  savedFoodIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'savedFoodId'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  savedFoodIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'savedFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  savedFoodIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'savedFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  savedFoodIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'savedFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  savedFoodIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'savedFoodId',
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
  savedFoodIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'savedFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  savedFoodIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'savedFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  savedFoodIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'savedFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  savedFoodIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'savedFoodId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  savedFoodIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'savedFoodId', value: ''),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  savedFoodIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'savedFoodId', value: ''),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sortOrderIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sortOrder'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sortOrderIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sortOrder'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sortOrderEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sortOrder', value: value),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sortOrderGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sortOrder',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sortOrderLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sortOrder',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sortOrderBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sortOrder',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceFoodOwnerUserIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sourceFoodOwnerUserId'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceFoodOwnerUserIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sourceFoodOwnerUserId'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceFoodOwnerUserIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sourceFoodOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceFoodOwnerUserIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceFoodOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceFoodOwnerUserIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceFoodOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceFoodOwnerUserIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceFoodOwnerUserId',
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
  sourceFoodOwnerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sourceFoodOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceFoodOwnerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sourceFoodOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceFoodOwnerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sourceFoodOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceFoodOwnerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sourceFoodOwnerUserId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceFoodOwnerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceFoodOwnerUserId', value: ''),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceFoodOwnerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'sourceFoodOwnerUserId',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceSavedFoodVersionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sourceSavedFoodVersion'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceSavedFoodVersionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sourceSavedFoodVersion'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceSavedFoodVersionEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sourceSavedFoodVersion',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceSavedFoodVersionGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceSavedFoodVersion',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceSavedFoodVersionLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceSavedFoodVersion',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceSavedFoodVersionBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceSavedFoodVersion',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceTypeIndexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sourceTypeIndex'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceTypeIndexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sourceTypeIndex'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceTypeIndexEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceTypeIndex', value: value),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceTypeIndexGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceTypeIndexLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  sourceTypeIndexBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceTypeIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  unitTypeIndexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'unitTypeIndex'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  unitTypeIndexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'unitTypeIndex'),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  unitTypeIndexEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'unitTypeIndex', value: value),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  unitTypeIndexGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'unitTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  unitTypeIndexLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'unitTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterFilterCondition>
  unitTypeIndexBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'unitTypeIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
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
  sortByBaseAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseAmount', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByBaseAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseAmount', Sort.desc);
    });
  }

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

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByConsumedAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAmount', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByConsumedAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAmount', Sort.desc);
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

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByMealGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealGroupId', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByMealGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealGroupId', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByMealGroupName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealGroupName', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByMealGroupNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealGroupName', Sort.desc);
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

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortBySavedFoodId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'savedFoodId', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortBySavedFoodIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'savedFoodId', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortBySourceFoodOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceFoodOwnerUserId', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortBySourceFoodOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceFoodOwnerUserId', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortBySourceSavedFoodVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSavedFoodVersion', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortBySourceSavedFoodVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSavedFoodVersion', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortBySourceTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortBySourceTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceTypeIndex', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByUnitTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  sortByUnitTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitTypeIndex', Sort.desc);
    });
  }
}

extension FoodEntryEntityQuerySortThenBy
    on QueryBuilder<FoodEntryEntity, FoodEntryEntity, QSortThenBy> {
  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByBaseAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseAmount', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByBaseAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseAmount', Sort.desc);
    });
  }

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

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByConsumedAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAmount', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByConsumedAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAmount', Sort.desc);
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

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByMealGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealGroupId', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByMealGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealGroupId', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByMealGroupName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealGroupName', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByMealGroupNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealGroupName', Sort.desc);
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

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenBySavedFoodId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'savedFoodId', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenBySavedFoodIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'savedFoodId', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenBySourceFoodOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceFoodOwnerUserId', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenBySourceFoodOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceFoodOwnerUserId', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenBySourceSavedFoodVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSavedFoodVersion', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenBySourceSavedFoodVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSavedFoodVersion', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenBySourceTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenBySourceTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceTypeIndex', Sort.desc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByUnitTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QAfterSortBy>
  thenByUnitTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitTypeIndex', Sort.desc);
    });
  }
}

extension FoodEntryEntityQueryWhereDistinct
    on QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct> {
  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctByBaseAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'baseAmount');
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctByCarbPerUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'carbPerUnit');
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctByConsumedAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'consumedAmount');
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

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctByMealGroupId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mealGroupId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctByMealGroupName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'mealGroupName',
        caseSensitive: caseSensitive,
      );
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

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctBySavedFoodId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'savedFoodId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sortOrder');
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctBySourceFoodOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'sourceFoodOwnerUserId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctBySourceSavedFoodVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceSavedFoodVersion');
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctBySourceTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceTypeIndex');
    });
  }

  QueryBuilder<FoodEntryEntity, FoodEntryEntity, QDistinct>
  distinctByUnitTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unitTypeIndex');
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
  baseAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'baseAmount');
    });
  }

  QueryBuilder<FoodEntryEntity, double?, QQueryOperations>
  carbPerUnitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'carbPerUnit');
    });
  }

  QueryBuilder<FoodEntryEntity, double?, QQueryOperations>
  consumedAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'consumedAmount');
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

  QueryBuilder<FoodEntryEntity, String?, QQueryOperations>
  mealGroupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mealGroupId');
    });
  }

  QueryBuilder<FoodEntryEntity, String?, QQueryOperations>
  mealGroupNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mealGroupName');
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

  QueryBuilder<FoodEntryEntity, String?, QQueryOperations>
  savedFoodIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'savedFoodId');
    });
  }

  QueryBuilder<FoodEntryEntity, int?, QQueryOperations> sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sortOrder');
    });
  }

  QueryBuilder<FoodEntryEntity, String?, QQueryOperations>
  sourceFoodOwnerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceFoodOwnerUserId');
    });
  }

  QueryBuilder<FoodEntryEntity, int?, QQueryOperations>
  sourceSavedFoodVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceSavedFoodVersion');
    });
  }

  QueryBuilder<FoodEntryEntity, int?, QQueryOperations>
  sourceTypeIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceTypeIndex');
    });
  }

  QueryBuilder<FoodEntryEntity, int?, QQueryOperations>
  unitTypeIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unitTypeIndex');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSavedFoodEntityCollection on Isar {
  IsarCollection<SavedFoodEntity> get savedFoodEntitys => this.collection();
}

const SavedFoodEntitySchema = CollectionSchema(
  name: r'SavedFoodEntity',
  id: -7737197941488531568,
  properties: {
    r'barcode': PropertySchema(id: 0, name: r'barcode', type: IsarType.string),
    r'baseAmount': PropertySchema(
      id: 1,
      name: r'baseAmount',
      type: IsarType.double,
    ),
    r'brand': PropertySchema(id: 2, name: r'brand', type: IsarType.string),
    r'carbPerBase': PropertySchema(
      id: 3,
      name: r'carbPerBase',
      type: IsarType.double,
    ),
    r'copiedFromFoodId': PropertySchema(
      id: 4,
      name: r'copiedFromFoodId',
      type: IsarType.string,
    ),
    r'copiedFromOwnerUserId': PropertySchema(
      id: 5,
      name: r'copiedFromOwnerUserId',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 6,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'deletedAt': PropertySchema(
      id: 7,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'fatPerBase': PropertySchema(
      id: 8,
      name: r'fatPerBase',
      type: IsarType.double,
    ),
    r'foodId': PropertySchema(id: 9, name: r'foodId', type: IsarType.string),
    r'kcalPerBase': PropertySchema(
      id: 10,
      name: r'kcalPerBase',
      type: IsarType.double,
    ),
    r'lastUsedAt': PropertySchema(
      id: 11,
      name: r'lastUsedAt',
      type: IsarType.dateTime,
    ),
    r'moderationStatusIndex': PropertySchema(
      id: 12,
      name: r'moderationStatusIndex',
      type: IsarType.long,
    ),
    r'name': PropertySchema(id: 13, name: r'name', type: IsarType.string),
    r'normalizedName': PropertySchema(
      id: 14,
      name: r'normalizedName',
      type: IsarType.string,
    ),
    r'ownerUserId': PropertySchema(
      id: 15,
      name: r'ownerUserId',
      type: IsarType.string,
    ),
    r'proteinPerBase': PropertySchema(
      id: 16,
      name: r'proteinPerBase',
      type: IsarType.double,
    ),
    r'reportCount': PropertySchema(
      id: 17,
      name: r'reportCount',
      type: IsarType.long,
    ),
    r'servingUnitLabel': PropertySchema(
      id: 18,
      name: r'servingUnitLabel',
      type: IsarType.string,
    ),
    r'sourceTypeIndex': PropertySchema(
      id: 19,
      name: r'sourceTypeIndex',
      type: IsarType.long,
    ),
    r'statusIndex': PropertySchema(
      id: 20,
      name: r'statusIndex',
      type: IsarType.long,
    ),
    r'supplementaryWeight': PropertySchema(
      id: 21,
      name: r'supplementaryWeight',
      type: IsarType.string,
    ),
    r'unitTypeIndex': PropertySchema(
      id: 22,
      name: r'unitTypeIndex',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 23,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'useCount': PropertySchema(id: 24, name: r'useCount', type: IsarType.long),
    r'version': PropertySchema(id: 25, name: r'version', type: IsarType.long),
    r'visibilityIndex': PropertySchema(
      id: 26,
      name: r'visibilityIndex',
      type: IsarType.long,
    ),
  },
  estimateSize: _savedFoodEntityEstimateSize,
  serialize: _savedFoodEntitySerialize,
  deserialize: _savedFoodEntityDeserialize,
  deserializeProp: _savedFoodEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'foodId': IndexSchema(
      id: 6823679418906861405,
      name: r'foodId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'foodId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'ownerUserId': IndexSchema(
      id: 1631799950038639233,
      name: r'ownerUserId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'ownerUserId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'normalizedName': IndexSchema(
      id: -9115371092206571671,
      name: r'normalizedName',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'normalizedName',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _savedFoodEntityGetId,
  getLinks: _savedFoodEntityGetLinks,
  attach: _savedFoodEntityAttach,
  version: '3.1.0+1',
);

int _savedFoodEntityEstimateSize(
  SavedFoodEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.barcode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.brand;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.copiedFromFoodId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.copiedFromOwnerUserId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.foodId.length * 3;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.normalizedName.length * 3;
  bytesCount += 3 + object.ownerUserId.length * 3;
  {
    final value = object.servingUnitLabel;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.supplementaryWeight;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _savedFoodEntitySerialize(
  SavedFoodEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.barcode);
  writer.writeDouble(offsets[1], object.baseAmount);
  writer.writeString(offsets[2], object.brand);
  writer.writeDouble(offsets[3], object.carbPerBase);
  writer.writeString(offsets[4], object.copiedFromFoodId);
  writer.writeString(offsets[5], object.copiedFromOwnerUserId);
  writer.writeDateTime(offsets[6], object.createdAt);
  writer.writeDateTime(offsets[7], object.deletedAt);
  writer.writeDouble(offsets[8], object.fatPerBase);
  writer.writeString(offsets[9], object.foodId);
  writer.writeDouble(offsets[10], object.kcalPerBase);
  writer.writeDateTime(offsets[11], object.lastUsedAt);
  writer.writeLong(offsets[12], object.moderationStatusIndex);
  writer.writeString(offsets[13], object.name);
  writer.writeString(offsets[14], object.normalizedName);
  writer.writeString(offsets[15], object.ownerUserId);
  writer.writeDouble(offsets[16], object.proteinPerBase);
  writer.writeLong(offsets[17], object.reportCount);
  writer.writeString(offsets[18], object.servingUnitLabel);
  writer.writeLong(offsets[19], object.sourceTypeIndex);
  writer.writeLong(offsets[20], object.statusIndex);
  writer.writeString(offsets[21], object.supplementaryWeight);
  writer.writeLong(offsets[22], object.unitTypeIndex);
  writer.writeDateTime(offsets[23], object.updatedAt);
  writer.writeLong(offsets[24], object.useCount);
  writer.writeLong(offsets[25], object.version);
  writer.writeLong(offsets[26], object.visibilityIndex);
}

SavedFoodEntity _savedFoodEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SavedFoodEntity();
  object.barcode = reader.readStringOrNull(offsets[0]);
  object.baseAmount = reader.readDouble(offsets[1]);
  object.brand = reader.readStringOrNull(offsets[2]);
  object.carbPerBase = reader.readDoubleOrNull(offsets[3]);
  object.copiedFromFoodId = reader.readStringOrNull(offsets[4]);
  object.copiedFromOwnerUserId = reader.readStringOrNull(offsets[5]);
  object.createdAt = reader.readDateTime(offsets[6]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[7]);
  object.fatPerBase = reader.readDoubleOrNull(offsets[8]);
  object.foodId = reader.readString(offsets[9]);
  object.id = id;
  object.kcalPerBase = reader.readDoubleOrNull(offsets[10]);
  object.lastUsedAt = reader.readDateTimeOrNull(offsets[11]);
  object.moderationStatusIndex = reader.readLong(offsets[12]);
  object.name = reader.readString(offsets[13]);
  object.normalizedName = reader.readString(offsets[14]);
  object.ownerUserId = reader.readString(offsets[15]);
  object.proteinPerBase = reader.readDoubleOrNull(offsets[16]);
  object.reportCount = reader.readLong(offsets[17]);
  object.servingUnitLabel = reader.readStringOrNull(offsets[18]);
  object.sourceTypeIndex = reader.readLong(offsets[19]);
  object.statusIndex = reader.readLong(offsets[20]);
  object.supplementaryWeight = reader.readStringOrNull(offsets[21]);
  object.unitTypeIndex = reader.readLong(offsets[22]);
  object.updatedAt = reader.readDateTime(offsets[23]);
  object.useCount = reader.readLong(offsets[24]);
  object.version = reader.readLong(offsets[25]);
  object.visibilityIndex = reader.readLong(offsets[26]);
  return object;
}

P _savedFoodEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readDoubleOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 8:
      return (reader.readDoubleOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readDoubleOrNull(offset)) as P;
    case 11:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 12:
      return (reader.readLong(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    case 16:
      return (reader.readDoubleOrNull(offset)) as P;
    case 17:
      return (reader.readLong(offset)) as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    case 19:
      return (reader.readLong(offset)) as P;
    case 20:
      return (reader.readLong(offset)) as P;
    case 21:
      return (reader.readStringOrNull(offset)) as P;
    case 22:
      return (reader.readLong(offset)) as P;
    case 23:
      return (reader.readDateTime(offset)) as P;
    case 24:
      return (reader.readLong(offset)) as P;
    case 25:
      return (reader.readLong(offset)) as P;
    case 26:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _savedFoodEntityGetId(SavedFoodEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _savedFoodEntityGetLinks(SavedFoodEntity object) {
  return [];
}

void _savedFoodEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  SavedFoodEntity object,
) {
  object.id = id;
}

extension SavedFoodEntityByIndex on IsarCollection<SavedFoodEntity> {
  Future<SavedFoodEntity?> getByFoodId(String foodId) {
    return getByIndex(r'foodId', [foodId]);
  }

  SavedFoodEntity? getByFoodIdSync(String foodId) {
    return getByIndexSync(r'foodId', [foodId]);
  }

  Future<bool> deleteByFoodId(String foodId) {
    return deleteByIndex(r'foodId', [foodId]);
  }

  bool deleteByFoodIdSync(String foodId) {
    return deleteByIndexSync(r'foodId', [foodId]);
  }

  Future<List<SavedFoodEntity?>> getAllByFoodId(List<String> foodIdValues) {
    final values = foodIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'foodId', values);
  }

  List<SavedFoodEntity?> getAllByFoodIdSync(List<String> foodIdValues) {
    final values = foodIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'foodId', values);
  }

  Future<int> deleteAllByFoodId(List<String> foodIdValues) {
    final values = foodIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'foodId', values);
  }

  int deleteAllByFoodIdSync(List<String> foodIdValues) {
    final values = foodIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'foodId', values);
  }

  Future<Id> putByFoodId(SavedFoodEntity object) {
    return putByIndex(r'foodId', object);
  }

  Id putByFoodIdSync(SavedFoodEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'foodId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFoodId(List<SavedFoodEntity> objects) {
    return putAllByIndex(r'foodId', objects);
  }

  List<Id> putAllByFoodIdSync(
    List<SavedFoodEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'foodId', objects, saveLinks: saveLinks);
  }
}

extension SavedFoodEntityQueryWhereSort
    on QueryBuilder<SavedFoodEntity, SavedFoodEntity, QWhere> {
  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SavedFoodEntityQueryWhere
    on QueryBuilder<SavedFoodEntity, SavedFoodEntity, QWhereClause> {
  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterWhereClause>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterWhereClause> idBetween(
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterWhereClause>
  foodIdEqualTo(String foodId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'foodId', value: [foodId]),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterWhereClause>
  foodIdNotEqualTo(String foodId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'foodId',
                lower: [],
                upper: [foodId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'foodId',
                lower: [foodId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'foodId',
                lower: [foodId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'foodId',
                lower: [],
                upper: [foodId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterWhereClause>
  ownerUserIdEqualTo(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'ownerUserId',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterWhereClause>
  ownerUserIdNotEqualTo(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterWhereClause>
  normalizedNameEqualTo(String normalizedName) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'normalizedName',
          value: [normalizedName],
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterWhereClause>
  normalizedNameNotEqualTo(String normalizedName) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'normalizedName',
                lower: [],
                upper: [normalizedName],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'normalizedName',
                lower: [normalizedName],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'normalizedName',
                lower: [normalizedName],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'normalizedName',
                lower: [],
                upper: [normalizedName],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension SavedFoodEntityQueryFilter
    on QueryBuilder<SavedFoodEntity, SavedFoodEntity, QFilterCondition> {
  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  barcodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'barcode'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  barcodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'barcode'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  barcodeEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'barcode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  barcodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'barcode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  barcodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'barcode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  barcodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'barcode',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  barcodeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'barcode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  barcodeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'barcode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  barcodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'barcode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  barcodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'barcode',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  barcodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'barcode', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  barcodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'barcode', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  baseAmountEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'baseAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  baseAmountGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'baseAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  baseAmountLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'baseAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  baseAmountBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'baseAmount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  brandIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'brand'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  brandIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'brand'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  brandEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'brand',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  brandGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'brand',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  brandLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'brand',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  brandBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'brand',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  brandStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'brand',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  brandEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'brand',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  brandContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'brand',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  brandMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'brand',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  brandIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'brand', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  brandIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'brand', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  carbPerBaseIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'carbPerBase'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  carbPerBaseIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'carbPerBase'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  carbPerBaseEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'carbPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  carbPerBaseGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'carbPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  carbPerBaseLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'carbPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  carbPerBaseBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'carbPerBase',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromFoodIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'copiedFromFoodId'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromFoodIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'copiedFromFoodId'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromFoodIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'copiedFromFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromFoodIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'copiedFromFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromFoodIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'copiedFromFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromFoodIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'copiedFromFoodId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromFoodIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'copiedFromFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromFoodIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'copiedFromFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromFoodIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'copiedFromFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromFoodIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'copiedFromFoodId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromFoodIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'copiedFromFoodId', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromFoodIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'copiedFromFoodId', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromOwnerUserIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'copiedFromOwnerUserId'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromOwnerUserIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'copiedFromOwnerUserId'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromOwnerUserIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'copiedFromOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromOwnerUserIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'copiedFromOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromOwnerUserIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'copiedFromOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromOwnerUserIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'copiedFromOwnerUserId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromOwnerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'copiedFromOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromOwnerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'copiedFromOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromOwnerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'copiedFromOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromOwnerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'copiedFromOwnerUserId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromOwnerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'copiedFromOwnerUserId', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  copiedFromOwnerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'copiedFromOwnerUserId',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'deletedAt'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'deletedAt'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'deletedAt', value: value),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  deletedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'deletedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  deletedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'deletedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  deletedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'deletedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  fatPerBaseIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'fatPerBase'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  fatPerBaseIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'fatPerBase'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  fatPerBaseEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fatPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  fatPerBaseGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fatPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  fatPerBaseLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fatPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  fatPerBaseBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fatPerBase',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  foodIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'foodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  foodIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'foodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  foodIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'foodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  foodIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'foodId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  foodIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'foodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  foodIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'foodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  foodIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'foodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  foodIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'foodId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  foodIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'foodId', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  foodIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'foodId', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  kcalPerBaseIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'kcalPerBase'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  kcalPerBaseIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'kcalPerBase'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  kcalPerBaseEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'kcalPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  kcalPerBaseGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'kcalPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  kcalPerBaseLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'kcalPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  kcalPerBaseBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'kcalPerBase',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  lastUsedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastUsedAt'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  lastUsedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastUsedAt'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  lastUsedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastUsedAt', value: value),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  lastUsedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastUsedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  lastUsedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastUsedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  lastUsedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastUsedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  moderationStatusIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'moderationStatusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  moderationStatusIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'moderationStatusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  moderationStatusIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'moderationStatusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  moderationStatusIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'moderationStatusIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  normalizedNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  normalizedNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  normalizedNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  normalizedNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'normalizedName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  normalizedNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  normalizedNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  normalizedNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  normalizedNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'normalizedName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  normalizedNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'normalizedName', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  normalizedNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'normalizedName', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ownerUserId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'ownerUserId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ownerUserId', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ownerUserId', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  proteinPerBaseIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'proteinPerBase'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  proteinPerBaseIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'proteinPerBase'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  proteinPerBaseEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'proteinPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  proteinPerBaseGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'proteinPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  proteinPerBaseLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'proteinPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  proteinPerBaseBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'proteinPerBase',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  reportCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'reportCount', value: value),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  reportCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'reportCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  reportCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'reportCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  reportCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'reportCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  servingUnitLabelIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'servingUnitLabel'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  servingUnitLabelIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'servingUnitLabel'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  servingUnitLabelEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'servingUnitLabel',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  servingUnitLabelGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'servingUnitLabel',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  servingUnitLabelLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'servingUnitLabel',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  servingUnitLabelBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'servingUnitLabel',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  servingUnitLabelStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'servingUnitLabel',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  servingUnitLabelEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'servingUnitLabel',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  servingUnitLabelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'servingUnitLabel',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  servingUnitLabelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'servingUnitLabel',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  servingUnitLabelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'servingUnitLabel', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  servingUnitLabelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'servingUnitLabel', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  sourceTypeIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceTypeIndex', value: value),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  sourceTypeIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  sourceTypeIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  sourceTypeIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceTypeIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  statusIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'statusIndex', value: value),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  statusIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'statusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  statusIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'statusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  statusIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'statusIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  supplementaryWeightIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'supplementaryWeight'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  supplementaryWeightIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'supplementaryWeight'),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  supplementaryWeightEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'supplementaryWeight',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  supplementaryWeightGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'supplementaryWeight',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  supplementaryWeightLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'supplementaryWeight',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  supplementaryWeightBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'supplementaryWeight',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  supplementaryWeightStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'supplementaryWeight',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  supplementaryWeightEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'supplementaryWeight',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  supplementaryWeightContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'supplementaryWeight',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  supplementaryWeightMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'supplementaryWeight',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  supplementaryWeightIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'supplementaryWeight', value: ''),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  supplementaryWeightIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'supplementaryWeight',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  unitTypeIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'unitTypeIndex', value: value),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  unitTypeIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'unitTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  unitTypeIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'unitTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  unitTypeIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'unitTypeIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
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

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  useCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'useCount', value: value),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  useCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'useCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  useCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'useCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  useCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'useCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'version', value: value),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  versionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'version',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  versionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'version',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  versionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'version',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  visibilityIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'visibilityIndex', value: value),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  visibilityIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'visibilityIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  visibilityIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'visibilityIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterFilterCondition>
  visibilityIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'visibilityIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SavedFoodEntityQueryObject
    on QueryBuilder<SavedFoodEntity, SavedFoodEntity, QFilterCondition> {}

extension SavedFoodEntityQueryLinks
    on QueryBuilder<SavedFoodEntity, SavedFoodEntity, QFilterCondition> {}

extension SavedFoodEntityQuerySortBy
    on QueryBuilder<SavedFoodEntity, SavedFoodEntity, QSortBy> {
  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy> sortByBarcode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barcode', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByBarcodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barcode', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByBaseAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseAmount', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByBaseAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseAmount', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy> sortByBrand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByBrandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByCarbPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbPerBase', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByCarbPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbPerBase', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByCopiedFromFoodId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'copiedFromFoodId', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByCopiedFromFoodIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'copiedFromFoodId', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByCopiedFromOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'copiedFromOwnerUserId', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByCopiedFromOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'copiedFromOwnerUserId', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByFatPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatPerBase', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByFatPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatPerBase', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy> sortByFoodId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'foodId', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByFoodIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'foodId', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByKcalPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kcalPerBase', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByKcalPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kcalPerBase', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByModerationStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moderationStatusIndex', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByModerationStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moderationStatusIndex', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByNormalizedName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedName', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByNormalizedNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedName', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByProteinPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinPerBase', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByProteinPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinPerBase', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByReportCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportCount', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByReportCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportCount', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByServingUnitLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servingUnitLabel', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByServingUnitLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servingUnitLabel', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortBySourceTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortBySourceTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceTypeIndex', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusIndex', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusIndex', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortBySupplementaryWeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supplementaryWeight', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortBySupplementaryWeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supplementaryWeight', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByUnitTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByUnitTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitTypeIndex', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByUseCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByVisibilityIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibilityIndex', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  sortByVisibilityIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibilityIndex', Sort.desc);
    });
  }
}

extension SavedFoodEntityQuerySortThenBy
    on QueryBuilder<SavedFoodEntity, SavedFoodEntity, QSortThenBy> {
  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy> thenByBarcode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barcode', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByBarcodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barcode', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByBaseAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseAmount', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByBaseAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseAmount', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy> thenByBrand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByBrandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByCarbPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbPerBase', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByCarbPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbPerBase', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByCopiedFromFoodId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'copiedFromFoodId', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByCopiedFromFoodIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'copiedFromFoodId', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByCopiedFromOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'copiedFromOwnerUserId', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByCopiedFromOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'copiedFromOwnerUserId', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByFatPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatPerBase', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByFatPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatPerBase', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy> thenByFoodId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'foodId', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByFoodIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'foodId', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByKcalPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kcalPerBase', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByKcalPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kcalPerBase', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByModerationStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moderationStatusIndex', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByModerationStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moderationStatusIndex', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByNormalizedName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedName', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByNormalizedNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedName', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByProteinPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinPerBase', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByProteinPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinPerBase', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByReportCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportCount', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByReportCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportCount', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByServingUnitLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servingUnitLabel', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByServingUnitLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servingUnitLabel', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenBySourceTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenBySourceTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceTypeIndex', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusIndex', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusIndex', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenBySupplementaryWeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supplementaryWeight', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenBySupplementaryWeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supplementaryWeight', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByUnitTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByUnitTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitTypeIndex', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByUseCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByVisibilityIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibilityIndex', Sort.asc);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QAfterSortBy>
  thenByVisibilityIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibilityIndex', Sort.desc);
    });
  }
}

extension SavedFoodEntityQueryWhereDistinct
    on QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct> {
  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct> distinctByBarcode({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'barcode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByBaseAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'baseAmount');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct> distinctByBrand({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'brand', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByCarbPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'carbPerBase');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByCopiedFromFoodId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'copiedFromFoodId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByCopiedFromOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'copiedFromOwnerUserId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByFatPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fatPerBase');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct> distinctByFoodId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'foodId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByKcalPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kcalPerBase');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUsedAt');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByModerationStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'moderationStatusIndex');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByNormalizedName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'normalizedName',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerUserId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByProteinPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'proteinPerBase');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByReportCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reportCount');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByServingUnitLabel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'servingUnitLabel',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctBySourceTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceTypeIndex');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'statusIndex');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctBySupplementaryWeight({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'supplementaryWeight',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByUnitTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unitTypeIndex');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'useCount');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }

  QueryBuilder<SavedFoodEntity, SavedFoodEntity, QDistinct>
  distinctByVisibilityIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'visibilityIndex');
    });
  }
}

extension SavedFoodEntityQueryProperty
    on QueryBuilder<SavedFoodEntity, SavedFoodEntity, QQueryProperty> {
  QueryBuilder<SavedFoodEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SavedFoodEntity, String?, QQueryOperations> barcodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'barcode');
    });
  }

  QueryBuilder<SavedFoodEntity, double, QQueryOperations> baseAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'baseAmount');
    });
  }

  QueryBuilder<SavedFoodEntity, String?, QQueryOperations> brandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'brand');
    });
  }

  QueryBuilder<SavedFoodEntity, double?, QQueryOperations>
  carbPerBaseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'carbPerBase');
    });
  }

  QueryBuilder<SavedFoodEntity, String?, QQueryOperations>
  copiedFromFoodIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'copiedFromFoodId');
    });
  }

  QueryBuilder<SavedFoodEntity, String?, QQueryOperations>
  copiedFromOwnerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'copiedFromOwnerUserId');
    });
  }

  QueryBuilder<SavedFoodEntity, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<SavedFoodEntity, DateTime?, QQueryOperations>
  deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<SavedFoodEntity, double?, QQueryOperations>
  fatPerBaseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fatPerBase');
    });
  }

  QueryBuilder<SavedFoodEntity, String, QQueryOperations> foodIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'foodId');
    });
  }

  QueryBuilder<SavedFoodEntity, double?, QQueryOperations>
  kcalPerBaseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kcalPerBase');
    });
  }

  QueryBuilder<SavedFoodEntity, DateTime?, QQueryOperations>
  lastUsedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUsedAt');
    });
  }

  QueryBuilder<SavedFoodEntity, int, QQueryOperations>
  moderationStatusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'moderationStatusIndex');
    });
  }

  QueryBuilder<SavedFoodEntity, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<SavedFoodEntity, String, QQueryOperations>
  normalizedNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'normalizedName');
    });
  }

  QueryBuilder<SavedFoodEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerUserId');
    });
  }

  QueryBuilder<SavedFoodEntity, double?, QQueryOperations>
  proteinPerBaseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'proteinPerBase');
    });
  }

  QueryBuilder<SavedFoodEntity, int, QQueryOperations> reportCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reportCount');
    });
  }

  QueryBuilder<SavedFoodEntity, String?, QQueryOperations>
  servingUnitLabelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'servingUnitLabel');
    });
  }

  QueryBuilder<SavedFoodEntity, int, QQueryOperations>
  sourceTypeIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceTypeIndex');
    });
  }

  QueryBuilder<SavedFoodEntity, int, QQueryOperations> statusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'statusIndex');
    });
  }

  QueryBuilder<SavedFoodEntity, String?, QQueryOperations>
  supplementaryWeightProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'supplementaryWeight');
    });
  }

  QueryBuilder<SavedFoodEntity, int, QQueryOperations> unitTypeIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unitTypeIndex');
    });
  }

  QueryBuilder<SavedFoodEntity, DateTime, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<SavedFoodEntity, int, QQueryOperations> useCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'useCount');
    });
  }

  QueryBuilder<SavedFoodEntity, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }

  QueryBuilder<SavedFoodEntity, int, QQueryOperations>
  visibilityIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'visibilityIndex');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMealTemplateEntityCollection on Isar {
  IsarCollection<MealTemplateEntity> get mealTemplateEntitys =>
      this.collection();
}

const MealTemplateEntitySchema = CollectionSchema(
  name: r'MealTemplateEntity',
  id: -1849159200932219738,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'deletedAt': PropertySchema(
      id: 1,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'dependencyStatusIndex': PropertySchema(
      id: 2,
      name: r'dependencyStatusIndex',
      type: IsarType.long,
    ),
    r'lastUsedAt': PropertySchema(
      id: 3,
      name: r'lastUsedAt',
      type: IsarType.dateTime,
    ),
    r'lastValidatedAt': PropertySchema(
      id: 4,
      name: r'lastValidatedAt',
      type: IsarType.dateTime,
    ),
    r'name': PropertySchema(id: 5, name: r'name', type: IsarType.string),
    r'normalizedName': PropertySchema(
      id: 6,
      name: r'normalizedName',
      type: IsarType.string,
    ),
    r'ownerUserId': PropertySchema(
      id: 7,
      name: r'ownerUserId',
      type: IsarType.string,
    ),
    r'statusIndex': PropertySchema(
      id: 8,
      name: r'statusIndex',
      type: IsarType.long,
    ),
    r'templateId': PropertySchema(
      id: 9,
      name: r'templateId',
      type: IsarType.string,
    ),
    r'totalCarbG': PropertySchema(
      id: 10,
      name: r'totalCarbG',
      type: IsarType.double,
    ),
    r'totalFatG': PropertySchema(
      id: 11,
      name: r'totalFatG',
      type: IsarType.double,
    ),
    r'totalKcal': PropertySchema(
      id: 12,
      name: r'totalKcal',
      type: IsarType.double,
    ),
    r'totalProteinG': PropertySchema(
      id: 13,
      name: r'totalProteinG',
      type: IsarType.double,
    ),
    r'updatedAt': PropertySchema(
      id: 14,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'useCount': PropertySchema(id: 15, name: r'useCount', type: IsarType.long),
    r'visibilityIndex': PropertySchema(
      id: 16,
      name: r'visibilityIndex',
      type: IsarType.long,
    ),
  },
  estimateSize: _mealTemplateEntityEstimateSize,
  serialize: _mealTemplateEntitySerialize,
  deserialize: _mealTemplateEntityDeserialize,
  deserializeProp: _mealTemplateEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'templateId': IndexSchema(
      id: -5352721467389445085,
      name: r'templateId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'templateId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'ownerUserId': IndexSchema(
      id: 1631799950038639233,
      name: r'ownerUserId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'ownerUserId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'normalizedName': IndexSchema(
      id: -9115371092206571671,
      name: r'normalizedName',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'normalizedName',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _mealTemplateEntityGetId,
  getLinks: _mealTemplateEntityGetLinks,
  attach: _mealTemplateEntityAttach,
  version: '3.1.0+1',
);

int _mealTemplateEntityEstimateSize(
  MealTemplateEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.normalizedName.length * 3;
  bytesCount += 3 + object.ownerUserId.length * 3;
  bytesCount += 3 + object.templateId.length * 3;
  return bytesCount;
}

void _mealTemplateEntitySerialize(
  MealTemplateEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeDateTime(offsets[1], object.deletedAt);
  writer.writeLong(offsets[2], object.dependencyStatusIndex);
  writer.writeDateTime(offsets[3], object.lastUsedAt);
  writer.writeDateTime(offsets[4], object.lastValidatedAt);
  writer.writeString(offsets[5], object.name);
  writer.writeString(offsets[6], object.normalizedName);
  writer.writeString(offsets[7], object.ownerUserId);
  writer.writeLong(offsets[8], object.statusIndex);
  writer.writeString(offsets[9], object.templateId);
  writer.writeDouble(offsets[10], object.totalCarbG);
  writer.writeDouble(offsets[11], object.totalFatG);
  writer.writeDouble(offsets[12], object.totalKcal);
  writer.writeDouble(offsets[13], object.totalProteinG);
  writer.writeDateTime(offsets[14], object.updatedAt);
  writer.writeLong(offsets[15], object.useCount);
  writer.writeLong(offsets[16], object.visibilityIndex);
}

MealTemplateEntity _mealTemplateEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MealTemplateEntity();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[1]);
  object.dependencyStatusIndex = reader.readLong(offsets[2]);
  object.id = id;
  object.lastUsedAt = reader.readDateTimeOrNull(offsets[3]);
  object.lastValidatedAt = reader.readDateTimeOrNull(offsets[4]);
  object.name = reader.readString(offsets[5]);
  object.normalizedName = reader.readString(offsets[6]);
  object.ownerUserId = reader.readString(offsets[7]);
  object.statusIndex = reader.readLong(offsets[8]);
  object.templateId = reader.readString(offsets[9]);
  object.totalCarbG = reader.readDouble(offsets[10]);
  object.totalFatG = reader.readDouble(offsets[11]);
  object.totalKcal = reader.readDouble(offsets[12]);
  object.totalProteinG = reader.readDouble(offsets[13]);
  object.updatedAt = reader.readDateTime(offsets[14]);
  object.useCount = reader.readLong(offsets[15]);
  object.visibilityIndex = reader.readLong(offsets[16]);
  return object;
}

P _mealTemplateEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readDouble(offset)) as P;
    case 11:
      return (reader.readDouble(offset)) as P;
    case 12:
      return (reader.readDouble(offset)) as P;
    case 13:
      return (reader.readDouble(offset)) as P;
    case 14:
      return (reader.readDateTime(offset)) as P;
    case 15:
      return (reader.readLong(offset)) as P;
    case 16:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _mealTemplateEntityGetId(MealTemplateEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _mealTemplateEntityGetLinks(
  MealTemplateEntity object,
) {
  return [];
}

void _mealTemplateEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  MealTemplateEntity object,
) {
  object.id = id;
}

extension MealTemplateEntityByIndex on IsarCollection<MealTemplateEntity> {
  Future<MealTemplateEntity?> getByTemplateId(String templateId) {
    return getByIndex(r'templateId', [templateId]);
  }

  MealTemplateEntity? getByTemplateIdSync(String templateId) {
    return getByIndexSync(r'templateId', [templateId]);
  }

  Future<bool> deleteByTemplateId(String templateId) {
    return deleteByIndex(r'templateId', [templateId]);
  }

  bool deleteByTemplateIdSync(String templateId) {
    return deleteByIndexSync(r'templateId', [templateId]);
  }

  Future<List<MealTemplateEntity?>> getAllByTemplateId(
    List<String> templateIdValues,
  ) {
    final values = templateIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'templateId', values);
  }

  List<MealTemplateEntity?> getAllByTemplateIdSync(
    List<String> templateIdValues,
  ) {
    final values = templateIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'templateId', values);
  }

  Future<int> deleteAllByTemplateId(List<String> templateIdValues) {
    final values = templateIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'templateId', values);
  }

  int deleteAllByTemplateIdSync(List<String> templateIdValues) {
    final values = templateIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'templateId', values);
  }

  Future<Id> putByTemplateId(MealTemplateEntity object) {
    return putByIndex(r'templateId', object);
  }

  Id putByTemplateIdSync(MealTemplateEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'templateId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByTemplateId(List<MealTemplateEntity> objects) {
    return putAllByIndex(r'templateId', objects);
  }

  List<Id> putAllByTemplateIdSync(
    List<MealTemplateEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'templateId', objects, saveLinks: saveLinks);
  }
}

extension MealTemplateEntityQueryWhereSort
    on QueryBuilder<MealTemplateEntity, MealTemplateEntity, QWhere> {
  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MealTemplateEntityQueryWhere
    on QueryBuilder<MealTemplateEntity, MealTemplateEntity, QWhereClause> {
  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterWhereClause>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterWhereClause>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterWhereClause>
  templateIdEqualTo(String templateId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'templateId', value: [templateId]),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterWhereClause>
  templateIdNotEqualTo(String templateId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [],
                upper: [templateId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [templateId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [templateId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [],
                upper: [templateId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterWhereClause>
  ownerUserIdEqualTo(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'ownerUserId',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterWhereClause>
  ownerUserIdNotEqualTo(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterWhereClause>
  normalizedNameEqualTo(String normalizedName) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'normalizedName',
          value: [normalizedName],
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterWhereClause>
  normalizedNameNotEqualTo(String normalizedName) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'normalizedName',
                lower: [],
                upper: [normalizedName],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'normalizedName',
                lower: [normalizedName],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'normalizedName',
                lower: [normalizedName],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'normalizedName',
                lower: [],
                upper: [normalizedName],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension MealTemplateEntityQueryFilter
    on QueryBuilder<MealTemplateEntity, MealTemplateEntity, QFilterCondition> {
  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'deletedAt'),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'deletedAt'),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'deletedAt', value: value),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  deletedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'deletedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  deletedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'deletedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  deletedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'deletedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  dependencyStatusIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'dependencyStatusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  dependencyStatusIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dependencyStatusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  dependencyStatusIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dependencyStatusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  dependencyStatusIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dependencyStatusIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  lastUsedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastUsedAt'),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  lastUsedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastUsedAt'),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  lastUsedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastUsedAt', value: value),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  lastUsedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastUsedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  lastUsedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastUsedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  lastUsedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastUsedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  lastValidatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastValidatedAt'),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  lastValidatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastValidatedAt'),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  lastValidatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastValidatedAt', value: value),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  lastValidatedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastValidatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  lastValidatedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastValidatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  lastValidatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastValidatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  normalizedNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  normalizedNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  normalizedNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  normalizedNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'normalizedName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  normalizedNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  normalizedNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  normalizedNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  normalizedNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'normalizedName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  normalizedNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'normalizedName', value: ''),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  normalizedNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'normalizedName', value: ''),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ownerUserId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'ownerUserId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ownerUserId', value: ''),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ownerUserId', value: ''),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  statusIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'statusIndex', value: value),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  statusIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'statusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  statusIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'statusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  statusIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'statusIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  templateIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  templateIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  templateIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  templateIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'templateId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  templateIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  templateIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  templateIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  templateIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'templateId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  templateIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'templateId', value: ''),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  templateIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'templateId', value: ''),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalCarbGEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'totalCarbG',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalCarbGGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalCarbG',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalCarbGLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalCarbG',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalCarbGBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalCarbG',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalFatGEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'totalFatG',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalFatGGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalFatG',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalFatGLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalFatG',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalFatGBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalFatG',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalKcalEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'totalKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalKcalGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalKcalLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalKcalBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalKcal',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalProteinGEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'totalProteinG',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalProteinGGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalProteinG',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalProteinGLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalProteinG',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  totalProteinGBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalProteinG',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
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

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  useCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'useCount', value: value),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  useCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'useCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  useCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'useCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  useCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'useCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  visibilityIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'visibilityIndex', value: value),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  visibilityIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'visibilityIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  visibilityIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'visibilityIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterFilterCondition>
  visibilityIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'visibilityIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension MealTemplateEntityQueryObject
    on QueryBuilder<MealTemplateEntity, MealTemplateEntity, QFilterCondition> {}

extension MealTemplateEntityQueryLinks
    on QueryBuilder<MealTemplateEntity, MealTemplateEntity, QFilterCondition> {}

extension MealTemplateEntityQuerySortBy
    on QueryBuilder<MealTemplateEntity, MealTemplateEntity, QSortBy> {
  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByDependencyStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dependencyStatusIndex', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByDependencyStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dependencyStatusIndex', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByLastValidatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastValidatedAt', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByLastValidatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastValidatedAt', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByNormalizedName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedName', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByNormalizedNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedName', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusIndex', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusIndex', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByTemplateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByTemplateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByTotalCarbG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCarbG', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByTotalCarbGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCarbG', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByTotalFatG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalFatG', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByTotalFatGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalFatG', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByTotalKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalKcal', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByTotalKcalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalKcal', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByTotalProteinG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalProteinG', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByTotalProteinGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalProteinG', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByUseCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByVisibilityIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibilityIndex', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  sortByVisibilityIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibilityIndex', Sort.desc);
    });
  }
}

extension MealTemplateEntityQuerySortThenBy
    on QueryBuilder<MealTemplateEntity, MealTemplateEntity, QSortThenBy> {
  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByDependencyStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dependencyStatusIndex', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByDependencyStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dependencyStatusIndex', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByLastValidatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastValidatedAt', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByLastValidatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastValidatedAt', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByNormalizedName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedName', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByNormalizedNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedName', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusIndex', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusIndex', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByTemplateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByTemplateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByTotalCarbG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCarbG', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByTotalCarbGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCarbG', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByTotalFatG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalFatG', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByTotalFatGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalFatG', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByTotalKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalKcal', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByTotalKcalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalKcal', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByTotalProteinG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalProteinG', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByTotalProteinGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalProteinG', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByUseCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByVisibilityIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibilityIndex', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QAfterSortBy>
  thenByVisibilityIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibilityIndex', Sort.desc);
    });
  }
}

extension MealTemplateEntityQueryWhereDistinct
    on QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct> {
  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByDependencyStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dependencyStatusIndex');
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUsedAt');
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByLastValidatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastValidatedAt');
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByNormalizedName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'normalizedName',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerUserId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'statusIndex');
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByTemplateId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByTotalCarbG() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalCarbG');
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByTotalFatG() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalFatG');
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByTotalKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalKcal');
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByTotalProteinG() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalProteinG');
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'useCount');
    });
  }

  QueryBuilder<MealTemplateEntity, MealTemplateEntity, QDistinct>
  distinctByVisibilityIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'visibilityIndex');
    });
  }
}

extension MealTemplateEntityQueryProperty
    on QueryBuilder<MealTemplateEntity, MealTemplateEntity, QQueryProperty> {
  QueryBuilder<MealTemplateEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MealTemplateEntity, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<MealTemplateEntity, DateTime?, QQueryOperations>
  deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<MealTemplateEntity, int, QQueryOperations>
  dependencyStatusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dependencyStatusIndex');
    });
  }

  QueryBuilder<MealTemplateEntity, DateTime?, QQueryOperations>
  lastUsedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUsedAt');
    });
  }

  QueryBuilder<MealTemplateEntity, DateTime?, QQueryOperations>
  lastValidatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastValidatedAt');
    });
  }

  QueryBuilder<MealTemplateEntity, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<MealTemplateEntity, String, QQueryOperations>
  normalizedNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'normalizedName');
    });
  }

  QueryBuilder<MealTemplateEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerUserId');
    });
  }

  QueryBuilder<MealTemplateEntity, int, QQueryOperations>
  statusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'statusIndex');
    });
  }

  QueryBuilder<MealTemplateEntity, String, QQueryOperations>
  templateIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateId');
    });
  }

  QueryBuilder<MealTemplateEntity, double, QQueryOperations>
  totalCarbGProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalCarbG');
    });
  }

  QueryBuilder<MealTemplateEntity, double, QQueryOperations>
  totalFatGProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalFatG');
    });
  }

  QueryBuilder<MealTemplateEntity, double, QQueryOperations>
  totalKcalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalKcal');
    });
  }

  QueryBuilder<MealTemplateEntity, double, QQueryOperations>
  totalProteinGProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalProteinG');
    });
  }

  QueryBuilder<MealTemplateEntity, DateTime, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<MealTemplateEntity, int, QQueryOperations> useCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'useCount');
    });
  }

  QueryBuilder<MealTemplateEntity, int, QQueryOperations>
  visibilityIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'visibilityIndex');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMealTemplateItemEntityCollection on Isar {
  IsarCollection<MealTemplateItemEntity> get mealTemplateItemEntitys =>
      this.collection();
}

const MealTemplateItemEntitySchema = CollectionSchema(
  name: r'MealTemplateItemEntity',
  id: -1972589090077136994,
  properties: {
    r'baseAmount': PropertySchema(
      id: 0,
      name: r'baseAmount',
      type: IsarType.double,
    ),
    r'carbPerBase': PropertySchema(
      id: 1,
      name: r'carbPerBase',
      type: IsarType.double,
    ),
    r'consumedAmount': PropertySchema(
      id: 2,
      name: r'consumedAmount',
      type: IsarType.double,
    ),
    r'fatPerBase': PropertySchema(
      id: 3,
      name: r'fatPerBase',
      type: IsarType.double,
    ),
    r'itemDependencyStatusIndex': PropertySchema(
      id: 4,
      name: r'itemDependencyStatusIndex',
      type: IsarType.long,
    ),
    r'itemId': PropertySchema(id: 5, name: r'itemId', type: IsarType.string),
    r'kcalPerBase': PropertySchema(
      id: 6,
      name: r'kcalPerBase',
      type: IsarType.double,
    ),
    r'name': PropertySchema(id: 7, name: r'name', type: IsarType.string),
    r'ownerUserId': PropertySchema(
      id: 8,
      name: r'ownerUserId',
      type: IsarType.string,
    ),
    r'proteinPerBase': PropertySchema(
      id: 9,
      name: r'proteinPerBase',
      type: IsarType.double,
    ),
    r'savedFoodId': PropertySchema(
      id: 10,
      name: r'savedFoodId',
      type: IsarType.string,
    ),
    r'snapshotSavedAt': PropertySchema(
      id: 11,
      name: r'snapshotSavedAt',
      type: IsarType.dateTime,
    ),
    r'sortOrder': PropertySchema(
      id: 12,
      name: r'sortOrder',
      type: IsarType.long,
    ),
    r'sourceOwnerUserId': PropertySchema(
      id: 13,
      name: r'sourceOwnerUserId',
      type: IsarType.string,
    ),
    r'templateId': PropertySchema(
      id: 14,
      name: r'templateId',
      type: IsarType.string,
    ),
    r'unitTypeIndex': PropertySchema(
      id: 15,
      name: r'unitTypeIndex',
      type: IsarType.long,
    ),
  },
  estimateSize: _mealTemplateItemEntityEstimateSize,
  serialize: _mealTemplateItemEntitySerialize,
  deserialize: _mealTemplateItemEntityDeserialize,
  deserializeProp: _mealTemplateItemEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'itemId': IndexSchema(
      id: -5342806140158601489,
      name: r'itemId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'itemId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'templateId': IndexSchema(
      id: -5352721467389445085,
      name: r'templateId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'templateId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'ownerUserId': IndexSchema(
      id: 1631799950038639233,
      name: r'ownerUserId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'ownerUserId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'sortOrder': IndexSchema(
      id: -1119549396205841918,
      name: r'sortOrder',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'sortOrder',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _mealTemplateItemEntityGetId,
  getLinks: _mealTemplateItemEntityGetLinks,
  attach: _mealTemplateItemEntityAttach,
  version: '3.1.0+1',
);

int _mealTemplateItemEntityEstimateSize(
  MealTemplateItemEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.itemId.length * 3;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.ownerUserId.length * 3;
  {
    final value = object.savedFoodId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.sourceOwnerUserId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.templateId.length * 3;
  return bytesCount;
}

void _mealTemplateItemEntitySerialize(
  MealTemplateItemEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.baseAmount);
  writer.writeDouble(offsets[1], object.carbPerBase);
  writer.writeDouble(offsets[2], object.consumedAmount);
  writer.writeDouble(offsets[3], object.fatPerBase);
  writer.writeLong(offsets[4], object.itemDependencyStatusIndex);
  writer.writeString(offsets[5], object.itemId);
  writer.writeDouble(offsets[6], object.kcalPerBase);
  writer.writeString(offsets[7], object.name);
  writer.writeString(offsets[8], object.ownerUserId);
  writer.writeDouble(offsets[9], object.proteinPerBase);
  writer.writeString(offsets[10], object.savedFoodId);
  writer.writeDateTime(offsets[11], object.snapshotSavedAt);
  writer.writeLong(offsets[12], object.sortOrder);
  writer.writeString(offsets[13], object.sourceOwnerUserId);
  writer.writeString(offsets[14], object.templateId);
  writer.writeLong(offsets[15], object.unitTypeIndex);
}

MealTemplateItemEntity _mealTemplateItemEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MealTemplateItemEntity();
  object.baseAmount = reader.readDouble(offsets[0]);
  object.carbPerBase = reader.readDoubleOrNull(offsets[1]);
  object.consumedAmount = reader.readDouble(offsets[2]);
  object.fatPerBase = reader.readDoubleOrNull(offsets[3]);
  object.id = id;
  object.itemDependencyStatusIndex = reader.readLong(offsets[4]);
  object.itemId = reader.readString(offsets[5]);
  object.kcalPerBase = reader.readDoubleOrNull(offsets[6]);
  object.name = reader.readString(offsets[7]);
  object.ownerUserId = reader.readString(offsets[8]);
  object.proteinPerBase = reader.readDoubleOrNull(offsets[9]);
  object.savedFoodId = reader.readStringOrNull(offsets[10]);
  object.snapshotSavedAt = reader.readDateTime(offsets[11]);
  object.sortOrder = reader.readLong(offsets[12]);
  object.sourceOwnerUserId = reader.readStringOrNull(offsets[13]);
  object.templateId = reader.readString(offsets[14]);
  object.unitTypeIndex = reader.readLong(offsets[15]);
  return object;
}

P _mealTemplateItemEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readDoubleOrNull(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDoubleOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readDoubleOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readDateTime(offset)) as P;
    case 12:
      return (reader.readLong(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _mealTemplateItemEntityGetId(MealTemplateItemEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _mealTemplateItemEntityGetLinks(
  MealTemplateItemEntity object,
) {
  return [];
}

void _mealTemplateItemEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  MealTemplateItemEntity object,
) {
  object.id = id;
}

extension MealTemplateItemEntityByIndex
    on IsarCollection<MealTemplateItemEntity> {
  Future<MealTemplateItemEntity?> getByItemId(String itemId) {
    return getByIndex(r'itemId', [itemId]);
  }

  MealTemplateItemEntity? getByItemIdSync(String itemId) {
    return getByIndexSync(r'itemId', [itemId]);
  }

  Future<bool> deleteByItemId(String itemId) {
    return deleteByIndex(r'itemId', [itemId]);
  }

  bool deleteByItemIdSync(String itemId) {
    return deleteByIndexSync(r'itemId', [itemId]);
  }

  Future<List<MealTemplateItemEntity?>> getAllByItemId(
    List<String> itemIdValues,
  ) {
    final values = itemIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'itemId', values);
  }

  List<MealTemplateItemEntity?> getAllByItemIdSync(List<String> itemIdValues) {
    final values = itemIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'itemId', values);
  }

  Future<int> deleteAllByItemId(List<String> itemIdValues) {
    final values = itemIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'itemId', values);
  }

  int deleteAllByItemIdSync(List<String> itemIdValues) {
    final values = itemIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'itemId', values);
  }

  Future<Id> putByItemId(MealTemplateItemEntity object) {
    return putByIndex(r'itemId', object);
  }

  Id putByItemIdSync(MealTemplateItemEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'itemId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByItemId(List<MealTemplateItemEntity> objects) {
    return putAllByIndex(r'itemId', objects);
  }

  List<Id> putAllByItemIdSync(
    List<MealTemplateItemEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'itemId', objects, saveLinks: saveLinks);
  }
}

extension MealTemplateItemEntityQueryWhereSort
    on QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QWhere> {
  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterWhere>
  anySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'sortOrder'),
      );
    });
  }
}

extension MealTemplateItemEntityQueryWhere
    on
        QueryBuilder<
          MealTemplateItemEntity,
          MealTemplateItemEntity,
          QWhereClause
        > {
  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
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
    MealTemplateItemEntity,
    MealTemplateItemEntity,
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
    MealTemplateItemEntity,
    MealTemplateItemEntity,
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
    MealTemplateItemEntity,
    MealTemplateItemEntity,
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

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterWhereClause
  >
  itemIdEqualTo(String itemId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'itemId', value: [itemId]),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterWhereClause
  >
  itemIdNotEqualTo(String itemId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'itemId',
                lower: [],
                upper: [itemId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'itemId',
                lower: [itemId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'itemId',
                lower: [itemId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'itemId',
                lower: [],
                upper: [itemId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterWhereClause
  >
  templateIdEqualTo(String templateId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'templateId', value: [templateId]),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterWhereClause
  >
  templateIdNotEqualTo(String templateId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [],
                upper: [templateId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [templateId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [templateId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [],
                upper: [templateId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterWhereClause
  >
  ownerUserIdEqualTo(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'ownerUserId',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterWhereClause
  >
  ownerUserIdNotEqualTo(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterWhereClause
  >
  sortOrderEqualTo(int sortOrder) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'sortOrder', value: [sortOrder]),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterWhereClause
  >
  sortOrderNotEqualTo(int sortOrder) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sortOrder',
                lower: [],
                upper: [sortOrder],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sortOrder',
                lower: [sortOrder],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sortOrder',
                lower: [sortOrder],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sortOrder',
                lower: [],
                upper: [sortOrder],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterWhereClause
  >
  sortOrderGreaterThan(int sortOrder, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'sortOrder',
          lower: [sortOrder],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterWhereClause
  >
  sortOrderLessThan(int sortOrder, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'sortOrder',
          lower: [],
          upper: [sortOrder],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterWhereClause
  >
  sortOrderBetween(
    int lowerSortOrder,
    int upperSortOrder, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'sortOrder',
          lower: [lowerSortOrder],
          includeLower: includeLower,
          upper: [upperSortOrder],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension MealTemplateItemEntityQueryFilter
    on
        QueryBuilder<
          MealTemplateItemEntity,
          MealTemplateItemEntity,
          QFilterCondition
        > {
  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  baseAmountEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'baseAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  baseAmountGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'baseAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  baseAmountLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'baseAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  baseAmountBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'baseAmount',
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
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  carbPerBaseIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'carbPerBase'),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  carbPerBaseIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'carbPerBase'),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  carbPerBaseEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'carbPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  carbPerBaseGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'carbPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  carbPerBaseLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'carbPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  carbPerBaseBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'carbPerBase',
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
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  consumedAmountEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'consumedAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  consumedAmountGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'consumedAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  consumedAmountLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'consumedAmount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  consumedAmountBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'consumedAmount',
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
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  fatPerBaseIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'fatPerBase'),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  fatPerBaseIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'fatPerBase'),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  fatPerBaseEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fatPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  fatPerBaseGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fatPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  fatPerBaseLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fatPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  fatPerBaseBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fatPerBase',
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
    MealTemplateItemEntity,
    MealTemplateItemEntity,
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
    MealTemplateItemEntity,
    MealTemplateItemEntity,
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
    MealTemplateItemEntity,
    MealTemplateItemEntity,
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
    MealTemplateItemEntity,
    MealTemplateItemEntity,
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
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemDependencyStatusIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'itemDependencyStatusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemDependencyStatusIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'itemDependencyStatusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemDependencyStatusIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'itemDependencyStatusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemDependencyStatusIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'itemDependencyStatusIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'itemId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'itemId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'itemId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'itemId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'itemId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'itemId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'itemId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'itemId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'itemId', value: ''),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'itemId', value: ''),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  kcalPerBaseIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'kcalPerBase'),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  kcalPerBaseIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'kcalPerBase'),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  kcalPerBaseEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'kcalPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  kcalPerBaseGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'kcalPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  kcalPerBaseLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'kcalPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  kcalPerBaseBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'kcalPerBase',
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
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ownerUserId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'ownerUserId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ownerUserId', value: ''),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ownerUserId', value: ''),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  proteinPerBaseIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'proteinPerBase'),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  proteinPerBaseIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'proteinPerBase'),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  proteinPerBaseEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'proteinPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  proteinPerBaseGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'proteinPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  proteinPerBaseLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'proteinPerBase',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  proteinPerBaseBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'proteinPerBase',
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
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  savedFoodIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'savedFoodId'),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  savedFoodIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'savedFoodId'),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  savedFoodIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'savedFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  savedFoodIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'savedFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  savedFoodIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'savedFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  savedFoodIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'savedFoodId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  savedFoodIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'savedFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  savedFoodIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'savedFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  savedFoodIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'savedFoodId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  savedFoodIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'savedFoodId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  savedFoodIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'savedFoodId', value: ''),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  savedFoodIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'savedFoodId', value: ''),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  snapshotSavedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'snapshotSavedAt', value: value),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  snapshotSavedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'snapshotSavedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  snapshotSavedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'snapshotSavedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  snapshotSavedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'snapshotSavedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sortOrderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sortOrder', value: value),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sortOrderGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sortOrder',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sortOrderLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sortOrder',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sortOrderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sortOrder',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceOwnerUserIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sourceOwnerUserId'),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceOwnerUserIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sourceOwnerUserId'),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceOwnerUserIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sourceOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceOwnerUserIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceOwnerUserIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceOwnerUserIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceOwnerUserId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceOwnerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sourceOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceOwnerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sourceOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceOwnerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sourceOwnerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceOwnerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sourceOwnerUserId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceOwnerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceOwnerUserId', value: ''),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceOwnerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sourceOwnerUserId', value: ''),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'templateId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'templateId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'templateId', value: ''),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'templateId', value: ''),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  unitTypeIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'unitTypeIndex', value: value),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  unitTypeIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'unitTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  unitTypeIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'unitTypeIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MealTemplateItemEntity,
    MealTemplateItemEntity,
    QAfterFilterCondition
  >
  unitTypeIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'unitTypeIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension MealTemplateItemEntityQueryObject
    on
        QueryBuilder<
          MealTemplateItemEntity,
          MealTemplateItemEntity,
          QFilterCondition
        > {}

extension MealTemplateItemEntityQueryLinks
    on
        QueryBuilder<
          MealTemplateItemEntity,
          MealTemplateItemEntity,
          QFilterCondition
        > {}

extension MealTemplateItemEntityQuerySortBy
    on QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QSortBy> {
  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByBaseAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseAmount', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByBaseAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseAmount', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByCarbPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbPerBase', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByCarbPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbPerBase', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByConsumedAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAmount', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByConsumedAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAmount', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByFatPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatPerBase', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByFatPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatPerBase', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByItemDependencyStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemDependencyStatusIndex', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByItemDependencyStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemDependencyStatusIndex', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByKcalPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kcalPerBase', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByKcalPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kcalPerBase', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByProteinPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinPerBase', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByProteinPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinPerBase', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortBySavedFoodId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'savedFoodId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortBySavedFoodIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'savedFoodId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortBySnapshotSavedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshotSavedAt', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortBySnapshotSavedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshotSavedAt', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortBySourceOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceOwnerUserId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortBySourceOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceOwnerUserId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByTemplateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByTemplateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByUnitTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  sortByUnitTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitTypeIndex', Sort.desc);
    });
  }
}

extension MealTemplateItemEntityQuerySortThenBy
    on
        QueryBuilder<
          MealTemplateItemEntity,
          MealTemplateItemEntity,
          QSortThenBy
        > {
  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByBaseAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseAmount', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByBaseAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseAmount', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByCarbPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbPerBase', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByCarbPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbPerBase', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByConsumedAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAmount', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByConsumedAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAmount', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByFatPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatPerBase', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByFatPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatPerBase', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByItemDependencyStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemDependencyStatusIndex', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByItemDependencyStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemDependencyStatusIndex', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByKcalPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kcalPerBase', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByKcalPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kcalPerBase', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByProteinPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinPerBase', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByProteinPerBaseDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinPerBase', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenBySavedFoodId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'savedFoodId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenBySavedFoodIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'savedFoodId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenBySnapshotSavedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshotSavedAt', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenBySnapshotSavedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snapshotSavedAt', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenBySourceOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceOwnerUserId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenBySourceOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceOwnerUserId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByTemplateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByTemplateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.desc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByUnitTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitTypeIndex', Sort.asc);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QAfterSortBy>
  thenByUnitTypeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitTypeIndex', Sort.desc);
    });
  }
}

extension MealTemplateItemEntityQueryWhereDistinct
    on QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct> {
  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctByBaseAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'baseAmount');
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctByCarbPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'carbPerBase');
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctByConsumedAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'consumedAmount');
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctByFatPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fatPerBase');
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctByItemDependencyStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemDependencyStatusIndex');
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctByItemId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctByKcalPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kcalPerBase');
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerUserId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctByProteinPerBase() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'proteinPerBase');
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctBySavedFoodId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'savedFoodId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctBySnapshotSavedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'snapshotSavedAt');
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sortOrder');
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctBySourceOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'sourceOwnerUserId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctByTemplateId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MealTemplateItemEntity, MealTemplateItemEntity, QDistinct>
  distinctByUnitTypeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unitTypeIndex');
    });
  }
}

extension MealTemplateItemEntityQueryProperty
    on
        QueryBuilder<
          MealTemplateItemEntity,
          MealTemplateItemEntity,
          QQueryProperty
        > {
  QueryBuilder<MealTemplateItemEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MealTemplateItemEntity, double, QQueryOperations>
  baseAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'baseAmount');
    });
  }

  QueryBuilder<MealTemplateItemEntity, double?, QQueryOperations>
  carbPerBaseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'carbPerBase');
    });
  }

  QueryBuilder<MealTemplateItemEntity, double, QQueryOperations>
  consumedAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'consumedAmount');
    });
  }

  QueryBuilder<MealTemplateItemEntity, double?, QQueryOperations>
  fatPerBaseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fatPerBase');
    });
  }

  QueryBuilder<MealTemplateItemEntity, int, QQueryOperations>
  itemDependencyStatusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemDependencyStatusIndex');
    });
  }

  QueryBuilder<MealTemplateItemEntity, String, QQueryOperations>
  itemIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemId');
    });
  }

  QueryBuilder<MealTemplateItemEntity, double?, QQueryOperations>
  kcalPerBaseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kcalPerBase');
    });
  }

  QueryBuilder<MealTemplateItemEntity, String, QQueryOperations>
  nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<MealTemplateItemEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerUserId');
    });
  }

  QueryBuilder<MealTemplateItemEntity, double?, QQueryOperations>
  proteinPerBaseProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'proteinPerBase');
    });
  }

  QueryBuilder<MealTemplateItemEntity, String?, QQueryOperations>
  savedFoodIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'savedFoodId');
    });
  }

  QueryBuilder<MealTemplateItemEntity, DateTime, QQueryOperations>
  snapshotSavedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'snapshotSavedAt');
    });
  }

  QueryBuilder<MealTemplateItemEntity, int, QQueryOperations>
  sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sortOrder');
    });
  }

  QueryBuilder<MealTemplateItemEntity, String?, QQueryOperations>
  sourceOwnerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceOwnerUserId');
    });
  }

  QueryBuilder<MealTemplateItemEntity, String, QQueryOperations>
  templateIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateId');
    });
  }

  QueryBuilder<MealTemplateItemEntity, int, QQueryOperations>
  unitTypeIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unitTypeIndex');
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
    r'activityId': PropertySchema(
      id: 0,
      name: r'activityId',
      type: IsarType.string,
    ),
    r'burnedKcal': PropertySchema(
      id: 1,
      name: r'burnedKcal',
      type: IsarType.double,
    ),
    r'calculationSource': PropertySchema(
      id: 2,
      name: r'calculationSource',
      type: IsarType.string,
    ),
    r'calculationVersion': PropertySchema(
      id: 3,
      name: r'calculationVersion',
      type: IsarType.string,
    ),
    r'categoryKey': PropertySchema(
      id: 4,
      name: r'categoryKey',
      type: IsarType.string,
    ),
    r'durationMin': PropertySchema(
      id: 5,
      name: r'durationMin',
      type: IsarType.long,
    ),
    r'entryId': PropertySchema(id: 6, name: r'entryId', type: IsarType.string),
    r'grossKcal': PropertySchema(
      id: 7,
      name: r'grossKcal',
      type: IsarType.double,
    ),
    r'intensity': PropertySchema(
      id: 8,
      name: r'intensity',
      type: IsarType.string,
    ),
    r'liftWeightKg': PropertySchema(
      id: 9,
      name: r'liftWeightKg',
      type: IsarType.double,
    ),
    r'loggedAt': PropertySchema(
      id: 10,
      name: r'loggedAt',
      type: IsarType.dateTime,
    ),
    r'metValue': PropertySchema(
      id: 11,
      name: r'metValue',
      type: IsarType.double,
    ),
    r'name': PropertySchema(id: 12, name: r'name', type: IsarType.string),
    r'netKcal': PropertySchema(id: 13, name: r'netKcal', type: IsarType.double),
    r'notes': PropertySchema(id: 14, name: r'notes', type: IsarType.string),
    r'reps': PropertySchema(id: 15, name: r'reps', type: IsarType.long),
    r'sets': PropertySchema(id: 16, name: r'sets', type: IsarType.long),
    r'sourceKey': PropertySchema(
      id: 17,
      name: r'sourceKey',
      type: IsarType.string,
    ),
    r'weightKgSnapshot': PropertySchema(
      id: 18,
      name: r'weightKgSnapshot',
      type: IsarType.double,
    ),
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
  {
    final value = object.activityId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.calculationSource;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.calculationVersion;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.categoryKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.entryId.length * 3;
  {
    final value = object.intensity;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  {
    final value = object.notes;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.sourceKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _exerciseEntryEntitySerialize(
  ExerciseEntryEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.activityId);
  writer.writeDouble(offsets[1], object.burnedKcal);
  writer.writeString(offsets[2], object.calculationSource);
  writer.writeString(offsets[3], object.calculationVersion);
  writer.writeString(offsets[4], object.categoryKey);
  writer.writeLong(offsets[5], object.durationMin);
  writer.writeString(offsets[6], object.entryId);
  writer.writeDouble(offsets[7], object.grossKcal);
  writer.writeString(offsets[8], object.intensity);
  writer.writeDouble(offsets[9], object.liftWeightKg);
  writer.writeDateTime(offsets[10], object.loggedAt);
  writer.writeDouble(offsets[11], object.metValue);
  writer.writeString(offsets[12], object.name);
  writer.writeDouble(offsets[13], object.netKcal);
  writer.writeString(offsets[14], object.notes);
  writer.writeLong(offsets[15], object.reps);
  writer.writeLong(offsets[16], object.sets);
  writer.writeString(offsets[17], object.sourceKey);
  writer.writeDouble(offsets[18], object.weightKgSnapshot);
}

ExerciseEntryEntity _exerciseEntryEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ExerciseEntryEntity();
  object.activityId = reader.readStringOrNull(offsets[0]);
  object.burnedKcal = reader.readDouble(offsets[1]);
  object.calculationSource = reader.readStringOrNull(offsets[2]);
  object.calculationVersion = reader.readStringOrNull(offsets[3]);
  object.categoryKey = reader.readStringOrNull(offsets[4]);
  object.durationMin = reader.readLong(offsets[5]);
  object.entryId = reader.readString(offsets[6]);
  object.grossKcal = reader.readDoubleOrNull(offsets[7]);
  object.id = id;
  object.intensity = reader.readStringOrNull(offsets[8]);
  object.liftWeightKg = reader.readDoubleOrNull(offsets[9]);
  object.loggedAt = reader.readDateTime(offsets[10]);
  object.metValue = reader.readDoubleOrNull(offsets[11]);
  object.name = reader.readString(offsets[12]);
  object.netKcal = reader.readDoubleOrNull(offsets[13]);
  object.notes = reader.readStringOrNull(offsets[14]);
  object.reps = reader.readLongOrNull(offsets[15]);
  object.sets = reader.readLongOrNull(offsets[16]);
  object.sourceKey = reader.readStringOrNull(offsets[17]);
  object.weightKgSnapshot = reader.readDoubleOrNull(offsets[18]);
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
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readDoubleOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readDoubleOrNull(offset)) as P;
    case 10:
      return (reader.readDateTime(offset)) as P;
    case 11:
      return (reader.readDoubleOrNull(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readDoubleOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readLongOrNull(offset)) as P;
    case 16:
      return (reader.readLongOrNull(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readDoubleOrNull(offset)) as P;
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
  activityIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'activityId'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  activityIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'activityId'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  activityIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  activityIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  activityIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  activityIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'activityId',
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
  activityIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  activityIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  activityIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  activityIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'activityId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  activityIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'activityId', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  activityIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'activityId', value: ''),
      );
    });
  }

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
  calculationSourceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'calculationSource'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationSourceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'calculationSource'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationSourceEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'calculationSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationSourceGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'calculationSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationSourceLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'calculationSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationSourceBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'calculationSource',
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
  calculationSourceStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'calculationSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationSourceEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'calculationSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationSourceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'calculationSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationSourceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'calculationSource',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationSourceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'calculationSource', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationSourceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'calculationSource', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationVersionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'calculationVersion'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationVersionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'calculationVersion'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationVersionEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'calculationVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationVersionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'calculationVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationVersionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'calculationVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationVersionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'calculationVersion',
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
  calculationVersionStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'calculationVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationVersionEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'calculationVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationVersionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'calculationVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationVersionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'calculationVersion',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'calculationVersion', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  calculationVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'calculationVersion', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  categoryKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'categoryKey'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  categoryKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'categoryKey'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  categoryKeyEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'categoryKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  categoryKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'categoryKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  categoryKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'categoryKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  categoryKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'categoryKey',
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
  categoryKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'categoryKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  categoryKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'categoryKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  categoryKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'categoryKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  categoryKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'categoryKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  categoryKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'categoryKey', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  categoryKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'categoryKey', value: ''),
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
  grossKcalIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'grossKcal'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  grossKcalIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'grossKcal'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  grossKcalEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'grossKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  grossKcalGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'grossKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  grossKcalLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'grossKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  grossKcalBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'grossKcal',
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
  intensityIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'intensity'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  intensityIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'intensity'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  intensityEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'intensity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  intensityGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'intensity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  intensityLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'intensity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  intensityBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'intensity',
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
  intensityStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'intensity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  intensityEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'intensity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  intensityContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'intensity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  intensityMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'intensity',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  intensityIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'intensity', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  intensityIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'intensity', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  liftWeightKgIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'liftWeightKg'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  liftWeightKgIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'liftWeightKg'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  liftWeightKgEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'liftWeightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  liftWeightKgGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'liftWeightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  liftWeightKgLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'liftWeightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  liftWeightKgBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'liftWeightKg',
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
  metValueIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'metValue'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  metValueIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'metValue'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  metValueEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'metValue',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  metValueGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'metValue',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  metValueLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'metValue',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  metValueBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'metValue',
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

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  netKcalIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'netKcal'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  netKcalIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'netKcal'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  netKcalEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'netKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  netKcalGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'netKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  netKcalLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'netKcal',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  netKcalBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'netKcal',
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
  notesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'notes'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  notesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'notes'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  notesEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  notesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  notesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  notesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'notes',
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
  notesStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  notesEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  notesContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  notesMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'notes',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'notes', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'notes', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  repsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'reps'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  repsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'reps'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  repsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'reps', value: value),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  repsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'reps',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  repsLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'reps',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  repsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'reps',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  setsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sets'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  setsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sets'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  setsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sets', value: value),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  setsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sets',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  setsLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sets',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  setsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sets',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  sourceKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sourceKey'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  sourceKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sourceKey'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  sourceKeyEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  sourceKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  sourceKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  sourceKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceKey',
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
  sourceKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  sourceKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  sourceKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  sourceKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sourceKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  sourceKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceKey', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  sourceKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sourceKey', value: ''),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  weightKgSnapshotIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'weightKgSnapshot'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  weightKgSnapshotIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'weightKgSnapshot'),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  weightKgSnapshotEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'weightKgSnapshot',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  weightKgSnapshotGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'weightKgSnapshot',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  weightKgSnapshotLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'weightKgSnapshot',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterFilterCondition>
  weightKgSnapshotBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'weightKgSnapshot',
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
  sortByActivityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityId', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByActivityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityId', Sort.desc);
    });
  }

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
  sortByCalculationSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'calculationSource', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByCalculationSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'calculationSource', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByCalculationVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'calculationVersion', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByCalculationVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'calculationVersion', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByCategoryKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryKey', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByCategoryKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryKey', Sort.desc);
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
  sortByGrossKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grossKcal', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByGrossKcalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grossKcal', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByIntensity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intensity', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByIntensityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intensity', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByLiftWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'liftWeightKg', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByLiftWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'liftWeightKg', Sort.desc);
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
  sortByMetValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metValue', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByMetValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metValue', Sort.desc);
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

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByNetKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'netKcal', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByNetKcalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'netKcal', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByReps() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reps', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByRepsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reps', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortBySets() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sets', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortBySetsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sets', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortBySourceKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceKey', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortBySourceKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceKey', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByWeightKgSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKgSnapshot', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  sortByWeightKgSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKgSnapshot', Sort.desc);
    });
  }
}

extension ExerciseEntryEntityQuerySortThenBy
    on QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QSortThenBy> {
  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByActivityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityId', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByActivityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityId', Sort.desc);
    });
  }

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
  thenByCalculationSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'calculationSource', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByCalculationSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'calculationSource', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByCalculationVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'calculationVersion', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByCalculationVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'calculationVersion', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByCategoryKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryKey', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByCategoryKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryKey', Sort.desc);
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
  thenByGrossKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grossKcal', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByGrossKcalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grossKcal', Sort.desc);
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
  thenByIntensity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intensity', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByIntensityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intensity', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByLiftWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'liftWeightKg', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByLiftWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'liftWeightKg', Sort.desc);
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
  thenByMetValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metValue', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByMetValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metValue', Sort.desc);
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

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByNetKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'netKcal', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByNetKcalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'netKcal', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByReps() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reps', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByRepsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reps', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenBySets() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sets', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenBySetsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sets', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenBySourceKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceKey', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenBySourceKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceKey', Sort.desc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByWeightKgSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKgSnapshot', Sort.asc);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QAfterSortBy>
  thenByWeightKgSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'weightKgSnapshot', Sort.desc);
    });
  }
}

extension ExerciseEntryEntityQueryWhereDistinct
    on QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct> {
  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByActivityId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activityId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByBurnedKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'burnedKcal');
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByCalculationSource({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'calculationSource',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByCalculationVersion({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'calculationVersion',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByCategoryKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'categoryKey', caseSensitive: caseSensitive);
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
  distinctByGrossKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'grossKcal');
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByIntensity({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'intensity', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByLiftWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'liftWeightKg');
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByLoggedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'loggedAt');
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByMetValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metValue');
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByNetKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'netKcal');
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByNotes({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByReps() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reps');
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctBySets() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sets');
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctBySourceKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExerciseEntryEntity, ExerciseEntryEntity, QDistinct>
  distinctByWeightKgSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'weightKgSnapshot');
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

  QueryBuilder<ExerciseEntryEntity, String?, QQueryOperations>
  activityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activityId');
    });
  }

  QueryBuilder<ExerciseEntryEntity, double, QQueryOperations>
  burnedKcalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'burnedKcal');
    });
  }

  QueryBuilder<ExerciseEntryEntity, String?, QQueryOperations>
  calculationSourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'calculationSource');
    });
  }

  QueryBuilder<ExerciseEntryEntity, String?, QQueryOperations>
  calculationVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'calculationVersion');
    });
  }

  QueryBuilder<ExerciseEntryEntity, String?, QQueryOperations>
  categoryKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'categoryKey');
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

  QueryBuilder<ExerciseEntryEntity, double?, QQueryOperations>
  grossKcalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'grossKcal');
    });
  }

  QueryBuilder<ExerciseEntryEntity, String?, QQueryOperations>
  intensityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'intensity');
    });
  }

  QueryBuilder<ExerciseEntryEntity, double?, QQueryOperations>
  liftWeightKgProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'liftWeightKg');
    });
  }

  QueryBuilder<ExerciseEntryEntity, DateTime, QQueryOperations>
  loggedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'loggedAt');
    });
  }

  QueryBuilder<ExerciseEntryEntity, double?, QQueryOperations>
  metValueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metValue');
    });
  }

  QueryBuilder<ExerciseEntryEntity, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<ExerciseEntryEntity, double?, QQueryOperations>
  netKcalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'netKcal');
    });
  }

  QueryBuilder<ExerciseEntryEntity, String?, QQueryOperations> notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }

  QueryBuilder<ExerciseEntryEntity, int?, QQueryOperations> repsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reps');
    });
  }

  QueryBuilder<ExerciseEntryEntity, int?, QQueryOperations> setsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sets');
    });
  }

  QueryBuilder<ExerciseEntryEntity, String?, QQueryOperations>
  sourceKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceKey');
    });
  }

  QueryBuilder<ExerciseEntryEntity, double?, QQueryOperations>
  weightKgSnapshotProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'weightKgSnapshot');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAlcoholEntryEntityCollection on Isar {
  IsarCollection<AlcoholEntryEntity> get alcoholEntryEntitys =>
      this.collection();
}

const AlcoholEntryEntitySchema = CollectionSchema(
  name: r'AlcoholEntryEntity',
  id: -2705665003704732987,
  properties: {
    r'alcoholCalories': PropertySchema(
      id: 0,
      name: r'alcoholCalories',
      type: IsarType.double,
    ),
    r'alcoholPercentage': PropertySchema(
      id: 1,
      name: r'alcoholPercentage',
      type: IsarType.double,
    ),
    r'amount': PropertySchema(id: 2, name: r'amount', type: IsarType.double),
    r'beverageName': PropertySchema(
      id: 3,
      name: r'beverageName',
      type: IsarType.string,
    ),
    r'consumedAt': PropertySchema(
      id: 4,
      name: r'consumedAt',
      type: IsarType.dateTime,
    ),
    r'entryId': PropertySchema(id: 5, name: r'entryId', type: IsarType.string),
    r'pureAlcoholGrams': PropertySchema(
      id: 6,
      name: r'pureAlcoholGrams',
      type: IsarType.double,
    ),
    r'totalCalories': PropertySchema(
      id: 7,
      name: r'totalCalories',
      type: IsarType.double,
    ),
    r'unit': PropertySchema(id: 8, name: r'unit', type: IsarType.string),
  },
  estimateSize: _alcoholEntryEntityEstimateSize,
  serialize: _alcoholEntryEntitySerialize,
  deserialize: _alcoholEntryEntityDeserialize,
  deserializeProp: _alcoholEntryEntityDeserializeProp,
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
  getId: _alcoholEntryEntityGetId,
  getLinks: _alcoholEntryEntityGetLinks,
  attach: _alcoholEntryEntityAttach,
  version: '3.1.0+1',
);

int _alcoholEntryEntityEstimateSize(
  AlcoholEntryEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.beverageName.length * 3;
  bytesCount += 3 + object.entryId.length * 3;
  bytesCount += 3 + object.unit.length * 3;
  return bytesCount;
}

void _alcoholEntryEntitySerialize(
  AlcoholEntryEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.alcoholCalories);
  writer.writeDouble(offsets[1], object.alcoholPercentage);
  writer.writeDouble(offsets[2], object.amount);
  writer.writeString(offsets[3], object.beverageName);
  writer.writeDateTime(offsets[4], object.consumedAt);
  writer.writeString(offsets[5], object.entryId);
  writer.writeDouble(offsets[6], object.pureAlcoholGrams);
  writer.writeDouble(offsets[7], object.totalCalories);
  writer.writeString(offsets[8], object.unit);
}

AlcoholEntryEntity _alcoholEntryEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AlcoholEntryEntity();
  object.alcoholCalories = reader.readDouble(offsets[0]);
  object.alcoholPercentage = reader.readDouble(offsets[1]);
  object.amount = reader.readDouble(offsets[2]);
  object.beverageName = reader.readString(offsets[3]);
  object.consumedAt = reader.readDateTime(offsets[4]);
  object.entryId = reader.readString(offsets[5]);
  object.id = id;
  object.pureAlcoholGrams = reader.readDouble(offsets[6]);
  object.totalCalories = reader.readDouble(offsets[7]);
  object.unit = reader.readString(offsets[8]);
  return object;
}

P _alcoholEntryEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDouble(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _alcoholEntryEntityGetId(AlcoholEntryEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _alcoholEntryEntityGetLinks(
  AlcoholEntryEntity object,
) {
  return [];
}

void _alcoholEntryEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  AlcoholEntryEntity object,
) {
  object.id = id;
}

extension AlcoholEntryEntityByIndex on IsarCollection<AlcoholEntryEntity> {
  Future<AlcoholEntryEntity?> getByEntryId(String entryId) {
    return getByIndex(r'entryId', [entryId]);
  }

  AlcoholEntryEntity? getByEntryIdSync(String entryId) {
    return getByIndexSync(r'entryId', [entryId]);
  }

  Future<bool> deleteByEntryId(String entryId) {
    return deleteByIndex(r'entryId', [entryId]);
  }

  bool deleteByEntryIdSync(String entryId) {
    return deleteByIndexSync(r'entryId', [entryId]);
  }

  Future<List<AlcoholEntryEntity?>> getAllByEntryId(
    List<String> entryIdValues,
  ) {
    final values = entryIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'entryId', values);
  }

  List<AlcoholEntryEntity?> getAllByEntryIdSync(List<String> entryIdValues) {
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

  Future<Id> putByEntryId(AlcoholEntryEntity object) {
    return putByIndex(r'entryId', object);
  }

  Id putByEntryIdSync(AlcoholEntryEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'entryId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByEntryId(List<AlcoholEntryEntity> objects) {
    return putAllByIndex(r'entryId', objects);
  }

  List<Id> putAllByEntryIdSync(
    List<AlcoholEntryEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'entryId', objects, saveLinks: saveLinks);
  }
}

extension AlcoholEntryEntityQueryWhereSort
    on QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QWhere> {
  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AlcoholEntryEntityQueryWhere
    on QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QWhereClause> {
  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterWhereClause>
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

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterWhereClause>
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

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterWhereClause>
  entryIdEqualTo(String entryId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'entryId', value: [entryId]),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterWhereClause>
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

extension AlcoholEntryEntityQueryFilter
    on QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QFilterCondition> {
  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  alcoholCaloriesEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'alcoholCalories',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  alcoholCaloriesGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'alcoholCalories',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  alcoholCaloriesLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'alcoholCalories',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  alcoholCaloriesBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'alcoholCalories',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  alcoholPercentageEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'alcoholPercentage',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  alcoholPercentageGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'alcoholPercentage',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  alcoholPercentageLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'alcoholPercentage',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  alcoholPercentageBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'alcoholPercentage',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  amountEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'amount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  amountGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'amount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  amountLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'amount',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  amountBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'amount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  beverageNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'beverageName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  beverageNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'beverageName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  beverageNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'beverageName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  beverageNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'beverageName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  beverageNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'beverageName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  beverageNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'beverageName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  beverageNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'beverageName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  beverageNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'beverageName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  beverageNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'beverageName', value: ''),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  beverageNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'beverageName', value: ''),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  consumedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'consumedAt', value: value),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  consumedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'consumedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  consumedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'consumedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  consumedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'consumedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
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

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
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

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
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

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
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

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
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

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
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

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
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

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
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

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  entryIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'entryId', value: ''),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  entryIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'entryId', value: ''),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
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

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
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

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
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

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  pureAlcoholGramsEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'pureAlcoholGrams',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  pureAlcoholGramsGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pureAlcoholGrams',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  pureAlcoholGramsLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pureAlcoholGrams',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  pureAlcoholGramsBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pureAlcoholGrams',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  totalCaloriesEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'totalCalories',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  totalCaloriesGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalCalories',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  totalCaloriesLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalCalories',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  totalCaloriesBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalCalories',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  unitEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'unit',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  unitGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'unit',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  unitLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'unit',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  unitBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'unit',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  unitStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'unit',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  unitEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'unit',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  unitContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'unit',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  unitMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'unit',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  unitIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'unit', value: ''),
      );
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterFilterCondition>
  unitIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'unit', value: ''),
      );
    });
  }
}

extension AlcoholEntryEntityQueryObject
    on QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QFilterCondition> {}

extension AlcoholEntryEntityQueryLinks
    on QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QFilterCondition> {}

extension AlcoholEntryEntityQuerySortBy
    on QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QSortBy> {
  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByAlcoholCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alcoholCalories', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByAlcoholCaloriesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alcoholCalories', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByAlcoholPercentage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alcoholPercentage', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByAlcoholPercentageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alcoholPercentage', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amount', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amount', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByBeverageName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beverageName', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByBeverageNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beverageName', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByConsumedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAt', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByConsumedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAt', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByPureAlcoholGrams() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pureAlcoholGrams', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByPureAlcoholGramsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pureAlcoholGrams', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByTotalCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCalories', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByTotalCaloriesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCalories', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unit', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  sortByUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unit', Sort.desc);
    });
  }
}

extension AlcoholEntryEntityQuerySortThenBy
    on QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QSortThenBy> {
  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByAlcoholCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alcoholCalories', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByAlcoholCaloriesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alcoholCalories', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByAlcoholPercentage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alcoholPercentage', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByAlcoholPercentageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'alcoholPercentage', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amount', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amount', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByBeverageName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beverageName', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByBeverageNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beverageName', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByConsumedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAt', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByConsumedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAt', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByEntryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByEntryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'entryId', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByPureAlcoholGrams() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pureAlcoholGrams', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByPureAlcoholGramsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pureAlcoholGrams', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByTotalCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCalories', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByTotalCaloriesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCalories', Sort.desc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unit', Sort.asc);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QAfterSortBy>
  thenByUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unit', Sort.desc);
    });
  }
}

extension AlcoholEntryEntityQueryWhereDistinct
    on QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QDistinct> {
  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QDistinct>
  distinctByAlcoholCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'alcoholCalories');
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QDistinct>
  distinctByAlcoholPercentage() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'alcoholPercentage');
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QDistinct>
  distinctByAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'amount');
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QDistinct>
  distinctByBeverageName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'beverageName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QDistinct>
  distinctByConsumedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'consumedAt');
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QDistinct>
  distinctByEntryId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'entryId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QDistinct>
  distinctByPureAlcoholGrams() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pureAlcoholGrams');
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QDistinct>
  distinctByTotalCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalCalories');
    });
  }

  QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QDistinct>
  distinctByUnit({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unit', caseSensitive: caseSensitive);
    });
  }
}

extension AlcoholEntryEntityQueryProperty
    on QueryBuilder<AlcoholEntryEntity, AlcoholEntryEntity, QQueryProperty> {
  QueryBuilder<AlcoholEntryEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AlcoholEntryEntity, double, QQueryOperations>
  alcoholCaloriesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'alcoholCalories');
    });
  }

  QueryBuilder<AlcoholEntryEntity, double, QQueryOperations>
  alcoholPercentageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'alcoholPercentage');
    });
  }

  QueryBuilder<AlcoholEntryEntity, double, QQueryOperations> amountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'amount');
    });
  }

  QueryBuilder<AlcoholEntryEntity, String, QQueryOperations>
  beverageNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'beverageName');
    });
  }

  QueryBuilder<AlcoholEntryEntity, DateTime, QQueryOperations>
  consumedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'consumedAt');
    });
  }

  QueryBuilder<AlcoholEntryEntity, String, QQueryOperations> entryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'entryId');
    });
  }

  QueryBuilder<AlcoholEntryEntity, double, QQueryOperations>
  pureAlcoholGramsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pureAlcoholGrams');
    });
  }

  QueryBuilder<AlcoholEntryEntity, double, QQueryOperations>
  totalCaloriesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalCalories');
    });
  }

  QueryBuilder<AlcoholEntryEntity, String, QQueryOperations> unitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unit');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetWorkoutTemplateEntityCollection on Isar {
  IsarCollection<WorkoutTemplateEntity> get workoutTemplateEntitys =>
      this.collection();
}

const WorkoutTemplateEntitySchema = CollectionSchema(
  name: r'WorkoutTemplateEntity',
  id: -1272492924788419919,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'deletedAt': PropertySchema(
      id: 1,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'lastUsedAt': PropertySchema(
      id: 2,
      name: r'lastUsedAt',
      type: IsarType.dateTime,
    ),
    r'name': PropertySchema(id: 3, name: r'name', type: IsarType.string),
    r'normalizedName': PropertySchema(
      id: 4,
      name: r'normalizedName',
      type: IsarType.string,
    ),
    r'ownerUserId': PropertySchema(
      id: 5,
      name: r'ownerUserId',
      type: IsarType.string,
    ),
    r'statusIndex': PropertySchema(
      id: 6,
      name: r'statusIndex',
      type: IsarType.long,
    ),
    r'templateId': PropertySchema(
      id: 7,
      name: r'templateId',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 8,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'useCount': PropertySchema(id: 9, name: r'useCount', type: IsarType.long),
  },
  estimateSize: _workoutTemplateEntityEstimateSize,
  serialize: _workoutTemplateEntitySerialize,
  deserialize: _workoutTemplateEntityDeserialize,
  deserializeProp: _workoutTemplateEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'templateId': IndexSchema(
      id: -5352721467389445085,
      name: r'templateId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'templateId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'ownerUserId': IndexSchema(
      id: 1631799950038639233,
      name: r'ownerUserId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'ownerUserId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'normalizedName': IndexSchema(
      id: -9115371092206571671,
      name: r'normalizedName',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'normalizedName',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _workoutTemplateEntityGetId,
  getLinks: _workoutTemplateEntityGetLinks,
  attach: _workoutTemplateEntityAttach,
  version: '3.1.0+1',
);

int _workoutTemplateEntityEstimateSize(
  WorkoutTemplateEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.normalizedName.length * 3;
  bytesCount += 3 + object.ownerUserId.length * 3;
  bytesCount += 3 + object.templateId.length * 3;
  return bytesCount;
}

void _workoutTemplateEntitySerialize(
  WorkoutTemplateEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeDateTime(offsets[1], object.deletedAt);
  writer.writeDateTime(offsets[2], object.lastUsedAt);
  writer.writeString(offsets[3], object.name);
  writer.writeString(offsets[4], object.normalizedName);
  writer.writeString(offsets[5], object.ownerUserId);
  writer.writeLong(offsets[6], object.statusIndex);
  writer.writeString(offsets[7], object.templateId);
  writer.writeDateTime(offsets[8], object.updatedAt);
  writer.writeLong(offsets[9], object.useCount);
}

WorkoutTemplateEntity _workoutTemplateEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WorkoutTemplateEntity();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[1]);
  object.id = id;
  object.lastUsedAt = reader.readDateTimeOrNull(offsets[2]);
  object.name = reader.readString(offsets[3]);
  object.normalizedName = reader.readString(offsets[4]);
  object.ownerUserId = reader.readString(offsets[5]);
  object.statusIndex = reader.readLong(offsets[6]);
  object.templateId = reader.readString(offsets[7]);
  object.updatedAt = reader.readDateTime(offsets[8]);
  object.useCount = reader.readLong(offsets[9]);
  return object;
}

P _workoutTemplateEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readDateTime(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _workoutTemplateEntityGetId(WorkoutTemplateEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _workoutTemplateEntityGetLinks(
  WorkoutTemplateEntity object,
) {
  return [];
}

void _workoutTemplateEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  WorkoutTemplateEntity object,
) {
  object.id = id;
}

extension WorkoutTemplateEntityByIndex
    on IsarCollection<WorkoutTemplateEntity> {
  Future<WorkoutTemplateEntity?> getByTemplateId(String templateId) {
    return getByIndex(r'templateId', [templateId]);
  }

  WorkoutTemplateEntity? getByTemplateIdSync(String templateId) {
    return getByIndexSync(r'templateId', [templateId]);
  }

  Future<bool> deleteByTemplateId(String templateId) {
    return deleteByIndex(r'templateId', [templateId]);
  }

  bool deleteByTemplateIdSync(String templateId) {
    return deleteByIndexSync(r'templateId', [templateId]);
  }

  Future<List<WorkoutTemplateEntity?>> getAllByTemplateId(
    List<String> templateIdValues,
  ) {
    final values = templateIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'templateId', values);
  }

  List<WorkoutTemplateEntity?> getAllByTemplateIdSync(
    List<String> templateIdValues,
  ) {
    final values = templateIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'templateId', values);
  }

  Future<int> deleteAllByTemplateId(List<String> templateIdValues) {
    final values = templateIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'templateId', values);
  }

  int deleteAllByTemplateIdSync(List<String> templateIdValues) {
    final values = templateIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'templateId', values);
  }

  Future<Id> putByTemplateId(WorkoutTemplateEntity object) {
    return putByIndex(r'templateId', object);
  }

  Id putByTemplateIdSync(
    WorkoutTemplateEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'templateId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByTemplateId(List<WorkoutTemplateEntity> objects) {
    return putAllByIndex(r'templateId', objects);
  }

  List<Id> putAllByTemplateIdSync(
    List<WorkoutTemplateEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'templateId', objects, saveLinks: saveLinks);
  }
}

extension WorkoutTemplateEntityQueryWhereSort
    on QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QWhere> {
  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension WorkoutTemplateEntityQueryWhere
    on
        QueryBuilder<
          WorkoutTemplateEntity,
          WorkoutTemplateEntity,
          QWhereClause
        > {
  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterWhereClause>
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

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterWhereClause>
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

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterWhereClause>
  templateIdEqualTo(String templateId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'templateId', value: [templateId]),
      );
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterWhereClause>
  templateIdNotEqualTo(String templateId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [],
                upper: [templateId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [templateId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [templateId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [],
                upper: [templateId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterWhereClause>
  ownerUserIdEqualTo(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'ownerUserId',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterWhereClause>
  ownerUserIdNotEqualTo(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterWhereClause>
  normalizedNameEqualTo(String normalizedName) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'normalizedName',
          value: [normalizedName],
        ),
      );
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterWhereClause>
  normalizedNameNotEqualTo(String normalizedName) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'normalizedName',
                lower: [],
                upper: [normalizedName],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'normalizedName',
                lower: [normalizedName],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'normalizedName',
                lower: [normalizedName],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'normalizedName',
                lower: [],
                upper: [normalizedName],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension WorkoutTemplateEntityQueryFilter
    on
        QueryBuilder<
          WorkoutTemplateEntity,
          WorkoutTemplateEntity,
          QFilterCondition
        > {
  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'deletedAt'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'deletedAt'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'deletedAt', value: value),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  deletedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'deletedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  deletedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'deletedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  deletedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'deletedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
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
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
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
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
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
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
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
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  lastUsedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastUsedAt'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  lastUsedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastUsedAt'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  lastUsedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastUsedAt', value: value),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  lastUsedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastUsedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  lastUsedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastUsedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  lastUsedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastUsedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  normalizedNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  normalizedNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  normalizedNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  normalizedNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'normalizedName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  normalizedNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  normalizedNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  normalizedNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'normalizedName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  normalizedNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'normalizedName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  normalizedNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'normalizedName', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  normalizedNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'normalizedName', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ownerUserId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'ownerUserId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ownerUserId', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ownerUserId', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  statusIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'statusIndex', value: value),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  statusIndexGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'statusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  statusIndexLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'statusIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  statusIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'statusIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  templateIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  templateIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  templateIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  templateIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'templateId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  templateIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  templateIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  templateIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  templateIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'templateId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  templateIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'templateId', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  templateIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'templateId', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
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
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
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
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
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
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
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
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  useCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'useCount', value: value),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  useCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'useCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  useCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'useCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateEntity,
    WorkoutTemplateEntity,
    QAfterFilterCondition
  >
  useCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'useCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension WorkoutTemplateEntityQueryObject
    on
        QueryBuilder<
          WorkoutTemplateEntity,
          WorkoutTemplateEntity,
          QFilterCondition
        > {}

extension WorkoutTemplateEntityQueryLinks
    on
        QueryBuilder<
          WorkoutTemplateEntity,
          WorkoutTemplateEntity,
          QFilterCondition
        > {}

extension WorkoutTemplateEntityQuerySortBy
    on QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QSortBy> {
  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByNormalizedName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedName', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByNormalizedNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedName', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusIndex', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusIndex', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByTemplateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByTemplateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  sortByUseCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.desc);
    });
  }
}

extension WorkoutTemplateEntityQuerySortThenBy
    on QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QSortThenBy> {
  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByNormalizedName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedName', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByNormalizedNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'normalizedName', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusIndex', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'statusIndex', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByTemplateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByTemplateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.asc);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QAfterSortBy>
  thenByUseCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.desc);
    });
  }
}

extension WorkoutTemplateEntityQueryWhereDistinct
    on QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QDistinct> {
  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QDistinct>
  distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QDistinct>
  distinctByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUsedAt');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QDistinct>
  distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QDistinct>
  distinctByNormalizedName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'normalizedName',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerUserId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QDistinct>
  distinctByStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'statusIndex');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QDistinct>
  distinctByTemplateId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, WorkoutTemplateEntity, QDistinct>
  distinctByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'useCount');
    });
  }
}

extension WorkoutTemplateEntityQueryProperty
    on
        QueryBuilder<
          WorkoutTemplateEntity,
          WorkoutTemplateEntity,
          QQueryProperty
        > {
  QueryBuilder<WorkoutTemplateEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, DateTime?, QQueryOperations>
  deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, DateTime?, QQueryOperations>
  lastUsedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUsedAt');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, String, QQueryOperations>
  normalizedNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'normalizedName');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerUserId');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, int, QQueryOperations>
  statusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'statusIndex');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, String, QQueryOperations>
  templateIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateId');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, DateTime, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<WorkoutTemplateEntity, int, QQueryOperations>
  useCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'useCount');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetWorkoutTemplateItemEntityCollection on Isar {
  IsarCollection<WorkoutTemplateItemEntity> get workoutTemplateItemEntitys =>
      this.collection();
}

const WorkoutTemplateItemEntitySchema = CollectionSchema(
  name: r'WorkoutTemplateItemEntity',
  id: -5752190397762700841,
  properties: {
    r'activityId': PropertySchema(
      id: 0,
      name: r'activityId',
      type: IsarType.string,
    ),
    r'categoryKey': PropertySchema(
      id: 1,
      name: r'categoryKey',
      type: IsarType.string,
    ),
    r'durationMin': PropertySchema(
      id: 2,
      name: r'durationMin',
      type: IsarType.long,
    ),
    r'intensity': PropertySchema(
      id: 3,
      name: r'intensity',
      type: IsarType.string,
    ),
    r'itemId': PropertySchema(id: 4, name: r'itemId', type: IsarType.string),
    r'liftWeightKg': PropertySchema(
      id: 5,
      name: r'liftWeightKg',
      type: IsarType.double,
    ),
    r'metValue': PropertySchema(
      id: 6,
      name: r'metValue',
      type: IsarType.double,
    ),
    r'name': PropertySchema(id: 7, name: r'name', type: IsarType.string),
    r'notes': PropertySchema(id: 8, name: r'notes', type: IsarType.string),
    r'ownerUserId': PropertySchema(
      id: 9,
      name: r'ownerUserId',
      type: IsarType.string,
    ),
    r'reps': PropertySchema(id: 10, name: r'reps', type: IsarType.long),
    r'sets': PropertySchema(id: 11, name: r'sets', type: IsarType.long),
    r'sortOrder': PropertySchema(
      id: 12,
      name: r'sortOrder',
      type: IsarType.long,
    ),
    r'sourceKey': PropertySchema(
      id: 13,
      name: r'sourceKey',
      type: IsarType.string,
    ),
    r'templateId': PropertySchema(
      id: 14,
      name: r'templateId',
      type: IsarType.string,
    ),
  },
  estimateSize: _workoutTemplateItemEntityEstimateSize,
  serialize: _workoutTemplateItemEntitySerialize,
  deserialize: _workoutTemplateItemEntityDeserialize,
  deserializeProp: _workoutTemplateItemEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'itemId': IndexSchema(
      id: -5342806140158601489,
      name: r'itemId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'itemId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'templateId': IndexSchema(
      id: -5352721467389445085,
      name: r'templateId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'templateId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'ownerUserId': IndexSchema(
      id: 1631799950038639233,
      name: r'ownerUserId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'ownerUserId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'sortOrder': IndexSchema(
      id: -1119549396205841918,
      name: r'sortOrder',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'sortOrder',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _workoutTemplateItemEntityGetId,
  getLinks: _workoutTemplateItemEntityGetLinks,
  attach: _workoutTemplateItemEntityAttach,
  version: '3.1.0+1',
);

int _workoutTemplateItemEntityEstimateSize(
  WorkoutTemplateItemEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.activityId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.categoryKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.intensity;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.itemId.length * 3;
  bytesCount += 3 + object.name.length * 3;
  {
    final value = object.notes;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.ownerUserId.length * 3;
  {
    final value = object.sourceKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.templateId.length * 3;
  return bytesCount;
}

void _workoutTemplateItemEntitySerialize(
  WorkoutTemplateItemEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.activityId);
  writer.writeString(offsets[1], object.categoryKey);
  writer.writeLong(offsets[2], object.durationMin);
  writer.writeString(offsets[3], object.intensity);
  writer.writeString(offsets[4], object.itemId);
  writer.writeDouble(offsets[5], object.liftWeightKg);
  writer.writeDouble(offsets[6], object.metValue);
  writer.writeString(offsets[7], object.name);
  writer.writeString(offsets[8], object.notes);
  writer.writeString(offsets[9], object.ownerUserId);
  writer.writeLong(offsets[10], object.reps);
  writer.writeLong(offsets[11], object.sets);
  writer.writeLong(offsets[12], object.sortOrder);
  writer.writeString(offsets[13], object.sourceKey);
  writer.writeString(offsets[14], object.templateId);
}

WorkoutTemplateItemEntity _workoutTemplateItemEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WorkoutTemplateItemEntity();
  object.activityId = reader.readStringOrNull(offsets[0]);
  object.categoryKey = reader.readStringOrNull(offsets[1]);
  object.durationMin = reader.readLong(offsets[2]);
  object.id = id;
  object.intensity = reader.readStringOrNull(offsets[3]);
  object.itemId = reader.readString(offsets[4]);
  object.liftWeightKg = reader.readDoubleOrNull(offsets[5]);
  object.metValue = reader.readDoubleOrNull(offsets[6]);
  object.name = reader.readString(offsets[7]);
  object.notes = reader.readStringOrNull(offsets[8]);
  object.ownerUserId = reader.readString(offsets[9]);
  object.reps = reader.readLongOrNull(offsets[10]);
  object.sets = reader.readLongOrNull(offsets[11]);
  object.sortOrder = reader.readLong(offsets[12]);
  object.sourceKey = reader.readStringOrNull(offsets[13]);
  object.templateId = reader.readString(offsets[14]);
  return object;
}

P _workoutTemplateItemEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readDoubleOrNull(offset)) as P;
    case 6:
      return (reader.readDoubleOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readLongOrNull(offset)) as P;
    case 11:
      return (reader.readLongOrNull(offset)) as P;
    case 12:
      return (reader.readLong(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _workoutTemplateItemEntityGetId(WorkoutTemplateItemEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _workoutTemplateItemEntityGetLinks(
  WorkoutTemplateItemEntity object,
) {
  return [];
}

void _workoutTemplateItemEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  WorkoutTemplateItemEntity object,
) {
  object.id = id;
}

extension WorkoutTemplateItemEntityByIndex
    on IsarCollection<WorkoutTemplateItemEntity> {
  Future<WorkoutTemplateItemEntity?> getByItemId(String itemId) {
    return getByIndex(r'itemId', [itemId]);
  }

  WorkoutTemplateItemEntity? getByItemIdSync(String itemId) {
    return getByIndexSync(r'itemId', [itemId]);
  }

  Future<bool> deleteByItemId(String itemId) {
    return deleteByIndex(r'itemId', [itemId]);
  }

  bool deleteByItemIdSync(String itemId) {
    return deleteByIndexSync(r'itemId', [itemId]);
  }

  Future<List<WorkoutTemplateItemEntity?>> getAllByItemId(
    List<String> itemIdValues,
  ) {
    final values = itemIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'itemId', values);
  }

  List<WorkoutTemplateItemEntity?> getAllByItemIdSync(
    List<String> itemIdValues,
  ) {
    final values = itemIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'itemId', values);
  }

  Future<int> deleteAllByItemId(List<String> itemIdValues) {
    final values = itemIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'itemId', values);
  }

  int deleteAllByItemIdSync(List<String> itemIdValues) {
    final values = itemIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'itemId', values);
  }

  Future<Id> putByItemId(WorkoutTemplateItemEntity object) {
    return putByIndex(r'itemId', object);
  }

  Id putByItemIdSync(
    WorkoutTemplateItemEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'itemId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByItemId(List<WorkoutTemplateItemEntity> objects) {
    return putAllByIndex(r'itemId', objects);
  }

  List<Id> putAllByItemIdSync(
    List<WorkoutTemplateItemEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'itemId', objects, saveLinks: saveLinks);
  }
}

extension WorkoutTemplateItemEntityQueryWhereSort
    on
        QueryBuilder<
          WorkoutTemplateItemEntity,
          WorkoutTemplateItemEntity,
          QWhere
        > {
  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhere
  >
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhere
  >
  anySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'sortOrder'),
      );
    });
  }
}

extension WorkoutTemplateItemEntityQueryWhere
    on
        QueryBuilder<
          WorkoutTemplateItemEntity,
          WorkoutTemplateItemEntity,
          QWhereClause
        > {
  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
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
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
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
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
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
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
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

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhereClause
  >
  itemIdEqualTo(String itemId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'itemId', value: [itemId]),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhereClause
  >
  itemIdNotEqualTo(String itemId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'itemId',
                lower: [],
                upper: [itemId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'itemId',
                lower: [itemId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'itemId',
                lower: [itemId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'itemId',
                lower: [],
                upper: [itemId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhereClause
  >
  templateIdEqualTo(String templateId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'templateId', value: [templateId]),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhereClause
  >
  templateIdNotEqualTo(String templateId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [],
                upper: [templateId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [templateId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [templateId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'templateId',
                lower: [],
                upper: [templateId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhereClause
  >
  ownerUserIdEqualTo(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'ownerUserId',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhereClause
  >
  ownerUserIdNotEqualTo(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerUserId',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhereClause
  >
  sortOrderEqualTo(int sortOrder) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'sortOrder', value: [sortOrder]),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhereClause
  >
  sortOrderNotEqualTo(int sortOrder) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sortOrder',
                lower: [],
                upper: [sortOrder],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sortOrder',
                lower: [sortOrder],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sortOrder',
                lower: [sortOrder],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sortOrder',
                lower: [],
                upper: [sortOrder],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhereClause
  >
  sortOrderGreaterThan(int sortOrder, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'sortOrder',
          lower: [sortOrder],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhereClause
  >
  sortOrderLessThan(int sortOrder, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'sortOrder',
          lower: [],
          upper: [sortOrder],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterWhereClause
  >
  sortOrderBetween(
    int lowerSortOrder,
    int upperSortOrder, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'sortOrder',
          lower: [lowerSortOrder],
          includeLower: includeLower,
          upper: [upperSortOrder],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension WorkoutTemplateItemEntityQueryFilter
    on
        QueryBuilder<
          WorkoutTemplateItemEntity,
          WorkoutTemplateItemEntity,
          QFilterCondition
        > {
  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  activityIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'activityId'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  activityIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'activityId'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  activityIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  activityIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  activityIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  activityIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'activityId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  activityIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  activityIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  activityIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'activityId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  activityIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'activityId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  activityIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'activityId', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  activityIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'activityId', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  categoryKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'categoryKey'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  categoryKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'categoryKey'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  categoryKeyEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'categoryKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  categoryKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'categoryKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  categoryKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'categoryKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  categoryKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'categoryKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  categoryKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'categoryKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  categoryKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'categoryKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  categoryKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'categoryKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  categoryKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'categoryKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  categoryKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'categoryKey', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  categoryKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'categoryKey', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  durationMinEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'durationMin', value: value),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
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
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
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
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
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
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
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
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  intensityIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'intensity'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  intensityIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'intensity'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  intensityEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'intensity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  intensityGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'intensity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  intensityLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'intensity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  intensityBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'intensity',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  intensityStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'intensity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  intensityEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'intensity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  intensityContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'intensity',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  intensityMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'intensity',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  intensityIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'intensity', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  intensityIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'intensity', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'itemId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'itemId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'itemId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'itemId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'itemId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'itemId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'itemId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'itemId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'itemId', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  itemIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'itemId', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  liftWeightKgIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'liftWeightKg'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  liftWeightKgIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'liftWeightKg'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  liftWeightKgEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'liftWeightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  liftWeightKgGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'liftWeightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  liftWeightKgLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'liftWeightKg',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  liftWeightKgBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'liftWeightKg',
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
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  metValueIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'metValue'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  metValueIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'metValue'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  metValueEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'metValue',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  metValueGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'metValue',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  metValueLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'metValue',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  metValueBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'metValue',
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
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  notesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'notes'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  notesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'notes'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  notesEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  notesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  notesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  notesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'notes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  notesStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  notesEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  notesContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'notes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  notesMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'notes',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'notes', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'notes', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ownerUserId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'ownerUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'ownerUserId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ownerUserId', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ownerUserId', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  repsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'reps'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  repsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'reps'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  repsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'reps', value: value),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  repsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'reps',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  repsLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'reps',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  repsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'reps',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  setsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sets'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  setsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sets'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  setsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sets', value: value),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  setsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sets',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  setsLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sets',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  setsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sets',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sortOrderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sortOrder', value: value),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sortOrderGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sortOrder',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sortOrderLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sortOrder',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sortOrderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sortOrder',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sourceKey'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sourceKey'),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceKeyEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sourceKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sourceKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceKey', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  sourceKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sourceKey', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'templateId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'templateId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'templateId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'templateId', value: ''),
      );
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterFilterCondition
  >
  templateIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'templateId', value: ''),
      );
    });
  }
}

extension WorkoutTemplateItemEntityQueryObject
    on
        QueryBuilder<
          WorkoutTemplateItemEntity,
          WorkoutTemplateItemEntity,
          QFilterCondition
        > {}

extension WorkoutTemplateItemEntityQueryLinks
    on
        QueryBuilder<
          WorkoutTemplateItemEntity,
          WorkoutTemplateItemEntity,
          QFilterCondition
        > {}

extension WorkoutTemplateItemEntityQuerySortBy
    on
        QueryBuilder<
          WorkoutTemplateItemEntity,
          WorkoutTemplateItemEntity,
          QSortBy
        > {
  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByActivityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityId', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByActivityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityId', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByCategoryKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryKey', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByCategoryKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryKey', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByDurationMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMin', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByDurationMinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMin', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByIntensity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intensity', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByIntensityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intensity', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByLiftWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'liftWeightKg', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByLiftWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'liftWeightKg', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByMetValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metValue', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByMetValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metValue', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByReps() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reps', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByRepsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reps', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortBySets() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sets', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortBySetsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sets', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortBySourceKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceKey', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortBySourceKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceKey', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByTemplateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  sortByTemplateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.desc);
    });
  }
}

extension WorkoutTemplateItemEntityQuerySortThenBy
    on
        QueryBuilder<
          WorkoutTemplateItemEntity,
          WorkoutTemplateItemEntity,
          QSortThenBy
        > {
  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByActivityId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityId', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByActivityIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityId', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByCategoryKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryKey', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByCategoryKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryKey', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByDurationMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMin', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByDurationMinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMin', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByIntensity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intensity', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByIntensityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intensity', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByLiftWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'liftWeightKg', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByLiftWeightKgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'liftWeightKg', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByMetValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metValue', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByMetValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metValue', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerUserId', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByReps() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reps', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByRepsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reps', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenBySets() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sets', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenBySetsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sets', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenBySourceKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceKey', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenBySourceKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceKey', Sort.desc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByTemplateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.asc);
    });
  }

  QueryBuilder<
    WorkoutTemplateItemEntity,
    WorkoutTemplateItemEntity,
    QAfterSortBy
  >
  thenByTemplateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateId', Sort.desc);
    });
  }
}

extension WorkoutTemplateItemEntityQueryWhereDistinct
    on
        QueryBuilder<
          WorkoutTemplateItemEntity,
          WorkoutTemplateItemEntity,
          QDistinct
        > {
  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctByActivityId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activityId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctByCategoryKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'categoryKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctByDurationMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'durationMin');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctByIntensity({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'intensity', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctByItemId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctByLiftWeightKg() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'liftWeightKg');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctByMetValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metValue');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctByNotes({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerUserId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctByReps() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reps');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctBySets() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sets');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sortOrder');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctBySourceKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, WorkoutTemplateItemEntity, QDistinct>
  distinctByTemplateId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateId', caseSensitive: caseSensitive);
    });
  }
}

extension WorkoutTemplateItemEntityQueryProperty
    on
        QueryBuilder<
          WorkoutTemplateItemEntity,
          WorkoutTemplateItemEntity,
          QQueryProperty
        > {
  QueryBuilder<WorkoutTemplateItemEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, String?, QQueryOperations>
  activityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activityId');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, String?, QQueryOperations>
  categoryKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'categoryKey');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, int, QQueryOperations>
  durationMinProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'durationMin');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, String?, QQueryOperations>
  intensityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'intensity');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, String, QQueryOperations>
  itemIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemId');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, double?, QQueryOperations>
  liftWeightKgProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'liftWeightKg');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, double?, QQueryOperations>
  metValueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metValue');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, String, QQueryOperations>
  nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, String?, QQueryOperations>
  notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerUserId');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, int?, QQueryOperations>
  repsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reps');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, int?, QQueryOperations>
  setsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sets');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, int, QQueryOperations>
  sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sortOrder');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, String?, QQueryOperations>
  sourceKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceKey');
    });
  }

  QueryBuilder<WorkoutTemplateItemEntity, String, QQueryOperations>
  templateIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateId');
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
