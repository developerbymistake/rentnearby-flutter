import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

class TripSheetFill extends StatelessWidget {
  const TripSheetFill({super.key, required this.children, this.gap = 12});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: DS.sym(h: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Gap.v(gap),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      );
}

class TripChoiceCard extends StatelessWidget {
  const TripChoiceCard({super.key, required this.art, required this.label, this.hint, required this.selected, required this.onTap, this.trailing, this.labelDot});

  final String art;
  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? labelDot;

  static double get topRoom => DS.s(26);

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    const white = DesignColors.surface;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final artSize = narrow ? 70.0 : 84.0;
    final h = hint;
    return Tap3D(
      onTap: onTap,
      label: label,
      selected: selected,
      child: Opacity(
        opacity: onTap == null ? Alpha.v45 : (selected ? 1 : Alpha.v80),
        child: Padding(
          padding: EdgeInsets.only(top: topRoom, bottom: DS.s(8)),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: BoxConstraints(minHeight: DS.s(78)),
                padding: DS.insets(l: artSize + 22, t: 12, r: 14, b: 12),
                decoration: BoxDecoration(
                  gradient: tone.gradient,
                  borderRadius: DS.br(CardRadius.card),
                  boxShadow: selected ? [BoxShadow(color: tone.shadow, offset: DS.shadowOffset(const Offset(1.1, 6)), blurRadius: DS.shadowBlur(12))] : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (labelDot != null) ...[
                                Container(
                                  width: DS.s(11),
                                  height: DS.s(11),
                                  decoration: BoxDecoration(color: labelDot, shape: BoxShape.circle, border: Border.all(color: white, width: 1.5)),
                                ),
                                Gap.h(8),
                              ],
                              Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, white))),
                            ],
                          ),
                          if (h != null)
                            Text(h, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, DesignColors.tint(white, Alpha.v92))),
                        ],
                      ),
                    ),
                    Gap.h(8),
                    trailing ??
                        Container(
                          width: DS.s(30),
                          height: DS.s(30),
                          decoration: BoxDecoration(color: DesignColors.tint(white, selected ? Alpha.full : Alpha.v30), shape: BoxShape.circle),
                          child: selected ? Icon(Icons.check_rounded, size: DS.s(20), color: tone.text) : null,
                        ),
                  ],
                ),
              ),
              Positioned(
                left: DS.s(10),
                top: -topRoom,
                child: IgnorePointer(
                  child: Art3D(asset: art, size: artSize, halo: artSize - 6, haloColor: DesignColors.tint(white, Alpha.v22)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
