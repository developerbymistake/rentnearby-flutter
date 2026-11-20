import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../utils/app_toast.dart';
import '../../../trip/widgets/trip_plan_header.dart';
import '../../buddy_navigation.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/buddy_result.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../../shared/widgets/buddy_bottom_bar.dart';
import '../../shared/widgets/buddy_page.dart';
import '../../shared/widgets/buddy_snack.dart';
import '../../shared/widgets/person_row.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/small_pill.dart';
import '../controllers/trip_members_controller.dart';
import '../models/sharing_models.dart';
import '../sharing_deps.dart';
import '../sharing_strings.dart';
import '../widgets/invite_sheet.dart';
import '../widgets/remove_traveller_dialog.dart';
import '../widgets/traveller_menu.dart';

class TravellersOwnerScreen extends StatefulWidget {
  const TravellersOwnerScreen({super.key, required this.tripId, required this.members});

  final String tripId;
  final TripMembers members;

  static String countTitle(TripMembers m) => SharingStrings.countTitle(m.isFull ? m.maxTravellers : m.travellerCount, m.maxTravellers);

  static String countLine(TripMembers m) {
    final p = m.pendingInvites;
    if (m.isFull || p == 0) return SharingStrings.joinedLine(m.travellerCount, m.isFull ? p : 0);
    return SharingStrings.invitesWaiting(p);
  }

  @override
  State<TravellersOwnerScreen> createState() => _TravellersOwnerScreenState();
}

