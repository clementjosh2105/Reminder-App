import 'package:cloud_firestore/cloud_firestore.dart';

class Challenge {
  final String id;
  final List<String> participantUids;
  final String creatorUid;
  final String recipientUid;
  final String title;
  final int durationDays;
  final String status;
  final List<String> completedUids;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Challenge({
    required this.id,
    required this.participantUids,
    required this.creatorUid,
    required this.recipientUid,
    required this.title,
    required this.durationDays,
    required this.status,
    required this.completedUids,
    this.createdAt,
    this.updatedAt,
  });

  factory Challenge.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Challenge(
      id: doc.id,
      participantUids: (data['participantUids'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      creatorUid: data['creatorUid'] as String? ?? '',
      recipientUid: data['recipientUid'] as String? ?? '',
      title: data['title'] as String? ?? 'Consistency challenge',
      durationDays: data['durationDays'] as int? ?? 3,
      status: data['status'] as String? ?? 'pending',
      completedUids: (data['completedUids'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
