import 'package:flutter/material.dart';
import '../tokens/design_colors.dart';
import 'art_3d.dart';
import 'dock_inset.dart';
import 'sheet_3d.dart';

class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
    this.handle = true,
    this.scrollable = true,
    this.tone,
    this.art,
    this.size = SheetSize.hug,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? footer;
  final EdgeInsets padding;
  final bool handle;
  final bool scrollable;
  final ListingTone? tone;
  final String? art;
  final SheetSize size;

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
    return Sheet3D(
      tone: tone ?? ListingTone.indigo,
      art: art,
      title: title,
      subtitle: subtitle,
      centerTitle: art != null,
      size: size,
      footer: footer,
      scrollable: scrollable,
      padding: footer == null ? padding.copyWith(bottom: 0) : padding,
      child: child,
    );
  }
}
