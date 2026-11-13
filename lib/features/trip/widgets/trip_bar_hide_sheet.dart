import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../../navigation/tab_keys.dart';
import '../trip_strings_bar.dart';

class TripBarHideSheet {
  static Future<bool> show(BuildContext context) async {
    final tabs = Get.isRegistered<AuthController>() ? tabKeys[Get.find<AuthController>().tabIndex.value].currentState : null;
    final host = tabs?.overlay?.context ?? context;
    final hide = await SheetFrame.show<bool>(
      host,
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
