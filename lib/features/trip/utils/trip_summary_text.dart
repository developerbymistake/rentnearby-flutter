import '../../../models/browse_item.dart';
import '../../taxi/ways/trip_strings_mcb_a2.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_summary_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_mcb_a1.dart';
import '../trip_strings_mcd_a1.dart';
import '../trip_strings_steps_a3.dart';
import '../trip_strings_v2_easy.dart';
import '../widgets/trip_status.dart';
import 'trip_day_timeline.dart';
import 'trip_format.dart';

class TripSummaryText {
  static int spotCount(TripSummaryRecord r) => r.days.fold(0, (sum, d) => sum + d.spots.length);

  static TripJourney? journeyOf(TripSummaryRecord r, TripStepRole role) =>
      role == TripStepRole.gettingThere ? r.gettingThere : r.comingBack;

  static bool isDone(TripRowState s) =>
      s == TripRowState.own || s == TripRowState.saved || s == TripRowState.confirmed || s == TripRowState.booked;

  static List<TripSummaryArrangement> shownArrangements(TripSummaryRecord r) =>
      [for (final a in r.arrangements) if (a.state != TripRowState.skipped) a];

  static TripDisplayStatus pillStatus(TripRowState s) => switch (s) {
        TripRowState.confirmed => TripDisplayStatus.confirmedByBoth,
        TripRowState.booked => TripDisplayStatus.bookedByYou,
        TripRowState.own || TripRowState.saved => TripDisplayStatus.own,
        TripRowState.asked || TripRowState.offer => TripDisplayStatus.asked,
        TripRowState.attention => TripDisplayStatus.notAvailable,
        _ => TripDisplayStatus.none,
      };

  static String stateWord(TripRowState s) => switch (s) {
        TripRowState.todo => TripStringsV2Easy.pillTodo,
        TripRowState.asked => TripStringsV2Easy.pillAsked,
        TripRowState.offer => TripStringsV2Easy.pillOffer,
        TripRowState.confirmed => TripStringsV2Easy.pillConfirmed,
        TripRowState.booked => TripStringsV2Easy.pillBooked,
        TripRowState.own => TripStringsV2Easy.pillOwn,
        TripRowState.saved => TripStringsV2Easy.pillSaved,
        TripRowState.skipped => TripStringsV2Easy.pillSkipped,
        TripRowState.attention => TripStringsV2Easy.pillAttention,
      };

  static String arrangementLine(TripSummaryArrangement a) {
    final detail = (a.detail ?? '').trim();
    final line = TripStrings.joinDots([a.title, detail.isEmpty ? null : detail, stateWord(a.state)]);
    return '${isDone(a.state) ? TripStringsV2Easy.shareDone : TripStringsV2Easy.shareWaiting}: $line';
  }

  static bool hasContent(TripSummaryRecord r) =>
      r.days.isNotEmpty || r.nights.isNotEmpty || r.taxis.isNotEmpty || shownArrangements(r).isNotEmpty || r.hasLegTravel;

  static bool canShare(TripSummaryRecord r) =>
      spotCount(r) > 0 || r.nights.isNotEmpty || r.taxis.isNotEmpty || shownArrangements(r).isNotEmpty || r.hasLegTravel;

  static String journeyHead(TripJourney j) => TripStrings.joinDots([
        TripStringsStepsA3.routeLine(j.places),
        TripStringsStepsA3.carsLine(j.cars),
        if ((j.listedTotal ?? 0) > 0) TripStringsStepsA3.aboutTotal(BrowseItem.inr(j.listedTotal!)),
        TripFormat.shortDate(j.date),
      ]);

  static String carLine(TripJourneyLeg leg, int n) => TripStrings.joinDots([
        TripStringsStepsA3.carRow(n, leg.driverName),
        if ((leg.listedFare ?? 0) > 0) BrowseItem.inr(leg.listedFare!),
        if (n > 1) TripStringsStepsA3.changeCarShort(leg.changePlace),
      ]);

  static String travelHeading(TripSummaryTravel t) {
    final date = t.date == null ? null : TripFormat.shortDate(t.date!);
    return t.isOwn
        ? TripStringsMcdA1.travelHeadingOwn(t.toName, date)
        : TripStringsMcdA1.travelHeading(t.toName, date, t.shownCars);
  }

  static String carStatus(TripSummaryTravelCar c) {
    if (c.cancelledBy == null && c.isNotAsked) return TripStringsMcbA2.notAsked;
    if (c.cancelledBy == null && c.display == TripDisplayStatus.asked && c.enquiryId == null) {
      return TripStringsMcbA2.asked;
    }
    return statusLabel(c.display, c.cancelledBy, taxi: true);
  }

  static String travelCarLine(TripSummaryTravelCar c) {
    final fare = c.fare;
    return TripStringsMcdA1.carLine(c.car, c.driverName, fare == null || fare <= 0 ? null : BrowseItem.inr(fare), carStatus(c));
  }

