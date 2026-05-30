class UserModel {
  final String id;
  final String googleEmail;
  final String? profilePhotoUrl;
  final String phoneNumber;
  final bool isPhoneVerified;
  final bool hasUsedPhoneChange;
  final String? name;
  final bool hasUsedFreePlan;
  final bool hasUsedFreePlotPlan;
  final bool isContactVisible;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.googleEmail,
    this.profilePhotoUrl,
    required this.phoneNumber,
    this.isPhoneVerified = false,
    this.hasUsedPhoneChange = false,
    this.name,
    required this.hasUsedFreePlan,
    this.hasUsedFreePlotPlan = false,
    this.isContactVisible = true,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        googleEmail: json['googleEmail'] ?? '',
        profilePhotoUrl: json['profilePhotoUrl'],
        phoneNumber: json['phoneNumber'] ?? '',
        isPhoneVerified: json['isPhoneVerified'] ?? false,
        hasUsedPhoneChange: json['hasUsedPhoneChange'] ?? false,
        name: json['name'],
        hasUsedFreePlan: json['hasUsedFreePlan'] ?? false,
        hasUsedFreePlotPlan: json['hasUsedFreePlotPlan'] ?? false,
        isContactVisible: json['isContactVisible'] ?? true,
        createdAt: DateTime.parse(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'googleEmail': googleEmail,
        'profilePhotoUrl': profilePhotoUrl,
        'phoneNumber': phoneNumber,
        'isPhoneVerified': isPhoneVerified,
        'hasUsedPhoneChange': hasUsedPhoneChange,
        'name': name,
        'hasUsedFreePlan': hasUsedFreePlan,
        'hasUsedFreePlotPlan': hasUsedFreePlotPlan,
        'isContactVisible': isContactVisible,
        'createdAt': createdAt.toIso8601String(),
      };

  String get displayName => name?.trim().isNotEmpty == true ? name! : googleEmail;
}
