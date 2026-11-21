import 'package:flutter/material.dart';

import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_stub_screen.dart';
import '../strings/stay_shell_strings.dart';

class StayMoneySummaryScreen extends StatelessWidget {
  const StayMoneySummaryScreen({super.key, this.args = const {}});

  final Map<String, dynamic> args;

  @override
  Widget build(BuildContext context) => OwnerStubScreen(title: StayShellStrings.moneySummary, look: OwnerLook.stay);
}
