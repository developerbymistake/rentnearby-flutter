import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../features/social/a/profile/seeker_profile_screen.dart';
import '../screens/profile_screen.dart';
import 'shell_kind.dart';
import 'app_tabs.dart';

class TabSlot {
  const TabSlot({
    required this.index,
    required this.label,
    required this.image,
    required this.root,
    required this.active,
    required this.rootTag,
    this.center = false,
    this.activeColor,
    this.badge,
    this.badgeColor,
    this.onTap,
    this.onLeave,
  });

  final int index;
  final String label;
  final String image;
  final bool center;
  final Color? activeColor;
  final String rootTag;
  final Widget Function() root;
  final bool Function() active;
  final int Function()? badge;
  final Color? badgeColor;
  final void Function(bool wasSelected)? onTap;
  final void Function()? onLeave;
}

class TabIntent {
  const TabIntent({required this.index, this.args = const {}, required this.seq});

  final int index;
  final Map<String, dynamic> args;
  final int seq;
}

abstract final class TabSlots {
  static const String art = 'assets/images/design/travel3d/';

  static TabSlot profile({required String label, bool Function()? active, void Function()? onTapExtra}) => TabSlot(
        index: AppTabs.profile,
        label: label,
        image: '${art}fox.png',
        rootTag: 'profile',
        root: () => ShellState.current.value == ShellKind.seeker ? const SeekerProfileScreen() : const ProfileScreen(),
        active: active ?? () => true,
        onTap: (wasSelected) {
          if (!wasSelected && Get.isRegistered<AuthController>()) Get.find<AuthController>().profileTabTrigger.value++;
          onTapExtra?.call();
        },
      );
}
