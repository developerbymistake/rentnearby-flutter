import 'package:flutter/material.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/type_tokens.dart';
import '../tokens/util_tokens.dart';
import 'buttons_kit.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';
import 'module_header.dart';
import 'stay_setup_kit.dart';
import 'state_card.dart';

class TaxiSetupKit {
  static final String hexAccent = DesignHex.of(DesignColors.statusAttention);
  static final String hexUser = DesignHex.of(DesignColors.info);
  static const Color whatsApp = DesignColors.whatsApp;
  static const String car = 'assets/images/design/travel3d/automobile.png';
}

class TaxiSetupHeader extends StatelessWidget {
  const TaxiSetupHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.subtitleWidget,
    this.onBack,
    this.showBack = true,
    this.trailing,
    this.bottom,
    this.asset = SetupAssets.pin,
    this.animation,
    this.showAsset = true,
  });

  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? subtitleWidget;
  final VoidCallback? onBack;
  final bool showBack;
  final Widget? trailing;
  final Widget? bottom;
  final String asset;
  final Animation<double>? animation;
  final bool showAsset;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final titleStyle = TypeTokens.style(22, FontWeight.w700, color: DesignColors.textInverse, letterSpacing: 1.2);
    Widget bar = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: KitTone.taxi.gradient,
        borderRadius: CardRadius.header,
        boxShadow: ShadowTokens.glow(KitTone.taxi.glow),
      ),
      padding: EdgeInsets.fromLTRB(showBack ? 8 : 20, top + ModuleHeader.paddingTop, 16, ModuleHeader.paddingBottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ModuleHeader.toolbarHeight),
          child: Row(children: [
            if (showBack) ...[
              PressScale(
                child: SizedBox(
                  width: KitMetrics.touch,
                  height: KitMetrics.touch,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    splashColor: DesignColors.whiteSoft,
                    highlightColor: Colors.transparent,
                    onTap: onBack,
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: DesignColors.textInverse),
                  ),
                ),
              ),
              const SizedBox(width: 2),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  titleWidget ?? Text(title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                  if (subtitleWidget != null)
                    subtitleWidget!
                  else if (subtitle != null)
                    Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.onGradientBody),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (showAsset) ...[
              const SizedBox(width: 8),
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: DesignColors.overlayWhiteSoft, shape: BoxShape.circle),
                child: Image.asset(asset),
              ),
            ],
          ]),
        ),
        if (bottom != null) ...[const SizedBox(height: 12), bottom!],
      ]),
    );
    if (animation != null) bar = FadeTransition(opacity: animation!, child: bar);
    return bar;
  }
}

class TaxiPill extends StatelessWidget {
  const TaxiPill({super.key, required this.label, required this.onTap, this.destructive = false});
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 88),
      child: PrimaryButton(
        label: label,
        onPressed: onTap,
        tone: destructive ? KitTone.danger : KitTone.taxi,
        expand: false,
        compact: true,
        height: KitMetrics.touch,
      ),
    );
  }
}

Future<bool?> showTaxiDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String cancelLabel,
  required String confirmLabel,
  bool destructive = false,
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => KitDialogFrame(
      title: title,
      body: body,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      tone: KitTone.taxi,
      destructive: destructive,
      onCancel: () => Navigator.of(ctx).pop(false),
      onConfirm: () => Navigator.of(ctx).pop(true),
    ),
  );
}

class TaxiEmpty extends StatelessWidget {
  const TaxiEmpty({
    super.key,
    required this.asset,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(24),
  });

  final String asset;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => StateCard(
        asset: asset,
        title: title,
        message: subtitle,
        kit: KitTone.taxi,
        actionLabel: actionLabel,
        onAction: onAction,
        padding: padding,
      );
}

class TaxiStepDot extends StatefulWidget {
  const TaxiStepDot({super.key, required this.index, required this.step, required this.label});
  final int index;
  final int step;
  final String label;

  @override
  State<TaxiStepDot> createState() => _TaxiStepDotState();
}

class _TaxiStepDotState extends State<TaxiStepDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(duration: const Duration(milliseconds: 400), vsync: this)
    ..value = 1;
  late final Animation<double> _scale =
      Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.fastOutSlowIn));

  @override
  void didUpdateWidget(TaxiStepDot old) {
    super.didUpdateWidget(old);
    final was = old.step >= widget.index;
    final now = widget.step >= widget.index;
    if (now && !was && !MediaQuery.of(context).disableAnimations) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.step == widget.index;
    final done = widget.step > widget.index;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: (active || done) ? KitTone.taxi.gradient : null,
            color: (active || done) ? null : DesignColors.dividerSoft,
            shape: BoxShape.circle,
            boxShadow: (active || done) ? ShadowTokens.elev2 : const [],
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, color: DesignColors.onPrimary, size: 16)
                : Text('${widget.index + 1}',
                    style: TypeTokens.style(13, FontWeight.w700,
                        color: active ? DesignColors.onPrimary : DesignColors.textSecondary)),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(widget.label,
          style: TypeTokens.style(11, FontWeight.w500, color: (active || done) ? KitTone.taxi.accentDark : DesignColors.textSecondary)),
    ]);
  }
}
