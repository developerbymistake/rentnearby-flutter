import 'package:flutter/material.dart';

import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_stub_screen.dart';
import '../strings/stay_shell_strings.dart';

class StayCalendarEntryScreen extends StatelessWidget {
  const StayCalendarEntryScreen({super.key, this.args = const {}});

  final Map<String, dynamic> args;

  @override
  Widget build(BuildContext context) => OwnerStubScreen(title: StayShellStrings.booking, look: OwnerLook.stay);
}
