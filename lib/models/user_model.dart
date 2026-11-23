import '../config/user_roles.dart';

class UserModel {
  final String id;
  final String phoneNumber;
  final bool isPhoneVerified;
  final bool hasUsedPhoneChange;
  final String? name;
  final String? username;
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
  final bool roleCorrectionUsed;
  final bool canCorrectRole;
  final bool roleLocked;
  final bool listingDeleted;
  final String? profilePhotoUrl;
  final bool photoKnown;
  final bool profilePhotoRemoved;

  UserModel({
    required this.id,
    required this.phoneNumber,
    this.isPhoneVerified = false,
    this.hasUsedPhoneChange = false,
    this.name,
    this.username,
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
    this.roleCorrectionUsed = false,
    this.canCorrectRole = false,
    this.roleLocked = false,
    this.listingDeleted = false,
    this.profilePhotoUrl,
    this.photoKnown = false,
    this.profilePhotoRemoved = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        phoneNumber: json['phoneNumber'] ?? '',
        isPhoneVerified: json['isPhoneVerified'] ?? false,
        hasUsedPhoneChange: json['hasUsedPhoneChange'] ?? false,
        name: json['name'],
        username: usernameOf(json['username']),
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
        roleCorrectionUsed: json['roleCorrectionUsed'] as bool? ?? false,
        canCorrectRole: json['canCorrectRole'] as bool? ?? false,
        roleLocked: json['roleLocked'] as bool? ?? false,
        listingDeleted: json['listingDeleted'] == true,
        profilePhotoUrl: usernameOf(json['profilePhotoUrl']),
        photoKnown: json.containsKey('profilePhotoUrl'),
        profilePhotoRemoved: json['profilePhotoRemoved'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneNumber': phoneNumber,
        'isPhoneVerified': isPhoneVerified,
        'hasUsedPhoneChange': hasUsedPhoneChange,
        'name': name,
        'username': username,
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
        'roleCorrectionUsed': roleCorrectionUsed,
        'canCorrectRole': canCorrectRole,
        'roleLocked': roleLocked,
        'listingDeleted': listingDeleted,
        if (photoKnown) 'profilePhotoUrl': profilePhotoUrl,
        'profilePhotoRemoved': profilePhotoRemoved,
      };

  static String? usernameOf(Object? raw) {
    final v = raw is String ? raw.trim() : '';
    return v.isEmpty ? null : v;
  }

  String get displayName => name?.trim().isNotEmpty == true ? name! : '+91 $phoneNumber';

  // Only a picture the admin removed must be replaced; a new user who never added one is not asked (optional since 2026-11-24).
  bool get needsProfilePhoto => photoKnown && profilePhotoUrl == null && profilePhotoRemoved;

  bool get hasPendingRoleRequest => roleRequestStatus == RoleRequestStatus.pending;

  bool get hasRejectedRoleRequest => roleRequestStatus == RoleRequestStatus.rejected;

  DateTime? get roleRequestBlockedUntil {
    final t = nextRoleRequestAt;
    return t != null && t.isAfter(DateTime.now()) ? t : null;
  }
}
