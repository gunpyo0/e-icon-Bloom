import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_score.freezed.dart';
part 'user_score.g.dart';

@freezed
abstract class UserScore with _$UserScore {
  const factory UserScore({
    required String name,
    required int rank,
    required int point,
  }) = _UserScore;

  factory UserScore.fromJson(Map<String, dynamic> json) =>
      _$UserScoreFromJson(json);
}