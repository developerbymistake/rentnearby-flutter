import '../../../models/browse_item.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_journey_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_summary_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_steps_a1.dart';
import '../trip_strings_steps_a3.dart';
import '../widgets/trip_status.dart';
import 'trip_format.dart';
import 'trip_step_rules.dart';

class TripSummaryText {
  static const String skippedStatus = 'skipped';

  static bool isSkipped(TripSummaryNight n) => n.displayStatus == skippedStatus;

  static int spotCount(TripSummaryRecord r) => r.days.fold(0, (sum, d) => sum + d.spots.length);

  static TripJourney? journeyOf(TripSummaryRecord r, TripStepRole role) =>
      role == TripStepRole.gettingThere ? r.gettingThere : r.comingBack;

  static TripStepDisplay stepDisplay(TripSummaryRecord r, TripStepRole role) =>
      TripStepRules.display(r.steps.of(role), journeyOf(r, role));

  static bool stepShown(TripSummaryRecord r, TripStepRole role) {
    final d = stepDisplay(r, role);
    return d != TripStepDisplay.notStarted && d != TripStepDisplay.notNeeded && d != TripStepDisplay.skipped;
  }

  static bool hasSteps(TripSummaryRecord r) => TripStepRole.values.any((role) => stepShown(r, role));

  static bool stepHasDriver(TripSummaryRecord r, TripStepRole role) {
    final d = stepDisplay(r, role);
    return d == TripStepDisplay.chosen || d == TripStepDisplay.asked || d == TripStepDisplay.booked;
  }

  static bool hasContent(TripSummaryRecord r) =>
      r.days.isNotEmpty || r.nights.isNotEmpty || r.taxis.isNotEmpty || hasSteps(r);

  static bool canShare(TripSummaryRecord r) =>
      spotCount(r) > 0 || r.nights.isNotEmpty || r.taxis.isNotEmpty || hasSteps(r);

  static String roleHeading(TripStepRole role) =>
      role == TripStepRole.gettingThere ? TripStringsStepsA3.gettingThere : TripStringsStepsA3.comingBack;

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

  static List<String> stepLines(TripSummaryRecord r, TripStepRole role, int level) {
    if (!stepShown(r, role)) return const [];
    final display = stepDisplay(r, role);
    final lines = <String>[roleHeading(role)];
    if (display == TripStepDisplay.own) {
      final note = (r.steps.of(role).note ?? '').trim();
      lines.add(note.isEmpty ? TripStringsStepsA3.arrangedByYou : TripStringsStepsA3.arrangedWithNote(note));
      lines.add('');
      return lines;
    }
    final j = journeyOf(r, role);
    if (j == null) return const [];
    lines.add(journeyHead(j));
    if (level < 2) {
      for (var i = 0; i < j.legs.length; i++) {
        lines.add('  ${carLine(j.legs[i], i + 1)}');
      }
    }
    lines.add('  ${TripStringsStepsA1.stepLabel(display)}');
    lines.add('');
    return lines;
  }

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
    if (fare == null) return '';
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

  static String checkOutOf(DateTime? date) => date == null ? '' : TripFormat.shortDate(DateTime(date.year, date.month, date.day + 1));

  static String dayRoute(TripSummaryDay d) {
    final route = d.spots.join(' → ');
    if (d.minutes <= 0) return route;
    return '$route (${TripStringsA5.aboutDuration(TripFormat.duration(d.minutes))})';
  }

  static String footer(TripSummaryRecord r) {
    final hostStay = r.nights.any((n) => !n.isOwn && !isSkipped(n));
    final driver = r.taxis.any((t) => !t.isOwn) || TripStepRole.values.any((role) => stepHasDriver(r, role));
    final parts = <String>[
      if (hostStay) TripStrings.summaryFooter,
      if (driver) TripStrings.taxiPayLine,
    ];
    if (parts.isNotEmpty) return parts.join('\n');
    final anyOwn = r.nights.any((n) => n.isOwn) ||
        r.taxis.any((t) => t.isOwn) ||
        TripStepRole.values.any((role) => stepDisplay(r, role) == TripStepDisplay.own);
    return anyOwn ? TripStringsA5.ownFooter : TripStringsA5.planOnlyFooter;
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
    lines.addAll(stepLines(r, TripStepRole.gettingThere, level));
    if (r.nights.isNotEmpty) {
      lines.add(TripStringsA5.staysSection);
      for (final n in r.nights) {
        final dateText = n.date == null ? '' : TripFormat.shortDate(n.date!);
        if (isSkipped(n)) {
          lines.add(TripStrings.joinDots([TripStrings.nightCard(n.night, dateText), TripStringsA5.noStayTravelling]));
          continue;
        }
        final title = [
          TripStrings.nightCard(n.night, dateText),
          n.listingName,
          n.isOwn ? TripStrings.ownBookingShort : statusLabel(n.display, n.cancelledBy),
          if (n.agreedTotal != null) BrowseItem.inr(n.agreedTotal!),
        ].where((e) => e.isNotEmpty).join(' · ');
        lines.add(title);
        if (n.isOwn && (n.ownPhone ?? '').isNotEmpty) lines.add('  ${n.ownPhone}');
        if (level < 2) {
          for (final room in n.roomLines) {
            lines.add('  ${TripStrings.room}: ${roomLine(room)}');
          }
        }
        if (level < 2 && !n.isOwn) lines.add('  ${TripStrings.advance}: ${advanceLine(n)}');
        if (level < 1) {
          final c = n.cancellationText;
          if (c != null && c.isNotEmpty) lines.add('  ${TripStrings.cancellationTerms}: $c');
          if (n.gstInvoice != null) {
            lines.add('  ${TripStrings.gstInvoice}: ${n.gstInvoice! ? TripStrings.yes : TripStrings.no}');
          }
        }
        if (level < 3 && !n.isOwn) lines.add('  ${TripStrings.confirmedLabel}: ${n.confirmedLine()}');
      }
      lines.add('');
    }
    if (r.taxis.isNotEmpty) {
      lines.add(TripStringsA5.taxisSection);
      for (final t in r.taxis) {
        final title = [
          t.listingName,
          taxiDayNumbers(t),
          t.isOwn ? TripStrings.ownBookingShort : statusLabel(t.display, t.cancelledBy, taxi: true),
          fareLine(t),
        ].where((e) => e.isNotEmpty).join(' · ');
        lines.add(title);
        if (t.isOwn && (t.ownPhone ?? '').isNotEmpty) lines.add('  ${t.ownPhone}');
        final pickup = [
          if (t.pickupTime != null && t.pickupTime!.isNotEmpty) TripFormat.time12(t.pickupTime!),
          if (level < 1 && t.pickupPlace != null && t.pickupPlace!.isNotEmpty) t.pickupPlace!,
        ].join(', ');
        if (pickup.isNotEmpty) lines.add('  ${TripStrings.pickup}: $pickup');
        if (level < 3 && !t.isOwn) lines.add('  ${TripStrings.confirmedLabel}: ${t.confirmedLine()}');
      }
      lines.add('');
    }
    lines.addAll(stepLines(r, TripStepRole.comingBack, level));
    if (r.agreedTotal > 0) lines.add(TripStrings.agreedInTotal(BrowseItem.inr(r.agreedTotal)));
    lines.add(footer(r));
    return lines.join('\n');
  }
}
