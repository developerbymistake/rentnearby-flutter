import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/money_name.dart';
import '../ledger_look.dart';
import '../ledger_rules.dart';
import '../ledger_strings.dart';
import '../models/ledger_models.dart';

class BalancePeopleCard extends StatelessWidget {
  const BalancePeopleCard({super.key, required this.people, this.margin});

  final List<BalancePerson> people;
  final EdgeInsets? margin;

  static BorderRadius get radius =>
      DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));

  @override
  Widget build(BuildContext context) => Container(
        margin: margin ?? DS.insets(l: 18, t: 16, r: 18),
        padding: DS.sym(h: 16, v: 2),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: radius, boxShadow: BuddyLook.cardShadows(DS.size)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < people.length; i++) _row(people[i], first: i == 0),
          ],
        ),
      );

  Widget _row(BalancePerson p, {required bool first}) {
    final tone = LedgerRules.netTone(p.net);
    final color = switch (tone) {
      NetTone.getsBack => LedgerLook.getsBack,
      NetTone.owes => LedgerLook.owes,
      NetTone.square => LedgerLook.square,
    };
    return Container(
      padding: DS.sym(v: 12),
      decoration: first ? null : BoxDecoration(border: Border(top: BorderSide(color: LedgerLook.line, width: DS.s(1)))),
      child: Row(
        children: [
          BuddyAvatar(initial: p.person.initial, seed: p.person.userId, photoUrl: p.person.photoUrl),
          Gap.h(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                MoneyName(person: p.person, style: Ink3D.text(14.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                Text(LedgerStrings.paidShare(p.paid, p.share), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
              ],
            ),
          ),
          Gap.h(12),
          Text(LedgerRules.netLabel(p.net), maxLines: 1, style: Ink3D.text(15, FontWeight.w700, color, letterSpacing: 0)),
        ],
      ),
    );
  }
}
