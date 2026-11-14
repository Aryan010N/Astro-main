class ExpertProfileModel {
  final String id;
  final String userId;
  final String name;
  final String? email;
  final String? bio;
  final int experienceYears;
  final List<String> languages;
  final List<String> expertise;
  final String idProofType;
  final String idProofNumber;
  final String payoutUpiId;
  final int chatRateInPaise;
  final int callRateInPaise;
  final int videoRateInPaise;
  final String kycStatus; // PENDING, APPROVED, REJECTED
  final String? rejectionReason;
  final bool isLive;
  final double rating;
  final int totalConsultations;

  ExpertProfileModel({
    required this.id,
    required this.userId,
    required this.name,
    this.email,
    this.bio,
    required this.experienceYears,
    required this.languages,
    required this.expertise,
    required this.idProofType,
    required this.idProofNumber,
    required this.payoutUpiId,
    required this.chatRateInPaise,
    required this.callRateInPaise,
    required this.videoRateInPaise,
    required this.kycStatus,
    this.rejectionReason,
    required this.isLive,
    required this.rating,
    required this.totalConsultations,
  });

  factory ExpertProfileModel.fromJson(Map<String, dynamic> json) {
    return ExpertProfileModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      bio: json['bio'] as String?,
      experienceYears: json['experienceYears'] as int? ?? 0,
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      expertise: (json['expertise'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      idProofType: json['idProofType'] as String? ?? '',
      idProofNumber: json['idProofNumber'] as String? ?? '',
      payoutUpiId: json['payoutUpiId'] as String? ?? '',
      chatRateInPaise: int.tryParse(json['chatRateInPaise']?.toString() ?? '0') ?? 0,
      callRateInPaise: int.tryParse(json['callRateInPaise']?.toString() ?? '0') ?? 0,
      videoRateInPaise: int.tryParse(json['videoRateInPaise']?.toString() ?? '0') ?? 0,
      kycStatus: (json['kycStatus'] as String?) ?? 'PENDING',
      rejectionReason: json['rejectionReason'] as String?,
      isLive: json['isLive'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalConsultations: json['totalConsultations'] as int? ?? 0,
    );
  }

  bool get isPending => kycStatus == 'PENDING';
  bool get isApproved => kycStatus == 'APPROVED';
  bool get isRejected => kycStatus == 'REJECTED';

  int get chatRateInRupees => chatRateInPaise ~/ 100;
  int get callRateInRupees => callRateInPaise ~/ 100;
  int get videoRateInRupees => videoRateInPaise ~/ 100;
}

