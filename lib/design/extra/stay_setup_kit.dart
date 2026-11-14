import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/type_tokens.dart';
import '../tokens/util_tokens.dart';
import 'buttons_kit.dart';
import 'card_kit.dart';
import 'dock_inset.dart';
import 'kit_tone.dart';
import 'module_header.dart';
import 'state_card.dart';
import 'template_motion.dart';
import 'art_3d.dart';
import 'dialog_3d.dart';
import '../tokens/listing_palette.dart';

class SetupAssets {
  static const String _dir = 'assets/images/design/travel3d/';
  static const String hotel = '${_dir}camping.png';
  static const String bed = '${_dir}bed.png';
  static const String clipboard = '${_dir}clipboard.png';
  static const String key = '${_dir}key.png';
  static const String moneyBag = '${_dir}money_bag.png';
  static const String camera = '${_dir}camera.png';
  static const String luggage = '${_dir}luggage.png';
  static const String airplane = '${_dir}airplane.png';
  static const String calendar = '${_dir}calendar.png';
  static const String pin = '${_dir}round_pushpin.png';
  static const String chat = '${_dir}speech_balloon.png';
  static const String map = '${_dir}world_map.png';
}

class SetupKit {
  static final String stayHex = DesignHex.of(DesignColors.lunchEnd);
  static final String userDotHex = DesignHex.of(DesignColors.info);

  static const LinearGradient sky = DesignGradients.lunch;
  static const LinearGradient rose = DesignGradients.snack;
  static const LinearGradient sunrise = DesignGradients.breakfast;
  static const LinearGradient dusk = DesignGradients.dinner;
  static const LinearGradient grey = LinearGradient(
      colors: [DesignColors.surfaceMuted, DesignColors.textDisabled],
      begin: DesignGradients.begin,
      end: DesignGradients.end);

  static AnimationController controller(TickerProvider vsync) =>
      AnimationController(duration: const Duration(milliseconds: 600), vsync: vsync);

  static void play(AnimationController c, BuildContext context, {bool restart = false}) {
    if (MediaQuery.of(context).disableAnimations) {
      c.value = 1;
    } else if (restart) {
      c.forward(from: 0);
    } else {
      c.forward();
    }
  }

  static TextStyle label() =>
      TypeTokens.style(12, FontWeight.w500, color: DesignColors.textSecondary, letterSpacing: 0.2);

  static TextStyle fieldText() => TypeTokens.style(14, FontWeight.w500);

  static InputDecoration input({
    String? hint,
    String? label,
    String? error,
    String? helper,
    String? prefix,
    Widget? suffix,
    Widget? prefixIcon,
    int? errorMaxLines,
  }) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
        borderRadius: KitMetrics.tileSmall,
        borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      labelText: label,
      errorText: error,
      helperText: helper,
      prefixText: prefix,
      prefixStyle: TypeTokens.style(14, FontWeight.w400),
      suffix: suffix,
      prefixIcon: prefixIcon,
      errorMaxLines: errorMaxLines,
      counterText: '',
      filled: true,
      fillColor: DesignColors.scaffold,
      floatingLabelBehavior: label == null ? null : FloatingLabelBehavior.always,
      labelStyle: TypeTokens.style(12, FontWeight.w400, color: DesignColors.inputLabel),
      hintStyle: TypeTokens.style(14, FontWeight.w400, color: DesignColors.inputHint),
      errorStyle: TypeTokens.style(12, FontWeight.w400, color: DesignColors.error),
      helperStyle: TypeTokens.style(12, FontWeight.w400, color: DesignColors.inputLabel),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: b(Colors.transparent, 0),
      enabledBorder: b(Colors.transparent, 0),
      disabledBorder: b(Colors.transparent, 0),
      focusedBorder: b(DesignColors.inputBorderFocus, 1.5),
      errorBorder: b(DesignColors.inputBorderError, 1.5),
      focusedErrorBorder: b(DesignColors.inputBorderError, 1.5),
    );
  }

  static Future<T?> sheet<T>(BuildContext context, {required WidgetBuilder builder}) {
    return showDockSheet<T>(
      context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: DesignColors.scrim,
      elevation: 0,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => DecoratedBox(
        decoration: const BoxDecoration(
          color: DesignColors.sheet,
          borderRadius: CardRadius.sheet,
          boxShadow: DesignShadows.top,
        ),
        child: ClipRRect(borderRadius: CardRadius.sheet, child: builder(ctx)),
      ),
    );
  }

  static Widget grabber() => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 14),
          decoration: BoxDecoration(
              color: DesignColors.tint(DesignColors.textGrey, Alpha.half), borderRadius: BorderRadius.circular(2)),
        ),
      );
}

