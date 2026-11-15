import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/sheet_close_button.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_strings_spots_x.dart';
import '../utils/trip_format.dart';
import 'trip_spot_row.dart';

class TripSpotDetailSheet extends StatefulWidget {
  final TripSpotModel spot;
  final bool selected;
  final bool locked;
  final VoidCallback? onToggle;

  const TripSpotDetailSheet({
    super.key,
    required this.spot,
    required this.selected,
    required this.locked,
    this.onToggle,
  });

  static Future<void> show(
    BuildContext context, {
    required TripSpotModel spot,
    required bool selected,
    required bool locked,
    VoidCallback? onToggle,
  }) {
    return showDockSheet<void>(
      context,
      backgroundColor: DesignColors.surface,
      barrierColor: DesignColors.scrim,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: DS.br(CardRadius.sheet)),
      builder: (_) => SafeArea(
        bottom: false,
        child: TripSpotDetailSheet(
          spot: spot,
          selected: selected,
          locked: locked,
          onToggle: onToggle,
        ),
      ),
    );
  }

  @override
  State<TripSpotDetailSheet> createState() => _TripSpotDetailSheetState();
}

class _TripSpotDetailSheetState extends State<TripSpotDetailSheet>
    with TickerProviderStateMixin {
  static double get _photoHeight => DS.s(248);
  static double get _overlap => DS.s(24);

  final _page = PageController();
  late final AnimationController _enter = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  );
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _enter.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KitMotion.reduce(context)) _enter.value = 1;
  }

  @override
  void dispose() {
    _enter.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final photos = spot.gallery;
    final area = spot.area;
    final description = spot.description;
    final hasDescription = description != null && description.isNotEmpty;
    final count = hasDescription ? 4 : 3;
    Widget wrap(int i, Widget child) => TemplateEntrance(
      animation: templateInterval(_enter, i, count),
      animationController: _enter,
      child: child,
    );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _photoHeight,
              child: wrap(
                0,
                ClipRRect(
                  borderRadius: DS.br(CardRadius.sheet),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (photos.isEmpty)
                        TripSpotMedia(spot: spot)
                      else
                        PageView.builder(
                          controller: _page,
                          itemCount: photos.length,
                          onPageChanged: (i) => setState(() => _index = i),
                          itemBuilder: (_, i) =>
                              TripSpotMedia(spot: spot, url: photos[i]),
                        ),
                      Positioned(
                        top: DS.s(10),
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: DS.s(36),
                            height: DS.s(4),
                            decoration: BoxDecoration(
                              color: DesignColors.tint(DesignColors.surface, Alpha.strong),
                              borderRadius: DS.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (photos.length > 1)
              Positioned(
                top: _photoHeight - _overlap - DS.s(20),
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < photos.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.fastOutSlowIn,
                          margin: EdgeInsets.symmetric(horizontal: DS.gh(3)),
                          width: DS.s(i == _index ? 16 : 6),
                          height: DS.s(6),
                          decoration: BoxDecoration(
                            color: i == _index
                                ? DesignColors.surface
                                : DesignColors.tint(DesignColors.surface, Alpha.strong),
                            borderRadius: DS.br(CardRadius.pill),
                            boxShadow: DS.shadows(ShadowTokens.elev1),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(top: _photoHeight - _overlap),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: DS.br(CardRadius.sheet),
                  boxShadow: DS.shadows(ShadowTokens.elev3),
                ),
                padding: DS.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    wrap(
                      1,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(spot.title, style: Ink3D.text(24, FontWeight.w700, Ink3D.title, height: 1.25)),
                                Gap.v(10),
                                Wrap(
                                  spacing: DS.gh(8),
                                  runSpacing: DS.gv(8),
                                  children: [
                                    _meta(TripSpotCategory.label(spot.category)),
                                    if (area != null && area.isNotEmpty) _meta(area),
                                    _meta('~${TripFormat.visit(spot.visitMinutes)}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Gap.h(10),
                          Transform.translate(
                            offset: Offset(0, DS.s(-10)),
                            child: Art3D(
                              asset: TripSpotLook.assetOf(spot.category),
                              size: 92,
                              halo: 96,
                              haloColor: ListingTone.indigo.tint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasDescription) ...[
                      Gap.v(12),
                      wrap(
                        2,
                        Text(
                          description,
                          style: TypeTokens.style(14, FontWeight.w400,
                              color: TypeTokens.secondary, height: 1.45),
                        ),
                      ),
                    ],
                    Gap.v(16),
                    wrap(count - 1, _action()),
                  ],
                ),
              ),
            ),
            Positioned(top: DS.s(12), right: DS.s(12), child: const SheetCloseButton()),
          ],
        ),
      ),
    );
  }

  Widget _action() {
    final enabled = widget.onToggle != null;
    final outlined = widget.selected && enabled;
    final label = widget.selected
        ? (widget.onToggle == null ? TripStringsSpotsX.addedWishlist : 'Remove')
        : TripStringsSpotsX.addToWishlist;
    final onTap = enabled
        ? () {
            Navigator.of(context).pop();
            widget.onToggle!();
          }
        : null;
    final tone = ListingTone.indigo;
    return outlined
        ? WhitePillButton(tone: tone, label: label, onTap: onTap)
        : GradientPillButton(tone: tone, label: label, onTap: onTap);
  }

  Widget _meta(String label) => Container(
    padding: DS.sym(h: 12, v: 5),
    decoration: BoxDecoration(color: ListingTone.indigo.tint, borderRadius: DS.br(CardRadius.pill)),
    child: Text(label, style: Ink3D.text(12.5, FontWeight.w600, ListingTone.indigo.text)),
  );
}
