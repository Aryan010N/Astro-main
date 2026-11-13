class UserModel {
  final String id;
  final String phoneNumber;
  final String role;
  final String? name;
  final String? avatarUrl;
  final WalletModel? wallet;

  UserModel({
    required this.id,
    required this.phoneNumber,
    required this.role,
    this.name,
    this.avatarUrl,
    this.wallet,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      role: json['role'] as String? ?? 'USER',
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      wallet: json['wallet'] != null ? WalletModel.fromJson(json['wallet']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'role': role,
      'name': name,
      'avatarUrl': avatarUrl,
      'wallet': wallet?.toJson(),
    };
  }
}

class WalletModel {
  final String id;
  final String balanceInPaise;
  final String currency;

  WalletModel({
    required this.id,
    required this.balanceInPaise,
    required this.currency,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      balanceInPaise: json['balanceInPaise']?.toString() ?? '0',
      currency: json['currency'] as String? ?? 'INR',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'balanceInPaise': balanceInPaise,
      'currency': currency,
    };
  }
}

