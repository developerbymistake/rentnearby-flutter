class UserModel {
  final String id;
  final String phoneNumber;
  final bool isPhoneVerified;
  final bool hasUsedPhoneChange;
  final String? name;
  final bool isContactVisible;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.phoneNumber,
    this.isPhoneVerified = false,
    this.hasUsedPhoneChange = false,
    this.name,
    this.isContactVisible = true,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        phoneNumber: json['phoneNumber'] ?? '',
        isPhoneVerified: json['isPhoneVerified'] ?? false,
        hasUsedPhoneChange: json['hasUsedPhoneChange'] ?? false,
        name: json['name'],
        isContactVisible: json['isContactVisible'] ?? true,
        createdAt: DateTime.parse(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneNumber': phoneNumber,
        'isPhoneVerified': isPhoneVerified,
        'hasUsedPhoneChange': hasUsedPhoneChange,
        'name': name,
        'isContactVisible': isContactVisible,
        'createdAt': createdAt.toIso8601String(),
      };

  String get displayName => name?.trim().isNotEmpty == true ? name! : '+91 $phoneNumber';
}
