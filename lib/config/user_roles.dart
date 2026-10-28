class UserRoleKeys {
  static const String seeker = 'SEEKER';
  static const String rentOwner = 'RENT_OWNER';
  static const String propertyOwner = 'PROPERTY_OWNER';
  static const String claim = 'role';
}

class RoleCapabilities {
  final bool canListRooms;
  final bool canListPlots;

  const RoleCapabilities({required this.canListRooms, required this.canListPlots});

  static const none = RoleCapabilities(canListRooms: false, canListPlots: false);

  static const Map<String, RoleCapabilities> byRole = {
    UserRoleKeys.seeker: none,
    UserRoleKeys.rentOwner: RoleCapabilities(canListRooms: true, canListPlots: false),
    UserRoleKeys.propertyOwner: RoleCapabilities(canListRooms: false, canListPlots: true),
  };

  static RoleCapabilities of(String? roleKey) => byRole[roleKey] ?? none;

  bool get isOwner => canListRooms || canListPlots;

  String? get deletionLine => canListRooms
      ? 'Your rooms will be deleted.'
      : canListPlots
          ? 'Your plots will be deleted.'
          : null;
}

class RoleRequestErrorTypes {
  static const String cooldown = 'RoleRequestCooldown';
  static const String liveListing = 'RoleChangeBlockedByLiveListing';
}

class RoleRequestStatus {
  static const String pending = 'PENDING';
  static const String approved = 'APPROVED';
  static const String rejected = 'REJECTED';
}
