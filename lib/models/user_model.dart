class UserModel {
  final String id;
  final String phoneNumber;
  final String? name;
  final String? gmailId;
  final bool isAdmin;
  final bool hasUsedFreePlan;
  final bool hasUsedFreePlotPlan;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.phoneNumber,
    this.name,
    this.gmailId,
    required this.isAdmin,
    required this.hasUsedFreePlan,
    this.hasUsedFreePlotPlan = false,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        phoneNumber: json['phoneNumber'],
        name: json['name'],
        gmailId: json['gmailId'],
        isAdmin: json['isAdmin'] ?? false,
        hasUsedFreePlan: json['hasUsedFreePlan'] ?? false,
        hasUsedFreePlotPlan: json['hasUsedFreePlotPlan'] ?? false,
        createdAt: DateTime.parse(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneNumber': phoneNumber,
        'name': name,
        'gmailId': gmailId,
        'isAdmin': isAdmin,
        'hasUsedFreePlan': hasUsedFreePlan,
        'hasUsedFreePlotPlan': hasUsedFreePlotPlan,
        'createdAt': createdAt.toIso8601String(),
      };

  String get displayName => name ?? phoneNumber;
}
