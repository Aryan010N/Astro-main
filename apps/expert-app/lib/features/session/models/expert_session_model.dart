class IncomingSessionRequest {
  final String sessionId;
  final String userId;
  final String userName;
  final String sessionType;
  final String rateInPaise;
  final double rateInRupees;
  final int timeoutSeconds;

  const IncomingSessionRequest({
    required this.sessionId,
    required this.userId,
    required this.userName,
    required this.sessionType,
    required this.rateInPaise,
    required this.rateInRupees,
    required this.timeoutSeconds,
  });

  factory IncomingSessionRequest.fromJson(Map<String, dynamic> json) {
    return IncomingSessionRequest(
      sessionId: json['sessionId'] as String,
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Seeker',
      sessionType: json['sessionType'] as String? ?? 'CHAT',
      rateInPaise: json['rateInPaise']?.toString() ?? '2000',
      rateInRupees: (json['rateInRupees'] as num?)?.toDouble() ?? 20.0,
      timeoutSeconds: json['timeoutSeconds'] as int? ?? 30,
    );
  }
}

class ExpertActiveSession {
  final String id;
  final String userId;
  final String userName;
  final String sessionType;
  final String status;
  final double rateInRupees;
  final int durationSeconds;
  final double totalBilledRupees;
  final bool isPaused;
  final String? pauseReason;

  const ExpertActiveSession({
    required this.id,
    required this.userId,
    required this.userName,
    required this.sessionType,
    required this.status,
    required this.rateInRupees,
    this.durationSeconds = 0,
    this.totalBilledRupees = 0.0,
    this.isPaused = false,
    this.pauseReason,
  });

  ExpertActiveSession copyWith({
    String? status,
    int? durationSeconds,
    double? totalBilledRupees,
    bool? isPaused,
    String? pauseReason,
  }) {
    return ExpertActiveSession(
      id: id,
      userId: userId,
      userName: userName,
      sessionType: sessionType,
      status: status ?? this.status,
      rateInRupees: rateInRupees,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      totalBilledRupees: totalBilledRupees ?? this.totalBilledRupees,
      isPaused: isPaused ?? this.isPaused,
      pauseReason: pauseReason ?? this.pauseReason,
    );
  }
}

class ExpertChatMessage {
  final String id;
  final String sessionId;
  final String senderId;
  final String senderRole;
  final String text;
  final DateTime createdAt;

  const ExpertChatMessage({
    required this.id,
    required this.sessionId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  factory ExpertChatMessage.fromJson(Map<String, dynamic> json) {
    return ExpertChatMessage(
      id: json['id'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: json['sessionId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderRole: json['senderRole'] as String? ?? 'EXPERT',
      text: json['text'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isExpert => senderRole == 'EXPERT';
}
