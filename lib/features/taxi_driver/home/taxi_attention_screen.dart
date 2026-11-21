import 'package:flutter/material.dart';

import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_stub_screen.dart';
import '../strings/taxi_shell_strings.dart';

class TaxiAttentionScreen extends StatelessWidget {
  const TaxiAttentionScreen({super.key});

  @override
  Widget build(BuildContext context) => OwnerStubScreen(title: TaxiShellStrings.needsAttention, look: OwnerLook.taxi);
}
