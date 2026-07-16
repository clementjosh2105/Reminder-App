import 'package:cloud_firestore/cloud_firestore.dart';

class Friendship {
  final String id;
  final List<String> participantUids;
  final String requesterUid;
  final String recipientUid;
  final String requesterName;
  final String requesterPhotoUrl;
  final String recipientName;
  final String recipientPhotoUrl;
  final String status;
  final List<String> unreadBy;
  final List<String> hiddenFor;
  final String lastMessageText;
  final String lastMessageSenderUid;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Friendship({
    required this.id,
    required this.participantUids,
    required this.requesterUid,
    required this.recipientUid,
    required this.requesterName,
    required this.requesterPhotoUrl,
    required this.recipientName,
    required this.recipientPhotoUrl,
    required this.status,
    required this.unreadBy,
    required this.hiddenFor,
    required this.lastMessageText,
    required this.lastMessageSenderUid,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
  });

  factory Friendship.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Friendship(
      id: doc.id,
      participantUids: (data['participantUids'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      requesterUid: data['requesterUid'] as String? ?? '',
      recipientUid: data['recipientUid'] as String? ?? '',
      requesterName: data['requesterName'] as String? ?? 'StreakMind user',
      requesterPhotoUrl: data['requesterPhotoUrl'] as String? ?? '',
      recipientName: data['recipientName'] as String? ?? 'StreakMind user',
      recipientPhotoUrl: data['recipientPhotoUrl'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      unreadBy: (data['unreadBy'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      hiddenFor: (data['hiddenFor'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      lastMessageText: data['lastMessageText'] as String? ?? '',
      lastMessageSenderUid: data['lastMessageSenderUid'] as String? ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  String otherUid(String currentUid) {
    return requesterUid == currentUid ? recipientUid : requesterUid;
  }

  String otherName(String currentUid) {
    return requesterUid == currentUid ? recipientName : requesterName;
  }

  String otherPhotoUrl(String currentUid) {
    return requesterUid == currentUid ? recipientPhotoUrl : requesterPhotoUrl;
  }
}
