import 'package:flutter/material.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/type_tokens.dart';

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
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? footer;
  final EdgeInsets padding;
  final bool handle;
  final bool scrollable;

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool useRootNavigator = false,
    bool isDismissible = true,
    BoxConstraints? constraints = const BoxConstraints(maxWidth: 560),
  }) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        useRootNavigator: useRootNavigator,
        isDismissible: isDismissible,
        backgroundColor: Colors.transparent,
        barrierColor: DesignColors.scrim,
        elevation: 0,
        constraints: constraints,
        builder: builder,
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final body = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!,
                style: TypeTokens.style(22, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.27)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: TypeTokens.style(14, FontWeight.w400, color: TypeTokens.secondary)),
            ],
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: DesignColors.sheet,
        borderRadius: CardRadius.sheet,
        boxShadow: DesignShadows.top,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (handle)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 14),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DesignColors.tint(DesignColors.textGrey, Alpha.half),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )
            else
              const SizedBox(height: 16),
            Flexible(
              child: scrollable
                  ? SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, child: body)
                  : body,
            ),
            if (footer != null)
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: footer),
          ],
        ),
      ),
    );
  }
}
