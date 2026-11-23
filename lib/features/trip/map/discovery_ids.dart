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

  static const double zoomOut = 10;
  static const double zoomIn = 14;

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
  });

  // Trip mock was drawn unscaled: marker sizes follow DS (D5); the 44 dp tap box stays raw.
  static DiscTuning get trip => DiscTuning(
        photoMax: 40,
        photoDp: DS.s(44),
        dotDp: DS.s(9),
        selDotDp: DS.s(14),
        badgeDp: DS.s(24),
        haloPhotoDp: DS.s(72),
        haloDotDp: DS.s(36),
      );
  // Owner sizes 2026-11-23: photo 44, badge 28, dot 12; smaller zoomed out, never below the minimums.
  static DiscTuning get stay => DiscTuning(
        photoMax: 24,
        photoDp: DS.s(44),
        photoMinDp: DS.s(36),
        badgeDp: DS.s(28),
        badgeMinDp: DS.s(24),
        dotDp: DS.s(12),
        dotMinDp: DS.s(10),
        selDotDp: DS.s(16),
        haloPhotoDp: DS.s(72),
        haloDotDp: DS.s(36),
      );

  int px(double dp) => (dp * pxPerDp).round();

  static Object _byZoom(double? low, double high) =>
      low == null || low >= high ? high : ['interpolate', ['linear'], ['zoom'], zoomOut, low, zoomIn, high];

  Object get photoIconSize => _byZoom(photoMinDp == null ? null : photoMinDp! / photoDp, 1.0);

  Object get badgeIconSize => _byZoom(badgeMinDp == null ? null : badgeMinDp! / badgeDp, 1.0);

  Object dotRadius(double ring) => _byZoom(dotMinDp == null ? null : dotMinDp! / 2 - ring, dotDp / 2 - ring);
}
