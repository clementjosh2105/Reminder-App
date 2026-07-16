import 'package:cloud_firestore/cloud_firestore.dart';

class FocusGroup {
  final String id;
  final String name;
  final String code;
  final String ownerUid;
  final String ownerName;
  final List<String> memberUids;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FocusGroup({
    required this.id,
    required this.name,
    required this.code,
    required this.ownerUid,
    required this.ownerName,
    required this.memberUids,
    this.createdAt,
    this.updatedAt,
  });

  factory FocusGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FocusGroup(
      id: doc.id,
      name: data['name'] as String? ?? 'Focus group',
      code: data['code'] as String? ?? doc.id,
      ownerUid: data['ownerUid'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? 'StreakMind user',
      memberUids: (data['memberUids'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
