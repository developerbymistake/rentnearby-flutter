import 'package:flutter/material.dart';

import '../../../../../design/design.dart';
import '../../../../buddy/shared/buddy_look.dart';
import '../../../shared/data/follow_api.dart';
import '../../../shared/social_models.dart';
import '../../social_strings_a.dart';
import 'discover_card.dart';

/// Horizontal strip of at most [max] suggested travellers (B1 feed rail tinted, B2 similar travellers white).
/// Display only: the caller loads [people] and hides the rail when the list is empty.
class DiscoverRail extends StatelessWidget {
  const DiscoverRail({
    super.key,
    required this.people,
    this.title = SocialStringsA.mayKnow,
    this.onSeeAll,
    this.viewedName,
    this.tinted = true,
    this.onFollowChanged,
    this.max = 5,
    this.margin,
    this.api = const FollowApi(),
  });

  final List<DiscoverPerson> people;
  final String title;
  final VoidCallback? onSeeAll;

  /// B2: the mutual reason reads "{viewedName} follows".
  final String? viewedName;
  final bool tinted;
  final void Function(String userId, bool iFollow, bool requested)? onFollowChanged;
  final int max;
  final EdgeInsets? margin;
  final FollowApi api;

  static const Key seeAllKey = ValueKey('discover_rail_see_all');
  static const double cardWidth = 132;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final seeAll = onSeeAll;
    return Container(
      margin: margin ?? DS.gapInsets(l: 18, t: 16, r: 18),
      padding: DS.insets(l: 10, t: 12, r: 10, b: 12),
      decoration: BoxDecoration(
        color: tinted ? BuddyLook.note[NoteToneColor.indigo]!.$1 : DesignColors.surface,
        borderRadius: DS.br(CardRadius.card),
        border: Border.all(color: Form3D.outline, width: DS.s(1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: DS.insets(l: 4, r: 4, b: 8),
            child: Row(
              children: [
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
                if (seeAll != null)
                  Tap3D(
                    tapKey: seeAllKey,
                    onTap: seeAll,
                    label: SocialStringsA.seeAll,
                    exclude: true,
                    child: Padding(
                      padding: DS.sym(h: 6, v: 4),
                      child: Text(SocialStringsA.seeAll, style: Ink3D.text(13, FontWeight.w700, BuddyLook.indigoText, letterSpacing: 0)),
                    ),
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) Gap.h(9),
                  SizedBox(
                    width: DS.s(cardWidth),
                    child: DiscoverCard(
                      item: shown[i],
                      reason: SocialStringsA.reasonShort(shown[i].reason, viewedName: viewedName),
                      small: true,
                      api: api,
                      onFollowChanged: onFollowChanged == null ? null : (f, q) => onFollowChanged!(shown[i].userId, f, q),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
