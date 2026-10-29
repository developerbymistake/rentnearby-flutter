class UserRoleKeys {
  static const String seeker = 'SEEKER';
  static const String rentOwner = 'RENT_OWNER';
  static const String propertyOwner = 'PROPERTY_OWNER';
  static const String stayOwner = 'STAY_OWNER';
  static const String claim = 'role';
}

class RoleCapabilities {
  final bool canListRooms;
  final bool canListPlots;
  final bool canListStays;

  const RoleCapabilities({required this.canListRooms, required this.canListPlots, this.canListStays = false});

  static const none = RoleCapabilities(canListRooms: false, canListPlots: false);

  static const Map<String, RoleCapabilities> byRole = {
    UserRoleKeys.seeker: none,
    UserRoleKeys.rentOwner: RoleCapabilities(canListRooms: true, canListPlots: false),
    UserRoleKeys.propertyOwner: RoleCapabilities(canListRooms: false, canListPlots: true),
    UserRoleKeys.stayOwner: RoleCapabilities(canListRooms: false, canListPlots: false, canListStays: true),
  };

  static RoleCapabilities of(String? roleKey) => byRole[roleKey] ?? none;

  bool get isOwner => canListRooms || canListPlots || canListStays;

  String? get deletionLine => canListRooms
      ? 'Your rooms will be deleted.'
      : canListPlots
          ? 'Your plots will be deleted.'
          : canListStays
              ? 'Your stay and jobs will be deleted.'
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
