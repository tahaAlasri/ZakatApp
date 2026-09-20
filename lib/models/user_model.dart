class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final bool isBiometricEnabled;
  final String? profileImagePath;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.isBiometricEnabled = false,
    this.profileImagePath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'isBiometricEnabled': isBiometricEnabled,
      'profileImagePath': profileImagePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      isBiometricEnabled: map['isBiometricEnabled'] ?? false,
      profileImagePath: map['profileImagePath'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    bool? isBiometricEnabled,
    String? profileImagePath,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
