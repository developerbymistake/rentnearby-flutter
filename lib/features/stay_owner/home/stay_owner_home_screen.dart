import 'package:flutter/material.dart';

import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_stub_screen.dart';
import '../strings/stay_shell_strings.dart';

class StayOwnerHomeScreen extends StatelessWidget {
  const StayOwnerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => OwnerStubScreen(title: StayShellStrings.tabHome, look: OwnerLook.stay, root: true);
}
