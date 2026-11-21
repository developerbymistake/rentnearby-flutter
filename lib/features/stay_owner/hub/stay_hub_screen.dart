import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_stub_screen.dart';
import '../strings/stay_shell_strings.dart';

class StayHubScreen extends StatelessWidget {
  const StayHubScreen({super.key, this.root = false});

  final bool root;

  @override
  Widget build(BuildContext context) =>
      OwnerStubScreen(title: StayShellStrings.tabMyStay, look: OwnerLook.stay, root: root, openRoute: AppRoutes.myStays);
}
