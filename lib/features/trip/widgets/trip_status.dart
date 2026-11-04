import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../utils/trip_format.dart';

enum TripDisplayStatus {
  none,
  shortlisted,
  asked,
  offered,
  confirmedByYou,
  confirmedByBoth,
  notAvailable,
  expired,
  declined,
  cancelled,
  notMe,
  closed,
  fareSent,
  bookedByYou,
  holdExpired,
  own;

  static TripDisplayStatus parse(String? wire) {
    if (wire == null) return none;
    for (final s in values) {
      if (s.name == wire) return s;
    }
    return none;
  }

  bool get isRed => this == notAvailable || this == expired || this == declined || this == cancelled || this == notMe || this == holdExpired;
  bool get isGreen => this == confirmedByBoth;
  bool get isOpen => this == asked || this == offered || this == fareSent;
  bool get isBookedByYou => this == bookedByYou;
  bool get isConfirmed => this == confirmedByYou || this == confirmedByBoth;
}

class TripStatusVisuals {
  static Color bar(TripDisplayStatus s) => switch (s) {
        TripDisplayStatus.asked || TripDisplayStatus.offered || TripDisplayStatus.fareSent => TripStatusColors.waiting,
        TripDisplayStatus.confirmedByYou => TripStatusColors.confirmedByYou,
        TripDisplayStatus.confirmedByBoth => TripStatusColors.both,
        TripDisplayStatus.own || TripDisplayStatus.bookedByYou => TripStatusColors.booked,
        _ when s.isRed => TripStatusColors.failed,
        _ => TripStatusColors.shortlisted,
      };

  static Color surface(TripDisplayStatus s) => switch (s) {
        TripDisplayStatus.asked || TripDisplayStatus.offered || TripDisplayStatus.fareSent => TripStatusColors.waitingSurface,
        TripDisplayStatus.confirmedByYou => TripStatusColors.confirmedByYouSurface,
        TripDisplayStatus.confirmedByBoth => TripStatusColors.bothSurface,
        TripDisplayStatus.own || TripDisplayStatus.bookedByYou => TripStatusColors.bookedSurface,
        TripDisplayStatus.closed => AppColors.neutralChip,
        _ when s.isRed => TripStatusColors.failedSurface,
        _ => AppColors.cardBg,
      };

  static Color text(TripDisplayStatus s) => switch (s) {
        TripDisplayStatus.asked || TripDisplayStatus.offered || TripDisplayStatus.fareSent => AppColors.warningText,
        TripDisplayStatus.confirmedByYou => AppColors.tripDark,
        TripDisplayStatus.confirmedByBoth => AppColors.successText,
        TripDisplayStatus.own || TripDisplayStatus.bookedByYou => AppColors.tripBooked,
        TripDisplayStatus.closed => AppColors.neutralChipText,
        _ when s.isRed => AppColors.errorText,
        _ => AppColors.textMedium,
      };

  static String label(TripDisplayStatus s, {bool ownerSide = false, bool taxi = false}) => switch (s) {
        TripDisplayStatus.none => '',
        TripDisplayStatus.shortlisted => TripStrings.shortlisted,
        TripDisplayStatus.asked => ownerSide ? TripStrings.newPill : TripStrings.askedWaitingShort,
        TripDisplayStatus.offered => ownerSide ? TripStrings.offerSent : TripStrings.offerReceived,
        TripDisplayStatus.confirmedByYou => ownerSide ? TripStrings.byGuest : TripStrings.confirmedByYou,
        TripDisplayStatus.confirmedByBoth => TripStrings.confirmedBothPill,
        TripDisplayStatus.notAvailable => TripStrings.notAvailable,
        TripDisplayStatus.expired => TripStrings.noReplyInTime,
        TripDisplayStatus.declined => ownerSide ? TripStrings.guestDeclined : TripStrings.youDeclined,
        TripDisplayStatus.cancelled => ownerSide ? TripStrings.guestCancelled : TripStrings.youCancelled,
        TripDisplayStatus.notMe => taxi ? TripStrings.driverSaysNotMe : TripStrings.hostSaysNotMe,
        TripDisplayStatus.closed => TripStrings.closed,
        TripDisplayStatus.fareSent => TripStrings.replied,
        TripDisplayStatus.bookedByYou => ownerSide ? TripStrings.byTraveller : TripStrings.bookedByYou,
        TripDisplayStatus.holdExpired => TripStrings.holdExpired,
        TripDisplayStatus.own => TripStrings.ownBooking,
      };

