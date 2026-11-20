import 'package:flutter/material.dart';

import '../../shared/widgets/buddy_stub_screen.dart';
import '../../buddies/buddies_strings.dart';

class BuddiesScreen extends StatelessWidget {
  const BuddiesScreen({super.key, this.tab = 'buddies', this.query, this.source});

  final String tab;
  final String? query;
  final String? source;

  @override
  Widget build(BuildContext context) => const BuddyStubScreen(title: BuddiesStrings.title);
}
