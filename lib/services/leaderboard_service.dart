import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/habit.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardService {
  LeaderboardService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static String currentWeekKey([DateTime? date]) {
    final now = date ?? DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  CollectionReference<Map<String, dynamic>> _entriesRef(String weekKey) {
    return _firestore
        .collection('leaderboards')
        .doc(weekKey)
        .collection('entries');
  }

  Stream<List<LeaderboardEntry>> watchTopUsers({int limit = 50}) {
    final weekKey = currentWeekKey();
    return _entriesRef(weekKey)
        .orderBy('score', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(LeaderboardEntry.fromFirestore).toList(),
        );
  }

  Future<void> syncCurrentUserScore(List<Habit> habits) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final weekKey = currentWeekKey(now);
    final today = DateFormat('yyyy-MM-dd').format(now);
    final weekStart = DateTime.parse(weekKey);

    int weeklyCompletions = 0;
    int completedToday = 0;
    int currentStreak = 0;

    for (final habit in habits) {
      if (habit.currentStreak > currentStreak) {
        currentStreak = habit.currentStreak;
      }

      for (final entry in habit.completedDates) {
        final datePart = entry.split('_split_').first;
        final completedDate = DateTime.tryParse(datePart);
        if (completedDate == null) continue;

        if (!completedDate.isBefore(weekStart) && !completedDate.isAfter(now)) {
          weeklyCompletions++;
        }
        if (datePart == today) {
          completedToday++;
        }
      }
    }

    final cappedToday = completedToday > 10 ? 10 : completedToday;
    final cappedWeekly = weeklyCompletions > 70 ? 70 : weeklyCompletions;
    final cappedStreak = currentStreak > 30 ? 30 : currentStreak;
    final score = (cappedWeekly * 10) + (cappedStreak * 4) + (cappedToday * 3);

    final displayName = _safeDisplayName(user);
    final photoUrl = user.photoURL ?? '';
    final entryRef = _entriesRef(weekKey).doc(user.uid);
    final privateUserRef = _firestore.collection('users_private').doc(user.uid);

    final batch = _firestore.batch();
    batch.set(entryRef, {
      'uid': user.uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'score': score,
      'weeklyCompletions': weeklyCompletions,
      'completedToday': completedToday,
      'currentStreak': currentStreak,
      'weekKey': weekKey,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(privateUserRef, {
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': displayName,
      'photoUrl': photoUrl,
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  String _safeDisplayName(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name.length > 40 ? name.substring(0, 40) : name;
    }
    final emailName = user.email?.split('@').first.trim();
    if (emailName != null && emailName.isNotEmpty) {
      return emailName.length > 40 ? emailName.substring(0, 40) : emailName;
    }
    return 'StreakMind user';
  }
}
