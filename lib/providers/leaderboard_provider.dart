import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';

final leaderboardServiceProvider = Provider<LeaderboardService>(
  (ref) => LeaderboardService(),
);

final leaderboardProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(leaderboardServiceProvider).watchTopUsers();
});
