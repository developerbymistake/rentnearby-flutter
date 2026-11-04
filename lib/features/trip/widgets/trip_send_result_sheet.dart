import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../widgets/gradient_button.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import 'trip_sheet_frame.dart';

class TripSendResultSheet {
  static Future<void> show(
    BuildContext context, {
    required TripEnquiryBatch batch,
    required Map<String, String> names,
  }) =>
      TripSheetFrame.show<void>(context, _ResultBody(batch: batch, names: names));

  static String reasonLabel(String reason) => switch (reason) {
        TripSkipReasons.alreadyOpen => TripStrings.alreadyAsked,
        TripSkipReasons.notAvailable => TripStrings.notAvailableNow,
        TripSkipReasons.blocked => TripStrings.cannotBeAsked,
        TripSkipReasons.limitReached => TripStrings.threeOpen,
        TripSkipReasons.alreadyBooked => TripStringsA5.alreadyBookedOther,
        _ => TripStrings.cannotBeAsked,
      };
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.batch, required this.names});

  final TripEnquiryBatch batch;
  final Map<String, String> names;

  Widget _row(String name, String label, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(ok ? Iconsax.tick_circle : Iconsax.info_circle,
                size: 18, color: ok ? AppColors.success : AppColors.textLight),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
      title: batch.items.isEmpty ? TripStringsA5.couldNotSend : TripStrings.sentTo(batch.items.length),
      description: batch.items.isEmpty ? TripStringsA5.couldNotSendSub : null,
      footer: batch.items.isEmpty
          ? null
          : const Text(TripStrings.eachStayReplies,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35)),
      children: [
        for (final e in batch.items) _row(e.listingName, TripStrings.sent, true),
        for (final s in batch.skipped)
          _row(names[s.listingId] ?? TripStrings.stay, TripSendResultSheet.reasonLabel(s.reason), false),
        const SizedBox(height: 16),
        GradientButton(
          label: TripStrings.done,
          height: 52,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
