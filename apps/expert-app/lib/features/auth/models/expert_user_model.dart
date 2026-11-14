class ExpertUserModel {
  final String id;
  final String phoneNumber;
  final String role;
  final DateTime? createdAt;

  ExpertUserModel({
    required this.id,
    required this.phoneNumber,
    required this.role,
    this.createdAt,
  });

  factory ExpertUserModel.fromJson(Map<String, dynamic> json) {
    return ExpertUserModel(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      role: (json['role'] as String?) ?? 'USER',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'role': role,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  bool get isApprovedExpert => role == 'EXPERT';
}

