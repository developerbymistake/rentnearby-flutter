import 'package:flutter/material.dart';

import '../../shared/widgets/buddy_stub_screen.dart';

class ViewerDayPlanScreen extends StatelessWidget {
  const ViewerDayPlanScreen({super.key, required this.tripId, this.day});

  final String tripId;
  final int? day;

  @override
  Widget build(BuildContext context) => const BuddyStubScreen(title: '');
}
