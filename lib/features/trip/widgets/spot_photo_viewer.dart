import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/sheet_close_button.dart';
import 'package:bakhli/utils/spot_photo_url.dart';
import '../trip_strings_spots_x.dart';

class SpotPhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  final String title;
  final String fallbackAsset;
  final SpotPhotoSize Function(int index) placeholderSizeOf;

  const SpotPhotoViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    required this.title,
    required this.fallbackAsset,
    this.placeholderSizeOf = _hero,
  });

  static SpotPhotoSize _hero(int _) => SpotPhotoSize.hero;

  static const Key pagerKey = ValueKey('spot-photo-viewer-pager');
  static const double closeDragDistance = 120;

  static Future<void> open(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
    required String title,
    required String fallbackAsset,
    SpotPhotoSize Function(int index) placeholderSizeOf = _hero,
  }) async {
    if (urls.isEmpty) return;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final fade = reduce ? Duration.zero : const Duration(milliseconds: 200);
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: fade,
        reverseTransitionDuration: fade,
        pageBuilder: (_, _, _) => SpotPhotoViewer(
          urls: urls,
          initialIndex: initialIndex.clamp(0, urls.length - 1),
          title: title,
          fallbackAsset: fallbackAsset,
          placeholderSizeOf: placeholderSizeOf,
        ),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<SpotPhotoViewer> createState() => _SpotPhotoViewerState();
}

class _SpotPhotoViewerState extends State<SpotPhotoViewer> {
  late final PageController _pages;
  late int _index;
  bool _zoomed = false;
  double _drag = 0;

  int get _count => widget.urls.length;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _count - 1);
    _pages = PageController(initialPage: _index);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheNeighbours();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  int _decodeWidth(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = (mq.size.width * mq.devicePixelRatio).ceil();
    return w < 1 ? SpotPhotoUrl.pixelWidth(SpotPhotoSize.full) : w;
  }

  void _precacheNeighbours() {
    final width = _decodeWidth(context);
    for (final i in [_index - 1, _index + 1]) {
      if (i < 0 || i >= _count) continue;
      final url = SpotPhotoUrl.of(widget.urls[i], SpotPhotoSize.full);
      if (url == null || url.isEmpty) continue;
      precacheImage(
        ResizeImage.resizeIfNeeded(width, null, CachedNetworkImageProvider(url)),
        context,
        onError: (_, _) {},
      );
    }
  }

  void _onPage(int i) {
    setState(() {
      _index = i;
      _zoomed = false;
    });
    _precacheNeighbours();
  }

  void _onZoom(bool zoomed) {
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final width = _decodeWidth(context);
    final pager = PageView.builder(
      key: SpotPhotoViewer.pagerKey,
      controller: _pages,
      physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
      onPageChanged: _onPage,
      itemCount: _count,
      itemBuilder: (_, i) => _ZoomPage(
        key: ValueKey('spot-photo-page-$i'),
        url: widget.urls[i],
        decodeWidth: width,
        fallbackAsset: widget.fallbackAsset,
        placeholderSize: widget.placeholderSizeOf(i),
        semanticsLabel: TripStringsSpotsX.photoOf(widget.title, i + 1, _count),
        onZoomChanged: i == _index ? _onZoom : null,
      ),
    );
    return Material(
      color: DesignColors.textInk,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: _zoomed ? null : (_) => _drag = 0,
            onVerticalDragUpdate: _zoomed ? null : (d) => _drag += d.delta.dy,
            onVerticalDragEnd: _zoomed
                ? null
                : (_) {
                    if (_drag > SpotPhotoViewer.closeDragDistance) _close();
                    _drag = 0;
                  },
            child: pager,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: top + DS.s(72),
                padding: EdgeInsets.only(top: top, bottom: DS.s(16)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [DesignColors.tint(DesignColors.textInk, Alpha.v60), DesignColors.tint(DesignColors.textInk, Alpha.none)],
                  ),
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text('${_index + 1} / $_count', style: Ink3D.text(12.5, FontWeight.w600, DesignColors.surface)),
                ),
              ),
            ),
          ),
          Positioned(
            top: top + DS.s(6),
            right: DS.s(6),
            child: SheetCloseButton(onTap: _close),
          ),
        ],
      ),
    );
  }
}

class _ZoomPage extends StatefulWidget {
  final String url;
  final int decodeWidth;
  final String fallbackAsset;
  final SpotPhotoSize placeholderSize;
  final String semanticsLabel;
  final ValueChanged<bool>? onZoomChanged;

  const _ZoomPage({
    super.key,
    required this.url,
    required this.decodeWidth,
    required this.fallbackAsset,
    required this.placeholderSize,
    required this.semanticsLabel,
    this.onZoomChanged,
  });

  @override
  State<_ZoomPage> createState() => _ZoomPageState();
}

class _ZoomPageState extends State<_ZoomPage> {
  final TransformationController _transform = TransformationController();
  Offset _tap = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged?.call(zoomed);
  }

  void _toggle() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
      return;
    }
    const s = 2.0;
    _transform.value = Matrix4.identity()
      ..translateByDouble(-_tap.dx * (s - 1), -_tap.dy * (s - 1), 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  Widget _broken() => LayoutBuilder(
        builder: (_, c) => Center(
          child: SizedBox(
            width: c.maxWidth,
            height: c.maxWidth * 2 / 3,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: ListingTone.indigo.gradient),
              child: Center(child: Art3D(asset: widget.fallbackAsset, size: 84)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final full = SpotPhotoUrl.of(widget.url, SpotPhotoSize.full);
    final Widget image = (full == null || full.isEmpty)
        ? _broken()
        : CachedNetworkImage(
            imageUrl: full,
            fit: BoxFit.contain,
            memCacheWidth: widget.decodeWidth,
            placeholder: (_, _) => _SmallerCopy(
              url: SpotPhotoUrl.of(widget.url, widget.placeholderSize),
            ),
            errorWidget: (_, _, _) => _broken(),
          );
    return Semantics(
      label: widget.semanticsLabel,
      image: true,
      child: GestureDetector(
        onDoubleTapDown: (d) => _tap = d.localPosition,
        onDoubleTap: _toggle,
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 4,
          child: SizedBox.expand(child: image),
        ),
      ),
    );
  }
}

class _SmallerCopy extends StatefulWidget {
  final String? url;

  const _SmallerCopy({required this.url});

  @override
  State<_SmallerCopy> createState() => _SmallerCopyState();
}

class _SmallerCopyState extends State<_SmallerCopy> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _lookUp();
  }

  Future<void> _lookUp() async {
    final url = widget.url;
    if (url == null || url.isEmpty) return;
    try {
      final info = await CachedNetworkImageProvider.defaultCacheManager.getFileFromMemory(url);
      if (!mounted || info == null) return;
      setState(() => _file = info.file);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file == null) return const SizedBox.expand();
    return Image.file(
      file,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.expand(),
    );
  }
}
