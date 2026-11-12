import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_strings.dart';
import 'trip_sheet_frame.dart';

class TripTwoButtons extends StatelessWidget {
  const TripTwoButtons({
    super.key,
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.onSecondary,
    required this.onPrimary,
    this.primaryColor = RepliesTone.bad,
    this.busy = false,
  });

  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onPrimary;
  final Color primaryColor;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final secondary = TripActionChip(
      height: 48,
      fontSize: 14,
      color: DesignColors.textSecondary,
      label: secondaryLabel,
      onTap: busy ? null : onSecondary,
    );
    final primary = TripButton(
      color: primaryColor,
      label: primaryLabel,
      loading: busy,
      onPressed: busy ? null : onPrimary,
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 340) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, const SizedBox(height: 8), secondary],
        );
      }
      return Row(
        children: [
          Expanded(child: secondary),
          const SizedBox(width: 10),
          Expanded(child: primary),
        ],
      );
    });
  }
}

class TripWithdrawSheet {
  static Future<bool> show(BuildContext context, {required TripEnquiryModel enquiry}) async {
    final ok = await TripSheetFrame.show<bool>(
      context,
      _WithdrawBody(enquiries: [enquiry], title: TripStrings.withdrawQuestion, keepLabel: TripStrings.keep),
    );
    return ok == true;
  }

  static Future<bool> confirmInline(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: RepliesCard.radius),
        backgroundColor: DesignColors.surface,
        content: const Text(TripStrings.withdrawToo, style: FitnessAppTheme.body2),
        actions: [
          TextLink(label: TripStrings.keepAsking, onTap: () => Navigator.pop(ctx, false), tone: KitTone.trip),
          TextLink(label: TripStrings.withdraw, onTap: () => Navigator.pop(ctx, true), tone: KitTone.trip),
        ],
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
  const _WithdrawBody({required this.enquiries, required this.title, required this.keepLabel});

  final List<TripEnquiryModel> enquiries;
  final String title;
  final String keepLabel;

  @override
  State<_WithdrawBody> createState() => _WithdrawBodyState();
}

class _WithdrawBodyState extends State<_WithdrawBody> {
  bool _busy = false;

  Future<void> _withdraw() async {
    if (_busy) return;
    setState(() => _busy = true);
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
    final names = widget.enquiries.map((e) => e.listingName).where((n) => n.isNotEmpty).join(', ');
    return TripSheetFrame(
      title: widget.title,
      description: TripStrings.hostSeesWithdraw,
      children: [
        TemplateStagger(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        if (names.isNotEmpty) ...[
          Text(names,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w600, color: DesignColors.textStrong)),
          const SizedBox(height: 16),
        ],
        TripTwoButtons(
          secondaryLabel: widget.keepLabel,
          primaryLabel: TripStrings.withdraw,
          busy: _busy,
          onSecondary: () => Navigator.pop(context, false),
          onPrimary: _withdraw,
        ),
          ],
        ),
      ],
    );
  }
}
