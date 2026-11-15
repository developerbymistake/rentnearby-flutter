import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/type_tokens.dart';
import 'buttons_kit.dart';
import 'kit_tone.dart';
import 'module_header.dart';
import 'motion_kit.dart';
import 'template_motion.dart';
import 'travel_icon.dart';
import 'trip_kit.dart';
import 'trip_pick_kit.dart';
import '../tokens/design_scale.dart';

class ChatKindStyle {
  const ChatKindStyle._(this.accent, this.dark, this.tint, this.gradient);
  final Color accent;
  final Color dark;
  final Color tint;
  final LinearGradient gradient;

  static const ChatKindStyle _stay = ChatKindStyle._(PickKit.stay, PickKit.stayDark, PickKit.stayTint, PickKit.stayGradient);
  static const ChatKindStyle _taxi = ChatKindStyle._(PickKit.taxi, PickKit.taxiDark, PickKit.taxiTint, PickKit.taxiGradient);
  static const ChatKindStyle _trip = ChatKindStyle._(PickKit.trip, PickKit.tripDark, PickKit.tripTint, PickKit.tripGradient);

  static ChatKindStyle of(String? listingType) => switch (listingType) {
        'Stay' => _stay,
        'Taxi' => _taxi,
        _ => _trip,
      };
}

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.onBack,
    required this.title,
    this.subtitle,
    this.gradient = PickKit.stayGradient,
    this.shadowColor = DesignColors.lunchEnd,
    this.actions = const [],
    this.leading,
    this.trailingAsset,
  });

  final VoidCallback onBack;
  final Widget title;
  final Widget? subtitle;
  final Gradient gradient;
  final Color shadowColor;
  final List<Widget> actions;
  final Widget? leading;
  final String? trailingAsset;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion(
      value: ModuleHeader.lightIcons,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: DS.br(CardRadius.header),
          boxShadow: DS.shadows(ShadowTokens.glow(shadowColor)),
        ),
        margin: EdgeInsets.only(bottom: DS.gv(4)),
        padding: EdgeInsets.fromLTRB(DS.s(8), top + DS.s(ModuleHeader.paddingTop), DS.s(12), DS.s(ModuleHeader.paddingBottom)),
        child: Row(
          children: [
            PressScale(
              child: SizedBox(
                width: DS.s(KitMetrics.touch),
                height: DS.s(KitMetrics.touch),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  splashColor: DesignColors.whiteSoft,
                  highlightColor: Colors.transparent,
                  onTap: onBack,
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: DS.s(20), color: DesignColors.textInverse),
                ),
              ),
            ),
            if (leading != null) ...[leading!, Gap.h(10)] else Gap.h(2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [title, if (subtitle != null) ...[Gap.v(2), subtitle!]],
              ),
            ),
            if (actions.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: math.max(MediaQuery.sizeOf(context).width * 0.3, DS.s(140.0))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [for (final a in actions) Flexible(child: a)]),
              ),
            if (trailingAsset != null) ...[
              Gap.h(8),
              Container(
                width: DS.s(56),
                height: DS.s(56),
                decoration: BoxDecoration(color: DesignColors.tint(DesignColors.surfaceAlt, Alpha.soft), shape: BoxShape.circle),
                child: Padding(padding: DS.all(8), child: Image.asset(trailingAsset!)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Text titleText(String text, {double size = 22}) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TypeTokens.style(size, FontWeight.w700, color: DesignColors.textInverse, letterSpacing: 1.2),
      );

  static Text subtitleText(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TypeTokens.style(12, FontWeight.w500, color: DesignColors.textInverse.withValues(alpha: Alpha.high)),
      );
}

class ChatRowCard extends StatelessWidget {
  const ChatRowCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.color = DesignColors.surface,
    this.shadowAlpha = 0.2,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final double shadowAlpha;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => TripKitSurface(
        margin: margin,
        padding: (padding ?? EdgeInsets.symmetric(horizontal: DS.s(14), vertical: DS.s(12))),
        color: color,
        onTap: onTap,
        shadow: shadowAlpha == 0.2
            ? ShadowTokens.elev1
            : [ShadowTokens.tint(DesignColors.textGrey, ShadowSpec.elev1Spec.scaled(shadowAlpha / 0.2))],
        child: child,
      );
}

class ChatPill extends StatelessWidget {
  const ChatPill({super.key, required this.label, required this.fill, required this.color, this.size = 10});
  final String label;
  final Color fill;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: DS.s(9), vertical: DS.s(3)),
        decoration: BoxDecoration(color: fill, borderRadius: DS.br(CardRadius.pill)),
        child: Text(label, style: TypeTokens.style(size, FontWeight.w700, color: color, letterSpacing: 0.4, chip: true)),
      );
}

class ChatReveal extends StatefulWidget {
  const ChatReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.count = 1,
    this.offset = 30,
    this.horizontal = false,
    this.animate = true,
  });

  final Widget child;
  final int index;
  final int count;
  final double offset;
  final bool horizontal;
  final bool animate;

  @override
  State<ChatReveal> createState() => _ChatRevealState();
}

