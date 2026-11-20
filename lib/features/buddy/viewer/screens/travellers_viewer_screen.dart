import 'package:flutter/material.dart';

import '../../shared/widgets/buddy_stub_screen.dart';
import '../../viewer/viewer_strings.dart';
import '../../sharing/models/sharing_models.dart';

class TravellersViewerScreen extends StatelessWidget {
  const TravellersViewerScreen({super.key, required this.tripId, required this.members});

  final String tripId;
  final TripMembers members;

  @override
  Widget build(BuildContext context) => const BuddyStubScreen(title: ViewerStrings.travellersTitle);
}
