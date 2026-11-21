import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_strings.dart';
import '../../trip/widgets/trip_status.dart';
import '../stay_share_strings.dart';
import 'stay_enquiries_controller.dart';
import 'stay_enquiry_actions.dart';
import 'stay_enquiry_button.dart';

class TripOwnerActionBar extends StatelessWidget {
  const TripOwnerActionBar({super.key, required this.enquiry, required this.onChanged, this.onShare});

  final TripEnquiryModel enquiry;
  final VoidCallback onChanged;
  final VoidCallback? onShare;

  static final ListingTone _tone = ListingTone.forest;

  static ChatBarKind _kind(StayEnquiryButtonKind k) => switch (k) {
        StayEnquiryButtonKind.primary || StayEnquiryButtonKind.positive => ChatBarKind.primary,
        StayEnquiryButtonKind.negative => ChatBarKind.negative,
        StayEnquiryButtonKind.plain => ChatBarKind.plain,
      };

  static List<List<Widget>> _pairs(List<Widget> items) {
    final cells = items.where((w) => w is! ChatBarMenu3D).toList();
    final menu = items.whereType<ChatBarMenu3D>().toList();
    final rows = <List<Widget>>[];
    for (var i = 0; i < cells.length; i += 2) {
      rows.add(cells.sublist(i, i + 2 > cells.length ? cells.length : i + 2));
    }
    if (menu.isNotEmpty) {
      if (rows.isEmpty) rows.add([]);
      rows.last.add(menu.first);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final buttons = _buttons(context);
    if (buttons.isEmpty) return const SizedBox.shrink();
    return ChatActionBar3D(
      note: _revisedWaiting ? '${TripStrings.revisedOffer} · ${TripStrings.notAcceptedYet}' : null,
      rows: _pairs(buttons),
    );
  }

  bool get _revisedWaiting =>
      enquiry.display == TripDisplayStatus.confirmedByBoth && enquiry.pendingRevised != null && enquiry.pendingChange == null;

  static bool _checkInOpen(TripEnquiryModel e) {
    final cin = e.checkIn;
    if (cin == null) return false;
    final now = DateTime.now();
    return !DateTime(cin.year, cin.month, cin.day).isBefore(DateTime(now.year, now.month, now.day));
  }

  List<Widget> _buttons(BuildContext context) {
    final ctrl = StayEnquiriesController.ensure();
    Widget button(String label, StayEnquiryButtonKind kind, Future<bool> Function() run) {
      return Obx(() => ChatBarButton3D(
            tone: _tone,
            label: label,
            kind: _kind(kind),
            busy: ctrl.busyIds.contains(enquiry.id),
            onTap: () async {
              if (await run()) onChanged();
            },
          ));
    }

    switch (enquiry.display) {
      case TripDisplayStatus.asked:
      case TripDisplayStatus.offered:
        final counter = enquiry.pendingCounter;
        if (counter != null) {
          return [
            button(TripStrings.acceptPrice, StayEnquiryButtonKind.positive,
                () => StayEnquiryActions.sendOffer(context, enquiry, counter: counter)),
            button(TripStrings.sendDifferentOffer, StayEnquiryButtonKind.plain, () => StayEnquiryActions.sendOffer(context, enquiry)),
            button(TripStrings.notAvailableAction, StayEnquiryButtonKind.negative, () => StayEnquiryActions.notAvailable(context, enquiry)),
          ];
        }
        final label = enquiry.display == TripDisplayStatus.asked ? TripStrings.sendOffer : TripStrings.sendNewOffer;
        return [
          button(label, StayEnquiryButtonKind.primary, () => StayEnquiryActions.sendOffer(context, enquiry)),
          button(TripStrings.notAvailableAction, StayEnquiryButtonKind.negative, () => StayEnquiryActions.notAvailable(context, enquiry)),
        ];
      case TripDisplayStatus.confirmedByBoth:
        final change = enquiry.pendingChange;
        final canRevise = enquiry.pendingRevised == null && _checkInOpen(enquiry);
        if (change != null) {
          return [
            button(TripStrings.acceptChange, StayEnquiryButtonKind.positive,
                () => StayEnquiryActions.acceptChange(context, enquiry, change.id)),
            button(TripStrings.sendDifferentOffer, StayEnquiryButtonKind.plain,
                () => StayEnquiryActions.revisedOffer(context, enquiry, changeRequest: change)),
            button(TripStrings.cancelBooking, StayEnquiryButtonKind.negative, () => StayEnquiryActions.cancel(context, enquiry)),
          ];
        }
        return [
          if (onShare != null)
            ChatBarButton3D(tone: _tone, label: StayShareStrings.shareAction, kind: ChatBarKind.primary, onTap: onShare),
          if (canRevise)
            button(TripStrings.revisedOffer, StayEnquiryButtonKind.plain, () => StayEnquiryActions.revisedOffer(context, enquiry)),
          button(TripStrings.cancelBooking, StayEnquiryButtonKind.negative, () => StayEnquiryActions.cancel(context, enquiry)),
        ];
      default:
        return const [];
    }
  }
}