class _ChatRevealState extends State<ChatReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
  late final Animation<double> _animation = templateInterval(
    _controller,
    widget.index.clamp(0, widget.count < 1 ? 0 : widget.count - 1),
    widget.count < 1 ? 1 : widget.count,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.horizontal) {
      return TemplateEntrance(animation: _animation, animationController: _controller, offset: DS.s(widget.offset), child: widget.child);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) => FadeTransition(
        opacity: _animation,
        child: Transform(
          transform: Matrix4.translationValues(DS.s(widget.offset) * (1.0 - _animation.value), 0.0, 0.0),
          child: widget.child,
        ),
      ),
    );
  }
}

class ChatButton extends StatelessWidget {
  const ChatButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = DesignColors.primary,
    this.outlined = false,
    this.loading = false,
    this.height = 40,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool outlined;
  final bool loading;
  final double height;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tone = tripToneForColor(color);
    if (outlined) {
      return SecondaryButton(
        label: label,
        onPressed: loading ? null : onPressed,
        tone: tone,
        height: height,
        expand: expand,
        compact: true,
        icon: loading
            ? SizedBox(width: DS.s(18), height: DS.s(18), child: CircularProgressIndicator(strokeWidth: DS.s(2), color: color))
            : icon != null
                ? Icon(icon, size: DS.s(18), color: onPressed == null ? DesignColors.textDisabled : color)
                : null,
      );
    }
    return PrimaryButton(
      label: label,
      onPressed: onPressed,
      loading: loading,
      tone: tone,
      height: height,
      expand: expand,
      compact: true,
      icon: icon != null ? Icon(icon, size: DS.s(18), color: onPressed == null ? DesignColors.textDisabled : DesignColors.onPrimary) : null,
    );
  }
}

class ChatSheetFrame extends StatelessWidget {
  const ChatSheetFrame({super.key, required this.child, this.showGrabber = true});
  final Widget child;
  final bool showGrabber;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: DesignColors.sheet,
          borderRadius: DS.br(CardRadius.sheet),
          boxShadow: DS.shadows(DesignShadows.top),
        ),
        child: child,
      );

  static Widget grabber() => Center(
        child: Container(
          width: DS.s(36),
          height: DS.s(4),
          margin: EdgeInsets.only(top: DS.gv(10), bottom: DS.gv(14)),
          decoration: BoxDecoration(color: DesignColors.tint(DesignColors.textGrey, Alpha.half), borderRadius: DS.circular(2)),
        ),
      );
}

class ChatSheetRow extends StatelessWidget {
  const ChatSheetRow({super.key, required this.asset, required this.label, required this.color, required this.onTap});
  final String asset;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: DS.br(CardRadius.tile),
        splashColor: DesignColors.splash,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: DS.s(KitMetrics.touch)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: DS.s(8), vertical: DS.s(10)),
            child: Row(
              children: [
                Container(
                  width: DS.s(44),
                  height: DS.s(44),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: DesignColors.tint(color, Alpha.tint), shape: BoxShape.circle),
                  child: TravelIcon(asset, size: 24),
                ),
                Gap.h(14),
                Expanded(
                  child: Text(label, style: TypeTokens.style(15, FontWeight.w500, color: DesignColors.textStrong)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatSheetLabel extends StatelessWidget {
  const ChatSheetLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(DS.s(8), DS.s(4), DS.s(8), DS.s(4)),
        child: Text(text.toUpperCase(), style: TypeTokens.style(11, FontWeight.w700, color: TypeTokens.secondary, letterSpacing: 0.4)),
      );
}

class ChatDayLabel extends StatelessWidget {
  const ChatDayLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(DS.s(2), DS.s(4), DS.s(2), DS.s(8)),
        child: Text(label.toUpperCase(), style: TypeTokens.style(12, FontWeight.w700, color: TypeTokens.secondary, letterSpacing: 0.5)),
      );
}

class NotificationLook {
  const NotificationLook._(this.asset, this.color);
  final String asset;
  final Color color;

  static const String bell = TravelIcon.bell;

  static NotificationLook of(String kind) => switch (kind) {
        'approved' => const NotificationLook._(TravelIcon.star, DesignColors.goodDeep),
        'rejected' => const NotificationLook._(TravelIcon.note, DesignColors.roseDeep),
        'takedown' => const NotificationLook._(TravelIcon.warning, DesignColors.warnDeep),
        _ => const NotificationLook._(bell, DesignColors.primary),
      };
}

class ChatSkeletonCard extends StatelessWidget {
  const ChatSkeletonCard({super.key, required this.children, this.avatar = 46});
  final List<Widget> children;
  final double avatar;

  @override
  Widget build(BuildContext context) => ChatRowCard(
        child: Row(
          children: [
            if (avatar > 0) ...[TemplatePlaceholder(height: DS.s(avatar), width: DS.s(avatar), radius: DS.radius(avatar / 2)), Gap.h(12)],
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
          ],
        ),
      );
}
