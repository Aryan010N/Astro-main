class ConsultationSession {
  final String id;
  final String userId;
  final String expertId;
  final String? expertName;
  final String sessionType;
  final String status;
  final double rateInRupees;
  final String rateInPaise;
  final int durationSeconds;
  final double totalBilledRupees;
  final String totalBilledPaise;
  final String? startedAt;
  final String? endedAt;
  final String? endReason;
  final bool isPaused;
  final String? pauseReason;

  const ConsultationSession({
    required this.id,
    required this.userId,
    required this.expertId,
    this.expertName,
    required this.sessionType,
    required this.status,
    required this.rateInRupees,
    required this.rateInPaise,
    this.durationSeconds = 0,
    this.totalBilledRupees = 0.0,
    this.totalBilledPaise = '0',
    this.startedAt,
    this.endedAt,
    this.endReason,
    this.isPaused = false,
    this.pauseReason,
  });

  factory ConsultationSession.fromJson(Map<String, dynamic> json) {
    return ConsultationSession(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      expertId: json['expertId'] as String? ?? '',
      expertName: json['expert']?['name'] as String? ?? json['expertName'] as String?,
      sessionType: json['sessionType'] as String? ?? 'CHAT',
      status: json['status'] as String? ?? 'REQUESTED',
      rateInRupees: (json['rateInRupees'] as num?)?.toDouble() ?? 20.0,
      rateInPaise: json['rateInPaise']?.toString() ?? '2000',
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      totalBilledRupees: (json['totalBilledRupees'] as num?)?.toDouble() ?? 0.0,
      totalBilledPaise: json['totalBilledPaise']?.toString() ?? '0',
      startedAt: json['startedAt'] as String?,
      endedAt: json['endedAt'] as String?,
      endReason: json['endReason'] as String?,
      isPaused: json['isPaused'] as bool? ?? false,
      pauseReason: json['pauseReason'] as String?,
    );
  }

  ConsultationSession copyWith({
    String? status,
    int? durationSeconds,
    double? totalBilledRupees,
    String? totalBilledPaise,
    String? endedAt,
    String? endReason,
    bool? isPaused,
    String? pauseReason,
  }) {
    return ConsultationSession(
      id: id,
      userId: userId,
      expertId: expertId,
      expertName: expertName,
      sessionType: sessionType,
      status: status ?? this.status,
      rateInRupees: rateInRupees,
      rateInPaise: rateInPaise,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      totalBilledRupees: totalBilledRupees ?? this.totalBilledRupees,
      totalBilledPaise: totalBilledPaise ?? this.totalBilledPaise,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      endReason: endReason ?? this.endReason,
      isPaused: isPaused ?? this.isPaused,
      pauseReason: pauseReason ?? this.pauseReason,
    );
  }
}

class SessionSummary {
  final String sessionId;
  final int durationSeconds;
  final double totalBilledRupees;
  final String totalBilledPaise;
  final double ratePerMinuteRupees;
  final String? startedAt;
  final String? endedAt;
  final String endReason;

  const SessionSummary({
    required this.sessionId,
    required this.durationSeconds,
    required this.totalBilledRupees,
    required this.totalBilledPaise,
    required this.ratePerMinuteRupees,
    this.startedAt,
    this.endedAt,
    required this.endReason,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    return SessionSummary(
      sessionId: json['sessionId'] as String,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      totalBilledRupees: (json['totalBilledRupees'] as num?)?.toDouble() ?? 0.0,
      totalBilledPaise: json['totalBilledPaise']?.toString() ?? '0',
      ratePerMinuteRupees: (json['ratePerMinuteRupees'] as num?)?.toDouble() ?? 20.0,
      startedAt: json['startedAt'] as String?,
      endedAt: json['endedAt'] as String?,
      endReason: json['endReason'] as String? ?? 'ENDED',
    );
  }
}