class KitDialogFrame extends StatelessWidget {
  const KitDialogFrame({
    super.key,
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.tone = KitTone.stay,
    this.destructive = false,
    this.art,
  });

  final String title;
  final String body;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final KitTone tone;
  final bool destructive;
  final String? art;

  @override
  Widget build(BuildContext context) {
    return Dialog3D(
      tone: listingToneOf(tone),
      art: art ?? SetupAssets.clipboard,
      title: title,
      body: body,
      secondaryLabel: cancelLabel,
      onSecondary: onCancel,
      primaryLabel: confirmLabel,
      onPrimary: onConfirm,
      primaryDanger: destructive,
    );
  }
}

class SetupHeader extends StatelessWidget {
  const SetupHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.showBack = true,
    this.trailing,
    this.asset = SetupAssets.hotel,
    this.animation,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool showBack;
  final Widget? trailing;
  final String asset;
  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    Widget bar = ModuleHeader(
      title: title,
      subtitle: subtitle,
      tone: KitTone.stay,
      onBack: showBack ? (onBack ?? () => Navigator.maybePop(context)) : null,
      autoHeight: true,
      animate: animation == null,
      trailing: [
        if (trailing != null) trailing!,
        const SizedBox(width: 8),
        Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: DesignColors.overlayWhiteSoft, shape: BoxShape.circle),
          child: Image.asset(asset),
        ),
      ],
    );
    if (animation != null) bar = FadeTransition(opacity: animation!, child: bar);
    return bar;
  }
}

class SetupCard extends StatelessWidget {
  const SetupCard({super.key, this.title, required this.child, this.margin = const EdgeInsets.only(bottom: 16)});

  final String? title;
  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: SectionTile(
        title: title,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: child,
      ),
    );
  }
}

class SetupFooter extends StatelessWidget {
  const SetupFooter({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: DesignColors.surface, boxShadow: ShadowTokens.elev3Up),
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.viewPaddingOf(context).bottom + 16),
      child: child,
    );
  }
}

class SetupOutlineButton extends StatelessWidget {
  const SetupOutlineButton({super.key, required this.label, required this.onPressed, this.height = 52});
  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) =>
      SecondaryButton(label: label, onPressed: onPressed, tone: KitTone.stay, height: height);
}

class SetupPill extends StatelessWidget {
  const SetupPill({super.key, required this.label, required this.onTap, this.destructive = false});
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 88),
      child: PrimaryButton(
        label: label,
        onPressed: onTap,
        tone: destructive ? KitTone.danger : KitTone.stay,
        expand: false,
        compact: true,
        height: KitMetrics.touch,
      ),
    );
  }
}

class SetupDialog extends StatelessWidget {
  const SetupDialog({
    super.key,
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.destructive = false,
    this.tone = KitTone.stay,
    this.art,
  });

  final String title;
  final String body;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool destructive;
  final KitTone tone;
  final String? art;

  @override
  Widget build(BuildContext context) => KitDialogFrame(
        title: title,
        body: body,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
        onCancel: onCancel,
        onConfirm: onConfirm,
        destructive: destructive,
        tone: tone,
        art: art,
      );
}

class SetupBusy extends StatelessWidget {
  const SetupBusy({super.key, required this.message, this.tone = KitTone.stay, this.art, this.progress, this.caption});
  final String message;
  final KitTone tone;
  final String? art;
  final double? progress;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = listingToneOf(tone);
    return Positioned.fill(
      child: BusyOverlay3D(
        tone: t,
        message: message,
        art: art ?? (identical(t, ListingTone.coral) ? ListingArt.taxi : SetupAssets.hotel),
        progress: progress,
        caption: caption,
      ),
    );
  }
}

class SetupEmpty extends StatelessWidget {
  const SetupEmpty({
    super.key,
    required this.asset,
    required this.title,
    this.subtitle,
    this.retryLabel,
    this.onRetry,
    this.padding = const EdgeInsets.all(24),
  });

  final String asset;
  final String title;
  final String? subtitle;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => StateCard(
        asset: asset,
        title: title,
        message: subtitle,
        kit: KitTone.stay,
        actionLabel: retryLabel,
        onAction: onRetry,
        padding: padding,
      );
}

class SetupSwitch extends StatelessWidget {
  const SetupSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: DesignColors.primary,
      inactiveTrackColor: DesignColors.switchTrackOff,
      thumbColor: DesignColors.switchThumbOff,
    );
  }
}

class SetupEntrance extends StatelessWidget {
  const SetupEntrance({
    super.key,
    required this.controller,
    required this.index,
    required this.count,
    required this.child,
  });
  final AnimationController controller;
  final int index;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TemplateEntrance(
      animation: templateInterval(controller, index.clamp(0, count - 1), count),
      animationController: controller,
      child: child,
    );
  }
}
