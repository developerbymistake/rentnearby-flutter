import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../buddy_error_types.dart';
import '../../buddy_live.dart';
import '../../buddy_navigation.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/buddy_result.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../../shared/widgets/buddy_bottom_bar.dart';
import '../../shared/widgets/buddy_page.dart';
import '../../shared/widgets/note_banner.dart';
import '../../shared/widgets/person_row.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/view_only_chip.dart';
import '../../sharing/models/sharing_models.dart';
import '../../sharing/screens/travellers_owner_screen.dart' show CountStack;
import '../data/trip_viewer_api.dart';
import '../data/viewer_trip_cache.dart';
import '../viewer_deps.dart';
import '../viewer_strings.dart';
import '../widgets/leave_trip_dialog.dart';

class TravellersViewerScreen extends StatefulWidget {
  const TravellersViewerScreen({super.key, required this.tripId, required this.members, this.api});

  final String tripId;
  final TripMembers members;
  final TripViewerApi? api;

  @override
  State<TravellersViewerScreen> createState() => _TravellersViewerScreenState();
}

class _TravellersViewerScreenState extends State<TravellersViewerScreen> {
  final _leaving = false.obs;

  TripViewerApi get _api => widget.api ?? ViewerDeps.viewer;

  Future<void> _leave() async {
    if (_leaving.value) return;
    _leaving.value = true;
    try {
      if (!await LeaveTripDialog.ask(context)) return;
      final r = await _api.leave(widget.tripId);
      if (!mounted) return;
      switch (r) {
        case BuddyOk():
          ViewerTripCache.remove(widget.tripId);
          BuddyLive.sharedTrips.value++;
          ViewerDeps.toMyTrips();
          ViewerDeps.snack(ViewerStrings.youLeft);
        case BuddyRefused(:final statusCode, :final type) when statusCode == 404 || type == BuddyErrorTypes.tripNotFound:
          ViewerTripCache.remove(widget.tripId);
          BuddyLive.sharedTrips.value++;
          BuddyNavigation.openTripView(widget.tripId, deleted: true, replace: true);
        default:
          ViewerDeps.toastError(r);
      }
    } finally {
      if (mounted) _leaving.value = false;
    }
  }

  Widget _row(JoinedMember j) {
    final when = j.joinedAt;
    final joined = when == null ? null : ViewerStrings.joinedOn(BuddyFormat.dayMonth(when.toLocal()));
    return PersonRow(
      key: ValueKey('viewer_traveller_${j.userId}'),
      avatar: BuddyAvatar(initial: j.initial, seed: j.userId),
      title: j.isMe ? ViewerStrings.you(j.name) : j.name,
      subtitle: j.isOwner ? ViewerStrings.dot(j.username, ViewerStrings.createdTheTrip) : (joined == null ? j.username : ViewerStrings.dot(j.username, joined)),
      trailing: j.isOwner ? const BuddyBadge(ViewerStrings.owner, tone: BuddyBadgeTone.owner) : const BuddyBadge(ViewerStrings.viewer, tone: BuddyBadgeTone.view),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.members;
    return BuddyPage(
      title: ViewerStrings.travellersTitle,
      subtitle: m.title,
      trailing: const [ViewOnlyChip()],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('viewer_count_card'),
            margin: DS.insets(l: 18, t: 20, r: 18),
            padding: DS.sym(h: 18, v: 14),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              borderRadius: DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
              boxShadow: BuddyLook.cardShadows(DS.size),
            ),
            child: Row(
              children: [
                CountStack(
                  people: [for (final j in m.joined.take(3)) (initial: j.initial, seed: j.userId)],
                  extra: m.travellerCount - (m.joined.length < 3 ? m.joined.length : 3),
                ),
                Gap.h(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(ViewerStrings.travellerCount(m.travellerCount), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                      Text(ViewerStrings.sharedBy(m.ownerName), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel(ViewerStrings.joinedSection),
          PersonListCard(children: [for (final j in m.joined) _row(j)]),
          NoteBanner(art: BuddyArt.shield, text: ViewerStrings.onlyOwnerCan(m.ownerName), tone: NoteTone.teal),
        ],
      ),
      bottomBar: m.canLeave
          ? BuddyBottomBar(
              children: [
                Obx(() => WhitePillButton(
                      key: const ValueKey('viewer_leave'),
                      tone: BuddyLook.danger,
                      label: ViewerStrings.leaveTrip,
                      danger: true,
                      enabled: !_leaving.value,
                      onTap: _leave,
                    )),
              ],
            )
          : null,
    );
  }
}
