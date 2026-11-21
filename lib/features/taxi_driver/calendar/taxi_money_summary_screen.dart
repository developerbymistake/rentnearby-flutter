import 'package:flutter/material.dart';

import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_stub_screen.dart';
import '../strings/taxi_shell_strings.dart';

class TaxiMoneySummaryScreen extends StatelessWidget {
  const TaxiMoneySummaryScreen({super.key, this.args = const {}});
  final Map<String, dynamic> args;

  @override
  Widget build(BuildContext context) => OwnerStubScreen(title: TaxiShellStrings.moneySummary, look: OwnerLook.taxi);
}
