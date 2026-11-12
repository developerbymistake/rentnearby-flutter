import 'package:flutter/material.dart';
import '../design/design.dart';

class RoleCorrectionDialog {
  const RoleCorrectionDialog._();

  static Future<bool> confirm(BuildContext context, {required String kind, required int percent}) async {
    final body = percent <= 0
        ? 'Nothing filled yet. You can do this only once.'
        : '$kind draft, $percent% filled, will be deleted. You can do this only once.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => GateDialog(
        glyph: Icons.warning_amber_rounded,
        gradient: TripEntryStyle.rose,
        title: 'Delete draft and change role?',
        body: body,
        horizontalActions: true,
        actions: [
          GateOutlineButton(label: 'Cancel', height: 46, onPressed: () => Navigator.of(ctx).pop(false)),
          GateButton(
            label: 'Change role',
            height: 46,
            gradient: TripEntryStyle.rose,
            shadowColor: PickKit.bad,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
