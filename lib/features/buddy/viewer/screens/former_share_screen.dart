import 'package:flutter/material.dart';

import '../../shared/widgets/buddy_stub_screen.dart';
import '../../viewer/viewer_strings.dart';

class FormerShareScreen extends StatelessWidget {
  const FormerShareScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) => const BuddyStubScreen(title: ViewerStrings.myShareTitle);
}
