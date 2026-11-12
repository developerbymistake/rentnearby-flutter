import 'package:flutter/material.dart';
import '../../../design/design.dart';

class StayPageHeader extends StatelessWidget {
  const StayPageHeader({
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
    return ModuleHeader(
      tone: KitTone.stay,
      title: title,
      subtitle: subtitle,
      onBack: showBack ? (onBack ?? () => Navigator.maybePop(context)) : null,
      trailing: [
        if (trailing != null) trailing!,
        const SizedBox(width: 8),
        Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: DesignColors.tint(DesignColors.surfaceAlt, Alpha.soft), shape: BoxShape.circle),
          child: Image.asset(asset),
        ),
      ],
    );
  }
}

class StayFooter extends StatelessWidget {
  const StayFooter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: DesignColors.surface, boxShadow: ShadowTokens.elev3Up),
      padding: EdgeInsets.fromLTRB(KitMetrics.gutter, 12, KitMetrics.gutter, MediaQuery.viewPaddingOf(context).bottom + 16),
      child: child,
    );
  }
}

class StayBusy extends StatelessWidget {
  const StayBusy({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: DesignColors.scrim,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(KitMetrics.gutter),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              color: DesignColors.surface,
              borderRadius: CardRadius.tile,
              boxShadow: ShadowTokens.elev3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(color: DesignColors.primary, strokeWidth: 3),
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: TypeTokens.style(14, FontWeight.w500, color: DesignColors.textStrong)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StayConfirmDialog extends StatelessWidget {
  const StayConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.destructive = false,
  });

  final String title;
  final String body;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DesignColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 24),
      shape: const RoundedRectangleBorder(borderRadius: CardRadius.tile),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: TypeTokens.style(18, FontWeight.w700, color: DesignColors.textStrong)),
              const SizedBox(height: 8),
              Text(body, style: TypeTokens.style(14, FontWeight.w400, color: DesignColors.textSecondary, height: 1.4)),
              const SizedBox(height: 20),
              ButtonPair(
                first: SecondaryButton(label: cancelLabel, onPressed: onCancel, tone: KitTone.stay, neutral: true),
                second: PrimaryButton(
                  label: confirmLabel,
                  onPressed: onConfirm,
                  tone: destructive ? KitTone.danger : KitTone.stay,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
