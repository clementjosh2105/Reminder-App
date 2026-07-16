import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/activity_item.dart';
import '../models/chat_message.dart';
import '../models/challenge.dart';
import '../models/friendship.dart';
import '../models/habit.dart';
import 'leaderboard_service.dart';

class FriendProfileStats {
  final int score;
  final int weeklyCompletions;
  final int completedToday;
  final int currentStreak;
  final DateTime? updatedAt;

  const FriendProfileStats({
    required this.score,
    required this.weeklyCompletions,
    required this.completedToday,
    required this.currentStreak,
    this.updatedAt,
  });
}

class SocialService {
  SocialService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _publicUsers =>
      _firestore.collection('users_public');

  CollectionReference<Map<String, dynamic>> get _emailLookup =>
      _firestore.collection('user_email_lookup');

  CollectionReference<Map<String, dynamic>> get _friendships =>
      _firestore.collection('friendships');

  CollectionReference<Map<String, dynamic>> get _activities =>
      _firestore.collection('activities');

  CollectionReference<Map<String, dynamic>> get _blocks =>
      _firestore.collection('blocks');

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  CollectionReference<Map<String, dynamic>> get _challenges =>
      _firestore.collection('challenges');

  Stream<List<Friendship>> watchMyFriendships() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _friendships
        .where('participantUids', arrayContains: user.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Friendship.fromDoc)
              .where(
                (friendship) =>
                    friendship.status != 'removed' &&
                    !friendship.hiddenFor.contains(user.uid),
              )
              .toList(),
        );
  }

  Stream<List<ChatMessage>> watchMessages(String friendshipId) {
    return _friendships
        .doc(friendshipId)
        .collection('messages')
        .orderBy('sentAt')
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatMessage.fromDoc).toList());
  }

  Stream<List<ActivityItem>> watchFriendActivity() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _activities
        .where('visibleToUids', arrayContains: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ActivityItem.fromDoc).toList());
  }

  Stream<List<Challenge>> watchMyChallenges() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _challenges
        .where('participantUids', arrayContains: user.uid)
        .orderBy('updatedAt', descending: true)
        .limit(40)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Challenge.fromDoc).toList());
  }

  Future<void> syncCurrentUserPublicProfile({
    bool shareActivityWithFriends = true,
    bool socialNotifications = true,
    String friendRequestMode = 'everyone',
  }) async {
    final user = _requireUser();
    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return;

    final displayName = _displayName(user);
    final photoUrl = user.photoURL ?? '';
    final emailHash = hashEmail(email);
    final batch = _firestore.batch();

    batch.set(_publicUsers.doc(user.uid), {
      'uid': user.uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'shareActivityWithFriends': shareActivityWithFriends,
      'socialNotifications': socialNotifications,
      'friendRequestMode': friendRequestMode,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(_emailLookup.doc(emailHash), {
      'uid': user.uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'emailHash': emailHash,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    await _syncDeviceToken(user.uid, socialNotifications);
  }

  Future<void> sendFriendRequestByEmail(String email) async {
    final user = _requireUser();
    await syncCurrentUserPublicProfile();

    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.contains('@')) {
      throw ArgumentError('Enter a valid email address.');
    }
    if (normalizedEmail == user.email?.trim().toLowerCase()) {
      throw ArgumentError('You cannot add yourself.');
    }

    final lookupDoc = await _emailLookup.doc(hashEmail(normalizedEmail)).get();
    final lookup = lookupDoc.data();
    final targetUid = lookup?['uid'] as String?;
    if (targetUid == null || targetUid.isEmpty) {
      throw StateError('No StreakMind user found for that email.');
    }

    final targetUser = await _publicUsers.doc(targetUid).get();
    final targetData = targetUser.data();
    if (targetData == null) {
      throw StateError('That user has not finished profile setup yet.');
    }
    if ((targetData['friendRequestMode'] as String? ?? 'everyone') ==
        'no_one') {
      throw StateError('This user is not accepting friend requests.');
    }

    final friendshipId = pairId(user.uid, targetUid);
    final existing = await _friendships.doc(friendshipId).get();
    if (existing.exists) {
      throw StateError('A friend request or friendship already exists.');
    }

    await _throwIfBlocked(user.uid, targetUid);

    await _friendships.doc(friendshipId).set({
      'participantUids': _sortedPair(user.uid, targetUid),
      'requesterUid': user.uid,
      'recipientUid': targetUid,
      'requesterName': _displayName(user),
      'requesterPhotoUrl': user.photoURL ?? '',
      'recipientName':
          targetData['displayName'] as String? ?? 'StreakMind user',
      'recipientPhotoUrl': targetData['photoUrl'] as String? ?? '',
      'status': 'pending',
      'unreadBy': <String>[],
      'hiddenFor': <String>[],
      'lastMessageText': '',
      'lastMessageSenderUid': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> respondToFriendRequest({
    required String friendshipId,
    required bool accept,
  }) async {
    _requireUser();
    await _friendships.doc(friendshipId).update({
      'status': accept ? 'accepted' : 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendMessage({
    required String friendshipId,
    required String text,
  }) async {
    final user = _requireUser();
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length > 500) {
      throw ArgumentError('Keep messages under 500 characters.');
    }

    await _friendships.doc(friendshipId).collection('messages').add({
      'senderUid': user.uid,
      'text': trimmed,
      'sentAt': FieldValue.serverTimestamp(),
      'readBy': [user.uid],
    });
  }

  Future<void> markThreadRead(String friendshipId) async {
    final user = _requireUser();
    final friendshipRef = _friendships.doc(friendshipId);
    final unread = await friendshipRef
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(20)
        .get();
    final batch = _firestore.batch();
    batch.update(friendshipRef, {
      'unreadBy': FieldValue.arrayRemove([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final doc in unread.docs) {
      if (doc.data()['senderUid'] == user.uid) continue;
      final readBy = (doc.data()['readBy'] as List<dynamic>? ?? const [])
          .whereType<String>();
      if (!readBy.contains(user.uid)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([user.uid]),
        });
      }
    }
    await batch.commit();
  }

  Future<void> hideConversation(String friendshipId) async {
    final user = _requireUser();
    await _friendships.doc(friendshipId).update({
      'hiddenFor': FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFriend(Friendship friendship) async {
    final user = _requireUser();
    if (!friendship.participantUids.contains(user.uid)) {
      throw StateError('You can only remove your own friendships.');
    }
    await _friendships.doc(friendship.id).update({
      'status': 'removed',
      'unreadBy': <String>[],
      'hiddenFor': friendship.participantUids,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> blockUser(Friendship friendship) async {
    final user = _requireUser();
    final blockedUid = friendship.otherUid(user.uid);
    await _blocks.doc('${user.uid}_$blockedUid').set({
      'ownerUid': user.uid,
      'blockedUid': blockedUid,
      'friendshipId': friendship.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _friendships.doc(friendship.id).update({
      'status': 'blocked',
      'hiddenFor': FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<FriendProfileStats?> getFriendProfileStats(String uid) async {
    final user = _requireUser();
    if (uid == user.uid) return null;
    final weekKey = LeaderboardService.currentWeekKey();
    final doc = await _firestore
        .collection('leaderboards')
        .doc(weekKey)
        .collection('entries')
        .doc(uid)
        .get();
    final data = doc.data();
    if (data == null) return null;
    return FriendProfileStats(
      score: data['score'] as int? ?? 0,
      weeklyCompletions: data['weeklyCompletions'] as int? ?? 0,
      completedToday: data['completedToday'] as int? ?? 0,
      currentStreak: data['currentStreak'] as int? ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Future<void> reportUser({
    required Friendship friendship,
    required String reason,
  }) async {
    final user = _requireUser();
    final reportedUid = friendship.otherUid(user.uid);
    await _reports.add({
      'reporterUid': user.uid,
      'reportedUid': reportedUid,
      'friendshipId': friendship.id,
      'reason': reason.trim().isEmpty ? 'unspecified' : reason.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> publishHabitActivity({
    required Habit habit,
    required bool shareActivityWithFriends,
  }) async {
    if (!shareActivityWithFriends) return;
    final user = _auth.currentUser;
    if (user == null) return;

    final friendships = await _friendships
        .where('participantUids', arrayContains: user.uid)
        .where('status', isEqualTo: 'accepted')
        .limit(50)
        .get();
    final visibleTo = <String>{};
    for (final doc in friendships.docs) {
      final data = doc.data();
      final participants = (data['participantUids'] as List<dynamic>? ?? [])
          .whereType<String>();
      visibleTo.addAll(participants.where((uid) => uid != user.uid));
    }
    if (visibleTo.isEmpty) return;

    await _activities.add({
      'actorUid': user.uid,
      'actorName': _displayName(user),
      'actorPhotoUrl': user.photoURL ?? '',
      'type': 'habit_completed',
      'title': habit.title,
      'streak': habit.currentStreak,
      'visibleToUids': visibleTo.toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createChallenge({
    required Friendship friendship,
    required String title,
    required int durationDays,
  }) async {
    final user = _requireUser();
    final recipientUid = friendship.otherUid(user.uid);
    await _throwIfBlocked(user.uid, recipientUid);
    await _challenges.add({
      'participantUids': friendship.participantUids,
      'creatorUid': user.uid,
      'recipientUid': recipientUid,
      'title': title.trim().isEmpty ? 'Consistency challenge' : title.trim(),
      'durationDays': durationDays,
      'status': 'pending',
      'completedUids': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> respondToChallenge({
    required String challengeId,
    required bool accept,
  }) async {
    _requireUser();
    await _challenges.doc(challengeId).update({
      'status': accept ? 'active' : 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeChallenge(String challengeId) async {
    final user = _requireUser();
    await _challenges.doc(challengeId).update({
      'completedUids': FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static String hashEmail(String email) {
    return sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();
  }

  static String pairId(String a, String b) => _sortedPair(a, b).join('_');

  static List<String> _sortedPair(String a, String b) {
    final values = [a, b]..sort();
    return values;
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to use friends.');
    return user;
  }

  String _displayName(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return _truncate(name);
    final emailName = user.email?.split('@').first.trim();
    if (emailName != null && emailName.isNotEmpty) return _truncate(emailName);
    return 'StreakMind user';
  }

  String _truncate(String value) {
    return value.length > 40 ? value.substring(0, 40) : value;
  }

  Future<void> _syncDeviceToken(String uid, bool socialNotifications) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await _firestore.collection('device_tokens').doc(token).set({
      'token': token,
      'uid': uid,
      'socialNotifications': socialNotifications,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _throwIfBlocked(String a, String b) async {
    final aBlockedB = await _blocks.doc('${a}_$b').get();
    final bBlockedA = await _blocks.doc('${b}_$a').get();
    if (aBlockedB.exists || bBlockedA.exists) {
      throw StateError('This user is blocked.');
    }
  }
}
