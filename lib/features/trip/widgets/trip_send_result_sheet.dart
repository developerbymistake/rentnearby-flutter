import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
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

  ListingTone get _tone => taxi ? ListingTone.coral : ListingTone.forest;

  Widget _back(BuildContext context) => GradientPillButton(
        tone: _tone,
        label: TripStringsV2Easy.sentBack,
        onTap: () {
          Navigator.pop(context);
          TripNavigation.backToPlan();
        },
      );

  Widget _shortlistBody(BuildContext context) {
    final results = batch.perRecipient;
    final sentCount = results.where((r) => r.ok).length;
    final nothing = sentCount == 0;
    final byListing = {for (final e in batch.items) e.listingId: e};
    return TripSheetFrame(
      tone: _tone,
      art: nothing ? ListingArt.clipboard : ListingArt.star,
      size: SheetSize.confirm,
      title: nothing ? TripStringsA5.couldNotSend : TripStringsShortlist.sentTitle(sentCount),
      description: nothing ? TripStringsA5.couldNotSendSub : TripStringsShortlist.sentBody(sentCount, taxi: taxi),
      footer: _back(context),
      children: [
        for (var i = 0; i < results.length; i++)
          ResultRow3D(
            art: results[i].ok ? ListingArt.star : ListingArt.clipboard,
            title: names[results[i].listingId] ?? byListing[results[i].listingId]?.listingName ?? (taxi ? TripStringsShortlist.taxiFallback : TripStrings.stay),
            label: TripStringsShortlist.statusLabel(results[i].status),
            ok: results[i].ok,
            divider: i < results.length - 1,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (shortlist) return _shortlistBody(context);
    final empty = batch.items.isEmpty;
    final rows = <Widget>[
      for (final e in batch.items)
        ResultRow3D(
          art: ListingArt.star,
          title: e.listingName,
          subtitle: !taxi && e.checkIn != null && e.checkOut != null ? TripFormat.dayMonthRange(e.checkIn!, e.checkOut!) : null,
          label: TripStrings.sent,
        ),
      for (final s in batch.skipped)
        ResultRow3D(art: ListingArt.clipboard, title: names[s.listingId] ?? TripStrings.stay, label: TripSendResultSheet.reasonLabel(s.reason), ok: false),
    ];
    return TripSheetFrame(
      tone: _tone,
      art: empty ? ListingArt.clipboard : ListingArt.star,
      size: SheetSize.confirm,
      title: empty ? TripStringsA5.couldNotSend : (taxi ? TripStringsV2Easy.sentToDrivers(batch.items.length) : TripStringsV2Easy.sentTo(batch.items.length)),
      description: empty ? TripStringsA5.couldNotSendSub : TripStringsV2Easy.replyWillShow,
      footnote: empty ? null : (taxi ? TripStringsV2Easy.driverNotify : TripStringsV2Easy.hostNotify),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _back(context),
          if (!empty) ...[
            const SizedBox(height: 10),
            WhitePillButton(tone: _tone, label: taxi ? TripStringsV2Easy.askMoreDrivers : TripStringsV2Easy.askMoreStays, onTap: () => Navigator.pop(context)),
          ],
        ],
      ),
      children: [
        const SizedBox(height: 4),
        ...rows,
      ],
    );
  }
}
