import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../controllers/wallet_controller.dart';
import '../models/plan_selection_result.dart';
import '../utils/app_toast.dart';
import 'coin_icon.dart';

/// The one shared Go-Live plan picker — used identically by Room and Plot
/// (`my_listings_screen.dart`/`my_plots_screen.dart`), parameterized by the
/// unit noun and per-plan unit-limit field name, never duplicated per
/// listing kind. A real `showModalBottomSheet` sliding up over a dimmed
/// scrim — not a centered `Dialog` — with the Confirm-Spend step folded into
/// the same sheet rather than a second floating dialog stacked on top.
class GoLivePlanSheet {
  GoLivePlanSheet._();

  static Future<PlanSelectionResult?> show(
    BuildContext context, {
    required Iterable<Map<String, dynamic>> plans,
    required String unitLimitKey, // 'roomLimit' | 'plotLimit'
    required String unitSingular, // 'room' | 'plot'
    required String unitPlural, // 'rooms' | 'plots'
    required Color accentColor,
  }) {
    final visiblePlans = [...plans]
      ..sort((a, b) => (a['originalPrice'] as num? ?? 0).compareTo(b['originalPrice'] as num? ?? 0));

    if (visiblePlans.isEmpty) {
      AppToast.error('No plans available right now. Please try again later.');
      return Future.value(null);
    }

    // Affordability is computed client-side against the live wallet balance
    // (read once — a fresh sheet is opened whenever the balance can have
    // changed, e.g. after a coin top-up) so each row can render its own
    // Select-vs-Add-Coins state instead of only discovering a shortfall
    // reactively from a 409 INSUFFICIENT_BALANCE after the network call.
    final walletBalance = Get.find<WalletController>().balance.value;
    String? selectedType = visiblePlans
        .firstWhere(
          (p) => walletBalance >= ((p['originalPrice'] as num?)?.toInt() ?? 0),
          orElse: () => const {},
        )['planType'] as String?;
    // Scoped to this one show() call via closure — never a module-level/static
    // field, which would leak state between separate sheet invocations (Room
    // vs Plot, or two opens in a row).
    bool confirming = false;

    return showModalBottomSheet<PlanSelectionResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final selectedPlan = selectedType == null
              ? null
              : visiblePlans.firstWhere(
                  (p) => p['planType'] == selectedType,
                  orElse: () => visiblePlans.first,
                );
          final selOrigPrice = (selectedPlan?['originalPrice'] as num?)?.toInt() ?? 0;
          final selDays = (selectedPlan?['days'] as num?)?.toInt() ?? 30;

          return _SheetShell(
            maxHeightFraction: 0.86,
            child: confirming
                ? _ConfirmSpendView(
                    coins: selOrigPrice,
                    days: selDays,
                    accentColor: accentColor,
                    onCancel: () => setS(() => confirming = false),
                    onConfirm: () => Navigator.pop(ctx, PlanSelected(selectedPlan!)),
                  )
                : _PlanListView(
                    plans: visiblePlans,
                    walletBalance: walletBalance,
                    selectedType: selectedType,
                    unitLimitKey: unitLimitKey,
                    unitSingular: unitSingular,
                    unitPlural: unitPlural,
                    accentColor: accentColor,
                    onSelect: (raw) => setS(() => selectedType = raw),
                    onAddCoins: () => Navigator.pop(ctx, PlanSelectionAddCoins()),
                    onContinue: selectedPlan == null
                        ? null
                        : () {
                            if (selOrigPrice == 0) {
                              Navigator.pop(ctx, PlanSelected(selectedPlan));
                              return;
                            }
                            // Distinct "Confirm Spend" moment, folded into this
                            // same sheet — the coin debit must not fire until
                            // the owner explicitly confirms the exact spend.
                            setS(() => confirming = true);
                          },
                  ),
          );
        },
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final Widget child;
  final double maxHeightFraction;
  const _SheetShell({required this.child, required this.maxHeightFraction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * maxHeightFraction),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanListView extends StatelessWidget {
  final List<Map<String, dynamic>> plans;
  final int walletBalance;
  final String? selectedType;
  final String unitLimitKey;
  final String unitSingular;
  final String unitPlural;
  final Color accentColor;
  final ValueChanged<String> onSelect;
  final VoidCallback onAddCoins;
  final VoidCallback? onContinue;

  const _PlanListView({
    required this.plans,
    required this.walletBalance,
    required this.selectedType,
    required this.unitLimitKey,
    required this.unitSingular,
    required this.unitPlural,
    required this.accentColor,
    required this.onSelect,
    required this.onAddCoins,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final selectedPlan = selectedType == null
        ? null
        : plans.firstWhere((p) => p['planType'] == selectedType, orElse: () => plans.first);
    final selOrigPrice = (selectedPlan?['originalPrice'] as num?)?.toInt() ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text('Choose a Plan',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Wallet balance',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const CoinIcon(size: 16),
                const SizedBox(width: 5),
                Text('$walletBalance',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: plans.map((p) {
                final normalPrice = (p['price'] as num?)?.toInt() ?? 0;
                final origPrice = (p['originalPrice'] as num?)?.toInt() ?? 0;
                final disc = (p['discountPercent'] as num?)?.toInt() ?? 0;
                final hasDiscount = disc > 0 && normalPrice > 0;
                final days = (p['days'] as num?)?.toInt() ?? 30;
                final units = (p[unitLimitKey] as num?)?.toInt() ?? 1;
                final raw = (p['planType'] as String? ?? '');
                final label = raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
                final isFeatured = p['isFeatured'] == true;
                final afford = walletBalance >= origPrice;
                final isSelected = afford && selectedType == raw;
                final shortfall = afford ? 0 : origPrice - walletBalance;
                final unitNoun = units > 1 ? unitPlural : unitSingular;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: afford ? () => onSelect(raw) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? accentColor.withValues(alpha: 0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? accentColor
                              : (afford ? accentColor.withValues(alpha: 0.3) : AppColors.divider),
                          width: isSelected ? 2 : 1.5,
                        ),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? accentColor : AppColors.textLight, width: 2)),
                          child: isSelected
                              ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor)))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text('$label Plan',
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                              if (hasDiscount) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(4)),
                                  child: Text('$disc% Savings',
                                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                                ),
                              ],
                              if (isFeatured) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('RECOMMENDED',
                                      style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                                ),
                              ],
                            ]),
                            Text('$days days · up to $units $unitNoun live',
                                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                            if (!afford) ...[
                              const SizedBox(height: 4),
                              Text('Need $shortfall more coin${shortfall == 1 ? '' : 's'}',
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
                            ],
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          if (hasDiscount) _coinAmount(normalPrice, color: AppColors.textLight, size: 12, strikethrough: true),
                          _coinAmount(origPrice, color: origPrice == 0 ? AppColors.success : accentColor),
                          if (!afford) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: onAddCoins,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(8)),
                                child: const Text('Add Coins',
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ),
                          ],
                        ]),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: accentColor.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  selectedPlan == null ? 'Select an affordable plan' : (selOrigPrice == 0 ? 'Activate FREE' : 'Continue'),
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight, fontSize: 13)),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _coinAmount(int amount, {required Color color, double size = 16, bool strikethrough = false}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      CoinIcon(size: size),
      const SizedBox(width: 4),
      Text(
        '$amount',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
          decoration: strikethrough ? TextDecoration.lineThrough : null,
        ),
      ),
    ]);
  }
}

class _ConfirmSpendView extends StatelessWidget {
  final int coins;
  final int days;
  final Color accentColor;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ConfirmSpendView({
    required this.coins,
    required this.days,
    required this.accentColor,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(16)),
          child: const CoinIcon(size: 30),
        ),
        const SizedBox(height: 14),
        const Text('Confirm Spend',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Text(
          'Spend $coins coins to go live for $days days?',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: AppColors.textMedium, height: 1.5),
        ),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textMedium,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Confirm', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ]),
    );
  }
}
