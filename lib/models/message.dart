import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String? id; 
  final String content;
  final String senderId;
  final String receiverId;
  final String conversationId;
  final Timestamp timestamp;
  final bool isRead;

  Message({
    this.id,
    required this.content,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    required this.conversationId,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json, [String? docId]) {
    return Message(
      id: docId,
      content: json['content'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      conversationId: json['conversation_id'] as String,
      timestamp: json['timestamp'] as Timestamp,
      isRead: json['is_read'] ?? false, // Default to false if not provided
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'conversation_id': conversationId,
      'timestamp': timestamp,
      'is_read': isRead,
    };
  }
}
