import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityItem {
  final String id;
  final String actorUid;
  final String actorName;
  final String actorPhotoUrl;
  final String type;
  final String title;
  final int streak;
  final DateTime? createdAt;

  const ActivityItem({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.actorPhotoUrl,
    required this.type,
    required this.title,
    required this.streak,
    this.createdAt,
  });

  factory ActivityItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ActivityItem(
      id: doc.id,
      actorUid: data['actorUid'] as String? ?? '',
      actorName: data['actorName'] as String? ?? 'StreakMind user',
      actorPhotoUrl: data['actorPhotoUrl'] as String? ?? '',
      type: data['type'] as String? ?? 'habit_completed',
      title: data['title'] as String? ?? 'Completed a habit',
      streak: data['streak'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
