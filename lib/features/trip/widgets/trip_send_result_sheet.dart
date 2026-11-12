import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_strings.dart';
import '../trip_navigation.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_shortlist.dart';
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
    bool shortlist = false,
  }) =>
      TripSheetFrame.show<void>(context, _ResultBody(batch: batch, names: names, taxi: taxi, shortlist: shortlist));

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
  const _ResultBody({required this.batch, required this.names, required this.taxi, this.shortlist = false});

  final TripEnquiryBatch batch;
  final Map<String, String> names;
  final bool taxi;
  final bool shortlist;

  Widget _row(String name, String label, bool ok, {String? sub}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            TravelIcon(ok ? TravelIcon.star : TravelIcon.note, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w600, color: DesignColors.textStrong)),
                  if (sub != null)
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11.5, color: DesignColors.textSecondary)),
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
                      fontFamily: FitnessAppTheme.fontName,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ok ? TripUi.goodDark : DesignColors.textSecondary)),
            ),
          ],
        ),
      );

  Widget _shortlistBody(BuildContext context) {
    final results = batch.perRecipient;
    final sentCount = results.where((r) => r.ok).length;
    final nothing = sentCount == 0;
    final byListing = {for (final e in batch.items) e.listingId: e};
    return TripSheetFrame(
      title: nothing ? TripStringsA5.couldNotSend : TripStringsShortlist.sentTitle(sentCount),
      description: nothing ? TripStringsA5.couldNotSendSub : TripStringsShortlist.sentBody(sentCount, taxi: taxi),
      children: [
        TemplateStagger(children: [
          Column(children: [
            for (final r in results)
              _row(
                names[r.listingId] ?? byListing[r.listingId]?.listingName ?? (taxi ? TripStringsShortlist.taxiFallback : TripStrings.stay),
                TripStringsShortlist.statusLabel(r.status),
                r.ok,
              ),
          ]),
          const SizedBox(height: 16),
          TripButton(
            label: TripStringsV2Easy.sentBack,
            height: 52,
            gradient: taxi ? KitTone.taxi.gradient : KitTone.stay.gradient,
            shadowColor: taxi ? TripUi.taxi : TripUi.stay,
            onPressed: () {
              Navigator.pop(context);
              TripNavigation.backToPlan();
            },
          ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (shortlist) return _shortlistBody(context);
    return TripSheetFrame(
      title: batch.items.isEmpty
          ? TripStringsA5.couldNotSend
          : (taxi ? TripStringsV2Easy.sentToDrivers(batch.items.length) : TripStringsV2Easy.sentTo(batch.items.length)),
      description: batch.items.isEmpty ? TripStringsA5.couldNotSendSub : TripStringsV2Easy.replyWillShow,
      footer: batch.items.isEmpty
          ? null
          : Text(taxi ? TripStringsV2Easy.driverNotify : TripStringsV2Easy.hostNotify,
              style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, color: DesignColors.textSecondary, height: 1.35)),
      children: [
        TemplateStagger(children: [
          Column(children: [
        for (final e in batch.items)
          _row(e.listingName, TripStrings.sent, true,
              sub: !taxi && e.checkIn != null && e.checkOut != null ? TripFormat.dayMonthRange(e.checkIn!, e.checkOut!) : null),
        for (final s in batch.skipped)
          _row(names[s.listingId] ?? TripStrings.stay, TripSendResultSheet.reasonLabel(s.reason), false),
          ]),
          const SizedBox(height: 16),
          TripButton(
          label: TripStringsV2Easy.sentBack,
          height: 52,
          gradient: taxi ? KitTone.taxi.gradient : KitTone.stay.gradient,
          shadowColor: taxi ? TripUi.taxi : TripUi.stay,
          onPressed: () {
            Navigator.pop(context);
            TripNavigation.backToPlan();
          },
        ),
          if (batch.items.isNotEmpty)
          Center(
            child: TextLink(label: taxi ? TripStringsV2Easy.askMoreDrivers : TripStringsV2Easy.askMoreStays, onTap: () => Navigator.pop(context), tone: KitTone.trip),
          ),
        ]),
      ],
    );
  }
}
