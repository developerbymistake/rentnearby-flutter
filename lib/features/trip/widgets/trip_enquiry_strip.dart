import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
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
    if (cin != null) parts.add(TripFormat.dayMonth(cin));
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
    if (status == TripDisplayStatus.confirmedByBoth && agreed != null) {
      return '${TripStrings.stayConfirmed} · ${BrowseItem.inr(agreed)}';
    }
    return TripStatusVisuals.label(status, ownerSide: ownerSide);
  }

  @override
  Widget build(BuildContext context) {
    final status = enquiry.display;
    final menu = actions.isNotEmpty && onAction != null;
    final revisedNote = status == TripDisplayStatus.confirmedByBoth && enquiry.hasPendingRevised;
    return ChatStripCard3D(
      barColor: TripStatusVisuals.bar(status),
      title: _title(),
      detail: _detail(),
      onTap: onTap,
      pill: StatusPill3D(
        label: revisedNote ? '${_statusLine()} · ${TripStrings.notAcceptedYet}' : _statusLine(),
        status: StatusTone3D.of(status.name),
        color: status == TripDisplayStatus.asked ? ChatLook3D.askedPill : null,
        onGradient: false,
      ),
      onMenu: menu
          ? (rect) => showMenu3D(
                context,
                anchor: rect,
                items: [
                  for (final a in actions)
                    MenuItem3D(label: a.label, danger: a.destructive, onTap: a.enabled ? () => onAction!(a.id) : null),
                ],
              )
          : null,
    );
  }
}
