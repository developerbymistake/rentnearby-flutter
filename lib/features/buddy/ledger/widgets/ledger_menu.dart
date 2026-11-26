import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/trip_plan_header.dart';
import '../../shared/buddy_look.dart';
import '../ledger_strings.dart';

class LedgerMenuItem {
  const LedgerMenuItem({required this.label, required this.art, required this.onTap});

  final String label;
  final String art;
  final VoidCallback onTap;
}

class LedgerMenu extends StatelessWidget {
  const LedgerMenu({super.key, required this.items});

  static const Key dotsKey = ValueKey('ledger_menu_dots');

  final List<LedgerMenuItem> items;

  static Key rowKey(String label) => ValueKey('ledger_menu_$label');

  static BorderRadius get _radius =>
      DS.br(CardRadius.card);

  Future<void> _open(BuildContext context, Rect anchor) {
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
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: DS.s(220),
                padding: DS.sym(v: 4),
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: _radius,
                  boxShadow: [BoxShadow(color: BuddyLook.cardShadow.withValues(alpha: Alpha.v30), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(14))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final it in items)
                      Tap3D(
                        tapKey: rowKey(it.label),
                        label: it.label,
                        exclude: true,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          it.onTap();
                        },
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: DS.s(52)),
                          child: Padding(
                            padding: DS.sym(h: 16, v: 10),
                            child: Row(
                              children: [
                                Art3D(asset: it.art, size: 32, shadowBlur: 3, shadowOffset: const Offset(2, 3)),
                                Gap.h(12),
                                Expanded(child: Text(it.label, style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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
          label: LedgerStrings.menuLabel,
          exclude: true,
          onTap: () {
            final box = ctx.findRenderObject() as RenderBox?;
            if (box == null || !box.hasSize) return;
            _open(ctx, box.localToGlobal(Offset.zero) & box.size);
          },
          child: TripMenuDots.box(),
        ),
      );
}
