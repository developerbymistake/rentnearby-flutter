import 'package:flutter/material.dart';

import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_stub_screen.dart';
import '../strings/stay_shell_strings.dart';

class StayAttentionScreen extends StatelessWidget {
  const StayAttentionScreen({super.key});

  @override
  Widget build(BuildContext context) => OwnerStubScreen(title: StayShellStrings.needsAttention, look: OwnerLook.stay);
}
