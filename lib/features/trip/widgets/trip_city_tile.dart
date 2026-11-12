import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../models/trip_city_model.dart';
import 'trip_city_art.dart';

class TripCityTile extends StatelessWidget {
  const TripCityTile({super.key, required this.city, required this.onTap});

  final TripCityModel city;
  final VoidCallback onTap;

  static const double aspect = 0.86;

  @override
  Widget build(BuildContext context) {
    final meta = city.tileLine;
    return RepaintBoundary(
      child: PressScale(
        child: Semantics(
          button: true,
          label: city.name,
          child: DecoratedBox(
            decoration: const BoxDecoration(borderRadius: KitMetrics.photo, boxShadow: ShadowTokens.elev2),
            child: Material(
              color: DesignColors.surface,
              borderRadius: KitMetrics.photo,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: LayoutBuilder(
                  builder: (context, box) => Stack(
                    fit: StackFit.expand,
                    children: [
                      TripCityArt(seed: city.cityKey, name: city.name),
                      if (city.cover != null)
                        KitPhoto(
                          url: city.cover,
                          width: box.maxWidth,
                          height: box.maxHeight,
                          tone: TripCityArt.toneOf(city.cityKey),
                          asset: TravelIcon.map,
                          iconSize: 48,
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, DesignColors.overlayDark.withValues(alpha: Alpha.strong)],
                            stops: const [0.45, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.3,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                city.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TypeTokens.style(15, FontWeight.w700, color: DesignColors.onPrimary, height: 1.15),
                              ),
                              if (meta.isNotEmpty)
                                Text(
                                  meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TypeTokens.style(12, FontWeight.w500, color: DesignColors.onPrimary),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
