import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/sheet_close_button.dart';
import 'package:bakhli/utils/spot_photo_url.dart';
import '../data/spot_gallery_loader.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_strings_spots_x.dart';
import '../utils/spot_gallery_cache.dart';
import '../utils/trip_format.dart';
import '../utils/trip_spots_cache.dart';
import 'spot_gallery_collage.dart';
import 'spot_photo_viewer.dart';
import 'trip_spot_row.dart';

class TripSpotDetailSheet extends StatefulWidget {
  final TripSpotModel spot;
  final bool selected;
  final bool locked;
  final VoidCallback? onToggle;
  final int? cityKey;
  final String? version;
  final bool partial;
  final bool showAction;
  final bool revalidate;

  const TripSpotDetailSheet({
    super.key,
    required this.spot,
    required this.selected,
    required this.locked,
    this.onToggle,
    this.cityKey,
    this.version,
    this.partial = false,
    this.showAction = true,
    this.revalidate = false,
  });

  static Future<void> show(
    BuildContext context, {
    required TripSpotModel spot,
    required bool selected,
    required bool locked,
    VoidCallback? onToggle,
    int? cityKey,
    String? version,
    bool partial = false,
    bool showAction = true,
    bool revalidate = false,
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
          cityKey: cityKey,
          version: version,
          partial: partial,
          showAction: showAction,
          revalidate: revalidate,
        ),
      ),
    );
  }

  static double heroHeight(double width) => math.max(DS.s(200), math.min(DS.s(248), width * 0.62));

  @override
  State<TripSpotDetailSheet> createState() => _TripSpotDetailSheetState();
}

