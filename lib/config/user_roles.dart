import '../controllers/tab_config_controller.dart' show AppTabKeys;

class UserRoleKeys {
  static const String seeker = 'SEEKER';
  static const String rentOwner = 'RENT_OWNER';
  static const String propertyOwner = 'PROPERTY_OWNER';
  static const String stayOwner = 'STAY_OWNER';
  static const String taxiDriver = 'TAXI_DRIVER';
  static const String claim = 'role';

  static String? tabKeyOf(String? roleKey) => switch (roleKey) {
        rentOwner => AppTabKeys.rooms,
        propertyOwner => AppTabKeys.plots,
        stayOwner => AppTabKeys.stays,
        taxiDriver => AppTabKeys.taxi,
        _ => null,
      };
}

class RoleCapabilities {
  final bool canListRooms;
  final bool canListPlots;
  final bool canListStays;
  final bool canListTaxis;

  const RoleCapabilities({
    required this.canListRooms,
    required this.canListPlots,
    this.canListStays = false,
    this.canListTaxis = false,
  });

  static const none = RoleCapabilities(canListRooms: false, canListPlots: false);

  static const Map<String, RoleCapabilities> byRole = {
    UserRoleKeys.seeker: none,
    UserRoleKeys.rentOwner: RoleCapabilities(canListRooms: true, canListPlots: false),
    UserRoleKeys.propertyOwner: RoleCapabilities(canListRooms: false, canListPlots: true),
    UserRoleKeys.stayOwner: RoleCapabilities(canListRooms: false, canListPlots: false, canListStays: true),
    UserRoleKeys.taxiDriver: RoleCapabilities(canListRooms: false, canListPlots: false, canListTaxis: true),
  };

  static RoleCapabilities of(String? roleKey) => byRole[roleKey] ?? none;

  bool get isOwner => canListRooms || canListPlots || canListStays || canListTaxis;

  String? get deletionLine => canListRooms
      ? 'Your rooms will be deleted.'
      : canListPlots
          ? 'Your plots will be deleted.'
          : canListStays
              ? 'Your stay and jobs will be deleted.'
              : canListTaxis
                  ? 'Your taxi will be deleted.'
                  : null;
}

class RoleRequestErrorTypes {
  static const String cooldown = 'RoleRequestCooldown';
  static const String liveListing = 'RoleChangeBlockedByLiveListing';
  static const String unavailable = 'RoleUnavailable';
  static const String invalidRole = 'InvalidRole';
  static const String correctionUsed = 'RoleCorrectionUsed';
  static const String correctionNotAllowed = 'RoleCorrectionNotAllowed';
  static const String requestPending = 'RoleRequestPending';
}

class RoleRequestStatus {
  static const String pending = 'PENDING';
  static const String approved = 'APPROVED';
  static const String rejected = 'REJECTED';
}
