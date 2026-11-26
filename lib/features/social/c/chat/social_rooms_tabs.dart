import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../design/extra/ext_chat.dart';
import '../../../buddy/buddies/models/buddy_models.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../../buddy/shared/widgets/buddy_confirm_box.dart';
import '../../../buddy/shared/widgets/segment_tabs.dart';
import '../../b/widgets/social_widgets_b.dart';
import '../../shared/social_nav.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/person_actions.dart';
import '../../shared/widgets/social_avatar_stack.dart';
import '../social_strings_c.dart';
import 'models/chat_models.dart';
import 'rooms_controller.dart';

typedef PeopleTabBuilder = Widget Function(BuildContext context, RoomsController rooms);

class SocialRoomsTabs extends StatefulWidget {
  const SocialRoomsTabs({super.key, required this.rooms, required this.people, this.initialTab = 0});

  final RoomsController rooms;
  final PeopleTabBuilder people;
  final int initialTab;

  @override
  State<SocialRoomsTabs> createState() => _SocialRoomsTabsState();
}

class _SocialRoomsTabsState extends State<SocialRoomsTabs> {
  late int _tab = widget.initialTab;

  static const List<String> _labels = [SocialStringsC.people, SocialStringsC.trips, SocialStringsC.requests];

  @override
  void initState() {
    super.initState();
    widget.rooms.reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.rooms;
    return Column(
      children: [
        Obx(() {
          final u = rooms.unread.value;
          final requestCount = rooms.requests.items.length;
          return SegmentTabs(
            key: const ValueKey('social_rooms_tabs'),
            labels: _labels,
            selected: _tab,
            tone: ListingTone.indigo,
            counts: {0: u.people, 1: u.trips, 2: requestCount > 0 ? requestCount : u.requests},
            solidBadges: const {0, 1, 2},
            margin: DS.gapInsets(l: 18, t: 4, r: 18, b: 10),
            onTap: (i) => setState(() => _tab = i),
          );
        }),
        Expanded(
          child: switch (_tab) {
            1 => _TripsTab(rooms: rooms),
            2 => _RequestsTab(rooms: rooms),
            _ => widget.people(context, rooms),
          },
        ),
      ],
    );
  }
}

abstract final class SocialChatTime {
  static String ago(DateTime? at, {DateTime? now}) {
    if (at == null) return '';
    final diff = (now ?? DateTime.now()).toUtc().difference(at.toUtc());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final l = at.toLocal();
    return '${l.day}/${l.month}';
  }

  static String badge(int n) => n <= 0 ? '' : (n > 99 ? '99+' : '$n');
}

class SocialPersonRoomRow extends StatelessWidget {
  const SocialPersonRoomRow({super.key, required this.room, required this.index});

  final ChatRoomModel room;
  final int index;

  static final List<ListingTone> _tones = [ListingTone.teal, ListingTone.indigo, ListingTone.cD];

  static String subtitleOf(ChatRoomModel r) {
    if (r.peerFollowsMe && r.iFollowPeer) return SocialStrings.followEachOther;
    final s = r.subtitle;
    if (s != null && s.isNotEmpty) return s;
    if (r.peerFollowsMe) return SocialStrings.followsYou;
    return r.peer?.homeCity ?? SocialStringsC.newToYou;
  }

  @override
  Widget build(BuildContext context) {
    final peer = room.peer;
    final name = peer?.name ?? '';
    return ChatThreadCard(
      key: ValueKey('social_room_${room.roomId}'),
      tone: _tones[index % _tones.length],
      initial: peer?.initial.isNotEmpty == true ? peer!.initial : ChatLook3D.initialOf(name),
      sticker: null,
      avatarGradient: BuddyLook.avatarGradient(peer?.userId ?? room.roomId),
      compactTop: true,
      tag: SocialStringsC.traveller,
      title: name,
      subtitle: subtitleOf(room),
      time: SocialChatTime.ago(room.lastMessageAt),
      unread: SocialChatTime.badge(room.unread),
      preview: room.preview ?? SocialStringsC.sayHi,
      onTap: () => SocialNav.openRoom(room.roomId),
      photoUrl: peer?.photoUrl,
    );
  }
}

class _TripsTab extends StatelessWidget {
  const _TripsTab({required this.rooms});

  final RoomsController rooms;

  @override
  Widget build(BuildContext context) => _RoomsListView(
        list: rooms.trips,
        rooms: rooms,
        empty: ChatStateCard3D(tone: ListingTone.indigo, art: ListingArt.luggage, title: SocialStringsC.noTripChats, message: SocialStringsC.noTripChatsLine),
        itemBuilder: (r, i) => SocialTripRoomRow(room: r, index: i),
      );
}

