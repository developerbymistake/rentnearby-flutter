import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/trip_plan_header.dart';
import '../../shared/buddy_look.dart';
import '../buddies_strings.dart';

class BuddiesHeaderMenu extends StatelessWidget {
  const BuddiesHeaderMenu({super.key, required this.blockedCount, required this.onBlocked});

  static const Key dotsKey = ValueKey('buddies-header-dots');
  static const Key rowKey = ValueKey('buddies-menu-blocked');

  final int Function() blockedCount;
  final VoidCallback onBlocked;

  static Future<void> open(BuildContext context, {required Rect anchor, required int blocked, required VoidCallback onBlocked}) {
    final width = MediaQuery.sizeOf(context).width;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (ctx, _, _) => Stack(
        children: [
          Positioned(
            top: anchor.bottom + DS.s(6),
            right: (width - anchor.right).clamp(DS.s(14), width),
            child: _Popup(
              blocked: blocked,
              onTap: () {
                Navigator.of(ctx).pop();
                onBlocked();
              },
            ),
          ),
        ],
      ),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  Widget build(BuildContext context) => Builder(
        builder: (ctx) => Tap3D(
          tapKey: dotsKey,
          label: BuddiesStrings.menuLabel,
          exclude: true,
          onTap: () {
            final box = ctx.findRenderObject() as RenderBox?;
            if (box == null || !box.hasSize) return;
            final anchor = box.localToGlobal(Offset.zero) & box.size;
            open(ctx, anchor: anchor, blocked: blockedCount(), onBlocked: onBlocked);
          },
          child: TripMenuDots.box(),
        ),
      );
}

class _Popup extends StatelessWidget {
  const _Popup({required this.blocked, required this.onTap});

  final int blocked;
  final VoidCallback onTap;

  static BorderRadius get radius =>
      DS.br(CardRadius.card);

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Container(
          width: DS.s(230),
          padding: DS.sym(v: 4),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: radius,
            border: Border.all(color: ListingPalette.indigo.g2.withValues(alpha: Alpha.v22), width: DS.s(2)),
            boxShadow: [BoxShadow(color: BuddyLook.cardShadow.withValues(alpha: Alpha.v30), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(14))],
          ),
          child: Tap3D(
            tapKey: BuddiesHeaderMenu.rowKey,
            onTap: onTap,
            label: BuddiesStrings.blockedTitle,
            exclude: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: DS.s(56)),
              child: Padding(
                padding: DS.sym(h: 16, v: 12),
                child: Row(
                  children: [
                    Art3D(asset: BuddyArt.shield, size: 36, shadowBlur: 3, shadowOffset: const Offset(2, 3)),
                    Gap.h(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(BuddiesStrings.blockedTitle, style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                          if (blocked > 0) Text(BuddiesStrings.people(blocked), style: Ink3D.text(12.5, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
