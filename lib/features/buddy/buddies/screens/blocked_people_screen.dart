import 'package:flutter/material.dart';

import '../../shared/widgets/buddy_stub_screen.dart';
import '../../buddies/buddies_strings.dart';

class BlockedPeopleScreen extends StatelessWidget {
  const BlockedPeopleScreen({super.key});

  @override
  Widget build(BuildContext context) => const BuddyStubScreen(title: BuddiesStrings.blockedTitle);
}
