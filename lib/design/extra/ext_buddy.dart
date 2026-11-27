import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../tokens/alpha_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/design_scale.dart';
import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'kit_tone.dart';
import 'pill_buttons_3d.dart';

abstract final class BuddyInk {
  static final ListingTone tone = ListingTone(
    g1: ListingPalette.teal.g2,
    g2: DesignColors.tealDeep,
    shadow: DesignColors.tealDeep.withValues(alpha: Alpha.v45),
    haloBase: ListingPalette.teal.g2,
    text: DesignColors.tealDeep,
  );
  static Color get tint => ListingPalette.teal.tint;
  static Color get artTint => ListingPalette.teal.g2.withValues(alpha: Alpha.v16);
  static List<BoxShadow> get qrShadow => [
        BoxShadow(color: DesignColors.shadowBase.withValues(alpha: Alpha.soft), offset: DS.shadowOffset(const Offset(1.1, 6)), blurRadius: DS.shadowBlur(16)),
      ];
}

class BuddyRoundButton extends StatelessWidget {
  const BuddyRoundButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = SizedBox(
      width: DS.s(KitMetrics.touch),
      height: DS.s(KitMetrics.touch),
      child: Center(
        child: Container(
          width: DS.s(42),
          height: DS.s(42),
          decoration: BoxDecoration(color: BuddyInk.tint, shape: BoxShape.circle),
          child: Icon(icon, size: DS.s(22), color: DesignColors.tealDeep),
        ),
      ),
    );
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: onTap == null ? Opacity(opacity: Alpha.v45, child: body) : body,
    );
  }
}

class BuddySkeletonBar extends StatelessWidget {
  const BuddySkeletonBar({super.key, this.width = 150, this.height = 14});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: DS.s(width),
          height: DS.s(height),
          decoration: BoxDecoration(color: DesignColors.skeletonBase, borderRadius: DS.circular(height / 2)),
        ),
      );
}

class UsernameLockedPill extends StatelessWidget {
  const UsernameLockedPill({super.key, required this.username, required this.art, required this.onCopy, required this.copyLabel, required this.loadingLabel, this.compact = false});

  final String? username;
  final String art;
  final VoidCallback onCopy;
  final String copyLabel;
  final String loadingLabel;
  final bool compact;

  static TextStyle get compactStyle => Ink3D.text(13.5, FontWeight.w600, Ink3D.sub, letterSpacing: 0);

  static double compactWidth(BuildContext context, String? username) {
    final double text;
    if (username == null) {
      text = DS.s(96);
    } else {
      final p = TextPainter(text: TextSpan(text: username, style: compactStyle), maxLines: 1, textDirection: TextDirection.ltr, textScaler: MediaQuery.textScalerOf(context))..layout();
      text = p.width;
      p.dispose();
    }
    return DS.s(8) + DS.s(24) + DS.s(6) + text + DS.s(34) + DS.s(4);
  }

  Widget _compact() {
    final name = username;
    final copy = Tap3D(
      onTap: name == null ? null : onCopy,
      label: copyLabel,
      child: SizedBox(
        width: DS.s(34),
        height: DS.s(KitMetrics.touch),
        child: Center(child: Icon(Icons.copy_rounded, size: DS.s(16), color: name == null ? DesignColors.tealDeep.withValues(alpha: Alpha.v45) : DesignColors.tealDeep)),
      ),
    );
    return Container(
      constraints: BoxConstraints(minHeight: DS.s(KitMetrics.touch)),
      padding: DS.insets(l: 8, t: 0, r: 0, b: 0),
      decoration: BoxDecoration(
        color: DesignColors.scaffold,
        borderRadius: DS.circular(22),
        border: Border.all(color: DesignColors.cardRing, width: DS.s(1.5)),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Opacity(opacity: Alpha.v60, child: Art3D(asset: art, size: 24, shadowBlur: 2, shadowOffset: const Offset(1, 2))),
          ),
          Gap.h(6),
          Expanded(
            child: name == null
                ? Semantics(label: loadingLabel, child: const BuddySkeletonBar(width: 96, height: 12))
                : FitLine3D(text: name, style: compactStyle),
          ),
          copy,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _compact();
    final name = username;
    return Container(
      constraints: BoxConstraints(minHeight: DS.s(58)),
      padding: EdgeInsets.fromLTRB(DS.s(8), DS.s(4), DS.s(6), DS.s(4)),
      decoration: BoxDecoration(
        color: DesignColors.scaffold,
        borderRadius: DS.circular(30),
        border: Border.all(color: DesignColors.cardRing, width: DS.s(2)),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Opacity(opacity: Alpha.v60, child: Art3D(asset: art, size: 42, shadowBlur: 3, shadowOffset: const Offset(2, 4))),
          ),
          Gap.h(10),
          Expanded(
            child: name == null
                ? Semantics(label: loadingLabel, child: const BuddySkeletonBar(width: 140, height: 16))
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(name, maxLines: 1, style: Ink3D.text(17, FontWeight.w600, Ink3D.sub)),
                  ),
          ),
          Gap.h(8),
          BuddyRoundButton(icon: Icons.copy_rounded, label: copyLabel, onTap: name == null ? null : onCopy),
        ],
      ),
    );
  }
}

class UsernameQrCard extends StatelessWidget {
  const UsernameQrCard({super.key, required this.username, required this.initial, required this.semanticsLabel});

  final String username;
  final String initial;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final avatar = DS.s(38);
    return Semantics(
      image: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Container(
        width: DS.s(176),
        height: DS.s(176),
        padding: DS.all(14),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.circular(20),
          border: Border.all(color: DesignColors.cardRing, width: DS.s(2)),
          boxShadow: BuddyInk.qrShadow,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            QrImageView(
              data: username,
              padding: EdgeInsets.zero,
              backgroundColor: DesignColors.surface,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: DesignColors.textStrong),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: DesignColors.textStrong),
            ),
            Container(
              width: avatar,
              height: avatar,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: ListingTone.indigo.gradient,
                shape: BoxShape.circle,
                border: Border.all(color: DesignColors.surface, width: DS.s(4)),
              ),
              child: initial.isEmpty
                  ? Icon(Icons.person_rounded, size: DS.s(16), color: DesignColors.onPrimary)
                  : Text(initial, maxLines: 1, textScaler: TextScaler.noScaling, style: Ink3D.text(15, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
            ),
          ],
        ),
      ),
    );
  }
}
