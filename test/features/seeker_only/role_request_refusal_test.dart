import 'package:bakhli/config/role_strings.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../social/shared/social_test_support.dart';

const _path = '/users/me/role-request';

void main() {
  setUpAll(initSocialTestStorage);
  setUp(Get.reset);
  tearDown(Get.reset);

  testWidgets('R3: the server refusing a Seeker role request shows the calm line and refreshes the profile', (t) async {
    final auth = putSeeker();
    final server = installServer();
    server.refuse('POST', _path, status: 403, type: RoleRequestErrorTypes.notAllowed, message: 'Travellers cannot change role.');
    await pumpSocial(t, const Scaffold(body: Text('ROLE')));

    final pending = auth.requestRoleChange(UserRoleKeys.stayOwner);
    await settle(t);
    expect(await pending, RoleActionResult.failed);
    expect(server.calls('POST', _path), hasLength(1));
    expect(find.text(RoleStrings.travellerCannotChange), findsOneWidget);
    expect(auth.refreshed, 1);
    expect(auth.isLoading.value, isFalse);
    await drain(t);
  });

  testWidgets('R2: an owner request that the server accepts still succeeds', (t) async {
    final auth = putSeeker(role: UserRoleKeys.stayOwner);
    final server = installServer();
    server.on('POST', _path, {'status': RoleRequestStatus.pending}, status: 201);
    await pumpSocial(t, const Scaffold(body: Text('ROLE')));

    final pending = auth.requestRoleChange(UserRoleKeys.taxiDriver);
    await settle(t);
    expect(await pending, RoleActionResult.success);
    expect((server.calls('POST', _path).single.data as Map)['role'], UserRoleKeys.taxiDriver);
    expect(find.text(RoleStrings.travellerCannotChange), findsNothing);
    await drain(t);
  });

  test('only owners may request a role change', () {
    expect(RoleCapabilities.of(UserRoleKeys.seeker).canRequestRoleChange, isFalse);
    expect(RoleCapabilities.of(UserRoleKeys.stayOwner).canRequestRoleChange, isTrue);
    expect(RoleCapabilities.of(UserRoleKeys.taxiDriver).canRequestRoleChange, isTrue);
    expect(RoleCapabilities.of(null).canRequestRoleChange, isFalse);
  });
}
