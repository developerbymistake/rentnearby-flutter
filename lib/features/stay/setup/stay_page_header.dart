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
    return SafeArea(
      bottom: false,
      child: PageHeader3D(
        tone: ListingTone.forest,
        title: title,
        subtitle: subtitle,
        art: asset,
        artSize: 100,
        onBack: showBack ? (onBack ?? () => Navigator.maybePop(context)) : null,
        trailing: trailing,
      ),
    );
  }
}

class StayFooter extends StatelessWidget {
  const StayFooter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: Ink3D.topEdge,
      ),
      padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.viewPaddingOf(context).bottom + 20),
      child: child,
    );
  }
}

class StayBusy extends StatelessWidget {
  const StayBusy({super.key, required this.message, this.art, this.progress, this.caption});

  final String message;
  final String? art;
  final double? progress;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BusyOverlay3D(tone: ListingTone.forest, message: message, art: art ?? SetupAssets.hotel, progress: progress, caption: caption),
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
    this.art,
  });

  final String title;
  final String body;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool destructive;
  final String? art;

  @override
  Widget build(BuildContext context) {
    return Dialog3D(
      tone: ListingTone.forest,
      art: art ?? ListingArt.clipboard,
      title: title,
      body: body,
      primaryLabel: confirmLabel,
      onPrimary: onConfirm,
      primaryDanger: destructive,
      secondaryLabel: cancelLabel,
      onSecondary: onCancel,
      familyCorner: true,
      tight: true,
      titleSize: 18,
    );
  }
}
