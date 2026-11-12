import 'trip_ui.dart';
import 'package:bakhli/design/template/fitness_app_theme.dart';
import 'package:flutter/material.dart';
import '../../../models/browse_item.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_strings.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
import 'trip_status.dart';

class TripStripAction {
  static const withdraw = 'withdraw';
  static const cancel = 'cancel';
  static const report = 'report';
  static const callHost = 'callHost';
  static const counter = 'counter';
  static const changeRequest = 'changeRequest';

  final String id;
  final String label;
  final bool destructive;
  final bool enabled;

  const TripStripAction(this.id, this.label, {this.destructive = false, this.enabled = true});

  static List<TripStripAction> forTraveller(TripEnquiryModel e, ) {
    const reportAction = TripStripAction(report, TripStrings.report);
    switch (e.display) {
      case TripDisplayStatus.asked:
      case TripDisplayStatus.offered:
        return [
          if (e.canCounter) const TripStripAction(counter, TripStrings.proposePrice),
          const TripStripAction(withdraw, TripStrings.withdraw),
          reportAction,
        ];
      case TripDisplayStatus.confirmedByBoth:
        return [
          if (e.advance.isPending || e.advance.isProofSent) const TripStripAction(callHost, TripStrings.callHost),
          if (e.canChangeRequest) const TripStripAction(changeRequest, TripStrings.changeRequest),
          const TripStripAction(cancel, TripStrings.cancelBooking, destructive: true),
          reportAction,
        ];
      default:
        return [reportAction];
    }
  }
}

class TripEnquiryStrip extends StatelessWidget {
  const TripEnquiryStrip({
    super.key,
    required this.enquiry,
    required this.onTap,
    this.ownerSide = false,
    this.actions = const [],
    this.onAction,
  });

  final TripEnquiryModel enquiry;
  final VoidCallback onTap;
  final bool ownerSide;
  final List<TripStripAction> actions;
  final ValueChanged<String>? onAction;

  String _title() {
    final parts = <String>[TripStrings.tripEnquiry];
    final city = enquiry.context.city;
    if (city.isNotEmpty) parts.add(city);
    final cin = enquiry.checkIn;
    if (cin != null) parts.add(TripFormat.shortDate(cin));
    return parts.join(' · ');
  }

  String _detail() {
    final c = enquiry.context;
    final parts = <String>[];
    final people = c.peopleLabel;
    if (people != null) parts.add(people);
    final rooms = c.roomsLabel;
    if (rooms != null) parts.add(rooms);
    final when = TripEnquiryRules.checkInLabel(enquiry.checkIn, DateTime.now().toUtc());
    if (when != null) parts.add(when);
    if (enquiry.isUrgent) parts.add(TripStrings.urgent);
    return parts.join(' · ');
  }

  String _statusLine() {
    final status = enquiry.display;
    final agreed = enquiry.agreedTotalLocked;
    if (status == TripDisplayStatus.confirmedByBoth && !enquiry.advance.hasRequest && agreed != null) {
      return '${TripStrings.stayConfirmed} · ${BrowseItem.inr(agreed)}';
    }
    return TripStatusVisuals.label(status, ownerSide: ownerSide);
  }

  (String, Color)? _advanceLine() {
    final a = enquiry.advance;
    final status = enquiry.display;
    if (!a.hasRequest) return null;
    final money = BrowseItem.inr(a.amount ?? 0);
    final color = TripStatusVisuals.advanceText(a.status);
    if (status == TripDisplayStatus.holdExpired) return (TripStrings.holdExpired, color);
    if (status != TripDisplayStatus.confirmedByBoth) return null;
    final hold = a.holdUntil;
    return switch (a.status) {
      'Pending' => (
        hold == null
            ? TripStrings.advancePending(money)
            : '${TripStrings.advancePending(money)} · ${TripStrings.holdTill(TripFormat.time12Of(hold))}',
        color
      ),
      'ProofSent' => (TripStrings.waitingForHostBar(money), color),
      'Received' => (TripStrings.advanceReceivedBar(money), color),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = enquiry.display;
    final advance = _advanceLine();
    final menu = actions.isNotEmpty && onAction != null;
    return Material(
      color: FitnessAppTheme.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: FitnessAppTheme.spacer))),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: advance != null && status == TripDisplayStatus.confirmedByBoth ? TripStatusVisuals.advanceBar(enquiry.advance.status) : TripStatusVisuals.bar(status)),
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(_title(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w600, color: FitnessAppTheme.darkerText)),
                          Text(_detail(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11.5, color: FitnessAppTheme.darkText)),
                          Text.rich(
                              TextSpan(text: _statusLine(), children: [
                                if (status == TripDisplayStatus.confirmedByBoth && enquiry.hasPendingRevised)
                                  TextSpan(
                                    text: ' · ${TripStrings.notAcceptedYet}',
                                    style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontWeight: FontWeight.w500, color: FitnessAppTheme.lightText),
                                  ),
                              ]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: FitnessAppTheme.fontName,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: TripStatusVisuals.text(status))),
                          if (advance != null)
                            Text(advance.$1,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w600, color: advance.$2)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 20, color: FitnessAppTheme.deactivatedText),
                    ]),
                  ),
                ),
              ),
            ),
            if (menu)
              SizedBox(
                width: 44,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  tooltip: '',
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: FitnessAppTheme.darkText),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    for (final a in actions)
                      PopupMenuItem<String>(
                        value: a.id,
                        enabled: a.enabled,
                        height: 44,
                        child: Text(a.label,
                            style: TextStyle(
                                fontFamily: FitnessAppTheme.fontName,
                                fontSize: 13,
                                color: a.destructive ? TripUi.bad : FitnessAppTheme.darkerText)),
                      ),
                  ],
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