class _TripSpotDetailSheetState extends State<TripSpotDetailSheet>
    with TickerProviderStateMixin {
  static double get _overlap => DS.s(24);
  static const int _descriptionLines = 4;
  static const double _readMoreFont = 13;

  final _page = PageController();
  late final AnimationController _enter = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  );
  int _index = 0;
  bool _expanded = false;
  late TripSpotModel _spot = widget.spot;
  SpotGalleryState? _gallery;
  List<String> _urls = const [];

  String get _version => widget.version ?? '';

  bool get _expectsGallery => _spot.galleryCount > 0;

  @override
  void initState() {
    super.initState();
    _enter.forward();
    final cityKey = widget.cityKey;
    if (cityKey == null || !(widget.revalidate || widget.partial || widget.spot.galleryCount > 0)) return;
    final hit = SpotGalleryCache.get(cityKey, widget.spot.id, _version);
    if (hit != null) _apply(hit);
    if (hit == null || widget.revalidate) {
      if (hit == null) _gallery = SpotGalleryState.loading;
      _fetch();
    }
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

  void _apply(SpotDetail d) {
    final s = d.spot;
    if ((widget.partial || widget.revalidate) && s != null) {
      _spot = s;
      if (_index >= math.max(1, s.photos.length)) _index = 0;
    }
    _urls = d.gallery;
    _gallery = SpotGalleryState.ready;
  }

  // A newer server answer means the stored city list is stale: drop it so the map memo and list reload.
  static void _dropStaleList(int cityKey, String answerVersion) {
    if (answerVersion.isEmpty) return;
    final listed = TripSpotsCache.versionOf(cityKey);
    if (listed != null && listed != answerVersion) TripSpotsCache.remove(cityKey);
  }

  void _retry() {
    setState(() => _gallery = SpotGalleryState.loading);
    _fetch();
  }

  Future<void> _fetch() async {
    final cityKey = widget.cityKey;
    if (cityKey == null) return;
    try {
      final d = await SpotGalleryLoader.load(cityKey, widget.spot.id, _version, revalidate: widget.revalidate);
      if (widget.revalidate) _dropStaleList(cityKey, d.version);
      if (!mounted) return;
      setState(() => _apply(d));
    } catch (_) {
      if (!mounted) return;
      if (_gallery == SpotGalleryState.ready) return;
      if (widget.revalidate && !widget.partial && !_expectsGallery) {
        setState(() => _gallery = null);
        return;
      }
      setState(() => _gallery = SpotGalleryState.error);
    }
  }

  bool get _showGallery => switch (_gallery) {
        SpotGalleryState.ready => _urls.isNotEmpty,
        SpotGalleryState.loading => _expectsGallery,
        SpotGalleryState.error => _expectsGallery || widget.partial,
        null => false,
      };

  void _openPhotos(int i) => SpotPhotoViewer.open(
        context,
        urls: _spot.photos,
        initialIndex: i,
        title: _spot.title,
        fallbackAsset: TripSpotLook.assetOf(_spot.category),
      );

  void _openGallery(int i) {
    final urls = _urls;
    final w = (context.size?.width ?? MediaQuery.sizeOf(context).width) - 2 * DS.s(20);
    SpotPhotoViewer.open(
      context,
      urls: urls,
      initialIndex: i,
      title: _spot.title,
      fallbackAsset: TripSpotLook.assetOf(_spot.category),
      placeholderSizeOf: (j) => SpotGalleryCollage.sizeOf(j, w, urls.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spot = _spot;
    final photos = spot.photos;
    final area = spot.area;
    final description = spot.description;
    final hasDescription = description != null && description.isNotEmpty;
    final showGallery = _showGallery;
    final count = 2 + (hasDescription ? 1 : 0) + (showGallery ? 1 : 0) + (widget.showAction ? 1 : 0);
    var slot = 1;
    Widget wrap(int i, Widget child) => TemplateEntrance(
      animation: templateInterval(_enter, i, count),
      animationController: _enter,
      child: child,
    );
    return SafeArea(
      top: false,
      child: LayoutBuilder(builder: (context, c) {
        final heroH = TripSpotDetailSheet.heroHeight(c.maxWidth.isFinite ? c.maxWidth : MediaQuery.sizeOf(context).width);
        return SingleChildScrollView(
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: heroH,
                child: wrap(
                  0,
                  ClipRRect(
                    borderRadius: DS.br(CardRadius.sheet),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (photos.isEmpty)
                          TripSpotMedia(spot: spot, size: SpotPhotoSize.hero)
                        else
                          PageView.builder(
                            controller: _page,
                            itemCount: photos.length,
                            onPageChanged: (i) => setState(() => _index = i),
                            itemBuilder: (_, i) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              excludeFromSemantics: true,
                              onTap: () => _openPhotos(i),
                              child: Semantics(
                                label: TripStringsSpotsX.photoOf(spot.title, i + 1, photos.length),
                                image: true,
                                button: true,
                                onTap: () => _openPhotos(i),
                                child: TripSpotMedia(spot: spot, url: photos[i], size: SpotPhotoSize.hero),
                              ),
                            ),
                          ),
                        Positioned(
                          top: DS.s(10),
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (photos.length > 1)
                Positioned(
                  top: heroH - _overlap - DS.s(20),
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
                padding: EdgeInsets.only(top: heroH - _overlap),
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
                        slot++,
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
                                      if (spot.isFeatured) _meta(TripStringsSpotsX.featured),
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
                        wrap(slot++, _description(description)),
                      ],
                      if (showGallery) ...[
                        Gap.v(16),
                        wrap(
                          slot++,
                          SpotGallerySection(
                            state: _gallery!,
                            urls: _urls,
                            title: spot.title,
                            fallbackAsset: TripSpotLook.assetOf(spot.category),
                            onTap: _openGallery,
                            onRetry: _retry,
                          ),
                        ),
                      ],
                      if (widget.showAction) ...[
                        Gap.v(16),
                        wrap(slot++, _action()),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(top: DS.s(12), right: DS.s(12), child: const SheetCloseButton()),
            ],
          ),
        );
      }),
    );
  }

  Widget _description(String text) {
    final style = TypeTokens.style(14, FontWeight.w400, color: TypeTokens.secondary, height: 1.45);
    return LayoutBuilder(builder: (context, c) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: _descriptionLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: c.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            maxLines: _expanded ? null : _descriptionLines,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: style,
          ),
          if (overflows) ...[
            Gap.v(10),
            WhitePillButton(
              tone: ListingTone.indigo,
              label: _expanded ? TripStringsSpotsX.showLess : TripStringsSpotsX.readMore,
              onTap: () => setState(() => _expanded = !_expanded),
              height: 34,
              fontSize: _readMoreFont,
              expand: false,
            ),
          ],
        ],
      );
    });
  }

  Widget _action() {
    final enabled = widget.onToggle != null;
    final outlined = widget.selected && enabled;
    final label = widget.selected
        ? (widget.onToggle == null ? TripStringsSpotsX.addedToTrip : TripStringsSpotsX.remove)
        : TripStringsSpotsX.addToTrip;
    final onTap = enabled
        ? () {
            Navigator.of(context).pop();
            widget.onToggle!();
          }
        : null;
    final tone = ListingTone.indigo;
    final button = outlined
        ? WhitePillButton(tone: tone, label: label, onTap: onTap)
        : GradientPillButton(tone: tone, label: label, onTap: onTap);
    return widget.locked && !widget.selected ? Opacity(opacity: Alpha.v45, child: button) : button;
  }

  Widget _meta(String label) => Container(
    padding: DS.sym(h: 12, v: 5),
    decoration: BoxDecoration(color: ListingTone.indigo.tint, borderRadius: DS.br(CardRadius.pill)),
    child: Text(label, style: Ink3D.text(12.5, FontWeight.w600, ListingTone.indigo.text)),
  );
}
