import '../controllers/tab_config_controller.dart' show AppTabKeys;

class UserRoleKeys {
  static const String seeker = 'SEEKER';
  static const String stayOwner = 'STAY_OWNER';
  static const String taxiDriver = 'TAXI_DRIVER';
  static const String claim = 'role';

  static String? tabKeyOf(String? roleKey) => switch (roleKey) {
        stayOwner => AppTabKeys.stays,
        taxiDriver => AppTabKeys.taxi,
        _ => null,
      };
}

class RoleCapabilities {
  final bool canListStays;
  final bool canListTaxis;

  const RoleCapabilities({
    this.canListStays = false,
    this.canListTaxis = false,
  });

  static const none = RoleCapabilities();

  static const Map<String, RoleCapabilities> byRole = {
    UserRoleKeys.seeker: none,
    UserRoleKeys.stayOwner: RoleCapabilities(canListStays: true),
    UserRoleKeys.taxiDriver: RoleCapabilities(canListTaxis: true),
  };

  static RoleCapabilities of(String? roleKey) => byRole[roleKey] ?? none;

  bool get isOwner => canListStays || canListTaxis;

  String? get deletionLine => canListStays
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
  static const String locked = 'RoleLocked';
}

class RoleRequestStatus {
  static const String pending = 'PENDING';
  static const String approved = 'APPROVED';
  static const String rejected = 'REJECTED';
}
