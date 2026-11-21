import 'package:flutter/material.dart';

import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_stub_screen.dart';
import '../strings/taxi_shell_strings.dart';

class TaxiDriverHomeScreen extends StatelessWidget {
  const TaxiDriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => OwnerStubScreen(title: TaxiShellStrings.tabHome, look: OwnerLook.taxi, root: true);
}
