import 'package:flutter/material.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/type_tokens.dart';
import 'kit_tone.dart';
import 'stay_setup_kit.dart';
import 'template_motion.dart';
import 'trip_plan_look.dart';
import 'ways_kit.dart';

enum JourneyButtonKind { filled, outline, positive, danger, dangerOutline }

class JourneyButton extends StatelessWidget {
  const JourneyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = JourneyButtonKind.filled,
    this.icon,
    this.busy = false,
    this.height = 44,
    this.maxLines = 1,
    this.fontSize = 13,
  });

  final String label;
  final VoidCallback? onPressed;
  final JourneyButtonKind kind;
  final Widget? icon;
  final bool busy;
  final double height;
  final int maxLines;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (KitTone tone, bool filled, Color? border) = switch (kind) {
      JourneyButtonKind.filled => (KitTone.brand, true, null),
      JourneyButtonKind.positive => (KitTone.stay, true, null),
      JourneyButtonKind.danger => (KitTone.danger, true, null),
      JourneyButtonKind.outline => (KitTone.brand, false, DesignColors.chipBorder),
      JourneyButtonKind.dangerOutline => (KitTone.danger, false, null),
    };
    return KitFlexButton(
      label: label,
      onPressed: onPressed,
      tone: tone,
      filled: filled,
      borderColor: border,
      icon: icon,
      busy: busy,
      minHeight: height,
      maxLines: maxLines,
      fontSize: fontSize,
    );
  }
}

class JourneyPill extends StatelessWidget {
  const JourneyPill({super.key, required this.text, required this.fg, required this.bg, this.fontSize = 11, this.maxLines = 2});

  final String text;
  final Color fg;
  final Color bg;
  final double fontSize;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: CardRadius.pill),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TypeTokens.style(fontSize, FontWeight.w600, color: fg, chip: true),
      ),
    );
  }
}

Future<bool> showTaxiConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String cancelLabel,
  required String actionLabel,
  required Color actionColor,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => KitDialogFrame(
      title: title,
      body: body,
      cancelLabel: cancelLabel,
      confirmLabel: actionLabel,
      tone: KitTone.fromColor(actionColor),
      onCancel: () => Navigator.of(ctx).pop(false),
      onConfirm: () => Navigator.of(ctx).pop(true),
    ),
  );
  return ok == true;
}

class JourneyDotMark extends StatelessWidget {
  const JourneyDotMark({super.key, required this.color, this.size = 22, this.child});

  final Color color;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: DesignColors.surface, width: 3),
        boxShadow: ShadowTokens.elev1,
      ),
      child: child,
    );
  }
}

Color journeyLegColor(int legIndex) => TripLook.dayColors[(legIndex - 1).abs() % TripLook.dayColors.length];

BoxDecoration journeyBarCard(Color bar) => BoxDecoration(
      color: DesignColors.surface,
      borderRadius: CardRadius.tile,
      boxShadow: [ShadowTokens.tint(bar, ShadowSpec.elev2Spec)],
    );

class JourneySkeletonCard extends StatelessWidget {
  const JourneySkeletonCard({super.key, this.buttons = 2});

  final int buttons;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: DesignColors.surface,
        borderRadius: CardRadius.tile,
        boxShadow: ShadowTokens.elev2,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TemplatePlaceholder(height: 16, width: c.maxWidth * 0.55),
                const SizedBox(height: 8),
                TemplatePlaceholder(height: 12, width: c.maxWidth * 0.75),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          const TemplatePlaceholder(height: 24, width: 72, radius: 18),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          for (var i = 0; i < buttons; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            const Expanded(child: TemplatePlaceholder(height: 44, radius: 16)),
          ],
        ]),
      ]),
    );
  }
}

class TaxiVehicleIcon {
  static String assetFor(String? vehicleType) {
    final v = (vehicleType ?? '').toLowerCase();
    if (v.contains('bus') || v.contains('tempo') || v.contains('traveller') || v.contains('traveler')) {
      return 'assets/images/design/travel3d/bus.png';
    }
    return 'assets/images/design/travel3d/taxi.png';
  }
}
