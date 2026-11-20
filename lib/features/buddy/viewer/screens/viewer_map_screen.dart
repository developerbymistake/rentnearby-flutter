import 'package:flutter/material.dart';

import '../../shared/widgets/buddy_stub_screen.dart';

class ViewerMapScreen extends StatelessWidget {
  const ViewerMapScreen({super.key, required this.tripId, this.day});

  final String tripId;
  final int? day;

  @override
  Widget build(BuildContext context) => const BuddyStubScreen(title: '');
}
