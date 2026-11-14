class ExpertWithPresence {
  final String id;
  final String userId;
  final String name;
  final String bio;
  final int experienceYears;
  final List<String> languages;
  final List<String> expertise;
  final double chatRateInRupees;
  final String chatRateInPaise;
  final double rating;
  final int totalConsultations;
  final String presenceStatus; // ONLINE, BUSY, OFFLINE

  const ExpertWithPresence({
    required this.id,
    required this.userId,
    required this.name,
    required this.bio,
    required this.experienceYears,
    required this.languages,
    required this.expertise,
    required this.chatRateInRupees,
    required this.chatRateInPaise,
    required this.rating,
    required this.totalConsultations,
    required this.presenceStatus,
  });

  factory ExpertWithPresence.fromJson(Map<String, dynamic> json) {
    return ExpertWithPresence(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? 'Expert Astrologer',
      bio: json['bio'] as String? ?? '',
      experienceYears: json['experienceYears'] as int? ?? 1,
      languages: (json['languages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      expertise: (json['expertise'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      chatRateInRupees: (json['chatRateInRupees'] as num?)?.toDouble() ?? 20.0,
      chatRateInPaise: json['chatRateInPaise']?.toString() ?? '2000',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalConsultations: json['totalConsultations'] as int? ?? 0,
      presenceStatus: json['presenceStatus'] as String? ?? 'OFFLINE',
    );
  }

  ExpertWithPresence copyWith({String? presenceStatus}) {
    return ExpertWithPresence(
      id: id,
      userId: userId,
      name: name,
      bio: bio,
      experienceYears: experienceYears,
      languages: languages,
      expertise: expertise,
      chatRateInRupees: chatRateInRupees,
      chatRateInPaise: chatRateInPaise,
      rating: rating,
      totalConsultations: totalConsultations,
      presenceStatus: presenceStatus ?? this.presenceStatus,
    );
  }
}
