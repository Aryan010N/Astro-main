class ChatMessage {
  final String id;
  final String sessionId;
  final String senderId;
  final String senderRole; // USER, EXPERT, SYSTEM
  final String text;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? UniqueKey().toString(),
      sessionId: json['sessionId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderRole: json['senderRole'] as String? ?? 'USER',
      text: json['text'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isUser => senderRole == 'USER';
  bool get isSystem => senderRole == 'SYSTEM';
}

class UniqueKey {
  static int _counter = 0;
  @override
  String toString() => 'msg_${DateTime.now().millisecondsSinceEpoch}_${++_counter}';
}
