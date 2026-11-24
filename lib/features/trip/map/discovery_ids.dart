import 'package:bakhli/design/design.dart';

class DiscIds {
  static const String srcAll = 'disc-all';
  static const String srcPhoto = 'disc-photo';
  static const String srcSel = 'disc-sel';
  static const List<String> sources = [srcAll, srcPhoto, srcSel];

  static const String layerDots = 'disc-dots';
  static const String layerBadge = 'disc-badge';
  static const String layerPhoto = 'disc-photo';
  static const String layerSelHalo = 'disc-sel-halo';
  static const String layerSelDot = 'disc-sel-dot';
  static const String layerSelIcon = 'disc-sel-icon';
  static const List<String> layers = [layerDots, layerBadge, layerPhoto, layerSelHalo, layerSelDot, layerSelIcon];
  static const List<String> discoveryLayers = [layerDots, layerBadge, layerPhoto];
  static const List<String> tapLayers = [layerBadge, layerPhoto];

  static const String badgePrefix = 'disc-b-';
  static const String photoPrefix = 'disc-p-';
  static const String badgeDefault = 'place';

  static const List<String> badgeCategories = [
    'temple', 'fort', 'palace', 'museum', 'lake', 'waterfall', 'viewpoint', 'park', 'garden',
    'zoo', 'wildlife', 'bridge', 'ghat', 'cave', 'historic', 'beach', badgeDefault,
  ];

  static String badgeKey(String category) =>
      badgeCategories.contains(category) ? category : badgeDefault;

  static String badgeImage(String category) => '$badgePrefix${badgeKey(category)}';

  static String photoImage(String spotId) => '$photoPrefix$spotId';

  static String photoSlot(int i) => '${photoPrefix}slot-$i';

  static bool isPhotoImage(String name) => name.startsWith(photoPrefix);

  static String? spotIdOfPhotoImage(String name) =>
      isPhotoImage(name) && name.length > photoPrefix.length ? name.substring(photoPrefix.length) : null;
}

enum DiscLayerKind { circle, symbol }

class DiscLayerSpec {
  final String id;
  final String sourceId;
  final DiscLayerKind kind;
  final List<Object>? filter;
  final double? minZoom;
  final bool interactive;

  const DiscLayerSpec({
    required this.id,
    required this.sourceId,
    required this.kind,
    this.filter,
    this.minZoom,
    this.interactive = true,
  });
}

class DiscLayers {
  static const List<Object> badgeTierFilter = ['<=', ['get', 'tier'], 2];
  static const List<Object> selDotFilter = ['==', ['get', 'kind'], 'dot'];
  static const List<Object> selIconFilter = ['in', ['get', 'kind'], ['literal', ['photo', 'badge']]];

  static List<DiscLayerSpec> specs(DiscTuning t) => [
        const DiscLayerSpec(id: DiscIds.layerDots, sourceId: DiscIds.srcAll, kind: DiscLayerKind.circle, interactive: false),
        DiscLayerSpec(
          id: DiscIds.layerBadge,
          sourceId: DiscIds.srcAll,
          kind: DiscLayerKind.symbol,
          filter: badgeTierFilter,
          minZoom: t.badgeMinZoom,
        ),
        const DiscLayerSpec(id: DiscIds.layerPhoto, sourceId: DiscIds.srcPhoto, kind: DiscLayerKind.symbol),
        const DiscLayerSpec(id: DiscIds.layerSelHalo, sourceId: DiscIds.srcSel, kind: DiscLayerKind.circle, interactive: false),
        const DiscLayerSpec(
          id: DiscIds.layerSelDot,
          sourceId: DiscIds.srcSel,
          kind: DiscLayerKind.circle,
          filter: selDotFilter,
          interactive: false,
        ),
        const DiscLayerSpec(
          id: DiscIds.layerSelIcon,
          sourceId: DiscIds.srcSel,
          kind: DiscLayerKind.symbol,
          filter: selIconFilter,
          interactive: false,
        ),
      ];

  static const List<Object> iconImageBadge = ['concat', DiscIds.badgePrefix, ['get', 'cat']];
  static const List<Object> iconImagePhoto = ['get', 'img'];
  static const List<Object> sortKey = ['get', 'rank'];
}

class DiscTuning {
  final int photoMax;
  final int badgeMax;
  final double photoDp;
  final double pxPerDp;
  final int batch;
  final double hitDp;
  final double badgeMinZoom;
  final int maxDownloads;
  final double dotDp;
  final double selDotDp;
  final double badgeDp;
  final double haloPhotoDp;
  final double haloDotDp;
  final double photoAreaFactor;
  final int markerCacheMax;
  final int thumbPx;
  final double? photoMinDp;
  final double? badgeMinDp;
  final double? dotMinDp;
  final double? selDotMinDp;
  final double? photoMidDp;
  final double? badgeMidDp;
  final double? dotMidDp;
  final double? selDotMidDp;
  final double? stopBadgeDp;

  static const double zoomOut = 10;
  static const double zoomMid = 14;
  static const double zoomIn = 17;

