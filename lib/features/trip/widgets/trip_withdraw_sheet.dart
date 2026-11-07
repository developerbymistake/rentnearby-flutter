import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
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
    this.primaryColor = AppColors.error,
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
    final secondary = OutlinedButton(
      onPressed: busy ? null : onSecondary,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(secondaryLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins', color: AppColors.textMedium)),
    );
    final primary = ElevatedButton(
      onPressed: busy ? null : onPrimary,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: primaryColor.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: busy
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(primaryLabel,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Poppins')),
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
        content: const Text(TripStrings.withdrawToo, style: TextStyle(fontFamily: 'Poppins', fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(TripStrings.keepAsking)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(TripStrings.withdraw)),
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
        if (names.isNotEmpty) ...[
          Text(names,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
    );
  }
}
