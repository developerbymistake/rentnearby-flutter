import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/utils/spot_photo_url.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_strings_spots_x.dart';
import 'trip_spot_detail_sheet.dart';
import 'trip_spot_row.dart';

final _tone = ListingTone.indigo;
const double _pillFont = 14;

double _side() => DS.s(14);

EdgeInsets _outer() => EdgeInsets.fromLTRB(_side(), DS.s(28), _side(), DS.gv(8));

class TripSpotCard extends StatelessWidget {
  final TripSpotModel spot;
  final bool selected;
  final VoidCallback? onToggle;
  final bool locked;
  final String? subtitle;
  final bool dimmed;
  final bool draft;
  final int? cityKey;
  final String? version;

  const TripSpotCard({super.key, required this.spot, required this.selected, this.onToggle, this.locked = false, this.subtitle, this.dimmed = false, this.draft = false, this.cityKey, this.version});

  static double get mediaHeight => DS.s(132);

  @override
  Widget build(BuildContext context) {
    final off = (locked && !selected) || dimmed;
    void open() => TripSpotDetailSheet.show(context, spot: spot, selected: selected, locked: locked, onToggle: onToggle, cityKey: cityKey, version: version);
    Widget body = Padding(
      padding: _outer(),
      child: LayoutBuilder(builder: (context, c) => _box(context, c.maxWidth, open)),
    );
    if (off) body = Opacity(opacity: Alpha.v60, child: body);
    return PressScale(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: open, child: body));
  }

  Widget _box(BuildContext context, double cardW, VoidCallback open) {
    final scaler = MediaQuery.textScalerOf(context);
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final photo = spot.hasPhoto;
    final art = TripSpotLook.assetOf(spot.category);
    final headLeft = DS.s(photo ? 96 : 16);
    final titleW = cardW - headLeft - DS.s(16);
    final titleStyle = KitText.wholeWords(spot.title, Ink3D.text(narrow ? 18 : 20, FontWeight.w700, Ink3D.title, height: 1.2), titleW, scaler);
    final sub = subtitle ?? spot.description ?? '';
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: mediaHeight, child: photo ? _PhotoMedia(spot: spot) : _ArtMedia(asset: art, featured: spot.isFeatured)),
        Padding(
          padding: DS.insets(l: photo ? 96 : 16, t: 10, r: 16, b: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: DS.s(2)),
                child: Text(
                  TripSpotCategory.label(spot.category).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(10.5, FontWeight.w700, _tone.text, letterSpacing: 0.6),
                ),
              ),
              Text(KitText.fitWords(spot.title, titleStyle, scaler, titleW - 1, 2), maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
            ],
          ),
        ),
        if (sub.isNotEmpty)
          Padding(
            padding: DS.insets(l: 16, t: 6, r: 16, b: 4),
            child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Ink3D.body.withValues(alpha: Alpha.high), height: 1.5)),
          ),
        _ActionBar(
          width: cardW - DS.s(32),
          selected: selected,
          draft: draft,
          dimmed: dimmed,
          onToggle: onToggle,
          onDetails: open,
        ),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(kMealsRadius),
        boxShadow: DS.shadows([BoxShadow(color: _tone.shadow.withValues(alpha: selected ? Alpha.v30 : Alpha.v22), offset: const Offset(0, 6), blurRadius: 16)]),
      ),
      foregroundDecoration: selected
          ? BoxDecoration(borderRadius: DS.br(kMealsRadius), border: Border.all(color: _tone.g2, width: DS.s(2.5), strokeAlign: BorderSide.strokeAlignOutside))
          : null,
      child: ClipRRect(
        borderRadius: DS.br(kMealsRadius),
        child: Stack(
          children: [
            content,
            if (photo)
              Positioned(
                left: DS.s(16),
                top: DS.s(96),
                child: IgnorePointer(
                  child: ExcludeSemantics(child: Art3D(asset: art, size: 72, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.3)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoMedia extends StatelessWidget {
  final TripSpotModel spot;

  const _PhotoMedia({required this.spot});

  @override
  Widget build(BuildContext context) {
    final extra = spot.photos.length - 1;
    return Stack(
      fit: StackFit.expand,
      children: [
        TripSpotMedia(spot: spot, size: SpotPhotoSize.card),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: DS.s(60),
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Ink3D.title.withValues(alpha: Alpha.scrim), Ink3D.title.withValues(alpha: Alpha.none)],
                ),
              ),
            ),
          ),
        ),
        if (extra > 0) Positioned(right: DS.s(12), top: DS.s(12), child: TripPhotoCount(count: extra)),
        if (spot.isFeatured) const _FeaturedSlot(),
      ],
    );
  }
}

class _ArtMedia extends StatelessWidget {
  final String asset;
  final bool featured;

  const _ArtMedia({required this.asset, required this.featured});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(gradient: _tone.gradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: DS.s(20),
              top: DS.s(10),
              width: DS.s(112),
              height: DS.s(112),
              child: IgnorePointer(
                child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: DesignColors.surface.withValues(alpha: Alpha.v24))),
              ),
            ),
            Positioned(
              left: DS.s(24),
              top: DS.s(14),
              child: IgnorePointer(child: ExcludeSemantics(child: Art3D(asset: asset, size: 104))),
            ),
            if (featured) const _FeaturedSlot(),
          ],
        ),
      );
}

class _FeaturedSlot extends StatelessWidget {
  const _FeaturedSlot();

