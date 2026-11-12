import 'package:flutter/material.dart';
import '../design/design.dart';

class OnboardingClosedDialog {
  const OnboardingClosedDialog._();

  static Future<void> show(BuildContext context, {VoidCallback? onChangeRole}) => showDialog<void>(
        context: context,
        builder: (ctx) => GateDialog(
          asset: TravelIcon.map,
          title: 'Not open here yet',
          body: "We can't take new listings in this area right now.",
          actions: [
            GateButton(label: 'OK', height: 44, onPressed: () => Navigator.of(ctx).pop()),
            if (onChangeRole != null)
              GateTextButton(
                label: 'Change role',
                color: PickKit.bad,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onChangeRole();
                },
              ),
          ],
        ),
      );
}
