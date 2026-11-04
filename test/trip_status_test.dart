import 'package:bakhli/config/app_colors.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/trip_colors.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:bakhli/features/trip/widgets/trip_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const wires = {
    'asked': TripDisplayStatus.asked,
    'offered': TripDisplayStatus.offered,
    'confirmedByYou': TripDisplayStatus.confirmedByYou,
    'confirmedByBoth': TripDisplayStatus.confirmedByBoth,
    'notAvailable': TripDisplayStatus.notAvailable,
    'expired': TripDisplayStatus.expired,
    'declined': TripDisplayStatus.declined,
    'cancelled': TripDisplayStatus.cancelled,
    'notMe': TripDisplayStatus.notMe,
    'closed': TripDisplayStatus.closed,
    'fareSent': TripDisplayStatus.fareSent,
    'bookedByYou': TripDisplayStatus.bookedByYou,
    'holdExpired': TripDisplayStatus.holdExpired,
  };

  test('parse maps every server displayStatus', () {
    wires.forEach((wire, status) => expect(TripDisplayStatus.parse(wire), status));
  });

  test('parse falls back to none', () {
    expect(TripDisplayStatus.parse(null), TripDisplayStatus.none);
    expect(TripDisplayStatus.parse(''), TripDisplayStatus.none);
    expect(TripDisplayStatus.parse('somethingNew'), TripDisplayStatus.none);
  });

  test('red set', () {
    final red = TripDisplayStatus.values.where((s) => s.isRed).toSet();
    expect(red, {
      TripDisplayStatus.notAvailable,
      TripDisplayStatus.expired,
      TripDisplayStatus.declined,
      TripDisplayStatus.cancelled,
      TripDisplayStatus.notMe,
      TripDisplayStatus.holdExpired,
    });
  });

  test('green set is only confirmedByBoth', () {
    expect(TripDisplayStatus.values.where((s) => s.isGreen), [TripDisplayStatus.confirmedByBoth]);
  });

  test('open set is asked, offered and fareSent', () {
    expect(TripDisplayStatus.values.where((s) => s.isOpen).toSet(), {
      TripDisplayStatus.asked,
      TripDisplayStatus.offered,
      TripDisplayStatus.fareSent,
    });
  });

  test('bookedByYou is its own flag and not red or green', () {
    expect(TripDisplayStatus.bookedByYou.isBookedByYou, isTrue);
    expect(TripDisplayStatus.confirmedByYou.isBookedByYou, isFalse);
    expect(TripDisplayStatus.bookedByYou.isRed, isFalse);
    expect(TripDisplayStatus.bookedByYou.isGreen, isFalse);
  });

  test('taxi statuses use the token table', () {
    expect(TripStatusVisuals.bar(TripDisplayStatus.fareSent), TripStatusColors.waiting);
    expect(TripStatusVisuals.surface(TripDisplayStatus.fareSent), TripStatusColors.waitingSurface);
    expect(TripStatusVisuals.text(TripDisplayStatus.fareSent), AppColors.warningText);
    expect(TripStatusVisuals.bar(TripDisplayStatus.bookedByYou), TripStatusColors.booked);
    expect(TripStatusVisuals.surface(TripDisplayStatus.bookedByYou), TripStatusColors.bookedSurface);
    expect(TripStatusVisuals.text(TripDisplayStatus.bookedByYou), AppColors.tripBooked);
    expect(TripStatusVisuals.bar(TripDisplayStatus.holdExpired), TripStatusColors.failed);
    expect(TripStatusVisuals.surface(TripDisplayStatus.holdExpired), TripStatusColors.failedSurface);
  });

  test('taxi and hold labels', () {
    expect(TripStatusVisuals.label(TripDisplayStatus.fareSent), 'Replied');
    expect(TripStatusVisuals.label(TripDisplayStatus.fareSent, ownerSide: true), 'Replied');
    expect(TripStatusVisuals.label(TripDisplayStatus.bookedByYou), 'Booked by you');
    expect(TripStatusVisuals.label(TripDisplayStatus.bookedByYou, ownerSide: true), 'By traveller');
    expect(TripStatusVisuals.label(TripDisplayStatus.holdExpired), 'Hold expired');
    expect(TripStatusVisuals.label(TripDisplayStatus.holdExpired, ownerSide: true), 'Hold expired');
    expect(TripStatusVisuals.label(TripDisplayStatus.notMe, taxi: true), 'Driver says not me');
    expect(TripStatusVisuals.label(TripDisplayStatus.notMe), 'Host says not me');
    expect(TripStatusVisuals.label(TripDisplayStatus.notAvailable, taxi: true), 'Not available');
  });

  test('advance colours follow the sub-state', () {
    for (final st in ['Pending', 'ProofSent']) {
      expect(TripStatusVisuals.advanceBar(st), TripStatusColors.waiting);
      expect(TripStatusVisuals.advanceSurface(st), TripStatusColors.waitingSurface);
      expect(TripStatusVisuals.advanceText(st), AppColors.warningText);
    }
    expect(TripStatusVisuals.advanceBar('Received'), TripStatusColors.advance);
    expect(TripStatusVisuals.advanceSurface('Received'), TripStatusColors.advanceSurface);
    expect(TripStatusVisuals.advanceText('Received'), AppColors.tripAdvance);
    expect(TripStatusVisuals.advanceBar('HoldExpired'), TripStatusColors.failed);
    expect(TripStatusVisuals.advanceBar('None'), TripStatusColors.both);
  });

  test('advance label by status', () {
    final hold = DateTime(2026, 11, 1, 18, 0);
    expect(TripStatusVisuals.advanceLabel(TripAdvanceModel(status: 'Pending', holdUntil: hold)), 'Advance pending · till 6:00 pm');
    expect(TripStatusVisuals.advanceLabel(TripAdvanceModel(status: 'ProofSent', holdUntil: hold)), 'Waiting for host · reminded hourly');
    expect(TripStatusVisuals.advanceLabel(const TripAdvanceModel(status: 'Received')), 'Advance received · host says');
    expect(TripStatusVisuals.advanceLabel(const TripAdvanceModel(status: 'HoldExpired')), 'Hold expired');
    expect(TripStatusVisuals.advanceLabel(const TripAdvanceModel()), '');
  });

  test('bar colours follow the token table', () {
    expect(TripStatusVisuals.bar(TripDisplayStatus.asked), TripStatusColors.waiting);
    expect(TripStatusVisuals.bar(TripDisplayStatus.offered), TripStatusColors.waiting);
    expect(TripStatusVisuals.bar(TripDisplayStatus.confirmedByYou), TripStatusColors.confirmedByYou);
    expect(TripStatusVisuals.bar(TripDisplayStatus.confirmedByBoth), TripStatusColors.both);
    expect(TripStatusVisuals.bar(TripDisplayStatus.own), TripStatusColors.booked);
    expect(TripStatusVisuals.bar(TripDisplayStatus.shortlisted), TripStatusColors.shortlisted);
    expect(TripStatusVisuals.bar(TripDisplayStatus.closed), TripStatusColors.shortlisted);
    for (final s in TripDisplayStatus.values.where((s) => s.isRed)) {
      expect(TripStatusVisuals.bar(s), TripStatusColors.failed);
      expect(TripStatusVisuals.surface(s), TripStatusColors.failedSurface);
      expect(TripStatusVisuals.text(s), AppColors.errorText);
    }
  });

  test('surfaces', () {
    expect(TripStatusVisuals.surface(TripDisplayStatus.confirmedByYou), TripStatusColors.confirmedByYouSurface);
    expect(TripStatusVisuals.surface(TripDisplayStatus.confirmedByBoth), TripStatusColors.bothSurface);
    expect(TripStatusVisuals.surface(TripDisplayStatus.own), TripStatusColors.bookedSurface);
    expect(TripStatusVisuals.surface(TripDisplayStatus.shortlisted), AppColors.cardBg);
  });

  test('traveller labels', () {
    expect(TripStatusVisuals.label(TripDisplayStatus.asked), 'Asked · waiting');
    expect(TripStatusVisuals.label(TripDisplayStatus.offered), 'Offer received');
    expect(TripStatusVisuals.label(TripDisplayStatus.confirmedByYou), 'Confirmed by you');
    expect(TripStatusVisuals.label(TripDisplayStatus.confirmedByBoth), TripStrings.confirmedBothPill);
    expect(TripStatusVisuals.label(TripDisplayStatus.notAvailable), 'Not available');
    expect(TripStatusVisuals.label(TripDisplayStatus.expired), 'No reply in time');
    expect(TripStatusVisuals.label(TripDisplayStatus.declined), 'You declined');
    expect(TripStatusVisuals.label(TripDisplayStatus.cancelled), 'Cancelled by you');
    expect(TripStatusVisuals.label(TripDisplayStatus.notMe), 'Host says not me');
    expect(TripStatusVisuals.label(TripDisplayStatus.closed), 'Closed');
    expect(TripStatusVisuals.label(TripDisplayStatus.own), 'Own booking');
    expect(TripStatusVisuals.label(TripDisplayStatus.none), '');
  });

  test('owner side labels differ only where the guest acted', () {
    expect(TripStatusVisuals.label(TripDisplayStatus.cancelled, ownerSide: true), 'Guest cancelled');
    expect(TripStatusVisuals.label(TripDisplayStatus.declined, ownerSide: true), 'Guest declined');
    expect(TripStatusVisuals.label(TripDisplayStatus.notAvailable, ownerSide: true), 'Not available');
  });

  test('no label uses a trust word', () {
    for (final s in TripDisplayStatus.values) {
      for (final owner in [false, true]) {
        final l = TripStatusVisuals.label(s, ownerSide: owner).toLowerCase();
        expect(l.contains('verified'), isFalse);
        expect(l.contains('guaranteed'), isFalse);
        expect(l.contains('checked'), isFalse);
      }
    }
  });

  testWidgets('pill shows the label and stays 36 dp tall at 1.3 text scale on a narrow width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
          child: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 110, child: TripStatusPill(TripDisplayStatus.confirmedByBoth)),
            ),
          ),
        ),
      ),
    );
    expect(find.text(TripStrings.confirmedBothPill), findsOneWidget);
    expect(tester.getSize(find.byType(TripStatusPill)).height, greaterThanOrEqualTo(36));
    expect(tester.takeException(), isNull);
  });

  test('booking state parses wires and falls back to draft', () {
    expect(TripBookingState.parse('draft'), TripBookingState.draft);
    expect(TripBookingState.parse('confirming'), TripBookingState.confirming);
    expect(TripBookingState.parse('ready'), TripBookingState.ready);
    expect(TripBookingState.parse('completed'), TripBookingState.completed);
    expect(TripBookingState.parse(null), TripBookingState.draft);
    expect(TripBookingState.parse(''), TripBookingState.draft);
    expect(TripBookingState.parse('Ready'), TripBookingState.draft);
    expect(TripBookingState.parse('other'), TripBookingState.draft);
  });

  test('booking state visuals', () {
    expect(TripBookingStateVisuals.label(TripBookingState.draft), TripStrings.stateDraft);
    expect(TripBookingStateVisuals.label(TripBookingState.confirming), TripStrings.stateConfirming);
    expect(TripBookingStateVisuals.label(TripBookingState.ready), TripStrings.stateReady);
    expect(TripBookingStateVisuals.label(TripBookingState.completed), TripStrings.stateCompleted);
    expect(TripBookingStateVisuals.bar(TripBookingState.confirming), TripStatusColors.confirmedByYou);
    expect(TripBookingStateVisuals.bar(TripBookingState.ready), TripStatusColors.both);
    expect(TripBookingStateVisuals.bar(TripBookingState.draft), TripStatusColors.shortlisted);
    expect(TripBookingStateVisuals.bar(TripBookingState.completed), TripStatusColors.shortlisted);
    expect(TripBookingStateVisuals.surface(TripBookingState.confirming), TripStatusColors.confirmedByYouSurface);
    expect(TripBookingStateVisuals.surface(TripBookingState.ready), TripStatusColors.bothSurface);
    expect(TripBookingStateVisuals.surface(TripBookingState.draft), AppColors.neutralChip);
    expect(TripBookingStateVisuals.surface(TripBookingState.completed), AppColors.neutralChip);
    expect(TripBookingStateVisuals.text(TripBookingState.draft), AppColors.textMedium);
    expect(TripBookingStateVisuals.text(TripBookingState.confirming), AppColors.tripDark);
    expect(TripBookingStateVisuals.text(TripBookingState.ready), AppColors.successText);
    expect(TripBookingStateVisuals.text(TripBookingState.completed), AppColors.neutralChipText);
  });

  testWidgets('booking state pill keeps a 36 dp height and fits at 320 dp with text scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
          child: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 90, child: TripBookingStatePill(TripBookingState.confirming)),
            ),
          ),
        ),
      ),
    );
    expect(find.text(TripStrings.stateConfirming), findsOneWidget);
    expect(tester.getSize(find.byType(TripBookingStatePill)).height, greaterThanOrEqualTo(36));
    expect(tester.takeException(), isNull);
  });
}