  static Color advanceBar(String advanceStatus) => switch (advanceStatus) {
        'Pending' || 'ProofSent' => TripStatusColors.waiting,
        'Received' => TripStatusColors.advance,
        'HoldExpired' => TripStatusColors.failed,
        _ => TripStatusColors.both,
      };

  static Color advanceSurface(String advanceStatus) => switch (advanceStatus) {
        'Pending' || 'ProofSent' => TripStatusColors.waitingSurface,
        'Received' => TripStatusColors.advanceSurface,
        'HoldExpired' => TripStatusColors.failedSurface,
        _ => TripStatusColors.bothSurface,
      };

  static Color advanceText(String advanceStatus) => switch (advanceStatus) {
        'Pending' || 'ProofSent' => AppColors.warningText,
        'Received' => AppColors.tripAdvance,
        'HoldExpired' => AppColors.errorText,
        _ => AppColors.successText,
      };

  static String advanceLabel(TripAdvanceModel a) {
    final hold = a.holdUntil;
    return switch (a.status) {
      'Pending' => hold == null ? '' : TripStrings.advancePendingTill(TripFormat.time12Of(hold)),
      'ProofSent' => TripStrings.waitingForHostHourly,
      'Received' => TripStrings.advanceReceivedHostSays,
      'HoldExpired' => TripStrings.holdExpired,
      _ => '',
    };
  }
}

class TripStatusPill extends StatelessWidget {
  const TripStatusPill(this.status, {super.key, this.ownerSide = false, this.label, this.taxi = false});

  final TripDisplayStatus status;
  final bool ownerSide;
  final String? label;
  final bool taxi;

  @override
  Widget build(BuildContext context) {
    final text = label ?? TripStatusVisuals.label(status, ownerSide: ownerSide, taxi: taxi);
    if (text.isEmpty) return const SizedBox.shrink();
    final color = TripStatusVisuals.text(status);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TripStatusVisuals.surface(status),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: TripStatusVisuals.bar(status).withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Center(
            widthFactor: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                maxLines: 1,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum TripBookingState {
  draft,
  planOnly,
  confirming,
  ready,
  completed;

  static TripBookingState parse(String? wire) {
    if (wire == null) return draft;
    for (final s in values) {
      if (s.name == wire) return s;
    }
    return draft;
  }
}

class TripBookingStateVisuals {
  static Color bar(TripBookingState s) => switch (s) {
        TripBookingState.confirming => TripStatusColors.confirmedByYou,
        TripBookingState.ready => TripStatusColors.both,
        _ => TripStatusColors.shortlisted,
      };

  static Color surface(TripBookingState s) => switch (s) {
        TripBookingState.confirming => TripStatusColors.confirmedByYouSurface,
        TripBookingState.ready => TripStatusColors.bothSurface,
        _ => AppColors.neutralChip,
      };

  static Color text(TripBookingState s) => switch (s) {
        TripBookingState.draft || TripBookingState.planOnly => AppColors.textMedium,
        TripBookingState.confirming => AppColors.tripDark,
        TripBookingState.ready => AppColors.successText,
        TripBookingState.completed => AppColors.neutralChipText,
      };

  static String label(TripBookingState s) => switch (s) {
        TripBookingState.draft => TripStrings.stateDraft,
        TripBookingState.planOnly => TripStrings.planOnly,
        TripBookingState.confirming => TripStrings.stateConfirming,
        TripBookingState.ready => TripStrings.stateReady,
        TripBookingState.completed => TripStrings.stateCompleted,
      };
}

class TripBookingStatePill extends StatelessWidget {
  const TripBookingStatePill(this.state, {super.key});

  final TripBookingState state;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TripBookingStateVisuals.surface(state),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: TripBookingStateVisuals.bar(state).withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Center(
            widthFactor: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                TripBookingStateVisuals.label(state),
                maxLines: 1,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TripBookingStateVisuals.text(state)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
