import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/utils/spot_photo_url.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_strings_spots_x.dart';
import 'trip_city_tile.dart';
import 'trip_spot_detail_sheet.dart';
import 'trip_spot_row.dart';

const double _pillFont = 14;

const double _padX = 18;

double _side() => DS.s(14);

EdgeInsets _outer() => EdgeInsets.fromLTRB(_side(), DS.s(28), _side(), DS.gv(16));

List<Shadow> _shade() => [Shadow(color: Colors.black.withValues(alpha: Alpha.soft), offset: DS.shadowOffset(const Offset(0, 1)), blurRadius: DS.shadowBlur(3))];

Color _inkOf(ListingTone t) {
  if (identical(t, ListingTone.cA)) return ListingPalette.coral.text;
  if (identical(t, ListingTone.cB)) return ListingPalette.indigo.text;
  if (identical(t, ListingTone.cC)) return DesignColors.roseDeepStart;
  return t.text;
}

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
  final int index;

  const TripSpotCard({super.key, required this.spot, required this.selected, this.onToggle, this.locked = false, this.subtitle, this.dimmed = false, this.draft = false, this.cityKey, this.version, this.index = 0});

  static double get mediaHeight => DS.s(180);

  static ListingTone toneOf(int index) => TripCityTile.toneOf(index);

  static Color inkOf(int index) => _inkOf(toneOf(index));

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
    final tone = toneOf(index);
    final ink = _inkOf(tone);
    final pill = ListingTone(g1: tone.g1, g2: tone.g2, shadow: tone.shadow, haloBase: tone.haloBase, text: ink, button: ink);
    final shade = _shade();
    final scaler = MediaQuery.textScalerOf(context);
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final photo = spot.hasPhoto;
    final art = TripSpotLook.assetOf(spot.category);
    final headLeft = DS.s(photo ? 100 : _padX);
    final titleW = cardW - headLeft - DS.s(_padX);
    final titleStyle = KitText.wholeWords(spot.title, Ink3D.text(narrow ? 18 : 20, FontWeight.w700, DesignColors.surface, height: 1.2).copyWith(shadows: shade), titleW, scaler);
    final sub = subtitle ?? spot.description ?? '';
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: mediaHeight, child: photo ? _PhotoMedia(spot: spot) : _ArtMedia(asset: art, spot: spot)),
        Padding(
          padding: DS.insets(l: photo ? 100 : _padX, r: _padX),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: DS.s(36)),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(KitText.fitWords(spot.title, titleStyle, scaler, titleW - 1, 2), maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
            ),
          ),
        ),
        if (sub.isNotEmpty)
          Padding(
            padding: DS.insets(l: _padX, t: 2, r: _padX, b: 4),
            child: _Blurb(
              text: sub,
              style: Ink3D.text(12.5, FontWeight.w500, DesignColors.surface.withValues(alpha: Alpha.v92), height: 1.5).copyWith(shadows: shade),
              moreStyle: Ink3D.text(12.5, FontWeight.w700, DesignColors.surface, height: 1.5).copyWith(shadows: shade),
              onMore: open,
            ),
          ),
        _ActionBar(
          tone: pill,
          width: cardW - DS.s(_padX * 2),
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
        gradient: tone.gradient,
        borderRadius: DS.br(kMealsRadius),
        boxShadow: DS.shadows([BoxShadow(color: tone.shadow.withValues(alpha: selected ? Alpha.v30 : Alpha.v22), offset: const Offset(0, 6), blurRadius: 16)]),
      ),
      foregroundDecoration: selected
          ? BoxDecoration(borderRadius: DS.br(kMealsRadius), border: Border.all(color: ink, width: DS.s(2.5), strokeAlign: BorderSide.strokeAlignOutside))
          : null,
      child: ClipRRect(
        borderRadius: DS.br(kMealsRadius),
        child: Stack(
          children: [
            content,
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(decoration: BoxDecoration(borderRadius: DS.br(kMealsRadius), border: Border.all(color: DesignColors.surface, width: DS.s(2)))),
                ),
              ),
            if (photo)
              Positioned(
                left: DS.s(_padX),
                top: mediaHeight - DS.s(36),
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

class _Blurb extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextStyle moreStyle;
  final VoidCallback onMore;

  const _Blurb({required this.text, required this.style, required this.moreStyle, required this.onMore});

  static const int lines = 2;

  @override
  State<_Blurb> createState() => _BlurbState();
}

class _BlurbState extends State<_Blurb> {
  late final TapGestureRecognizer _tap = TapGestureRecognizer()..onTap = () => widget.onMore();
  Object? _key;
  String? _cut;

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  bool _fits(InlineSpan span, double width, TextScaler scaler, TextDirection dir) {
    final p = TextPainter(text: span, maxLines: _Blurb.lines, textDirection: dir, textScaler: scaler)..layout(maxWidth: width);
    final ok = !p.didExceedMaxLines;
    p.dispose();
    return ok;
  }

  InlineSpan _span(String head, TextStyle base) => TextSpan(style: base, children: [TextSpan(text: '$head… '), TextSpan(text: TripStringsSpotsX.more, style: widget.moreStyle)]);

  String? _measure(TextStyle base, double width, TextScaler scaler, TextDirection dir) {
    final text = widget.text;
    if (_fits(TextSpan(text: text, style: base), width, scaler, dir)) return null;
    var lo = 0, hi = text.length;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_fits(_span(text.substring(0, mid).trimRight(), base), width, scaler, dir)) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    var head = text.substring(0, lo);
    if (lo < text.length && text[lo].trim().isNotEmpty) {
      final space = head.lastIndexOf(' ');
      if (space > 0) head = head.substring(0, space);
    }
    return head.trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    var base = DefaultTextStyle.of(context).style.merge(widget.style);
    if (MediaQuery.boldTextOf(context)) base = base.merge(const TextStyle(fontWeight: FontWeight.bold));
    return LayoutBuilder(builder: (context, c) {
      final key = (widget.text, base, widget.moreStyle, c.maxWidth, scaler, dir);
      if (key != _key) {
        _key = key;
        _cut = _measure(base, c.maxWidth, scaler, dir);
      }
      final cut = _cut;
      if (cut == null) return Text(widget.text, maxLines: _Blurb.lines, overflow: TextOverflow.ellipsis, style: widget.style);
      return Text.rich(
        TextSpan(children: [TextSpan(text: '$cut… '), TextSpan(text: TripStringsSpotsX.more, style: widget.moreStyle, recognizer: _tap)]),
        maxLines: _Blurb.lines,
        overflow: TextOverflow.ellipsis,
        style: widget.style,
      );
    });
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
        _BadgeRow(spot: spot),
      ],
    );
  }
}

