import '../../../taxi_driver/strings/taxi_work_strings.dart';
import 'driver_request_models.dart';

enum RingEndKind { missed, ended, pausedOnFree, requestsPaused }

class RingEnd {
  const RingEnd(this.kind, this.title, this.sub);

  final RingEndKind kind;
  final String title;
  final String sub;

  static const missed = RingEnd(RingEndKind.missed, TaxiWorkStrings.missed, TaxiWorkStrings.missedLine);
  static const paused = RingEnd(RingEndKind.requestsPaused, TaxiWorkStrings.requestsPausedTitle, TaxiWorkStrings.requestsPausedSub);
  static const closed = RingEnd(RingEndKind.ended, TaxiWorkStrings.endClosed, TaxiWorkStrings.notAMiss);

  static RingEnd _line(String title) => RingEnd(RingEndKind.ended, title, TaxiWorkStrings.notAMiss);

  /// Ring-end push reason (server `RingEndBody`); unknown = "This request is closed".
  static RingEnd forReason(String? reason, {required bool paymentOn}) => switch (reason) {
        'Filled' || 'Booked' => _line(TaxiWorkStrings.endTaken),
        'RequestCancelled' => _line(TaxiWorkStrings.endTravellerCancelled),
        'DriverOffline' => _line(TaxiWorkStrings.endOffline),
        'RouteRemoved' => _line(TaxiWorkStrings.endRouteRemoved),
        'RoutePausedByPlan' => paymentOn
            ? const RingEnd(RingEndKind.pausedOnFree, TaxiWorkStrings.endPausedOnFree, TaxiWorkStrings.pausedOnFreeSub)
            : closed,
        'Accepted' => _line(TaxiWorkStrings.endAccepted),
        'Declined' => _line(TaxiWorkStrings.endDeclined),
        'Expired' => missed,
        _ => closed,
      };

  /// The end state of an offer read from the server; null while it still rings or was answered (the detail opens).
  static RingEnd? forOffer(DriverOffer o, {required bool paymentOn}) {
    switch (o.state) {
      case OfferState.ringing || OfferState.accepted || OfferState.selected || OfferState.confirmed:
        return null;
      case OfferState.missed:
        return missed;
      case OfferState.declined:
        return _line(TaxiWorkStrings.endDeclined);
      default:
        final r = o.endReasonText;
        if (r == null || r.isEmpty) return closed;
        return forReason(r, paymentOn: paymentOn);
    }
  }
}
