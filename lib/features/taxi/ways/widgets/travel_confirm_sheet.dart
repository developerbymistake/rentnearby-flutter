import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/app_insets.dart';
import '../trip_strings_mcb_a2.dart';

class TravelConfirmSheet {
  static Future<bool> show(BuildContext context, {required String title, required String body, required String confirm}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text(body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textLight, height: 1.35)),
                  const SizedBox(height: 16),
                  LayoutBuilder(builder: (context, box) {
                    final keep = OutlinedButton(
                      onPressed: () => Navigator.pop(sheetCtx, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(TripStringsMcbA2.keep,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                    );
                    final go = ElevatedButton(
                      onPressed: () => Navigator.pop(sheetCtx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(confirm,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                    );
                    if (box.maxWidth < 340) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [keep, const SizedBox(height: 8), go]);
                    }
                    return Row(children: [Expanded(child: keep), const SizedBox(width: 10), Expanded(child: go)]);
                  }),
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
