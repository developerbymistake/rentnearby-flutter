import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/utils/spot_photo_url.dart';
import '../trip_strings.dart';
import '../trip_strings_spots_x.dart';
import 'trip_spot_row.dart';

enum SpotGalleryState { loading, ready, error }

class SpotGalleryCollage extends StatelessWidget {
  final List<String> urls;
  final String fallbackAsset;
  final ValueChanged<int> onTap;
  final String title;

  const SpotGalleryCollage({super.key, required this.urls, required this.fallbackAsset, required this.onTap, this.title = ''});

  static const double wideFrom = 560;

  static double get gap => DS.s(6);

  static double heightOf(double w, int n) {
    if (n <= 0) return 0;
    if (n == 1) return w * 0.56;
    if (n == 2) return w * 0.50;
    return (w >= wideFrom && n >= 4) ? w * 0.46 : w * 0.58;
  }

  @override
  Widget build(BuildContext context) {
    final n = urls.length;
    if (n == 0) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = heightOf(w, n);
      final g = gap;
      if (n == 1) return SizedBox(height: h, child: _tile(0, SpotPhotoSize.card));
      if (n == 2) {
        return SizedBox(
          height: h,
          child: Row(children: [
            Expanded(child: _tile(0, SpotPhotoSize.square)),
            SizedBox(width: g),
            Expanded(child: _tile(1, SpotPhotoSize.square)),
          ]),
        );
      }
      if (w >= wideFrom && n >= 4) {
        final unit = (w - 2 * g) / 4;
        return SizedBox(
          height: h,
          child: Row(children: [
            SizedBox(width: unit * 2, child: _tile(0, SpotPhotoSize.card)),
            SizedBox(width: g),
            Expanded(
              child: Column(children: [
                Expanded(child: _tile(1, SpotPhotoSize.card)),
                SizedBox(height: g),
                Expanded(
                  child: Row(children: [
                    Expanded(child: _tile(2, SpotPhotoSize.square)),
                    SizedBox(width: g),
                    Expanded(child: _tile(3, SpotPhotoSize.square, more: n - 4)),
                  ]),
                ),
              ]),
            ),
          ]),
        );
      }
      return SizedBox(
        height: h,
        child: Row(children: [
          SizedBox(width: (w - g) * 2 / 3, child: _tile(0, SpotPhotoSize.card)),
          SizedBox(width: g),
          Expanded(
            child: Column(children: [
              Expanded(child: _tile(1, SpotPhotoSize.square)),
              SizedBox(height: g),
              Expanded(child: _tile(2, SpotPhotoSize.square, more: n - 3)),
            ]),
          ),
        ]),
      );
    });
  }

  Widget _tile(int i, SpotPhotoSize size, {int more = 0}) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () => onTap(i),
        child: Semantics(
          label: TripStringsSpotsX.photoOf(title, i + 1, urls.length),
          image: true,
          button: true,
          onTap: () => onTap(i),
          child: ClipRRect(
            borderRadius: DS.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                TripSpotMedia.photo(urls[i], size, TripSpotMedia.fallbackArt(fallbackAsset)),
                if (more > 0)
                  ColoredBox(
                    color: DesignColors.tint(DesignColors.textInk, Alpha.v55),
                    child: Center(
                      child: ExcludeSemantics(
                        child: Text(TripStringsSpotsX.morePhotos(more), style: Ink3D.text(12.5, FontWeight.w600, DesignColors.surface)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class SpotGallerySection extends StatelessWidget {
  final SpotGalleryState state;
  final List<String> urls;
  final String title;
  final String fallbackAsset;
  final ValueChanged<int> onTap;
  final VoidCallback onRetry;

  const SpotGallerySection({
    super.key,
    required this.state,
    required this.urls,
    required this.title,
    required this.fallbackAsset,
    required this.onTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final ready = state == SpotGalleryState.ready;
    if (ready && urls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            TripStringsSpotsX.gallery,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Ink3D.text(18, FontWeight.w600, Ink3D.body, letterSpacing: 0.4, height: 1.3),
          ),
        ),
        if (ready)
          Padding(
            padding: EdgeInsets.only(top: DS.s(4)),
            child: Text(
              TripStringsSpotsX.photoCount(urls.length),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, letterSpacing: 0),
            ),
          ),
        Gap.v(10),
        switch (state) {
          SpotGalleryState.ready => SpotGalleryCollage(urls: urls, fallbackAsset: fallbackAsset, onTap: onTap, title: title),
          SpotGalleryState.loading => const _Loading(),
          SpotGalleryState.error => StateCard.error(
              title: TripStringsSpotsX.galleryError,
              message: TripStringsSpotsX.galleryErrorBody,
              kit: KitTone.brand,
              layout: StateLayout.plain,
              actionLabel: TripStrings.retry,
              onAction: onRetry,
            ),
        },
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final g = SpotGalleryCollage.gap;
        final r = DS.radius(16);
        return ExcludeSemantics(
          child: SizedBox(
            height: w * 0.58,
            child: Row(children: [
              SizedBox(width: (w - g) * 2 / 3, child: TemplatePlaceholder(height: double.infinity, radius: r)),
              SizedBox(width: g),
              Expanded(
                child: Column(children: [
                  Expanded(child: TemplatePlaceholder(height: double.infinity, radius: r)),
                  SizedBox(height: g),
                  Expanded(child: TemplatePlaceholder(height: double.infinity, radius: r)),
                ]),
              ),
            ]),
          ),
        );
      });
}
