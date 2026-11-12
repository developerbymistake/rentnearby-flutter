import 'package:flutter/material.dart';
import '../config/app_insets.dart';
import '../config/module_palette.dart';
import '../design/design.dart';

class NearestConfirmSheet extends StatelessWidget {
  final String itemLabel;
  final VoidCallback onConfirm;
  final ModulePalette palette;
  const NearestConfirmSheet({
    super.key,
    required this.itemLabel,
    required this.onConfirm,
    this.palette = templateModulePalette,
  });

  static Future<void> show(
    BuildContext context, {
    required String itemLabel,
    required VoidCallback onConfirm,
    ModulePalette palette = templateModulePalette,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NearestConfirmSheet(
          itemLabel: itemLabel, onConfirm: onConfirm, palette: palette),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FitnessAppTheme.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          ShadowTokens.tint(FitnessAppTheme.grey, ShadowSpec.topBar),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            24, 12, 24, 24 + AppInsets.bottomViewPadding(context)),
        child: TemplateStagger(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: FitnessAppTheme.spacer,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const GateBadge(asset: TravelIcon.map, size: 72),
            const SizedBox(height: 16),
            Text('No ${_cap(itemLabel)} Nearby',
                style: FitnessAppTheme.headline.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Search the nearest $itemLabel in your district instead?',
              style: FitnessAppTheme.body2
                  .copyWith(height: 1.5, color: FitnessAppTheme.lightText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GateButton(
              label: 'Search Nearest',
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
            ),
            const SizedBox(height: 10),
            GateTextButton(
              label: 'Not Now',
              color: FitnessAppTheme.lightText,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
