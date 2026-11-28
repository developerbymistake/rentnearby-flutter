import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_strings.dart';
import '../trip_strings_enquiry_simple.dart';
import 'trip_sheet_frame.dart';
import 'trip_step_full_sheet.dart';
import 'trip_undo_snack.dart';

class TripTwoButtons extends StatelessWidget {
  const TripTwoButtons({
    super.key,
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.onSecondary,
    required this.onPrimary,
    this.danger = true,
    this.busy = false,
    this.tone,
  });

  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onPrimary;
  final bool danger;
  final bool busy;
  final ListingTone? tone;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ListingTone.indigo;
    return PillButtonRow(
      children: [
        WhitePillButton(tone: t, label: secondaryLabel, onTap: busy ? null : onSecondary),
        GradientPillButton(tone: t, label: primaryLabel, danger: danger, loading: busy, onTap: busy ? null : onPrimary),
      ],
    );
  }
}

class TripWithdrawSheet {
  static Future<TripEnquiryModel?> show(BuildContext context, {required TripEnquiryModel enquiry}) async {
    final row = await TripSheetFrame.show<Object>(
      context,
      _WithdrawBody(enquiries: [enquiry], title: TripStrings.withdrawQuestion, keepLabel: TripStrings.keep, undo: true),
    );
    return row is TripEnquiryModel ? row : null;
  }

  static const int _undoMaxMs = 10000;

  static void showUndo(BuildContext context, TripEnquiryModel row, {VoidCallback? onGone}) {
    final until = row.undoUntil;
    final m = ScaffoldMessenger.maybeOf(context);
    final host = Navigator.of(context, rootNavigator: true).context;
    final left = until?.difference(DateTime.now());
    if (left == null || m == null || left <= Duration.zero) {
      onGone?.call();
      return;
    }
    final handle = TripUndoSnack.show(
      m,
      TripStringsEnq.withdrawnUndo(row.listingName.isEmpty ? TripStrings.stay : row.listingName),
      actionLabel: TripStringsEnq.undo,
      duration: Duration(milliseconds: left.inMilliseconds.clamp(1000, _undoMaxMs)),
      onUndo: () async {
        final ctrl = TripEnquiryController.to;
        if (await ctrl.undoWithdraw(row.id)) return;
        final full = ctrl.lastStepFull;
        if (full != null && host.mounted) await TripStepFullSheet.show(host, full);
      },
    );
    if (handle == null) {
      onGone?.call();
      return;
    }
    handle.closed.then((r) {
      if (r != SnackBarClosedReason.action) onGone?.call();
    });
  }

  static Future<bool> confirmInline(BuildContext context) async {
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.indigo,
        art: ListingArt.clipboard,
        title: TripStrings.withdrawToo,
        body: TripStrings.hostSeesWithdraw,
        secondaryLabel: TripStrings.keepAsking,
        onSecondary: () => Navigator.pop(ctx, false),
        primaryLabel: TripStrings.withdraw,
        primaryDanger: true,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    return ok == true;
  }

  static Future<bool> showForRemove(BuildContext context, {required List<TripEnquiryModel> open}) async {
    if (open.isEmpty) return true;
    final ok = await TripSheetFrame.show<bool>(
      context,
      _WithdrawBody(enquiries: open, title: TripStrings.withdrawToo, keepLabel: TripStrings.keepAsking),
    );
    return ok == true;
  }
}

class _WithdrawBody extends StatefulWidget {
  const _WithdrawBody({required this.enquiries, required this.title, required this.keepLabel, this.undo = false});

  final List<TripEnquiryModel> enquiries;
  final String title;
  final String keepLabel;
  final bool undo;

  @override
  State<_WithdrawBody> createState() => _WithdrawBodyState();
}

class _WithdrawBodyState extends State<_WithdrawBody> {
  bool _busy = false;

  Future<void> _withdraw() async {
    if (_busy) return;
    setState(() => _busy = true);
    if (widget.undo && widget.enquiries.length == 1) {
      final row = await TripEnquiryController.to.withdrawWithUndo(widget.enquiries.first.id);
      if (!mounted) return;
      setState(() => _busy = false);
      if (row != null) Navigator.pop(context, row);
      return;
    }
    var all = true;
    for (final e in widget.enquiries) {
      if (!await TripEnquiryController.to.withdraw(e.id)) all = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (all) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final named = widget.enquiries.where((e) => e.listingName.isNotEmpty).toList();
    final taxi = widget.enquiries.isNotEmpty && widget.enquiries.every((e) => e.isTaxi);
    final tone = taxi ? ListingTone.coral : ListingTone.forest;
    return TripSheetFrame(
      tone: tone,
      art: ListingArt.clipboard,
      size: SheetSize.short,
      title: widget.title,
      description: TripStrings.hostSeesWithdraw,
      footer: TripTwoButtons(
        tone: tone,
        secondaryLabel: widget.keepLabel,
        primaryLabel: TripStrings.withdraw,
        busy: _busy,
        onSecondary: () => Navigator.pop(context, false),
        onPrimary: _withdraw,
      ),
      children: [
        if (named.isNotEmpty)
          NameChips3D(tone: tone, items: [for (final e in named) (e.isTaxi ? ListingArt.taxi : ListingArt.stay, e.listingName)]),
        Gap.v(16),
      ],
    );
  }
}
