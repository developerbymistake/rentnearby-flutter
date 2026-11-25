import 'package:flutter/material.dart';

import '../../../design/design.dart';

class OwnerUpcomingHeading extends StatelessWidget {
  const OwnerUpcomingHeading({
    super.key,
    required this.title,
    required this.sub,
    required this.seeAll,
    required this.onSeeAll,
    required this.linkColor,
    this.seeAllSemantics,
  });

  final String title;
  final String sub;
  final String seeAll;
  final VoidCallback onSeeAll;
  final Color linkColor;
  final String? seeAllSemantics;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(l: 22, t: 22, r: 22, b: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: Ink3D.text(17, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                    if (sub.isNotEmpty) Text(sub, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                  ],
                ),
              ),
            ),
            Gap.h(8),
            Semantics(
              button: true,
              label: seeAllSemantics ?? seeAll,
              excludeSemantics: true,
              child: TextButton(
                onPressed: onSeeAll,
                child: Text('$seeAll ›', style: Ink3D.text(13, FontWeight.w600, linkColor, letterSpacing: 0)),
              ),
            ),
          ],
        ),
      );
}
