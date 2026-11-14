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
      shape: const RoundedRectangleBorder(borderRadius: CardRadius.sheet),
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
  static const double _photoHeight = 248;
  static const double _overlap = 24;

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
                  borderRadius: CardRadius.sheet,
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
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: DesignColors.tint(DesignColors.surface, Alpha.strong),
                              borderRadius: BorderRadius.circular(2),
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
                top: _photoHeight - _overlap - 20,
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
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _index ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? DesignColors.surface
                                : DesignColors.tint(DesignColors.surface, Alpha.strong),
                            borderRadius: CardRadius.pill,
                            boxShadow: ShadowTokens.elev1,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: _photoHeight - _overlap),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: CardRadius.sheet,
                  boxShadow: ShadowTokens.elev3,
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _meta(TripSpotCategory.label(spot.category)),
                                    if (area != null && area.isNotEmpty) _meta(area),
                                    _meta('~${TripFormat.visit(spot.visitMinutes)}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Transform.translate(
                            offset: const Offset(0, -10),
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
                      const SizedBox(height: 12),
                      wrap(
                        2,
                        Text(
                          description,
                          style: TypeTokens.style(14, FontWeight.w400,
                              color: TypeTokens.secondary, height: 1.45),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    wrap(count - 1, _action()),
                  ],
                ),
              ),
            ),
            const Positioned(top: 12, right: 12, child: SheetCloseButton()),
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
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: ListingTone.indigo.tint, borderRadius: CardRadius.pill),
    child: Text(label, style: Ink3D.text(12.5, FontWeight.w600, ListingTone.indigo.text)),
  );
}
