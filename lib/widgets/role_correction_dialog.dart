import 'package:flutter/material.dart';
import '../design/design.dart';

class RoleCorrectionDialog {
  const RoleCorrectionDialog._();

  static Future<bool> confirm(BuildContext context, {required String kind, required int percent}) async {
    final body = percent <= 0
        ? 'Nothing filled yet. You can do this only once.'
        : '$kind draft, $percent% filled, will be deleted. You can do this only once.';
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.coral,
        art: ListingArt.pushpin,
        title: 'Delete draft and change role?',
        body: body,
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.of(ctx).pop(false),
        primaryLabel: 'Change role',
        onPrimary: () => Navigator.of(ctx).pop(true),
      ),
    );
    return ok ?? false;
  }
}
