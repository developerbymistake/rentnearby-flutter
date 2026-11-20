import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../buddies_strings.dart';
import '../models/buddy_models.dart';

class FindResultCard extends StatelessWidget {
  const FindResultCard({
    super.key,
    required this.person,
    this.sentHere = false,
    this.busy = false,
    this.onAdd,
    this.onCancel,
    this.onAccept,
    this.onOpenBuddy,
  });

  final FoundPerson person;
  final bool sentHere;
  final bool busy;
  final VoidCallback? onAdd;
  final VoidCallback? onCancel;
  final VoidCallback? onAccept;
  final VoidCallback? onOpenBuddy;

  static BorderRadius get radius =>
      DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));

  Widget _action() => switch (person.relation) {
        BuddyRelation.none => Padding(
            padding: EdgeInsets.only(top: DS.s(20)),
            child: GradientPillButton(tone: BuddyLook.teal, label: BuddiesStrings.addBuddy, onTap: busy ? null : onAdd, loading: busy),
          ),
        BuddyRelation.requestedMe => Padding(
            padding: EdgeInsets.only(top: DS.s(20)),
            child: GradientPillButton(tone: BuddyLook.teal, label: BuddiesStrings.accept, onTap: busy ? null : onAccept, loading: busy),
          ),
        BuddyRelation.buddy => Padding(
            padding: EdgeInsets.only(top: DS.s(8)),
            child: const Center(child: _BuddyTickBadge()),
          ),
        BuddyRelation.cooldown => Padding(
            padding: EdgeInsets.only(top: DS.s(8)),
            child: const Center(child: BuddyBadge(BuddiesStrings.sendAgainLater, tone: BuddyBadgeTone.grey, large: true)),
          ),
        BuddyRelation.requestedByMe => Padding(
            padding: EdgeInsets.only(top: DS.s(sentHere ? 20 : 8)),
            child: sentHere
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const BuddyBadge(BuddiesStrings.requested, tone: BuddyBadgeTone.pending, large: true),
                      Gap.h(12),
                      Tap3D(
                        onTap: busy ? null : onCancel,
                        label: BuddiesStrings.cancelRequest,
                        exclude: true,
                        child: Container(
                          constraints: BoxConstraints(minHeight: DS.s(40)),
                          padding: DS.sym(h: 8),
                          alignment: Alignment.center,
                          child: Text(
                            BuddiesStrings.cancelRequest,
                            style: Ink3D.text(13.5, FontWeight.w700, BuddyLook.dangerText, letterSpacing: 0)
                                .copyWith(decoration: TextDecoration.underline, decorationColor: BuddyLook.dangerText),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(child: BuddyBadge(BuddiesStrings.requestSent, tone: BuddyBadgeTone.pending, large: true)),
          ),
        BuddyRelation.self => const SizedBox.shrink(),
      };

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: DS.insets(l: 18, r: 18),
      padding: DS.insets(l: 22, t: 26, r: 22, b: 22),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: radius, boxShadow: BuddyLook.cardShadows(DS.size)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: BuddyAvatar(initial: person.initial, seed: person.userId, size: BuddyAvatarSize.lg)),
          Gap.v(12),
          Text(person.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(20, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          Padding(
            padding: EdgeInsets.only(top: DS.s(2)),
            child: Text(person.username ?? '', textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w600, BuddyLook.tealEnd, letterSpacing: 0)),
          ),
          _action(),
        ],
      ),
    );
    if (person.relation != BuddyRelation.buddy || onOpenBuddy == null) return card;
    return Tap3D(onTap: onOpenBuddy, label: person.name, child: card);
  }
}

class _BuddyTickBadge extends StatelessWidget {
  const _BuddyTickBadge();

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = BuddyLook.badge[BuddyBadgeColor.teal]!;
    return Semantics(
      label: BuddiesStrings.yourBuddy,
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: DS.s(32)),
        padding: DS.sym(h: 16),
        decoration: BoxDecoration(color: bg, borderRadius: DS.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: DS.s(16), color: fg),
            Gap.h(4),
            Text(BuddiesStrings.yourBuddyText, maxLines: 1, style: Ink3D.text(13, FontWeight.w700, fg, letterSpacing: 0)),
          ],
        ),
      ),
    );
  }
}
