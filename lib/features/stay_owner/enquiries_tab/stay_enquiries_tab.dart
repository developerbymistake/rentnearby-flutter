import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_stub_screen.dart';
import '../strings/stay_shell_strings.dart';

class StayEnquiriesTab extends StatelessWidget {
  const StayEnquiriesTab({super.key});

  @override
  Widget build(BuildContext context) =>
      OwnerStubScreen(title: StayShellStrings.tabEnquiries, look: OwnerLook.stay, root: true, openRoute: AppRoutes.stayEnquiries);
}
