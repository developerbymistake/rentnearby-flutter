import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';

class TripShimmers {
  static Widget rowBox({double height = 76, double radius = 16}) => Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(
          height: height,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
        ),
      );
}

class TripSpotRowSkeleton extends StatelessWidget {
  const TripSpotRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) => TripShimmers.rowBox(height: 84, radius: 14);
}

class TripDayTileSkeleton extends StatelessWidget {
  const TripDayTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => TripShimmers.rowBox(height: 230, radius: 18);
}

class TripCardSkeleton extends StatelessWidget {
  const TripCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => TripShimmers.rowBox(height: 140);
}