  @override
  Widget build(BuildContext context) => Positioned(
        left: DS.s(14),
        top: DS.s(12),
        right: DS.s(60),
        child: Align(
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: DesignColors.surface.withValues(alpha: Alpha.v92),
              borderRadius: DS.circular(14),
              boxShadow: DS.shadows([BoxShadow(color: Colors.black.withValues(alpha: Alpha.soft), offset: const Offset(0, 2), blurRadius: 8)]),
            ),
            child: Padding(
              padding: DS.insets(l: 10, t: 4, r: 12, b: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: DS.s(14), color: Ink3D.title),
                  SizedBox(width: DS.s(4)),
                  Flexible(child: Text(TripStringsSpotsX.featured, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, Ink3D.title))),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ActionBar extends StatelessWidget {
  final double width;
  final bool selected;
  final bool draft;
  final bool dimmed;
  final VoidCallback? onToggle;
  final VoidCallback onDetails;

  const _ActionBar({required this.width, required this.selected, required this.draft, required this.dimmed, required this.onToggle, required this.onDetails});

  static TextStyle get _label => Ink3D.text(_pillFont, FontWeight.w700, _tone.text);

  static double _pillW(String text, TextScaler scaler) => DS.s(18) * 2 + DS.s(18) + DS.s(8) + KitText.widthOf(text, _label, scaler);

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final circle = draft && !dimmed;
    final soft = selected && !circle;
    final label = soft ? TripStringsSpotsX.addedToTrip : TripStringsSpotsX.addToTrip;
    final rightW = circle ? DS.s(KitMetrics.touch) : _pillW(label, scaler);
    final detailsW = DS.s(26) + DS.s(8) + KitText.widthOf(TripSpotRow.details, _label, scaler);
    final stacked = detailsW + DS.s(12) + rightW > width;
    final toggle = draft && dimmed ? null : onToggle;
    final right = circle
        ? _CircleToggle(selected: selected, onTap: toggle)
        : soft
            ? _SoftPill(onTap: toggle)
            : _hit(GradientPillButton(tone: _tone, label: TripStringsSpotsX.addToTrip, icon: Icons.add_rounded, height: 38, fontSize: _pillFont, expand: false, onTap: toggle), toggle);
    final details = _Details(onTap: onDetails);
    final edge = (DS.s(KitMetrics.touch) - DS.s(38)) / 2;
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(8) - edge, DS.s(16), DS.s(12) - edge),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(alignment: Alignment.centerLeft, child: details),
                Gap.v(8),
                Align(alignment: Alignment.centerRight, child: right),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [details, right],
            ),
    );
  }
}

Widget _hit(Widget child, VoidCallback? onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap ?? () {},
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DS.s(KitMetrics.touch)),
        child: Center(widthFactor: 1, child: child),
      ),
    );

class _Details extends StatelessWidget {
  final VoidCallback onTap;

  const _Details({required this.onTap});

  @override
  Widget build(BuildContext context) => Tap3D(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: DS.s(KitMetrics.touch)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: _tone.tint, shape: BoxShape.circle),
                child: SizedBox(
                  width: DS.s(26),
                  height: DS.s(26),
                  child: Icon(Icons.info_outline_rounded, size: DS.s(14), color: _tone.text),
                ),
              ),
              SizedBox(width: DS.s(8)),
              Text(TripSpotRow.details, maxLines: 1, softWrap: false, style: _ActionBar._label),
            ],
          ),
        ),
      );
}

class _SoftPill extends StatelessWidget {
  final VoidCallback? onTap;

  const _SoftPill({this.onTap});

  @override
  Widget build(BuildContext context) {
    final h = DS.s(38);
    return _hit(
      Tap3D(
        onTap: onTap,
        label: TripStringsSpotsX.addedToTrip,
        selected: true,
        exclude: true,
        child: DecoratedBox(
          decoration: BoxDecoration(color: _tone.tint, borderRadius: BorderRadius.circular(h / 2)),
          child: SizedBox(
            height: h,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: DS.s(18)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: DS.s(18), color: _tone.text),
                  SizedBox(width: DS.s(8)),
                  Text(TripStringsSpotsX.addedToTrip, maxLines: 1, softWrap: false, style: _ActionBar._label),
                ],
              ),
            ),
          ),
        ),
      ),
      onTap,
    );
  }
}

class _CircleToggle extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;

  const _CircleToggle({required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) => Tap3D(
        onTap: onTap,
        label: selected ? TripStringsSpotsX.addedToTrip : TripStringsSpotsX.addToTrip,
        selected: selected,
        exclude: true,
        child: SizedBox(
          width: DS.s(KitMetrics.touch),
          height: DS.s(KitMetrics.touch),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(color: selected ? _tone.button : _tone.tint, shape: BoxShape.circle),
              child: SizedBox(
                width: DS.s(26),
                height: DS.s(26),
                child: Icon(selected ? Icons.check_rounded : Icons.circle_outlined, size: DS.s(14), color: selected ? DesignColors.surface : _tone.text),
              ),
            ),
          ),
        ),
      );
}

class TripSpotCardSkeleton extends StatelessWidget {
  const TripSpotCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    double t(double n) => scaler.scale(DS.s(n));
    return Padding(
      padding: _outer(),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(kMealsRadius), boxShadow: DS.shadows(Ink3D.softShadow)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TemplatePlaceholder(height: TripSpotCard.mediaHeight, radius: 0),
            Padding(
              padding: DS.insets(l: 16, t: 14, r: 16, b: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TemplatePlaceholder(height: t(16), width: DS.s(130), radius: DS.radius(8)),
                  SizedBox(height: DS.s(10)),
                  TemplatePlaceholder(height: t(10), radius: DS.radius(8)),
                  SizedBox(height: DS.s(8)),
                  TemplatePlaceholder(height: t(10), width: DS.s(90), radius: DS.radius(8)),
                  SizedBox(height: DS.s(14)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TemplatePlaceholder(height: DS.s(38), width: DS.s(150), radius: DS.radius(19)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
