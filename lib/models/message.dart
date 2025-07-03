class Message {
  final String id;
  final String content;
  final String senderId;
  final String receiverId;
  final String conversationId;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.content,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    required this.conversationId,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      content: json['content'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      conversationId: json['conversationId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
