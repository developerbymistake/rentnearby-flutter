import 'package:flutter/material.dart';

import '../../../design/extra/art_3d.dart';
import '../../../design/extra/dialog_3d.dart';
import '../../../design/tokens/listing_palette.dart';
import '../strings/owner_shared_strings.dart';

abstract final class OwnerConfirm {
  static Future<bool> ask(
    BuildContext context, {
    required String title,
    String? body,
    required String confirm,
    required String cancel,
    bool destructive = false,
    ListingTone? tone,
    String? art,
  }) async {
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (c) => Dialog3D(
        tone: tone ?? ListingTone.indigo,
        art: art ?? ListingArt.clipboard,
        title: title,
        body: body,
        primaryLabel: confirm,
        onPrimary: () => Navigator.of(c).pop(true),
        primaryDanger: destructive,
        secondaryLabel: cancel,
        onSecondary: () => Navigator.of(c).pop(false),
        familyCorner: true,
        tight: true,
        titleSize: 18,
      ),
    );
    return ok == true;
  }

  static Future<bool> discard(BuildContext context) => ask(
        context,
        title: OwnerSharedStrings.discardTitle,
        confirm: OwnerSharedStrings.discard,
        cancel: OwnerSharedStrings.keepEditing,
        destructive: true,
      );
}
