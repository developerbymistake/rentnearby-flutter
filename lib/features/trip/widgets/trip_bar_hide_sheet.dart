import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../trip_strings_bar.dart';

class TripBarHideSheet {
  static Future<bool> show(BuildContext context) async {
    final hide = await SheetFrame.show<bool>(
      context,
      useRootNavigator: true,
      builder: (ctx) => SheetFrame(
        title: TripStringsBar.hideTitle,
        subtitle: TripStringsBar.hideBody,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton(label: TripStringsBar.hideAction, tone: KitTone.trip, onPressed: () => Navigator.pop(ctx, true)),
            const SizedBox(height: 12),
            SecondaryButton(label: TripStringsBar.keepShowing, tone: KitTone.trip, onPressed: () => Navigator.pop(ctx, false)),
          ],
        ),
      ),
    );
    return hide == true;
  }
}
