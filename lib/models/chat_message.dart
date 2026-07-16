import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderUid;
  final String text;
  final List<String> readBy;
  final DateTime? sentAt;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.readBy,
    this.sentAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      senderUid: data['senderUid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      readBy: (data['readBy'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
    );
  }
}
