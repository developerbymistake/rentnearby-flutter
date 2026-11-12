import 'package:flutter/material.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/type_tokens.dart';
import 'buttons_kit.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';
import 'travel_icon.dart';

enum StateTone { empty, error }

class StateCard extends StatelessWidget {
  const StateCard({
    super.key,
    required this.title,
    this.message,
    this.tone = StateTone.empty,
    this.kit = KitTone.brand,
    this.asset = TravelIcon.route,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
  });

  const StateCard.error({
    super.key,
    required this.title,
    this.message,
    this.kit = KitTone.brand,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
  })  : tone = StateTone.error,
        asset = TravelIcon.route;

  final String title;
  final String? message;
  final StateTone tone;
  final KitTone kit;
  final String asset;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isError = tone == StateTone.error;
    final base = isError ? DesignColors.error : kit.accentDark;
    return Center(
      child: EntranceOnce(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      DesignColors.tint(base, Alpha.soft),
                      DesignColors.tint(base, Alpha.faint),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: isError
                      ? const Icon(Icons.cloud_off_rounded, size: 34, color: DesignColors.error)
                      : TravelIcon(asset, size: 40),
                ),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.2)),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(message!,
                    textAlign: TextAlign.center,
                    style: TypeTokens.style(14, FontWeight.w400, color: TypeTokens.secondary)),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                isError
                    ? SecondaryButton(label: actionLabel!, onPressed: onAction, tone: kit, expand: false)
                    : PrimaryButton(label: actionLabel!, onPressed: onAction, tone: kit, expand: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
