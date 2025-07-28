// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_score.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserScore {

 String get name; int get rank; int get point;
/// Create a copy of UserScore
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserScoreCopyWith<UserScore> get copyWith => _$UserScoreCopyWithImpl<UserScore>(this as UserScore, _$identity);

  /// Serializes this UserScore to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserScore&&(identical(other.name, name) || other.name == name)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.point, point) || other.point == point));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,rank,point);

@override
String toString() {
  return 'UserScore(name: $name, rank: $rank, point: $point)';
}


}

/// @nodoc
abstract mixin class $UserScoreCopyWith<$Res>  {
  factory $UserScoreCopyWith(UserScore value, $Res Function(UserScore) _then) = _$UserScoreCopyWithImpl;
@useResult
$Res call({
 String name, int rank, int point
});




}
/// @nodoc
class _$UserScoreCopyWithImpl<$Res>
    implements $UserScoreCopyWith<$Res> {
  _$UserScoreCopyWithImpl(this._self, this._then);

  final UserScore _self;
  final $Res Function(UserScore) _then;

/// Create a copy of UserScore
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? rank = null,Object? point = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,point: null == point ? _self.point : point // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UserScore].
extension UserScorePatterns on UserScore {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserScore value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserScore() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserScore value)  $default,){
final _that = this;
switch (_that) {
case _UserScore():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserScore value)?  $default,){
final _that = this;
switch (_that) {
case _UserScore() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int rank,  int point)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserScore() when $default != null:
return $default(_that.name,_that.rank,_that.point);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int rank,  int point)  $default,) {final _that = this;
switch (_that) {
case _UserScore():
return $default(_that.name,_that.rank,_that.point);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int rank,  int point)?  $default,) {final _that = this;
switch (_that) {
case _UserScore() when $default != null:
return $default(_that.name,_that.rank,_that.point);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserScore implements UserScore {
  const _UserScore({required this.name, required this.rank, required this.point});
  factory _UserScore.fromJson(Map<String, dynamic> json) => _$UserScoreFromJson(json);

@override final  String name;
@override final  int rank;
@override final  int point;

/// Create a copy of UserScore
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserScoreCopyWith<_UserScore> get copyWith => __$UserScoreCopyWithImpl<_UserScore>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserScoreToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserScore&&(identical(other.name, name) || other.name == name)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.point, point) || other.point == point));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,rank,point);

@override
String toString() {
  return 'UserScore(name: $name, rank: $rank, point: $point)';
}


}

/// @nodoc
abstract mixin class _$UserScoreCopyWith<$Res> implements $UserScoreCopyWith<$Res> {
  factory _$UserScoreCopyWith(_UserScore value, $Res Function(_UserScore) _then) = __$UserScoreCopyWithImpl;
@override @useResult
$Res call({
 String name, int rank, int point
});




}
/// @nodoc
class __$UserScoreCopyWithImpl<$Res>
    implements _$UserScoreCopyWith<$Res> {
  __$UserScoreCopyWithImpl(this._self, this._then);

  final _UserScore _self;
  final $Res Function(_UserScore) _then;

/// Create a copy of UserScore
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? rank = null,Object? point = null,}) {
  return _then(_UserScore(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,point: null == point ? _self.point : point // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
