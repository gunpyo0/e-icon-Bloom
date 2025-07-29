import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/api_client.dart';
import '../../../data/models/user_score.dart';

final mainViewModelProvider = FutureProvider<UserScore>((ref) async {
  final api = ApiClient();
  return api.getMyScore();
});
