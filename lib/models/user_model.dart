class UserModel {
  final String id;
  final String phoneNumber;
  final String? name;
  final bool hasUsedFreePlan;
  final bool hasUsedFreePlotPlan;
  final bool isContactVisible;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.phoneNumber,
    this.name,
    required this.hasUsedFreePlan,
    this.hasUsedFreePlotPlan = false,
    this.isContactVisible = true,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        phoneNumber: json['phoneNumber'],
        name: json['name'],
        hasUsedFreePlan: json['hasUsedFreePlan'] ?? false,
        hasUsedFreePlotPlan: json['hasUsedFreePlotPlan'] ?? false,
        isContactVisible: json['isContactVisible'] ?? true,
        createdAt: DateTime.parse(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneNumber': phoneNumber,
        'name': name,
        'hasUsedFreePlan': hasUsedFreePlan,
        'hasUsedFreePlotPlan': hasUsedFreePlotPlan,
        'isContactVisible': isContactVisible,
        'createdAt': createdAt.toIso8601String(),
      };

  String get displayName => name ?? phoneNumber;
}
