import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String photoUrl;
  final int score;
  final int weeklyCompletions;
  final int completedToday;
  final int currentStreak;
  final DateTime updatedAt;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.score,
    required this.weeklyCompletions,
    required this.completedToday,
    required this.currentStreak,
    required this.updatedAt,
  });

  factory LeaderboardEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LeaderboardEntry(
      uid: data['uid'] as String? ?? doc.id,
      displayName: data['displayName'] as String? ?? 'StreakMind user',
      photoUrl: data['photoUrl'] as String? ?? '',
      score: data['score'] as int? ?? 0,
      weeklyCompletions: data['weeklyCompletions'] as int? ?? 0,
      completedToday: data['completedToday'] as int? ?? 0,
      currentStreak: data['currentStreak'] as int? ?? 0,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
