import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';

abstract final class OnboardingExit {
  static bool get canCorrectRole => Get.isRegistered<AuthController>() && (Get.find<AuthController>().user.value?.canCorrectRole ?? false);

  static Future<void> onBackFromFirstPage({required bool isDraft, required bool hasDraft}) async {
    if (isDraft && canCorrectRole) await openRoleCorrection(hasDraft: hasDraft);
  }

  static Future<void> openRoleCorrection({required bool hasDraft}) async {
    await Get.toNamed(AppRoutes.roleSelect, arguments: {'correction': true, 'hasDraft': hasDraft});
  }

  static void openMenu(BuildContext context, {required bool isDraft, required bool hasDraft, Rect? anchor}) {
    final top = MediaQuery.paddingOf(context).top + DS.s(8);
    final auth = Get.find<AuthController>();
    showMenu3D(
      context,
      anchor: anchor ?? Rect.fromLTWH(DS.s(18), top, PageHeader3D.buttonSize, PageHeader3D.buttonSize),
      items: [
        MenuItem3D(
          label: 'Change role',
          onTap: () => isDraft && canCorrectRole ? openRoleCorrection(hasDraft: hasDraft) : Get.toNamed(AppRoutes.roleChange),
        ),
        MenuItem3D(label: 'Log out', danger: true, onTap: auth.logout),
      ],
    );
  }
}
