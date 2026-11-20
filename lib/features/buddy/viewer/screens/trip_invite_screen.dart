import 'package:flutter/material.dart';

import '../../shared/widgets/buddy_stub_screen.dart';
import '../../viewer/viewer_strings.dart';

class TripInviteScreen extends StatelessWidget {
  const TripInviteScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context) => const BuddyStubScreen(title: ViewerStrings.inviteTitle);
}
