import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_item.dart';
import '../models/challenge.dart';
import '../models/friendship.dart';
import '../services/social_service.dart';

final socialServiceProvider = Provider<SocialService>((ref) => SocialService());

final myFriendshipsProvider = StreamProvider<List<Friendship>>((ref) {
  return ref.watch(socialServiceProvider).watchMyFriendships();
});

final friendActivityProvider = StreamProvider<List<ActivityItem>>((ref) {
  return ref.watch(socialServiceProvider).watchFriendActivity();
});

final myChallengesProvider = StreamProvider<List<Challenge>>((ref) {
  return ref.watch(socialServiceProvider).watchMyChallenges();
});
