import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../../widgets/profile_avatar.dart';

class SocialAvatarStack extends StatelessWidget {
  const SocialAvatarStack({super.key, required this.photoUrls, required this.initials, this.size = 24});

  final List<String> photoUrls;
  final List<String> initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final count = photoUrls.length > initials.length ? photoUrls.length : initials.length;
    final shown = count > 3 ? 3 : count;
    if (shown == 0) return const SizedBox.shrink();
    final box = DS.s(size);
    final step = box * 0.7;
    return SizedBox(
      width: box + step * (shown - 1),
      height: box,
      child: Stack(
        children: [
          for (var i = 0; i < shown; i++)
            Positioned(
              left: step * i,
              child: _Face(
                photoUrl: i < photoUrls.length ? photoUrls[i] : null,
                initial: i < initials.length ? initials[i] : '',
                box: box,
              ),
            ),
        ],
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.photoUrl, required this.initial, required this.box});

  final String? photoUrl;
  final String initial;
  final double box;

  @override
  Widget build(BuildContext context) {
    final ring = DS.s(2);
    final letter = Text(
      initial.isEmpty ? '?' : initial,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
      style: Ink3D.text(10, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0),
    );
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: BuddyLook.avatarGradient(photoUrl ?? initial),
        border: Border.all(color: DesignColors.surface, width: ring),
      ),
      child: ProfileAvatar.usable(photoUrl) == null ? letter : ProfileAvatar(photoUrl: photoUrl, size: box - 2 * ring, fallback: letter),
    );
  }
}
