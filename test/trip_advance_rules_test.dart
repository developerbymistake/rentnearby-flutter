import 'package:bakhli/features/trip/trip_constants.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/utils/trip_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool upi(String s) => TripConstants.upiPattern.hasMatch(s);

  test('upi pattern accepts common shapes', () {
    for (final ok in ['name@bank', 'a.b-c_d@okhdfc', '98765@ybl', 'ab@cd', 'Name.Surname@OkSBI']) {
      expect(upi(ok), isTrue, reason: ok);
    }
  });

  test('upi pattern rejects bad shapes', () {
    for (final bad in ['', 'name', '@bank', 'name@', 'a@bank', 'name@b', 'name@bank1', 'na me@bank', 'name@@bank', 'name@bank.com', 'नाम@bank']) {
      expect(upi(bad), isFalse, reason: bad);
    }
  });

  test('upi pattern length edges', () {
    expect(upi('${'a' * 50}@bank'), isTrue);
    expect(upi('${'a' * 51}@bank'), isFalse);
    expect(upi('ab@${'b' * 64}'), isTrue);
    expect(upi('ab@${'b' * 65}'), isFalse);
  });

  test('constants mirror the server rules', () {
    expect(TripConstants.holdMinHours, 1);
    expect(TripConstants.holdDefaultHours, 6);
    expect(TripConstants.holdMaxHours, 48);
    expect(TripConstants.holdCheckInCutoffHour, 12);
    expect(TripConstants.upiMax, 60);
    expect(TripConstants.maxFareEdits, 3);
    expect(TripConstants.leadsPerTripPerDay, 10);
    expect(TripConstants.maxLeadDays, 14);
    expect(TripConstants.driverNoteMax, 300);
  });

  test('time12Of formats am, pm, noon and midnight', () {
    expect(TripFormat.time12Of(DateTime(2026, 11, 1, 18, 0)), '6:00 pm');
    expect(TripFormat.time12Of(DateTime(2026, 11, 1, 9, 5)), '9:05 am');
    expect(TripFormat.time12Of(DateTime(2026, 11, 1, 12, 0)), '12:00 pm');
    expect(TripFormat.time12Of(DateTime(2026, 11, 1, 0, 30)), '12:30 am');
    expect(TripFormat.time12Of(DateTime(2026, 11, 1, 23, 59)), '11:59 pm');
  });

  test('time12Of converts a UTC instant to local time', () {
    final utc = DateTime.utc(2026, 11, 1, 6, 30);
    expect(TripFormat.time12Of(utc), TripFormat.time12Of(utc.toLocal()));
  });

  test('dayTime says Today for the same local day', () {
    final now = DateTime(2026, 11, 1, 10, 0);
    expect(TripFormat.dayTime(DateTime(2026, 11, 1, 18, 0), now: now), 'Today, 6:00 pm');
  });

  test('dayTime uses the short date for another day', () {
    final now = DateTime(2026, 11, 1, 10, 0);
    final d = DateTime(2026, 11, 3, 18, 0);
    expect(TripFormat.dayTime(d, now: now), '${TripFormat.shortDate(d)}, 6:00 pm');
    expect(TripFormat.dayTime(DateTime(2026, 11, 3, 18, 0), now: now), 'Tue 03 Nov, 6:00 pm');
  });

  test('dayTime treats the previous year same day as another day', () {
    final now = DateTime(2026, 11, 1, 10, 0);
    expect(TripFormat.dayTime(DateTime(2025, 11, 1, 18, 0), now: now), startsWith('Sat 01 Nov'));
  });

  test('payment lines name the other party and deny holding money', () {
    expect(TripStrings.stayPayLine, 'Pay the host directly. Bakhli does not take or hold payment.');
    expect(TripStrings.taxiPayLine, 'Pay the driver directly. Bakhli does not take or hold payment.');
  });

  test('advance and taxi copy avoids trust words', () {
    final samples = <String>[
      TripStrings.advanceReceivedHostSays,
      TripStrings.advanceReceivedBar('Rs 500'),
      TripStrings.saysReceived('Deodar', 'Rs 500', '6:00 pm'),
      TripStrings.waitingFooter,
      TripStrings.checkAmountFirst,
      TripStrings.ifPaidFooter,
      TripStrings.driverReplyFooter,
      TripStrings.fareFooter,
      TripStrings.taxiEnquiryFooter,
      TripStrings.askFooter,
      TripStrings.askFooterEmpty,
      TripStrings.canStillMark('Rahul'),
      TripStrings.guestMovedOn,
    ];
    for (final t in samples) {
      final l = t.toLowerCase();
      for (final bad in ['verified', 'guaranteed', 'secured', 'dispute', 'screenshot upload']) {
        expect(l.contains(bad), isFalse, reason: t);
      }
    }
  });

  test('copy builders fill their arguments', () {
    expect(TripStrings.advanceHoldTill('6:00 pm'), 'Advance · hold till 6:00 pm');
    expect(TripStrings.openWhatsAppTo('9876543210'), 'Open WhatsApp · +91 9876543210');
    expect(TripStrings.proofWhatsAppText('Rs 500', 'Deodar', 'Sat 01 Nov'), 'Hi, advance of Rs 500 for Deodar, Sat 01 Nov. Screenshot attached.');
    expect(TripStrings.nDays(1), '1 day');
    expect(TripStrings.nDays(3), '3 days');
    expect(TripStrings.changesLeft(1), '1 change left');
    expect(TripStrings.changesLeft(2), '2 changes left');
    expect(TripStrings.listedTimes('Rs 1,800', 2, 'Rs 3,600'), 'Rs 1,800 × 2 days = Rs 3,600');
    expect(TripStrings.dayLine(1, '5 h 35 min', 'Mall Road → Naini Lake'), 'Day 1 · 5 h 35 min · Mall Road → Naini Lake');
  });
}
