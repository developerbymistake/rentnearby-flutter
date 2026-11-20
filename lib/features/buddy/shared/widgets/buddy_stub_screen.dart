import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../strings_shared.dart';
import 'buddy_page.dart';

class BuddyStubScreen extends StatelessWidget {
  const BuddyStubScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => BuddyPage(
        title: title,
        body: Padding(
          padding: DS.all(24),
          child: Center(child: Text(BuddySharedStrings.comingSoon, style: Ink3D.text(15, FontWeight.w600, Ink3D.grey))),
        ),
      );
}