class _TravellersOwnerScreenState extends State<TravellersOwnerScreen> {
  late final TripMembersController _c;
  bool _menuBusy = false;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<TripMembersController>(tag: widget.tripId)) Get.delete<TripMembersController>(tag: widget.tripId);
    _c = Get.put(TripMembersController(widget.tripId, initial: widget.members, api: SharingDeps.members), tag: widget.tripId);
  }

  @override
  void dispose() {
    if (Get.isRegistered<TripMembersController>(tag: widget.tripId)) Get.delete<TripMembersController>(tag: widget.tripId);
    super.dispose();
  }

  void _snack(String text) => BuddySnack.show(context, text, bottom: 104);

  Future<void> _invite() => InviteSheet.show(context, widget.tripId, onChanged: _c.reload);

  Future<void> _cancel(InvitedMember i) async {
    final r = await _c.cancelInvite(i.userId);
    if (!mounted) return;
    if (r is BuddyOk<void>) {
      _snack(SharingStrings.inviteCancelled);
    } else if (r is! BuddyFailed<void> || r.message != 'busy') {
      SharingDeps.toastError(r);
    }
  }

  Future<void> _menu(JoinedMember m) async {
    if (_menuBusy) return;
    _menuBusy = true;
    try {
      final action = await TravellerMenu.show(context, m);
      if (action != TravellerAction.remove || !mounted) return;
      final outcome = await RemoveTravellerDialog.show(context, widget.tripId, m);
      if (outcome == null || !mounted) return;
      await _c.reload();
      if (!mounted) return;
      if (outcome == RemoveOutcome.removed) {
        _snack(SharingStrings.removed(m.name));
      } else {
        AppToast.error(SharingStrings.noLongerOnTrip(m.name));
      }
    } finally {
      _menuBusy = false;
    }
  }

  Widget _dots() => PopupMenuButton<int>(
        key: const ValueKey('travellers_menu'),
        tooltip: SharingStrings.moreOptions,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: DS.circular(12)),
        color: DesignColors.surface,
        onSelected: (_) => BuddyNavigation.openExpenses(widget.tripId),
        itemBuilder: (_) => [
          PopupMenuItem<int>(value: 0, child: Text(SharingStrings.openExpenses, style: Ink3D.text(13, FontWeight.w600, Ink3D.title))),
        ],
        child: TripMenuDots.box(),
      );

  Widget _countCard(TripMembers m) {
    final shown = m.isFull ? m.maxTravellers : m.travellerCount;
    final people = [for (final j in m.joined) (initial: j.initial, seed: j.userId)];
    return Container(
      key: const ValueKey('travellers_count_card'),
      margin: DS.insets(l: 18, t: 20, r: 18),
      padding: DS.sym(h: 18, v: 14),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
        boxShadow: BuddyLook.cardShadows(DS.size),
      ),
      child: Row(
        children: [
          CountStack(people: people.take(3).toList(), extra: shown - (people.length < 3 ? people.length : 3)),
          Gap.h(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(TravellersOwnerScreen.countTitle(m),
                    key: const ValueKey('travellers_count_title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                Text(TravellersOwnerScreen.countLine(m),
                    key: const ValueKey('travellers_count_line'), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _joinedRow(JoinedMember j) {
    final owner = j.isOwner;
    final when = j.joinedAt;
    return PersonRow(
      key: ValueKey('traveller_row_${j.userId}'),
      avatar: BuddyAvatar(initial: j.initial, seed: j.userId),
      title: j.isMe ? SharingStrings.you(j.name) : j.name,
      subtitle: owner
          ? SharingStrings.dotLine(j.username, SharingStrings.createdTheTrip)
          : (when == null ? j.username : SharingStrings.dotLine(j.username, SharingStrings.joinedOn(BuddyFormat.dayMonth(when.toLocal())))),
      trailing: owner
          ? const BuddyBadge(SharingStrings.owner, tone: BuddyBadgeTone.owner)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BuddyBadge(SharingStrings.viewer, tone: BuddyBadgeTone.view),
                Tap3D(
                  tapKey: ValueKey('traveller_dots_${j.userId}'),
                  onTap: () => _menu(j),
                  label: SharingStrings.moreOptions,
                  child: SizedBox(
                    width: DS.s(36),
                    height: DS.s(40),
                    child: Center(child: TripMenuDots.glyph(BuddyLook.subText)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _invitedRow(InvitedMember i) => PersonRow(
        key: ValueKey('invited_row_${i.userId}'),
        avatar: BuddyAvatar(initial: i.initial, seed: i.userId),
        title: i.name,
        subtitle: SharingStrings.dotLine(i.username, SharingStrings.inviteWaitingRow),
        trailing: Obx(() => SmallPill(
              key: ValueKey('cancel_invite_${i.userId}'),
              label: SharingStrings.cancelInvite,
              kind: SmallPillKind.dangerOutline,
              busy: _c.cancelling.contains(i.userId),
              onTap: () => _cancel(i),
            )),
      );

  @override
  Widget build(BuildContext context) => Obx(() {
        final m = _c.members.value;
        if (_c.gone.value) {
          return BuddyPage(
            title: SharingStrings.travellersTitle,
            body: StateCard3D(tone: BuddyLook.teal, art: BuddyArt.luggage, title: BuddySharedStrings.couldNotLoad, layout: StateLayout.tall),
          );
        }
        final full = m.isFull;
        return BuddyPage(
          title: SharingStrings.travellersTitle,
          subtitle: m.title,
          trailing: [_dots()],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _countCard(m),
              const SectionLabel(SharingStrings.joinedSection),
              PersonListCard(children: [for (final j in m.joined) _joinedRow(j)]),
              if (m.invited.isNotEmpty) ...[
                const SectionLabel(SharingStrings.invitedSection),
                PersonListCard(children: [for (final i in m.invited) _invitedRow(i)]),
              ],
            ],
          ),
          bottomBar: BuddyBottomBar(
            line: full ? SharingStrings.tripIsFull : null,
            lineDanger: true,
            children: [
              GradientPillButton(
                key: const ValueKey('travellers_invite'),
                tone: BuddyLook.teal,
                label: SharingStrings.invite,
                enabled: !full,
                onTap: full ? null : _invite,
                offColor: BuddyLook.checkOff,
              ),
            ],
          ),
        );
      });
}

class CountStack extends StatelessWidget {
  const CountStack({super.key, required this.people, this.extra = 0});

  final List<({String initial, String seed})> people;
  final int extra;

  @override
  Widget build(BuildContext context) {
    final box = DS.s(BuddyAvatarSize.xs.box);
    final step = box - DS.s(10);
    final items = <Widget>[
      for (final p in people) BuddyAvatar(initial: p.initial, seed: p.seed, size: BuddyAvatarSize.xs, ring: true),
      if (extra > 0)
        Container(
          key: const ValueKey('travellers_count_more'),
          width: box,
          height: box,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: BuddyLook.avatarGradients.last, begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: DesignColors.surface, width: DS.s(2)),
          ),
          child: Text('+$extra', maxLines: 1, textScaler: TextScaler.noScaling, style: Ink3D.text(11.5, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: box + step * (items.length - 1),
      height: box,
      child: Stack(children: [for (var i = 0; i < items.length; i++) Positioned(left: step * i, top: 0, child: items[i])]),
    );
  }
}
