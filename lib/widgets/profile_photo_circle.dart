import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/profile_photo_strings.dart';
import '../controllers/profile_photo_controller.dart';
import '../design/design.dart';
import '../design/extra/ext_auth.dart';
import 'profile_avatar.dart';

// The own picture: a local file wins over the url; busy = dim + ring; failed = coral ring (+ retry glyph over a local file).
class ProfilePhotoCircle extends StatelessWidget {
  const ProfilePhotoCircle({
    super.key,
    required this.size,
    this.url,
    this.localPath,
    this.placeholderPath,
    this.busy = false,
    this.progress,
    this.failed = false,
    required this.fallback,
    this.ring = true,
    this.ringColor,
    this.ringWidth,
    this.failColor,
  });

  final double size;
  final String? url;
  final String? localPath;
  final String? placeholderPath;
  final bool busy;
  final double? progress;
  final bool failed;
  final Widget fallback;
  final bool ring;
  final Color? ringColor;
  final double? ringWidth;
  final Color? failColor;

  static const Key imageKey = ValueKey('profile-photo-image');
  static const Key localKey = ValueKey('profile-photo-local');
  static const Key retryKey = ValueKey('profile-photo-retry');

  Widget _file(String path, int decode) => Image.file(
        File(path),
        key: localKey,
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: decode,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final decode = ProfileAvatar.decodeWidth(size, dpr);
    final local = localPath;
    final src = ProfileAvatar.usable(url);
    final hold = placeholderPath;
    final Widget content;
    if (local != null) {
      content = _file(local, decode);
    } else if (src != null) {
      final under = hold != null ? _file(hold, decode) : fallback;
      content = CachedNetworkImage(
        key: imageKey,
        imageUrl: src,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: decode,
        fadeInDuration: ProfileAvatar.fadeIn,
        placeholder: (_, _) => under,
        errorWidget: (_, _, _) => fallback,
      );
    } else {
      content = fallback;
    }
    final width = ringWidth ?? DS.s(2);
    final edge = failed ? (failColor ?? ListingTone.coral.g2) : (ringColor ?? AuthInk.bone);
    final spin = busy && progress == null;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: ring && !spin ? Border.all(color: edge, width: width) : null,
            ),
            child: Padding(
              padding: ring ? EdgeInsets.all(width) : EdgeInsets.zero,
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    content,
                    if (busy || (failed && local != null)) const ColoredBox(color: DesignColors.scrim),
                    if (failed && !busy && local != null)
                      Center(child: Icon(Icons.refresh_rounded, key: retryKey, size: DS.s(30), color: DesignColors.onPrimary)),
                    if (busy && progress != null) ...[
                      Padding(
                        padding: DS.all(3),
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: DS.s(4),
                          color: DesignColors.onPrimary,
                          backgroundColor: DesignColors.onPrimary.withValues(alpha: Alpha.v30),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Center(
                        child: Text(
                          '${((progress ?? 0) * 100).round()}%',
                          maxLines: 1,
                          style: Ink3D.text(16, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (spin)
            CircularProgressIndicator(
              strokeWidth: width,
              color: DesignColors.onPrimary,
              backgroundColor: DesignColors.onPrimary.withValues(alpha: Alpha.scrim),
              strokeCap: StrokeCap.round,
            ),
        ],
      ),
    );
  }
}

// The white 28 round button used on the picture and next to the name.
class ProfileRoundButton extends StatelessWidget {
  const ProfileRoundButton({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: DS.s(28),
        height: DS.s(28),
        decoration: BoxDecoration(color: DesignColors.onPrimary, shape: BoxShape.circle, boxShadow: DS.shadows(Ink3D.whiteBtn)),
        child: Icon(icon, size: DS.s(15), color: color),
      );
}

// Onboarding and gate page: circle 96 + label + helper (or the upload error line). Tap = [onTap].
class ProfilePhotoBlock extends StatelessWidget {
  const ProfilePhotoBlock({super.key, required this.controller, required this.bad, required this.onTap, this.tapRetries = true, this.optional = false});

  final ProfilePhotoController controller;
  final bool bad;
  final VoidCallback onTap;
  // False: a tap after a failed upload opens the picker (gate page), so the circle keeps its camera badge.
  final bool tapRetries;
  final bool optional;

  static final ListingTone _tone = ListingTone.indigo;

  Widget _fallback(bool bad) => ColoredBox(
        color: bad ? DesignColors.onPrimary : AuthInk.page,
        child: Center(child: ExcludeSemantics(child: Art3D(asset: ListingArt.camera, size: 56, shadowBlur: 3, shadowOffset: const Offset(2, 4)))),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(() {
          final local = controller.localPath.value;
          final busy = controller.busy.value;
          final failed = controller.failed.value && local != null;
          final ringBad = bad && local == null;
          return Center(
            child: Semantics(
              button: true,
              enabled: !busy,
              label: failed && tapRetries ? ProfilePhotoStrings.semRetryUpload : ProfilePhotoStrings.semProfilePhoto,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: busy ? null : onTap,
                child: SizedBox.square(
                  dimension: DS.s(96),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: ringBad ? AuthInk.focusShadow(AuthInk.ringBad) : null),
                        child: ProfilePhotoCircle(
                          size: DS.s(96),
                          localPath: local,
                          busy: busy,
                          progress: busy ? controller.progress.value : null,
                          failed: failed && tapRetries,
                          ringColor: ringBad ? AuthInk.ringBad : (failed ? ListingTone.coral.g2 : null),
                          ringWidth: failed ? DS.s(3) : null,
                          fallback: _fallback(ringBad),
                        ),
                      ),
                      if (!busy && !(failed && tapRetries))
                        Positioned(right: -DS.s(2), bottom: -DS.s(2), child: ProfileRoundButton(icon: Icons.photo_camera_rounded, color: _tone.g2)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        Gap.v(9),
        ExcludeSemantics(child: Text(ProfilePhotoStrings.label, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w600, Ink3D.sub))),
        Obx(() {
          final failed = controller.failed.value && controller.localPath.value != null;
          return failed
              ? Text(ProfilePhotoStrings.uploadFailed, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w600, AuthInk.badText, height: 1.5))
              : Text(optional ? ProfilePhotoStrings.optionalHint : ProfilePhotoStrings.helper, textAlign: TextAlign.center, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0));
        }),
      ],
    );
  }
}

// Looks dimmed until a photo is picked but stays tappable, so the tap can say why.
class ProfilePhotoSubmitButton extends StatelessWidget {
  const ProfilePhotoSubmitButton({super.key, required this.tone, required this.label, required this.ready, required this.loading, required this.onTap});

  final ListingTone tone;
  final String label;
  final bool ready;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = GradientPillButton(tone: tone, label: label, onTap: loading ? null : onTap, loading: loading, enabled: ready || loading);
    if (ready || loading) return button;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: button),
    );
  }
}
