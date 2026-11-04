import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/app_insets.dart';
import '../../../../models/browse_item.dart';
import '../../taxi_option_sets.dart';
import '../taxi_ways_strings.dart';

class JourneyAskButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const JourneyAskButton({super.key, required this.label, required this.onPressed, this.busy = false});

  static String labelFor(int drivers, {bool these = false}) {
    if (drivers <= 1) return TaxiWaysStrings.askOne;
    if (these) return TaxiWaysStrings.askThese(drivers);
    return drivers == 2 ? TaxiWaysStrings.askBoth : TaxiWaysStrings.askAll(drivers);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: busy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: TaxiColors.accentDark,
        foregroundColor: Colors.white,
        disabledBackgroundColor: TaxiColors.accent.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
          : Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700),
            ),
    );
  }
}

class JourneyTotalBar extends StatelessWidget {
  final int total;
  final String askLabel;
  final VoidCallback? onAsk;
  final VoidCallback? onSave;
  final bool busy;

  const JourneyTotalBar({
    super.key,
    required this.total,
    required this.askLabel,
    required this.onAsk,
    this.onSave,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 10 + AppInsets.bottomViewPadding(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: AppColors.textDark.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: Text(
              TaxiWaysStrings.listedFares,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            BrowseItem.inr(total),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          if (onSave != null) ...[
            SizedBox(
              width: 48,
              height: 48,
              child: Tooltip(
                message: TaxiWaysStrings.saveJourney,
                child: OutlinedButton(
                  onPressed: busy ? null : onSave,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: TaxiColors.accentDark,
                    side: BorderSide(color: TaxiColors.accent.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Icon(Iconsax.bookmark, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: JourneyAskButton(label: askLabel, onPressed: onAsk, busy: busy)),
        ]),
        const SizedBox(height: 8),
        const Text(
          TaxiWaysStrings.payLine,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
        ),
      ]),
    );
  }
}
