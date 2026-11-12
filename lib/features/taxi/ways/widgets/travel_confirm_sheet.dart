import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../../../../config/app_insets.dart';
import '../trip_strings_mcb_a2.dart';

class TravelConfirmSheet {
  static Future<bool> show(BuildContext context, {required String title, required String body, required String confirm}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: DesignColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        bottom: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, AppInsets.bottomViewPadding(sheetCtx) + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: DesignColors.textMuted.withValues(alpha: Alpha.half), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  TemplateStagger(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: FitnessAppTheme.title.copyWith(fontSize: 18, letterSpacing: 0.27)),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: FitnessAppTheme.subtitle.copyWith(fontSize: 13, color: DesignColors.textGrey, height: 1.4)),
                        ),
                      ),
                      LayoutBuilder(builder: (context, box) {
                        final keep = SecondaryButton(
                          label: TripStringsMcbA2.keep,
                          tone: KitTone.taxi,
                          height: 48,
                          onPressed: () => Navigator.pop(sheetCtx, false),
                        );
                        final go = PrimaryButton(
                          label: confirm,
                          height: 48,
                          tone: KitTone.taxi,
                          onPressed: () => Navigator.pop(sheetCtx, true),
                        );
                        if (box.maxWidth < 340) {
                          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [keep, const SizedBox(height: 8), go]);
                        }
                        return Row(children: [Expanded(child: keep), const SizedBox(width: 10), Expanded(child: go)]);
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return ok == true;
  }

  static Future<bool> removeTravel(BuildContext context, int bookedCars) => show(
        context,
        title: TripStringsMcbA2.removeTravelQ,
        body: TripStringsMcbA2.bookedCarsCancelled(bookedCars),
        confirm: TripStringsMcbA2.cancelAndRemove,
      );

  static Future<bool> replaceTravel(BuildContext context, int bookedCars) => show(
        context,
        title: TripStringsMcbA2.replaceTravelQ,
        body: TripStringsMcbA2.bookedCarsCancelled(bookedCars),
        confirm: TripStringsMcbA2.replace,
      );
}
