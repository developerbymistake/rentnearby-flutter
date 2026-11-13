import 'package:flutter/material.dart';
import '../config/module_palette.dart';
import '../design/design.dart';
import 'location_switch_sheet.dart';

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
    return Sheet3D.show<void>(
      context,
      builder: (_) => NearestConfirmSheet(
          itemLabel: itemLabel, onConfirm: onConfirm, palette: palette),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final tone = moduleToneFor(palette);
    return Sheet3D(
      tone: tone,
      art: ListingArt.worldMap,
      title: 'No ${_cap(itemLabel)} Nearby',
      subtitle: 'Search the nearest $itemLabel in your district instead?',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientPillButton(
            tone: tone,
            label: 'Search Nearest',
            height: 52,
            onTap: () {
              Navigator.pop(context);
              onConfirm();
            },
          ),
          const SizedBox(height: 12),
          WhitePillButton(tone: tone, label: 'Not Now', height: 52, onTap: () => Navigator.pop(context)),
        ],
      ),
      child: const SizedBox(height: 12),
    );
  }
}
