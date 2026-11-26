import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../social_models.dart';
import '../social_strings.dart';
import 'social_avatar_stack.dart';

class MutualsLine extends StatelessWidget {
  const MutualsLine({super.key, required this.mutuals, this.avatars = false, this.color});

  final Mutuals mutuals;
  final bool avatars;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (mutuals.isEmpty) return const SizedBox.shrink();
    final text = Text(
      avatars ? SocialStrings.mutualsLine(mutuals) : (mutuals.names.isEmpty ? SocialStrings.mutualCount(mutuals.count) : SocialStrings.mutualsLine(mutuals)),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Ink3D.text(12, FontWeight.w400, color ?? Form3D.hint, letterSpacing: 0),
    );
    if (!avatars || (mutuals.photoUrls.isEmpty && mutuals.names.isEmpty)) return text;
    return Row(
      children: [
        SocialAvatarStack(photoUrls: mutuals.photoUrls, initials: [for (final n in mutuals.names) n.isEmpty ? '' : n.substring(0, 1).toUpperCase()], size: 28),
        Gap.h(10),
        Expanded(child: text),
      ],
    );
  }
}
