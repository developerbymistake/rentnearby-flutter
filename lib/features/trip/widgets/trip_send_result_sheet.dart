import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../widgets/gradient_button.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../trip_navigation.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_v2_easy.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_format.dart';
import 'trip_sheet_frame.dart';

class TripSendResultSheet {
  static Future<void> show(
    BuildContext context, {
    required TripEnquiryBatch batch,
    required Map<String, String> names,
    bool taxi = false,
  }) =>
      TripSheetFrame.show<void>(context, _ResultBody(batch: batch, names: names, taxi: taxi));

  static String reasonLabel(String reason) => switch (reason) {
        TripSkipReasons.alreadyOpen => TripStrings.alreadyAsked,
        TripSkipReasons.notAvailable => TripStrings.notAvailableNow,
        TripSkipReasons.blocked => TripStrings.cannotBeAsked,
        TripSkipReasons.limitReached => TripStrings.threeOpen,
        TripSkipReasons.alreadyBooked => TripStringsA5.alreadyBookedOther,
        'DaysAcrossCities' => TripStringsV2Find.driverOneCity,
        _ => TripStrings.cannotBeAsked,
      };
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.batch, required this.names, required this.taxi});

  final TripEnquiryBatch batch;
  final Map<String, String> names;
  final bool taxi;

  Widget _row(String name, String label, bool ok, {String? sub}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(ok ? Iconsax.tick_circle : Iconsax.info_circle,
                size: 18, color: ok ? AppColors.success : AppColors.textLight),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  if (sub != null)
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ok ? AppColors.successText : AppColors.textLight)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return TripSheetFrame(
      title: batch.items.isEmpty
          ? TripStringsA5.couldNotSend
          : (taxi ? TripStringsV2Easy.sentToDrivers(batch.items.length) : TripStringsV2Easy.sentTo(batch.items.length)),
      description: batch.items.isEmpty ? TripStringsA5.couldNotSendSub : TripStringsV2Easy.replyWillShow,
      footer: batch.items.isEmpty
          ? null
          : Text(taxi ? TripStringsV2Easy.driverNotify : TripStringsV2Easy.hostNotify,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35)),
      children: [
        for (final e in batch.items)
          _row(e.listingName, TripStrings.sent, true,
              sub: !taxi && e.checkIn != null && e.checkOut != null ? TripFormat.dayMonthRange(e.checkIn!, e.checkOut!) : null),
        for (final s in batch.skipped)
          _row(names[s.listingId] ?? TripStrings.stay, TripSendResultSheet.reasonLabel(s.reason), false),
        const SizedBox(height: 16),
        GradientButton(
          label: TripStringsV2Easy.sentBack,
          height: 52,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: () {
            Navigator.pop(context);
            TripNavigation.backToPlan();
          },
        ),
        if (batch.items.isNotEmpty)
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(taxi ? TripStringsV2Easy.askMoreDrivers : TripStringsV2Easy.askMoreStays,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: TripColors.accentDark)),
            ),
          ),
      ],
    );
  }
}
