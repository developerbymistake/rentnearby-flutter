import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_constants.dart';
import '../trip_strings_v2_plan.dart';

class TripPaceSheet {
  static Future<int?> show(BuildContext context) {
    final current = TripPlanController.to.settings.dayLimitMinutes;
    return SheetFrame.show<int>(
      context,
      builder: (ctx) => SheetFrame(
        tone: ListingTone.indigo,
        art: ListingArt.sunrise,
        size: SheetSize.confirm,
        scrollable: false,
        padding: const EdgeInsets.only(bottom: 20),
        title: TripStringsV2Plan.paceTitle,
        subtitle: TripStringsV2Plan.paceSub,
        footer: Text(
          TripStringsV2Plan.paceFooter,
          textAlign: TextAlign.center,
          style: Ink3D.text(12, FontWeight.w400, Ink3D.grey),
        ),
        child: TripSheetFill(
          children: [
            TripChoiceCard(
              art: ListingArt.tent,
              label: TripStringsV2Plan.paceRelaxed,
              hint: TripStringsV2Plan.paceRelaxedHint,
              selected: current <= TripPace.relaxed,
              onTap: () => Navigator.pop(ctx, current <= TripPace.relaxed ? null : TripPace.relaxed),
            ),
            TripChoiceCard(
              art: ListingArt.backpack,
              label: TripStringsV2Plan.paceNormal,
              hint: TripStringsV2Plan.paceNormalHint,
              selected: current > TripPace.relaxed,
              onTap: () => Navigator.pop(ctx, current > TripPace.relaxed ? null : TripPace.normal),
            ),
          ],
        ),
      ),
    );
  }
}

class TripSheetFill extends StatelessWidget {
  const TripSheetFill({super.key, required this.children, this.gap = 12});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(height: gap),
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

  static const double topRoom = 26;

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
          padding: const EdgeInsets.only(top: topRoom, bottom: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 78),
                padding: EdgeInsets.fromLTRB(artSize + 22, 12, 14, 12),
                decoration: BoxDecoration(
                  gradient: tone.gradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(32),
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  boxShadow: selected ? [BoxShadow(color: tone.shadow, offset: const Offset(1.1, 6), blurRadius: 12)] : null,
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
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(color: labelDot, shape: BoxShape.circle, border: Border.all(color: white, width: 1.5)),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, white))),
                            ],
                          ),
                          if (h != null)
                            Text(h, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, DesignColors.tint(white, Alpha.v92))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    trailing ??
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: DesignColors.tint(white, selected ? Alpha.full : Alpha.v30), shape: BoxShape.circle),
                          child: selected ? Icon(Icons.check_rounded, size: 20, color: tone.text) : null,
                        ),
                  ],
                ),
              ),
              Positioned(
                left: 10,
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
