import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_strings.dart';
import '../../trip/widgets/trip_status.dart';
import 'stay_enquiries_controller.dart';
import 'stay_enquiry_actions.dart';
import 'stay_enquiry_button.dart';

class TripOwnerActionBar extends StatelessWidget {
  const TripOwnerActionBar({super.key, required this.enquiry, required this.onChanged});

  final TripEnquiryModel enquiry;
  final VoidCallback onChanged;

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
    final advanceRow = _advanceRowWithChange(context);
    return ChatActionBar3D(
      note: _revisedWaiting ? '${TripStrings.revisedOffer} · ${TripStrings.notAcceptedYet}' : null,
      rows: [..._pairs(buttons), if (advanceRow.isNotEmpty) ..._pairs(advanceRow)],
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

  bool get _changeWithAdvance {
    final adv = enquiry.advance;
    return enquiry.display == TripDisplayStatus.confirmedByBoth &&
        enquiry.pendingChange != null &&
        (adv.isPending || adv.isProofSent);
  }

  List<Widget> _advanceRowWithChange(BuildContext context) {
    if (!_changeWithAdvance) return const [];
    final ctrl = StayEnquiriesController.ensure();
    Widget button(String label, StayEnquiryButtonKind kind, Future<bool> Function() run) => Obx(() => ChatBarButton3D(
          tone: _tone,
          label: label,
          kind: _kind(kind),
          busy: ctrl.busyIds.contains(enquiry.id),
          onTap: () async {
            if (await run()) onChanged();
          },
        ));
    return [
      button(TripStrings.markAdvanceReceived, StayEnquiryButtonKind.positive, () => StayEnquiryActions.markReceived(context, enquiry)),
      button(TripStrings.notYet, StayEnquiryButtonKind.plain, () => StayEnquiryActions.notYet(context, enquiry)),
      _overflow(context, cancelOnly: true),
    ];
  }

  Widget _overflow(BuildContext context, {bool cancelOnly = false}) {
    final ctrl = StayEnquiriesController.ensure();
    Future<void> pick(String v) async {
      if (ctrl.busyIds.contains(enquiry.id)) return;
      final done = v == 'ask'
          ? await StayEnquiryActions.askAdvance(context, enquiry)
          : await StayEnquiryActions.cancel(context, enquiry);
      if (done) onChanged();
    }

    return ChatBarMenu3D(
      onTap: (rect) => showMenu3D(
        context,
        anchor: rect,
        items: [
          if (!cancelOnly) MenuItem3D(label: TripStrings.askAgain, onTap: () => pick('ask')),
          MenuItem3D(label: TripStrings.cancelBooking, danger: true, onTap: () => pick('cancel')),
        ],
      ),
    );
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
        final adv = enquiry.advance;
        final change = enquiry.pendingChange;
        final canRevise = enquiry.pendingRevised == null && _checkInOpen(enquiry);
        if (change != null) {
          return [
            button(TripStrings.acceptChange, StayEnquiryButtonKind.positive,
                () => StayEnquiryActions.acceptChange(context, enquiry, change.id)),
            button(TripStrings.sendDifferentOffer, StayEnquiryButtonKind.plain,
                () => StayEnquiryActions.revisedOffer(context, enquiry, changeRequest: change)),
            if (!_changeWithAdvance)
              button(TripStrings.cancelBooking, StayEnquiryButtonKind.negative, () => StayEnquiryActions.cancel(context, enquiry)),
          ];
        }
        if (!adv.hasRequest) {
          return [
            button(TripStrings.askForAdvance, StayEnquiryButtonKind.primary, () => StayEnquiryActions.askAdvance(context, enquiry)),
            if (canRevise)
              button(TripStrings.revisedOffer, StayEnquiryButtonKind.plain, () => StayEnquiryActions.revisedOffer(context, enquiry)),
            button(TripStrings.cancelBooking, StayEnquiryButtonKind.negative, () => StayEnquiryActions.cancel(context, enquiry)),
          ];
        }
        if (adv.isPending || adv.isProofSent) {
          return [
            button(TripStrings.markAdvanceReceived, StayEnquiryButtonKind.positive, () => StayEnquiryActions.markReceived(context, enquiry)),
            button(TripStrings.notYet, StayEnquiryButtonKind.plain, () => StayEnquiryActions.notYet(context, enquiry)),
            _overflow(context),
          ];
        }
        return [
          if (canRevise)
            button(TripStrings.revisedOffer, StayEnquiryButtonKind.plain, () => StayEnquiryActions.revisedOffer(context, enquiry)),
          button(TripStrings.cancelBooking, StayEnquiryButtonKind.negative, () => StayEnquiryActions.cancel(context, enquiry)),
        ];
      case TripDisplayStatus.holdExpired:
        if (!_checkInOpen(enquiry)) return const [];
        return [
          button(TripStrings.markAdvanceReceived, StayEnquiryButtonKind.positive, () => StayEnquiryActions.markReceived(context, enquiry)),
          if ((enquiry.traveller.phone ?? '').isNotEmpty)
            ChatBarButton3D(tone: _tone, label: TripStrings.callGuest, onTap: () => StayEnquiryActions.callGuest(enquiry)),
        ];
      default:
        return const [];
    }
  }
}