  static List<String> travelLines(TripSummaryTravel t, int level) {
    final lines = <String>[travelHeading(t)];
    if (t.isOwn) {
      lines.add('  ${TripStringsV2Easy.youArrangeTravel}');
    } else if (level < 2 && t.cars.isNotEmpty) {
      for (final c in t.cars) {
        lines.add('  ${travelCarLine(c)}');
      }
    } else if (t.state != null) {
      lines.add('  ${TripStringsMcdA1.carsState(t.shownCars, TripStringsMcbA1.stateLabel(t.state!))}');
    }
    lines.add('');
    return lines;
  }

  static String legHeading(TripSummaryLeg l) => TripStringsMcdA1.legSection(l.cityName, l.dates);

  static String roomLine(TripSummaryRoom r) {
    final name = r.roomName == null || r.roomName!.isEmpty ? TripStrings.room : r.roomName!;
    final units = r.units > 1 ? ' x${r.units}' : '';
    return r.guests > 0 ? '$name$units · ${TripStrings.peopleText(r.guests)}' : '$name$units';
  }

  static String advanceLine(TripSummaryNight n) {
    final amount = n.advanceAmount;
    if (amount == null || amount <= 0) return TripStrings.advanceNone;
    final p = BrowseItem.inr(amount);
    return switch (n.advanceStatus) {
      TripAdvanceStatuses.received => TripStrings.advanceReceivedShort(p),
      TripAdvanceStatuses.pending || TripAdvanceStatuses.proofSent => TripStrings.advanceAskedShort(p),
      _ => TripStrings.advanceNone,
    };
  }

  static String statusLabel(TripDisplayStatus s, String? cancelledBy, {bool taxi = false}) {
    if (cancelledBy != null) {
      return cancelledBy == 'traveller' ? TripStrings.youCancelled : TripStrings.hostCancelled;
    }
    return TripStatusVisuals.label(s, taxi: taxi);
  }

  static String fareLine(TripSummaryTaxi t) {
    final fare = t.agreedFare;
    if (fare == null || fare <= 0) return '';
    final p = BrowseItem.inr(fare);
    return t.tollExtra ? '$p · ${TripStrings.tollExtraShort}' : p;
  }

  static String taxiDays(TripSummaryTaxi t) {
    final a = t.checkIn;
    final b = t.checkOut;
    if (a == null) return '';
    return TripFormat.dayMonthRange(a, b ?? a);
  }

  static String taxiDayNumbers(TripSummaryTaxi t) {
    final d = [...t.days]..sort();
    if (d.isEmpty) return taxiDays(t);
    return d.length == 1 ? 'Day ${d.first}' : 'Days ${d.first}-${d.last}';
  }

  static String datesOf(TripSummaryRecord r) {
    final a = r.startDate;
    if (a == null) return '';
    return TripFormat.dayMonthRange(a, r.endDate ?? a);
  }

  static String headerLine(TripSummaryRecord r) {
    final dates = datesOf(r);
    return TripStrings.joinDots([
      r.routeLine,
      dates.isEmpty ? TripStringsA5.datesNotSet : dates,
      TripStrings.peopleText(r.people),
    ]);
  }

  static bool _sameStay(TripSummaryNight a, TripSummaryNight b) =>
      a.enquiryId != null && a.enquiryId == b.enquiryId && b.night == a.night + 1;

  static List<TripSummaryNightGroup> nightGroups(List<TripSummaryNight> nights) {
    final groups = <List<TripSummaryNight>>[];
    for (final n in nights) {
      if (groups.isNotEmpty && _sameStay(groups.last.last, n)) {
        groups.last.add(n);
      } else {
        groups.add([n]);
      }
    }
    return [for (final g in groups) TripSummaryNightGroup(List.unmodifiable(g))];
  }

  static String checkOutOf(DateTime? date) => date == null ? '' : TripFormat.shortDate(DateTime(date.year, date.month, date.day + 1));

  static String spotLine(TripSummaryDay d, int i) =>
      d.hasTimes ? '${TripDayTimeline.clock(d.starts[i])} ${d.spots[i]}' : d.spots[i];

  static String dayRoute(TripSummaryDay d) {
    final String route;
    if (d.hasTimes) {
      route = [for (var i = 0; i < d.spots.length; i++) spotLine(d, i)].join('\n');
    } else {
      route = d.spots.join(' → ');
    }
    if (d.minutes <= 0) return route;
    final about = TripStringsA5.aboutDuration(TripFormat.duration(d.minutes));
    return d.hasTimes ? '$route\n($about)' : '$route ($about)';
  }