  const DiscTuning({
    required this.photoMax,
    required this.photoDp,
    this.badgeMax = 120,
    this.pxPerDp = 1.0,
    this.batch = 8,
    this.hitDp = 44,
    this.badgeMinZoom = 12,
    this.maxDownloads = 4,
    this.dotDp = 9,
    this.selDotDp = 14,
    this.badgeDp = 24,
    this.haloPhotoDp = 72,
    this.haloDotDp = 36,
    this.photoAreaFactor = 2,
    this.markerCacheMax = 300,
    this.thumbPx = 96,
    this.photoMinDp,
    this.badgeMinDp,
    this.dotMinDp,
    this.selDotMinDp,
    this.photoMidDp,
    this.badgeMidDp,
    this.dotMidDp,
    this.selDotMidDp,
    this.stopBadgeDp,
  });

  static DiscTuning get trip => _shared(photoMax: 40);

  static DiscTuning get stay => _shared(photoMax: 24);

  // Owner order 2026-11-24: design units (DS gives 80%), so the phone gets photo 44 / 60 / 72, badge 30 / 40 / 48,
  // dot 18 / 28 / 34, selected dot 26 / 36 / 43 dp at zoom 10 / 14 / 17; the full size is the drawn size.
  static DiscTuning _shared({required int photoMax}) => DiscTuning(
        photoMax: photoMax,
        photoMinDp: DS.s(55),
        photoMidDp: DS.s(75),
        photoDp: DS.s(90),
        badgeMinDp: DS.s(37.5),
        badgeMidDp: DS.s(50),
        badgeDp: DS.s(60),
        dotMinDp: DS.s(22.5),
        dotMidDp: DS.s(35),
        dotDp: DS.s(42.5),
        selDotMinDp: DS.s(32.5),
        selDotMidDp: DS.s(45),
        selDotDp: DS.s(53.75),
        haloPhotoDp: DS.s(127),
        haloDotDp: DS.s(76),
        stopBadgeDp: DS.s(54),
      );

  int px(double dp) => (dp * pxPerDp).round();

  _ZoomSize get _photo => (low: photoMinDp, mid: photoMidDp, high: photoDp);
  _ZoomSize get _badge => (low: badgeMinDp, mid: badgeMidDp, high: badgeDp);
  _ZoomSize get _dot => (low: dotMinDp, mid: dotMidDp, high: dotDp);
  _ZoomSize get _selDot => (low: selDotMinDp, mid: selDotMidDp, high: selDotDp);

  // No normal size = full size from zoom 14 on; no zoomed-out size = flat below zoom 14.
  static List<double> _zooms(Iterable<_ZoomSize> sizes) => [
        if (sizes.any((s) => s.low != null)) zoomOut,
        zoomMid,
        if (sizes.any((s) => s.mid != null)) zoomIn,
      ];

  static double _at(_ZoomSize s, double zoom) {
    final stops = [
      if (s.low != null) (zoomOut, s.low!),
      (zoomMid, s.mid ?? s.high),
      if (s.mid != null) (zoomIn, s.high),
    ];
    if (zoom <= stops.first.$1) return stops.first.$2;
    for (var i = 1; i < stops.length; i++) {
      final (z0, v0) = stops[i - 1];
      final (z1, v1) = stops[i];
      if (zoom <= z1) return v0 + (v1 - v0) * (zoom - z0) / (z1 - z0);
    }
    return stops.last.$2;
  }

  static Object _byZoom(Iterable<_ZoomSize> sizes, Object Function(double zoom) value) {
    final zooms = _zooms(sizes);
    return zooms.length == 1 ? value(zooms.first) : ['interpolate', ['linear'], ['zoom'], for (final z in zooms) ...[z, value(z)]];
  }

  Object get photoIconSize => _byZoom([_photo], (z) => _at(_photo, z) / photoDp);

  Object get badgeIconSize => _byZoom([_badge], (z) => _at(_badge, z) / badgeDp);

  Object dotRadius(double ring) => _byZoom([_dot], (z) => _at(_dot, z) / 2 - ring);

  Object selDotRadius(double ring) => _byZoom([_selDot], (z) => _at(_selDot, z) / 2 - ring);

  Object selIconSize(double scale) => _byZoom([_photo, _badge], (z) {
        final photo = scale * (_at(_photo, z) / photoDp);
        final badge = scale * (_at(_badge, z) / badgeDp);
        return photo == badge ? photo : ['match', ['get', 'kind'], 'badge', badge, photo];
      });

  Object haloRadius(String dotKind, double photoScale) => _byZoom([_photo, _selDot], (z) => [
        'match',
        ['get', 'kind'],
        dotKind,
        (haloDotDp - (selDotDp - _at(_selDot, z))) / 2,
        (haloPhotoDp - photoScale * (photoDp - _at(_photo, z))) / 2,
      ]);

  Object stopIconSize(double minScale) {
    final stop = (low: photoMinDp ?? photoDp * minScale, mid: photoMidDp, high: photoDp);
    return _byZoom([stop], (z) => _at(stop, z) / photoDp);
  }
}

typedef _ZoomSize = ({double? low, double? mid, double high});
