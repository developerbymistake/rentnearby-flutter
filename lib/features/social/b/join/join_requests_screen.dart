import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../buddy/buddies/models/buddy_models.dart';
import '../../../buddy/buddies/widgets/block_dialog.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../../buddy/shared/widgets/buddy_page.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../../buddy/shared/widgets/note_banner.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/person_actions.dart';
import '../../shared/widgets/travel_level_widgets.dart';
import '../data/join_api.dart';
import '../social_strings_b.dart';
import '../../a/widgets/social_chips_a.dart';
import '../widgets/social_widgets_b.dart';
import 'join_requests_controller.dart';

class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({super.key, required this.tripId});

  final String tripId;

  static Key acceptKey(String id) => ValueKey('join_accept_$id');
  static Key declineKey(String id) => ValueKey('join_decline_$id');
  static Key buddyKey(String id) => ValueKey('join_buddy_$id');
  static Key levelKey(String id) => ValueKey('join_level_$id');

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  late final String _tag = 'join-requests-${widget.tripId}-${identityHashCode(this)}';
  late final JoinRequestsController c = Get.put(JoinRequestsController(tripId: widget.tripId), tag: _tag);

  @override
  void dispose() {
    Get.delete<JoinRequestsController>(tag: _tag);
    super.dispose();
  }

  Future<void> _accept(JoinRequestItem item) async {
    final (ok, line) = await c.accept(item);
    if (mounted) BuddySnack.show(context, line, danger: !ok);
  }

  Future<void> _decline(JoinRequestItem item) async {
    final (ok, line) = await c.decline(item);
    if (mounted) BuddySnack.show(context, line, danger: !ok);
  }

  String _facts(JoinRequestItem item) {
    final p = item.person;
    final parts = <String>[
      if (item.tier == JoinRequestItem.tierBuddy) SocialStringsB.yourBuddy,
      if (item.tier == JoinRequestItem.tierFollower) SocialStringsB.followsYou,
      if (p.mutualCount > 0)
        p.mutualName != null && item.tier == JoinRequestItem.tierOther
            ? SocialStrings.mutualsLine(Mutuals(count: p.mutualCount, names: [p.mutualName!]))
            : SocialStrings.mutualCount(p.mutualCount),
      if (item.tier == JoinRequestItem.tierOther && item.interests.isNotEmpty) item.interests.take(2).join(', '),
    ];
    return parts.join(' · ');
  }

  Widget _card(JoinRequestItem item) {
    final p = item.person.person;
    final facts = _facts(item);
    final ticked = c.addToBuddies.contains(item.id);
    return Container(
      key: ValueKey('join_card_${item.id}'),
      margin: DS.gapInsets(l: 18, r: 18, b: 12),
      padding: DS.insets(l: 16, t: 14, r: 10, b: 14),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), boxShadow: DS.shadows(Form3D.cardShadow)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Tap3D(
                  onTap: () => SocialNav.openTraveller(p.userId),
                  label: p.name,
                  exclude: true,
                  child: Row(
                    children: [
                      BuddyAvatar(initial: p.initial, seed: p.userId, photoUrl: p.photoUrl),
                      Gap.h(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15.5, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
                                if (p.gender.isNotEmpty) ...[Gap.h(6), GenderGlyph(gender: p.gender, color: GenderGlyph.inkOf(p.gender), size: 12, badge: true)],
                                Gap.h(6),
                                TrophyBadge(key: JoinRequestsScreen.levelKey(item.id), level: p.level, trips: p.completedTrips),
                              ],
                            ),
                            if ((p.username ?? '').isNotEmpty) Text(p.username!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.hint, letterSpacing: 0)),
                            if (facts.isNotEmpty) Text(facts, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Tap3D(
                onTap: () => PersonActions.showMenu(context, person: p, contextName: BuddyContext.joinReq, onBlocked: () => c.removePerson(p.userId)),
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
          if (item.note != null) ...[
            Gap.v(10),
            Container(
              padding: DS.sym(h: 12, v: 10),
              margin: DS.insets(r: 6),
              decoration: BoxDecoration(color: Form3D.fill, borderRadius: DS.circular(12)),
              child: Text('“${item.note}”', style: Ink3D.text(14, FontWeight.w400, Ink3D.body, height: 1.45, letterSpacing: 0)),
            ),
          ],
          if (item.tier == JoinRequestItem.tierFollower) ...[
            Gap.v(8),
            Padding(
              padding: DS.insets(r: 6),
              child: TickRow(
                key: JoinRequestsScreen.buddyKey(item.id),
                label: SocialStringsB.alsoAddToBuddies,
                hint: SocialStringsB.optional,
                checked: ticked,
                onTap: () => c.toggleBuddy(item.id),
              ),
            ),
          ],
          Gap.v(12),
          Padding(
            padding: DS.insets(r: 6),
            child: Row(
              children: [
                Expanded(
                  child: WhitePillButton(
                    key: JoinRequestsScreen.declineKey(item.id),
                    tone: ListingTone.indigo,
                    label: SocialStringsB.decline,
                    height: SocialButtonsA.midHeight,
                    fontSize: SocialButtonsA.midFont,
                    onTap: () => _decline(item),
                  ),
                ),
                Gap.h(12),
                Expanded(
                  child: GradientPillButton(
                    key: JoinRequestsScreen.acceptKey(item.id),
                    tone: BuddyLook.teal,
                    label: SocialStringsB.accept,
                    height: SocialButtonsA.midHeight,
                    fontSize: SocialButtonsA.midFont,
                    onTap: () => _accept(item),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(String title, List<JoinRequestItem> list) {
    if (list.isEmpty) return const [];
    return [SmallLabel(text: title, caps: true, padding: DS.gapInsets(l: 22, t: 14, r: 22, b: 10)), for (final i in list) _card(i)];
  }

  Widget _content() {
    final items = c.items.toList();
    c.addToBuddies.length;
    if (items.isEmpty) {
      return Padding(
        padding: DS.gapInsets(t: 40),
        child: StateCard(title: SocialStringsB.noRequestsTitle, message: SocialStringsB.noRequestsBody, asset: ListingArt.panda),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._section(SocialStringsB.sectionBuddies(c.tier(JoinRequestItem.tierBuddy).length), c.tier(JoinRequestItem.tierBuddy)),
        ..._section(SocialStringsB.sectionFollowers(c.tier(JoinRequestItem.tierFollower).length), c.tier(JoinRequestItem.tierFollower)),
        ..._section(SocialStringsB.sectionOthers(c.tier(JoinRequestItem.tierOther).length), c.tier(JoinRequestItem.tierOther)),
        NoteBanner(art: ListingArt.luggage, text: SocialStringsB.acceptNote, margin: DS.insets(l: 18, t: 4, r: 18)),
        Gap.v(16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final t = c.trip.value;
      final st = c.state.value;
      return BuddyPage(
        title: SocialStringsB.joinRequestsTitle,
        subtitle: t == null ? null : SocialStringsB.requestsSub(t),
        body: switch (st) {
          JoinRequestsLoad.loading => Padding(
              padding: DS.gapInsets(l: 18, t: 8, r: 18),
              child: Column(children: [for (var i = 0; i < 2; i++) ...[SkeletonBox(height: DS.s(180), borderRadius: DS.circular(18)), Gap.v(12)]]),
            ),
          JoinRequestsLoad.gone => Padding(padding: DS.gapInsets(t: 40), child: StateCard(title: SocialStrings.gone, asset: ListingArt.panda)),
          JoinRequestsLoad.offline => Padding(
              padding: DS.gapInsets(t: 40),
              child: StateCard.error(title: SocialStrings.offline, actionLabel: SocialStrings.retry, onAction: c.load),
            ),
          JoinRequestsLoad.failed => Padding(
              padding: DS.gapInsets(t: 40),
              child: StateCard.error(title: SocialStrings.failed, actionLabel: SocialStrings.retry, onAction: c.load),
            ),
          JoinRequestsLoad.ready => _content(),
        },
      );
    });
  }
}
