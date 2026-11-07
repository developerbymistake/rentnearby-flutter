import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final buttons = _buttons(context);
    if (buttons.isEmpty) return const SizedBox.shrink();
    final advanceRow = _advanceRowWithChange(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (_revisedWaiting)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('${TripStrings.revisedOffer} · ${TripStrings.notAcceptedYet}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText)),
          ),
        Wrap(spacing: 8, runSpacing: 8, children: buttons),
        if (advanceRow.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: advanceRow),
        ],
      ]),
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
    Widget button(String label, StayEnquiryButtonKind kind, Future<bool> Function() run) => Obx(() => StayEnquiryButton(
          label: label,
          kind: kind,
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
    return SizedBox(
      width: 44,
      height: 44,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        tooltip: '',
        icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMedium),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (v) async {
          if (ctrl.busyIds.contains(enquiry.id)) return;
          final done = v == 'ask'
              ? await StayEnquiryActions.askAdvance(context, enquiry)
              : await StayEnquiryActions.cancel(context, enquiry);
          if (done) onChanged();
        },
        itemBuilder: (_) => [
          if (!cancelOnly)
            const PopupMenuItem<String>(
                value: 'ask', height: 44, child: Text(TripStrings.askAgain, style: TextStyle(fontSize: 13))),
          const PopupMenuItem<String>(
              value: 'cancel',
              height: 44,
              child: Text(TripStrings.cancelBooking, style: TextStyle(fontSize: 13, color: AppColors.error))),
        ],
      ),
    );
  }

  List<Widget> _buttons(BuildContext context) {
    final ctrl = StayEnquiriesController.ensure();
    Widget button(String label, StayEnquiryButtonKind kind, Future<bool> Function() run) {
      return Obx(() => StayEnquiryButton(
            label: label,
            kind: kind,
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
            StayEnquiryButton(label: TripStrings.callGuest, onTap: () => StayEnquiryActions.callGuest(enquiry)),
        ];
      default:
        return const [];
    }
  }
}
