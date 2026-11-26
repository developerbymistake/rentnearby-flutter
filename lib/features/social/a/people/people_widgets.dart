import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../shared/social_models.dart';
import '../../shared/social_strings.dart';
import '../widgets/social_chips_a.dart';
import 'people_controller.dart';

class SocialPersonTile extends StatelessWidget {
  const SocialPersonTile({
    super.key,
    required this.person,
    required this.subtitle,
    this.mutualText,
    this.actions,
    this.onTap,
    this.onMenu,
    this.star = false,
  });

  final SocialPerson person;
  final String subtitle;
  final String? mutualText;
  final Widget? actions;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;
  final bool star;

  static String relationLine({required bool followsMe, required bool iFollow}) {
    if (followsMe && iFollow) return SocialStrings.followEachOther;
    if (followsMe) return SocialStrings.followsYou;
    return '';
  }

  static String? mutualOf(PersonRow r) {
    if (r.mutualCount <= 0) return null;
    final name = r.mutualName;
    if (name != null && r.mutualCount == 1) return SocialStrings.mutualsLine(Mutuals(count: 1, names: [name]));
    return SocialStrings.mutualCount(r.mutualCount);
  }

  @override
  Widget build(BuildContext context) {
    final mutual = mutualText;
    final menu = onMenu;
    final body = Padding(
      padding: DS.insets(l: 18, t: 14, r: 8, b: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: DS.s(52),
            height: DS.s(52),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                BuddyAvatar(initial: person.initial, seed: person.userId, size: BuddyAvatarSize.md, photoUrl: person.photoUrl),
                if (star)
                  Positioned(
                    right: -DS.s(2),
                    bottom: DS.s(2),
                    child: Container(
                      width: DS.s(22),
                      height: DS.s(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: BuddyLook.snackAction,
                        border: Border.all(color: DesignColors.surface, width: DS.s(2)),
                      ),
                      child: Icon(Icons.star_rounded, size: DS.s(13), color: BuddyLook.amberText),
                    ),
                  ),
              ],
            ),
          ),
          Gap.h(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(person.shortName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
                    if (person.gender.isNotEmpty) ...[Gap.h(6), GenderGlyph(gender: person.gender, color: GenderGlyph.inkOf(person.gender), size: 12, badge: true)],
                  ],
                ),
                if (subtitle.isNotEmpty)
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                if (mutual != null) Text(mutual, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Form3D.hint, letterSpacing: 0)),
                if (actions != null) Padding(padding: EdgeInsets.only(top: DS.gv(10)), child: actions),
              ],
            ),
          ),
          if (menu != null)
            Tap3D(
              onTap: menu,
              label: '${SocialStrings.report} / ${SocialStrings.block}',
              exclude: true,
              child: SizedBox(
                width: DS.s(KitMetrics.touch),
                height: DS.s(KitMetrics.touch),
                child: Icon(Icons.more_vert_rounded, size: DS.s(22), color: Form3D.hint),
              ),
            ),
        ],
      ),
    );
    return onTap == null ? body : Tap3D(onTap: onTap, label: person.name, child: body);
  }
}

class PeopleCard extends StatelessWidget {
  const PeopleCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: DS.insets(l: 18, r: 18),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.br(CardRadius.hero),
          boxShadow: BuddyLook.cardShadows(DS.size),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: DS.s(1), thickness: DS.s(1), color: BuddyLook.hairline),
              children[i],
            ],
          ],
        ),
      );
}

class PeopleLabel extends StatelessWidget {
  const PeopleLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.gapInsets(l: 22, t: 24, r: 22, b: 10),
        child: Text(text.toUpperCase(), style: Ink3D.text(12, FontWeight.w700, Ink3D.grey, letterSpacing: 0.8)),
      );
}

abstract final class PeopleStates {
  static Widget? of(ListLoad state, {required bool empty, required String emptyTitle, String? emptyLine, required VoidCallback onRetry}) {
    switch (state) {
      case ListLoad.idle:
      case ListLoad.loading:
        return Padding(
          padding: DS.gapInsets(l: 18, t: 16, r: 18),
          child: Column(children: [
            for (var i = 0; i < 3; i++) ...[if (i > 0) Gap.v(12), SkeletonBox(height: DS.s(72), borderRadius: DS.circular(16))],
          ]),
        );
      case ListLoad.offline:
        return Padding(padding: DS.gapInsets(t: 30), child: StateCard.error(title: SocialStrings.offline, actionLabel: SocialStrings.retry, onAction: onRetry));
      case ListLoad.failed:
        return Padding(padding: DS.gapInsets(t: 30), child: StateCard.error(title: SocialStrings.failed, actionLabel: SocialStrings.retry, onAction: onRetry));
      case ListLoad.ready:
        if (!empty) return null;
        return Padding(padding: DS.gapInsets(t: 30), child: StateCard(title: emptyTitle, message: emptyLine, asset: ListingArt.panda));
    }
  }
}

class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({super.key, required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) => loading
      ? Padding(
          padding: DS.gapInsets(t: 16),
          child: Center(child: SizedBox.square(dimension: DS.s(24), child: CircularProgressIndicator(strokeWidth: DS.s(2.5), color: ListingTone.indigo.g2))),
        )
      : const SizedBox.shrink();
}
