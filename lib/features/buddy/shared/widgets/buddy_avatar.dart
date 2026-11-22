import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../widgets/profile_avatar.dart';
import '../buddy_look.dart';

enum BuddyAvatarSize {
  md(44, 15),
  sm(32, 12),
  xs(34, 12),
  lg(72, 26);

  const BuddyAvatarSize(this.box, this.font);

  final double box;
  final double font;
}

class BuddyAvatar extends StatelessWidget {
  const BuddyAvatar({super.key, required this.initial, required this.seed, this.size = BuddyAvatarSize.md, this.ring = false, this.photoUrl});

  final String initial;
  final String seed;
  final BuddyAvatarSize size;
  final bool ring;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final box = DS.s(size.box);
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: BuddyLook.avatarGradient(seed),
        border: ring ? Border.all(color: DesignColors.surface, width: DS.s(2.5)) : null,
        boxShadow: ring
            ? null
            : [BoxShadow(color: DesignColors.textStrong.withValues(alpha: Alpha.v18), offset: DS.shadowOffset(const Offset(2, 4)), blurRadius: DS.shadowBlur(8))],
      ),
      child: _face(box),
    );
  }

  Widget _face(double box) {
    final letter = Text(
      initial.isEmpty ? '?' : initial,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
      style: Ink3D.text(size.font, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0).copyWith(
        shadows: [Shadow(color: DesignColors.textStrong.withValues(alpha: Alpha.soft), offset: DS.shadowOffset(const Offset(0, 1)), blurRadius: DS.shadowBlur(2))],
      ),
    );
    if (ProfileAvatar.usable(photoUrl) == null) return letter;
    final inner = ring ? box - 2 * DS.s(2.5) : box;
    return ProfileAvatar(photoUrl: photoUrl, size: inner, fallback: letter);
  }
}

class BuddyAvatarStack extends StatelessWidget {
  const BuddyAvatarStack({super.key, required this.people, this.max = 3, this.extra = 0, this.size = BuddyAvatarSize.xs});

  final List<({String initial, String seed, String? photoUrl})> people;
  final int max;
  final int extra;
  final BuddyAvatarSize size;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    final more = extra + (people.length - shown.length);
    final children = <Widget>[
      for (final p in shown) BuddyAvatar(initial: p.initial, seed: p.seed, size: size, ring: true, photoUrl: p.photoUrl),
      if (more > 0) _MoreDot(count: more, size: size),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++)
          i == 0 ? children[i] : Transform.translate(offset: Offset(-DS.s(10) * i, 0), child: children[i]),
      ],
    );
  }
}

class _MoreDot extends StatelessWidget {
  const _MoreDot({required this.count, required this.size});

  final int count;
  final BuddyAvatarSize size;

  @override
  Widget build(BuildContext context) => Container(
        width: DS.s(size.box),
        height: DS.s(size.box),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DesignColors.surfaceTint,
          border: Border.all(color: DesignColors.surface, width: DS.s(2.5)),
        ),
        child: Text('+$count', maxLines: 1, textScaler: TextScaler.noScaling, style: Ink3D.text(size.font - 1, FontWeight.w700, BuddyLook.indigoText, letterSpacing: 0)),
      );
}
