import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_stub_screen.dart';
import '../strings/taxi_shell_strings.dart';

class TaxiHubScreen extends StatelessWidget {
  const TaxiHubScreen({super.key, this.root = false});
  final bool root;

  @override
  Widget build(BuildContext context) => OwnerStubScreen(title: TaxiShellStrings.tabMyTaxi, look: OwnerLook.taxi, root: root, openRoute: AppRoutes.myTaxi);
}