class SocialTripRoomRow extends StatelessWidget {
  const SocialTripRoomRow({super.key, required this.room, required this.index});

  final ChatRoomModel room;
  final int index;

  static final List<(String, ListingTone)> _looks = [
    (ListingArt.mountain, ListingTone.indigo),
    (ListingArt.canoe, ListingTone.cA),
    (ListingArt.camping, ListingTone.teal),
    (ListingArt.beach, ListingTone.cF),
  ];

  static (String, ListingTone) lookOf(String tripId, {int cityKey = 0}) {
    if (cityKey != 0) {
      final seed = SocialLookB.seedOf(cityKey, tripId);
      return (SocialLookB.artOf(seed), SocialLookB.toneOf(seed));
    }
    var h = 0;
    for (final c in tripId.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _looks[h % _looks.length];
  }

  @override
  Widget build(BuildContext context) {
    final trip = room.trip;
    final (art, tone) = lookOf(trip?.tripId ?? room.roomId, cityKey: trip?.cityKey ?? 0);
    final badge = SocialChatTime.badge(room.unread);
    final stackHasFaces = (trip?.photoUrls.isNotEmpty ?? false) || (trip?.initials.isNotEmpty ?? false);
    return Padding(
      padding: DS.gapInsets(l: 18, r: 18, b: 14),
      child: Tap3D(
        key: ValueKey('social_trip_room_${room.roomId}'),
        onTap: () => SocialNav.openRoom(room.roomId),
        label: [trip?.title ?? '', SocialStringsC.members(trip?.memberCount ?? 0), room.preview ?? ''].join(', '),
        exclude: true,
        child: Container(
          padding: DS.insets(l: 16, t: 14, r: 16, b: 14),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(32), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
            boxShadow: BuddyLook.cardShadows(DS.size),
          ),
          child: Row(
            children: [
              Container(
                width: DS.s(64),
                height: DS.s(64),
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.circular(16)),
                child: Image.asset(art, width: DS.s(44), height: DS.s(44)),
              ),
              Gap.h(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                    Gap.v(3),
                    Row(children: [
                      if (stackHasFaces) ...[
                        SocialAvatarStack(photoUrls: trip?.photoUrls ?? const [], initials: trip?.initials ?? const []),
                        Gap.h(6),
                      ],
                      Flexible(child: Text(SocialStringsC.members(trip?.memberCount ?? 0), maxLines: 1, style: Ink3D.text(12.5, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0))),
                    ]),
                    if ((room.preview ?? '').isNotEmpty) ...[
                      Gap.v(4),
                      Text(room.preview!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w400, Ink3D.body, letterSpacing: 0)),
                    ],
                  ],
                ),
              ),
              Gap.h(8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(SocialChatTime.ago(room.lastMessageAt), style: Ink3D.text(12, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
                  if (badge.isNotEmpty) ...[
                    Gap.v(8),
                    Container(
                      constraints: BoxConstraints(minWidth: DS.s(26), minHeight: DS.s(26)),
                      padding: DS.sym(h: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: BuddyLook.countBadge, borderRadius: DS.circular(13)),
                      child: Text(badge, textScaler: TextScaler.noScaling, style: Ink3D.text(12.5, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({required this.rooms});

  final RoomsController rooms;

  @override
  Widget build(BuildContext context) => _RoomsListView(
        list: rooms.requests,
        rooms: rooms,
        empty: ChatStateCard3D(tone: ListingTone.indigo, art: ListingArt.speechBalloon, title: SocialStringsC.noRequests, message: SocialStringsC.repliesFree),
        header: Obx(() => Padding(
              padding: DS.gapInsets(l: 22, r: 22, b: 10),
              child: Text(SocialStringsC.requestCount(rooms.requests.items.length), style: Ink3D.text(13, FontWeight.w600, BuddyLook.subText, letterSpacing: 0)),
            )),
        footer: Padding(
          padding: DS.gapInsets(l: 18, t: 4, r: 18, b: 18),
          child: ChatSafetyNote3D(text: SocialStringsC.repliesFree, margin: EdgeInsets.zero),
        ),
        itemBuilder: (r, i) => SocialRequestRow(room: r, rooms: rooms),
      );
}

class SocialRequestRow extends StatelessWidget {
  const SocialRequestRow({super.key, required this.room, required this.rooms});

  final ChatRoomModel room;
  final RoomsController rooms;

  Future<void> _delete(BuildContext context) async {
    final ok = await BuddyConfirmBox.ask(context,
        art: ListingArt.memo, title: SocialStringsC.deleteRequestTitle, body: SocialStringsC.deleteRequestBody, confirmLabel: SocialStringsC.delete, confirmKind: ConfirmKind.danger);
    if (!ok) return;
    await rooms.deleteRoom(room.roomId);
  }

  @override
  Widget build(BuildContext context) {
    final peer = room.peer;
    final name = peer?.name ?? '';
    return Padding(
      padding: DS.gapInsets(l: 18, r: 18, b: 12),
      child: Container(
        key: ValueKey('social_request_${room.roomId}'),
        padding: DS.insets(l: 16, t: 14, r: 16, b: 14),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(16), boxShadow: BuddyLook.cardShadows(DS.size)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuddyAvatar(initial: peer?.initial ?? ChatLook3D.initialOf(name), seed: peer?.userId ?? room.roomId, photoUrl: peer?.photoUrl),
            Gap.h(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15.5, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
                    Text(SocialChatTime.ago(room.lastMessageAt), style: Ink3D.text(12, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
                  ]),
                  Gap.v(4),
                  Text(room.preview ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w400, Ink3D.body, letterSpacing: 0, height: 1.45)),
                  Gap.v(10),
                  Wrap(
                    spacing: DS.s(10),
                    runSpacing: DS.s(8),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _SmallButton(label: SocialStringsC.reply, filled: true, onTap: () => SocialNav.openRoom(room.roomId)),
                      _SmallButton(label: SocialStringsC.delete, filled: false, onTap: () => _delete(context)),
                      if (peer != null)
                        Tap3D(
                          onTap: () => PersonActions.showMenu(context, person: peer, contextName: BuddyContext.chat, onBlocked: () => rooms.removeRoom(room.roomId)),
                          label: SocialStringsC.reportBlock,
                          exclude: true,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: DS.s(KitMetrics.touch)),
                            child: Center(
                              widthFactor: 1,
                              child: Text(SocialStringsC.reportBlock, style: Ink3D.text(13, FontWeight.w600, BuddyLook.dangerText, letterSpacing: 0)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.filled, required this.onTap});

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: Container(
        constraints: BoxConstraints(minHeight: DS.s(36), minWidth: DS.s(76)),
        padding: DS.sym(h: 16),
        decoration: BoxDecoration(
          gradient: filled ? tone.gradient : null,
          color: filled ? null : BuddyLook.closeBg,
          borderRadius: DS.circular(18),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(label, style: Ink3D.text(13.5, FontWeight.w600, filled ? DesignColors.onPrimary : BuddyLook.subText, letterSpacing: 0)),
        ),
      ),
    );
  }
}

class _RoomsListView extends StatefulWidget {
  const _RoomsListView({required this.list, required this.rooms, required this.empty, required this.itemBuilder, this.header, this.footer});

  final RoomsList list;
  final RoomsController rooms;
  final Widget empty;
  final Widget Function(ChatRoomModel room, int index) itemBuilder;
  final Widget? header;
  final Widget? footer;

  @override
  State<_RoomsListView> createState() => _RoomsListViewState();
}

class _RoomsListViewState extends State<_RoomsListView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - DS.s(200)) widget.rooms.loadMore(widget.list.bucket);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final list = widget.list;
        final state = list.state.value;
        final items = list.items.toList();
        if (items.isEmpty && (state == RoomsLoad.loading || state == RoomsLoad.idle)) {
          return ListView.builder(physics: const NeverScrollableScrollPhysics(), itemCount: 4, itemBuilder: (_, _) => const ChatThreadCard.skeleton());
        }
        if (items.isEmpty && (state == RoomsLoad.failed || state == RoomsLoad.offline)) {
          return ListView(physics: const NeverScrollableScrollPhysics(), children: [
            StateCard.error(
              title: state == RoomsLoad.offline ? SocialStrings.offline : SocialStrings.failed,
              actionLabel: SocialStrings.retry,
              onAction: () => widget.rooms.load(list.bucket),
            ),
          ]);
        }
        return RefreshIndicator(
          color: ListingTone.indigo.g2,
          backgroundColor: DesignColors.surface,
          onRefresh: () => widget.rooms.load(list.bucket),
          child: ListView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: DS.insets(b: 24),
            children: [
              if (items.isEmpty)
                widget.empty
              else ...[
                ?widget.header,
                for (var i = 0; i < items.length; i++) EntranceOnce(key: ValueKey(items[i].roomId), index: i < 6 ? i : 6, child: widget.itemBuilder(items[i], i)),
                ?widget.footer,
              ],
              if (list.loadingMore.value)
                Padding(padding: DS.gapInsets(t: 16, b: 16), child: Center(child: SizedBox(width: DS.s(24), height: DS.s(24), child: CircularProgressIndicator(strokeWidth: DS.s(3), color: ListingTone.indigo.g2)))),
            ],
          ),
        );
      });
}
