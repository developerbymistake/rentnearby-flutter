import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';
import '../strings_shared.dart';

enum ConfirmKind { teal, rose, green, danger, indigo }

abstract final class BuddyConfirmBox {
  static ListingTone toneOf(ConfirmKind kind) => switch (kind) {
        ConfirmKind.teal => BuddyLook.teal,
        ConfirmKind.rose => BuddyLook.rose,
        ConfirmKind.green => BuddyLook.green,
        ConfirmKind.danger => BuddyLook.danger,
        ConfirmKind.indigo => BuddyLook.indigo,
      };

  static Widget? _extra({String? note, String? dangerNote, Widget? content}) {
    if (note == null && dangerNote == null && content == null) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (note != null) Text(note, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w400, BuddyLook.subText, height: 1.5, letterSpacing: 0)),
        if (dangerNote != null)
          Padding(
            padding: EdgeInsets.only(top: DS.s(note == null ? 0 : 8)),
            child: Text(dangerNote, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w600, BuddyLook.dangerText, height: 1.45, letterSpacing: 0)),
          ),
        if (content != null) Padding(padding: EdgeInsets.only(top: DS.s(note == null && dangerNote == null ? 0 : 12)), child: content),
      ],
    );
  }

  static Widget box({
    required String title,
    String? art,
    String? body,
    String? note,
    String? dangerNote,
    String? cancelLabel,
    required String confirmLabel,
    ConfirmKind confirmKind = ConfirmKind.indigo,
    Widget? content,
    bool busy = false,
    VoidCallback? onCancel,
    VoidCallback? onConfirm,
  }) =>
      Dialog3D(
        tone: toneOf(confirmKind),
        art: art,
        title: title,
        body: body,
        content: _extra(note: note, dangerNote: dangerNote, content: content),
        artDanger: confirmKind == ConfirmKind.danger,
        secondaryLabel: cancelLabel,
        onSecondary: busy ? null : onCancel,
        primaryLabel: confirmLabel,
        onPrimary: busy ? null : onConfirm,
        primaryLoading: busy,
        tight: true,
      );

  static Future<bool> ask(
    BuildContext context, {
    String? art,
    required String title,
    String? body,
    String? note,
    String? dangerNote,
    String cancelLabel = BuddySharedStrings.cancel,
    required String confirmLabel,
    ConfirmKind confirmKind = ConfirmKind.indigo,
    Widget? content,
  }) async {
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => box(
        title: title,
        art: art,
        body: body,
        note: note,
        dangerNote: dangerNote,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
        confirmKind: confirmKind,
        content: content,
        onCancel: () => Navigator.of(ctx).pop(false),
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    return ok == true;
  }

  static Future<void> info(
    BuildContext context, {
    String? art,
    required String title,
    String? body,
    String? note,
    String? dangerNote,
    String label = BuddySharedStrings.close,
    ConfirmKind kind = ConfirmKind.indigo,
    Widget? content,
  }) =>
      Dialog3D.show<void>(
        context,
        builder: (ctx) => box(
          title: title,
          art: art,
          body: body,
          note: note,
          dangerNote: dangerNote,
          confirmLabel: label,
          confirmKind: kind,
          content: content,
          onConfirm: () => Navigator.of(ctx).pop(),
        ),
      );
}