class _ArtMedia extends StatelessWidget {
  final String asset;
  final TripSpotModel spot;

  const _ArtMedia({required this.asset, required this.spot});

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: DS.s(20),
            top: DS.s(34),
            width: DS.s(112),
            height: DS.s(112),
            child: IgnorePointer(
              child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: DesignColors.surface.withValues(alpha: Alpha.v24))),
            ),
          ),
          Positioned(
            left: DS.s(24),
            top: DS.s(38),
            child: IgnorePointer(child: ExcludeSemantics(child: Art3D(asset: asset, size: 104))),
          ),
          _BadgeRow(spot: spot),
        ],
      );
}

class _BadgeRow extends StatelessWidget {
  final TripSpotModel spot;

  const _BadgeRow({required this.spot});

  @override
  Widget build(BuildContext context) => Positioned(
        left: DS.s(14),
        top: DS.s(12),
        right: DS.s(60),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _Badge(
                  padding: DS.insets(l: 12, t: 4, r: 12, b: 4),
                  child: Text(
                    TripSpotCategory.label(spot.category).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(10.5, FontWeight.w700, Ink3D.title, letterSpacing: 0.6),
                  ),
                ),
              ),
              if (spot.isFeatured) ...[
                SizedBox(width: DS.s(6)),
                Flexible(
                  child: _Badge(
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
              ],
            ],
          ),
        ),
      );
}

class _Badge extends StatelessWidget {
  final EdgeInsets padding;
  final Widget child;

  const _Badge({required this.padding, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: DesignColors.surface.withValues(alpha: Alpha.v92),
          borderRadius: DS.circular(14),
          boxShadow: DS.shadows([BoxShadow(color: Colors.black.withValues(alpha: Alpha.soft), offset: const Offset(0, 2), blurRadius: 8)]),
        ),
        child: Padding(padding: padding, child: child),
      );
}

class _ActionBar extends StatelessWidget {
  final ListingTone tone;
  final double width;
  final bool selected;
  final bool draft;
  final bool dimmed;
  final VoidCallback? onToggle;
  final VoidCallback onDetails;

