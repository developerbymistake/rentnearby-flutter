import 'package:flutter/material.dart';

import '../../shared/widgets/buddy_stub_screen.dart';

class ViewerTripScreen extends StatelessWidget {
  const ViewerTripScreen({super.key, required this.tripId, this.deleted = false});

  final String tripId;
  final bool deleted;

  @override
  Widget build(BuildContext context) => const BuddyStubScreen(title: '');
}
