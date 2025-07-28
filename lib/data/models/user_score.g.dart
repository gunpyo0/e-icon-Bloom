// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_score.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserScore _$UserScoreFromJson(Map<String, dynamic> json) => _UserScore(
  name: json['name'] as String,
  rank: (json['rank'] as num).toInt(),
  point: (json['point'] as num).toInt(),
);

Map<String, dynamic> _$UserScoreToJson(_UserScore instance) =>
    <String, dynamic>{
      'name': instance.name,
      'rank': instance.rank,
      'point': instance.point,
    };
