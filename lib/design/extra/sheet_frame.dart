import 'package:flutter/material.dart';
import '../tokens/design_colors.dart';
import 'art_3d.dart';
import 'dock_inset.dart';
import 'sheet_3d.dart';
import 'package:bakhli/design/tokens/design_scale.dart';

class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.footer,
    this.padding,
    this.handle = true,
    this.scrollable = true,
    this.tone,
    this.art,
    this.size = SheetSize.hug,
    this.showClose = true,
    this.closeEnabled = true,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? footer;
  final EdgeInsets? padding;
  final bool handle;
  final bool scrollable;
  final ListingTone? tone;
  final String? art;
  final SheetSize size;
  final bool showClose;
  final bool closeEnabled;

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    BoxConstraints? constraints = const BoxConstraints(maxWidth: 560),
  }) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        useRootNavigator: false,
        isDismissible: isDismissible,
        backgroundColor: Colors.transparent,
        barrierColor: DesignColors.scrim,
        elevation: 0,
        clipBehavior: Clip.none,
        constraints: constraints,
        builder: (c) => DockLift(child: builder(c)),
      );

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? DS.insets(l: 20, b: 20, r: 20);
    return Sheet3D(
      tone: tone ?? ListingTone.indigo,
      art: art,
      title: title,
      subtitle: subtitle,
      centerTitle: art != null,
      size: size,
      showClose: showClose,
      closeEnabled: closeEnabled,
      footer: footer,
      scrollable: scrollable,
      padding: footer == null ? pad.copyWith(bottom: 0) : pad,
      child: child,
    );
  }
}
