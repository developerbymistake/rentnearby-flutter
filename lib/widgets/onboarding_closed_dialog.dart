import 'package:flutter/material.dart';
import '../design/design.dart';
import 'location_switch_sheet.dart';

class OnboardingClosedDialog {
  const OnboardingClosedDialog._();

  static Future<void> show(BuildContext context, {VoidCallback? onChangeRole}) => Dialog3D.show<void>(
        context,
        builder: (ctx) => Dialog3D(
          tone: moduleToneFor(),
          art: ListingArt.worldMap,
          title: 'Not open here yet',
          body: "We can't take new listings in this area right now.",
          primaryLabel: 'OK',
          onPrimary: () => Navigator.of(ctx).pop(),
          secondaryLabel: onChangeRole == null ? null : 'Change role',
          secondaryDanger: true,
          onSecondary: onChangeRole == null
              ? null
              : () {
                  Navigator.of(ctx).pop();
                  onChangeRole();
                },
        ),
      );
}
