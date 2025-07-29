import 'package:dio/dio.dart';
import '../models/user_score.dart';

class ApiClient {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.yourserver.com'));

  Future<UserScore> getMyScore() async {
    final res = await dio.get('/user/score');
    return UserScore.fromJson(res.data);
  }
}
