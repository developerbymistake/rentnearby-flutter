import '../config/user_roles.dart';

class UserModel {
  final String id;
  final String phoneNumber;
  final bool isPhoneVerified;
  final bool hasUsedPhoneChange;
  final String? name;
  final bool isContactVisible;
  final DateTime createdAt;
  final String role;
  final bool roleConfirmed;
  final String? roleRequestStatus;
  final String? roleRequestReason;
  final DateTime? nextRoleRequestAt;
  final String? stayStatus;
  final String? taxiStatus;
  final bool roleTabActive;

  UserModel({
    required this.id,
    required this.phoneNumber,
    this.isPhoneVerified = false,
    this.hasUsedPhoneChange = false,
    this.name,
    this.isContactVisible = true,
    required this.createdAt,
    this.role = UserRoleKeys.seeker,
    this.roleConfirmed = false,
    this.roleRequestStatus,
    this.roleRequestReason,
    this.nextRoleRequestAt,
    this.stayStatus,
    this.taxiStatus,
    this.roleTabActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        phoneNumber: json['phoneNumber'] ?? '',
        isPhoneVerified: json['isPhoneVerified'] ?? false,
        hasUsedPhoneChange: json['hasUsedPhoneChange'] ?? false,
        name: json['name'],
        isContactVisible: json['isContactVisible'] ?? true,
        createdAt: DateTime.parse(json['createdAt']),
        role: json['role'] ?? UserRoleKeys.seeker,
        roleConfirmed: json['roleConfirmed'] ?? false,
        roleRequestStatus: json['roleRequestStatus'],
        roleRequestReason: json['roleRequestReason'],
        nextRoleRequestAt: json['nextRoleRequestAt'] != null ? DateTime.parse(json['nextRoleRequestAt']) : null,
        stayStatus: json['stayStatus'] as String?,
        taxiStatus: json['taxiStatus'] as String?,
        roleTabActive: json['roleTabActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneNumber': phoneNumber,
        'isPhoneVerified': isPhoneVerified,
        'hasUsedPhoneChange': hasUsedPhoneChange,
        'name': name,
        'isContactVisible': isContactVisible,
        'createdAt': createdAt.toIso8601String(),
        'role': role,
        'roleConfirmed': roleConfirmed,
        'roleRequestStatus': roleRequestStatus,
        'roleRequestReason': roleRequestReason,
        'nextRoleRequestAt': nextRoleRequestAt?.toIso8601String(),
        'stayStatus': stayStatus,
        'taxiStatus': taxiStatus,
        'roleTabActive': roleTabActive,
      };

  String get displayName => name?.trim().isNotEmpty == true ? name! : '+91 $phoneNumber';

  bool get hasPendingRoleRequest => roleRequestStatus == RoleRequestStatus.pending;

  bool get hasRejectedRoleRequest => roleRequestStatus == RoleRequestStatus.rejected;

  DateTime? get roleRequestBlockedUntil {
    final t = nextRoleRequestAt;
    return t != null && t.isAfter(DateTime.now()) ? t : null;
  }
}