  static String footer(TripSummaryRecord r) {
    final driver = r.taxis.isNotEmpty || r.hasTravelCars || r.gettingThere != null || r.comingBack != null;
    final parts = <String>[
      if (r.nights.isNotEmpty) TripStrings.summaryFooter,
      if (driver) TripStrings.taxiPayLine,
    ];
    return parts.isEmpty ? TripStringsA5.planOnlyFooter : parts.join('\n');
  }

  static String build(TripSummaryRecord r) {
    var level = 0;
    var out = _compose(r, level);
    while (out.length > TripConstants.summaryShareMax && level < 3) {
      out = _compose(r, ++level);
    }
    if (out.length > TripConstants.summaryShareMax) {
      final f = footer(r);
      final room = TripConstants.summaryShareMax - f.length - 1;
      out = '${out.substring(0, room.clamp(0, out.length))}\n$f';
    }
    return out;
  }

  static List<String> _nightLines(TripSummaryNight n, int level) {
    final lines = <String>[];
    final dateText = n.date == null ? '' : TripFormat.shortDate(n.date!);
    final title = [
      TripStrings.nightCard(n.night, dateText),
      n.listingName,
      statusLabel(n.display, n.cancelledBy),
      if ((n.agreedTotal ?? 0) > 0) BrowseItem.inr(n.agreedTotal!),
    ].where((e) => e.isNotEmpty).join(' · ');
    lines.add(title);
    if (level < 2) {
      for (final room in n.roomLines) {
        lines.add('  ${TripStrings.room}: ${roomLine(room)}');
      }
    }
    if (level < 2) lines.add('  ${TripStrings.advance}: ${advanceLine(n)}');
    if (level < 1) {
      final c = n.cancellationText;
      if (c != null && c.isNotEmpty) lines.add('  ${TripStrings.cancellationTerms}: $c');
      if (n.gstInvoice != null) {
        lines.add('  ${TripStrings.gstInvoice}: ${n.gstInvoice! ? TripStrings.yes : TripStrings.no}');
      }
    }
    if (level < 3) lines.add('  ${TripStrings.confirmedLabel}: ${n.confirmedLine()}');
    return lines;
  }

  static List<String> _taxiLines(TripSummaryTaxi t, int level) {
    final lines = <String>[];
    final title = [
      t.listingName,
      taxiDayNumbers(t),
      statusLabel(t.display, t.cancelledBy, taxi: true),
      fareLine(t),
    ].where((e) => e.isNotEmpty).join(' · ');
    lines.add(title);
    final pickup = [
      if (t.pickupTime != null && t.pickupTime!.isNotEmpty) TripFormat.time12(t.pickupTime!),
      if (level < 1 && t.pickupPlace != null && t.pickupPlace!.isNotEmpty) t.pickupPlace!,
    ].join(', ');
    if (pickup.isNotEmpty) lines.add('  ${TripStrings.pickup}: $pickup');
    if (level < 3) lines.add('  ${TripStrings.confirmedLabel}: ${t.confirmedLine()}');
    return lines;
  }

  static List<String> _legLines(TripSummaryLeg l, int level) {
    final lines = <String>[];
    final travel = l.travel;
    if (l.index >= 2 && travel != null) lines.addAll(travelLines(travel, level));
    lines.add(legHeading(l));
    for (final n in l.nights) {
      lines.addAll(_nightLines(n, level));
    }
    for (final t in l.taxis) {
      lines.addAll(_taxiLines(t, level));
    }
    lines.add('');
    return lines;
  }

  static String _compose(TripSummaryRecord r, int level) {
    final lines = <String>[
      r.title.isEmpty ? TripStrings.shareSubject(r.routeLine) : r.title,
      headerLine(r),
      '',
    ];
    for (final d in r.days) {
      if (d.spots.isEmpty) continue;
      final date = d.date == null ? null : TripFormat.shortDate(d.date!);
      lines.add(TripStringsA5.dayHeading(d.day, date));
      lines.add(dayRoute(d));
      lines.add('');
    }
    final arranged = shownArrangements(r);
    if (arranged.isNotEmpty) {
      lines.add(TripStringsV2Easy.arrangementsHeading);
      for (final a in arranged) {
        lines.add(arrangementLine(a));
      }
      lines.add('');
    }
    if (r.isMultiCity) {
      for (final l in r.legs) {
        lines.addAll(_legLines(l, level));
      }
    } else {
      if (r.nights.isNotEmpty) {
        lines.add(TripStringsA5.staysSection);
        for (final n in r.nights) {
          lines.addAll(_nightLines(n, level));
        }
        lines.add('');
      }
      if (r.taxis.isNotEmpty) {
        lines.add(TripStringsA5.taxisSection);
        for (final t in r.taxis) {
          lines.addAll(_taxiLines(t, level));
        }
        lines.add('');
      }
    }
    if (r.agreedTotal > 0) lines.add(TripStrings.agreedInTotal(BrowseItem.inr(r.agreedTotal)));
    lines.add(footer(r));
    return lines.join('\n');
  }
}
