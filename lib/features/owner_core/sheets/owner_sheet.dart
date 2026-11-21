import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../look/owner_look.dart';
import 'owner_confirm.dart';

abstract final class OwnerSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required OwnerLook look,
    required String title,
    String? subtitle,
    String? art,
    required WidgetBuilder child,
    WidgetBuilder? footer,
    bool Function()? dirty,
    SheetSize size = SheetSize.form,
  }) {
    return SheetFrame.show<T>(
      context,
      isDismissible: dirty == null,
      builder: (c) => _DirtyGuard(
        dirty: dirty,
        child: SheetFrame(
          tone: look.tone,
          art: art,
          title: title,
          subtitle: subtitle,
          size: size,
          footer: footer?.call(c),
          child: child(c),
        ),
      ),
    );
  }
}

class _DirtyGuard extends StatelessWidget {
  const _DirtyGuard({required this.child, this.dirty});

  final Widget child;
  final bool Function()? dirty;

  @override
  Widget build(BuildContext context) {
    final isDirty = dirty;
    if (isDirty == null) return child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (!isDirty()) {
          nav.pop();
          return;
        }
        final discard = await OwnerConfirm.discard(context);
        if (discard && nav.mounted) nav.pop();
      },
      child: child,
    );
  }
}