  const _ActionBar({required this.tone, required this.width, required this.selected, required this.draft, required this.dimmed, required this.onToggle, required this.onDetails});

  static TextStyle label(ListingTone tone) => Ink3D.text(_pillFont, FontWeight.w700, tone.text);

  static double _pillW(String text, TextStyle style, TextScaler scaler) => DS.s(18) * 2 + DS.s(18) + DS.s(8) + KitText.widthOf(text, style, scaler);

  static double _detailsW(TextStyle style, TextScaler scaler) => DS.s(12) + DS.s(24) + DS.s(8) + KitText.widthOf(TripSpotRow.details, style, scaler) + DS.s(16);

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final style = label(tone);
    final circle = draft && !dimmed;
    final soft = selected && !circle;
    final text = soft ? TripStringsSpotsX.addedToTrip : TripStringsSpotsX.addToTrip;
    final rightW = circle ? DS.s(KitMetrics.touch) : _pillW(text, style, scaler);
    final detailsW = _detailsW(style, scaler);
    final stacked = detailsW + DS.s(12) + rightW > width;
    final toggle = draft && dimmed ? null : onToggle;
    final right = circle
        ? _CircleToggle(tone: tone, selected: selected, onTap: toggle)
        : soft
            ? _SoftPill(tone: tone, onTap: toggle)
            : _hit(WhitePillButton(tone: tone, label: TripStringsSpotsX.addToTrip, icon: Icons.add_rounded, height: KitMetrics.touch, fontSize: _pillFont, expand: false, onGradient: true, onTap: toggle), toggle);
    final details = _Details(tone: tone, onTap: onDetails);
    return Padding(
      padding: DS.insets(l: _padX, t: 14, r: _padX, b: 16),
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
  final ListingTone tone;
  final VoidCallback onTap;

  const _Details({required this.tone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final h = DS.s(KitMetrics.touch);
    return Tap3D(
      onTap: onTap,
      child: Container(
        height: h,
        padding: DS.insets(l: 12, r: 16),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.circular(h / 2),
          border: Border.all(color: tone.haloBase.withValues(alpha: Alpha.v24), width: DS.s(1.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: tone.tint, shape: BoxShape.circle),
              child: SizedBox(
                width: DS.s(24),
                height: DS.s(24),
                child: Icon(Icons.info_outline_rounded, size: DS.s(13), color: tone.text),
              ),
            ),
            SizedBox(width: DS.s(8)),
            Text(TripSpotRow.details, maxLines: 1, softWrap: false, style: _ActionBar.label(tone)),
          ],
        ),
      ),
    );
  }
}

class _SoftPill extends StatelessWidget {
  final ListingTone tone;
  final VoidCallback? onTap;

  const _SoftPill({required this.tone, this.onTap});

  @override
  Widget build(BuildContext context) {
    final h = DS.s(KitMetrics.touch);
    return _hit(
      Tap3D(
        onTap: onTap,
        label: TripStringsSpotsX.addedToTrip,
        selected: true,
        exclude: true,
        child: DecoratedBox(
          decoration: BoxDecoration(color: DesignColors.surface.withValues(alpha: Alpha.v92), borderRadius: BorderRadius.circular(h / 2)),
          child: SizedBox(
            height: h,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: DS.s(18)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: DS.s(18), color: tone.text),
                  SizedBox(width: DS.s(8)),
                  Text(TripStringsSpotsX.addedToTrip, maxLines: 1, softWrap: false, style: _ActionBar.label(tone)),
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
  final ListingTone tone;
  final bool selected;
  final VoidCallback? onTap;

  const _CircleToggle({required this.tone, required this.selected, this.onTap});

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
              decoration: BoxDecoration(color: selected ? tone.text : DesignColors.surface, shape: BoxShape.circle, border: selected ? Border.all(color: DesignColors.surface, width: DS.s(2)) : null),
              child: SizedBox(
                width: DS.s(26),
                height: DS.s(26),
                child: Icon(selected ? Icons.check_rounded : Icons.circle_outlined, size: DS.s(14), color: selected ? DesignColors.surface : tone.text),
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
              padding: DS.insets(l: _padX, t: 14, r: _padX, b: 16),
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
                    child: TemplatePlaceholder(height: DS.s(KitMetrics.touch), width: DS.s(150), radius: DS.radius(KitMetrics.touch / 2)),
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
