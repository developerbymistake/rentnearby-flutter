import 'package:flutter/material.dart';

import '../../shared/widgets/buddy_stub_screen.dart';
import '../../sharing/sharing_strings.dart';
import '../../sharing/models/sharing_models.dart';

class TravellersOwnerScreen extends StatelessWidget {
  const TravellersOwnerScreen({super.key, required this.tripId, required this.members});

  final String tripId;
  final TripMembers members;

  @override
  Widget build(BuildContext context) => const BuddyStubScreen(title: SharingStrings.travellersTitle);
}
