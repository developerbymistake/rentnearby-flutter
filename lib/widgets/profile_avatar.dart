import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../design/extra/card_kit.dart';

// Another person's picture in a circle of [size] final pixels. No url, while loading or on error: [fallback].
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.photoUrl, required this.size, required this.fallback});

  final String? photoUrl;
  final double size;
  final Widget fallback;

  static const Key imageKey = ValueKey('profile-avatar-image');
  static const Duration fadeIn = Duration(milliseconds: 120);

  static String? usable(String? url) {
    final u = url?.trim();
    return (u == null || u.isEmpty) ? null : u;
  }

  static int decodeWidth(double size, double dpr) => math.max(1, math.min(KitPhoto.maxDecodePx, (size * dpr).round()));

  @override
  Widget build(BuildContext context) {
    final src = usable(photoUrl);
    if (src == null) return fallback;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: CachedNetworkImage(
          key: imageKey,
          imageUrl: src,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: decodeWidth(size, dpr),
          fadeInDuration: fadeIn,
          placeholder: (_, _) => fallback,
          errorWidget: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
