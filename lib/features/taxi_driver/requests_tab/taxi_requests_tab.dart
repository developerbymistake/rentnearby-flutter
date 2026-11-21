import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_stub_screen.dart';
import '../strings/taxi_shell_strings.dart';

class TaxiRequestsTab extends StatelessWidget {
  const TaxiRequestsTab({super.key});

  @override
  Widget build(BuildContext context) => OwnerStubScreen(title: TaxiShellStrings.tabRequests, look: OwnerLook.taxi, root: true, openRoute: AppRoutes.taxiRequests);
}
