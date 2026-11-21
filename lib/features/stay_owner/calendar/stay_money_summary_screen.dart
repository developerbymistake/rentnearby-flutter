import 'package:flutter/material.dart';

import 'stay_calendar_screen.dart';

class StayMoneySummaryScreen extends StatelessWidget {
  const StayMoneySummaryScreen({super.key, this.args = const {}});

  final Map<String, dynamic> args;

  @override
  Widget build(BuildContext context) => StayCalendarScreen(args: {...args, 'summary': true});
}
