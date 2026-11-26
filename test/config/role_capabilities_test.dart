import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only SEEKER can use traveller features', () {
    expect(RoleCapabilities.of(UserRoleKeys.seeker).canUseTravellerFeatures, isTrue);
    for (final key in [UserRoleKeys.stayOwner, UserRoleKeys.taxiDriver, 'RENT_OWNER', 'PROPERTY_OWNER', '', null, 'SOMETHING_NEW']) {
      expect(RoleCapabilities.of(key).canUseTravellerFeatures, isFalse, reason: '$key');
    }
  });

  test('unknown and removed roles fall back to none', () {
    for (final key in ['RENT_OWNER', 'PROPERTY_OWNER', '', null, 'SOMETHING_NEW']) {
      expect(identical(RoleCapabilities.of(key), RoleCapabilities.none), isTrue, reason: '$key');
    }
  });

  test('owners keep their listing capabilities', () {
    expect(RoleCapabilities.of(UserRoleKeys.stayOwner).canListStays, isTrue);
    expect(RoleCapabilities.of(UserRoleKeys.stayOwner).canListTaxis, isFalse);
    expect(RoleCapabilities.of(UserRoleKeys.taxiDriver).canListTaxis, isTrue);
    expect(RoleCapabilities.of(UserRoleKeys.taxiDriver).canListStays, isFalse);
    expect(RoleCapabilities.of(UserRoleKeys.seeker).isOwner, isFalse);
  });

  test('AuthController.canUseTravellerFeatures follows roleKey', () {
    final auth = AuthController();
    expect(auth.canUseTravellerFeatures, isTrue);
    for (final (key, want) in [
      (UserRoleKeys.stayOwner, false),
      (UserRoleKeys.taxiDriver, false),
      ('SOMETHING_NEW', false),
      (UserRoleKeys.seeker, true),
    ]) {
      auth.roleKey.value = key;
      expect(auth.canUseTravellerFeatures, want, reason: key);
    }
  });
}
