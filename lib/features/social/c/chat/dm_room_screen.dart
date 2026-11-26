import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../design/extra/ext_chat.dart';
import '../../../../utils/app_toast.dart';
import '../../../../utils/input_formatters.dart';
import '../../../buddy/buddies/buddy_feedback.dart';
import '../../../buddy/buddies/models/buddy_models.dart';
import '../../../buddy/buddies/widgets/block_dialog.dart';
import '../../../buddy/buddies/widgets/report_sheet.dart';
import '../../../buddy/buddy_live.dart';
import '../../../buddy/buddy_navigation.dart';
import '../../../buddy/shared/buddy_format.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../../buddy/shared/widgets/buddy_confirm_box.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../../buddy/viewer/data/viewer_trip_cache.dart';
import '../../../buddy/viewer/viewer_deps.dart';
import '../../../buddy/viewer/viewer_strings.dart';
import '../../../buddy/viewer/widgets/leave_trip_dialog.dart';
import '../../shared/social_error_types.dart';
import '../../shared/social_formats.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../shared/social_strings.dart';
import '../../a/people/people_widgets.dart';
import '../../a/widgets/social_chips_a.dart';
import '../../shared/widgets/plus_widgets.dart';
import '../../shared/widgets/social_avatar_stack.dart';
import '../social_strings_c.dart';
import '../widgets/chat_room_header.dart';
import 'models/chat_models.dart';
import 'open_room_tracker.dart';
import 'report_message_dialog.dart';
import 'room_controller.dart';
import 'rooms_controller.dart';
import 'social_rooms_tabs.dart';

class DmRoomScreen extends StatefulWidget {
  const DmRoomScreen({super.key, this.roomId, this.userId, this.name, this.photoUrl, this.tripId, this.controller});

  final String? roomId;
  final String? userId;
  final String? name;
  final String? photoUrl;
  final String? tripId;
  final RoomController? controller;

  @override
  State<DmRoomScreen> createState() => _DmRoomScreenState();
}

class _DmRoomScreenState extends State<DmRoomScreen> {
  static int _seq = 0;
  late final String _tag = 'dm_room_${_seq++}';
  late final RoomController _c;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Worker> _workers = [];
  String? _trackedRoom;

  ListingTone get _tone => ListingTone.indigo;

  @override
  void initState() {
    super.initState();
    _c = Get.put(widget.controller ?? RoomController(roomId: widget.roomId, userId: widget.userId, tripId: widget.tripId), tag: _tag);
    _workers
      ..add(ever<ChatRoomModel?>(_c.room, _track))
      ..add(ever<List<ChatMessageModel>>(_c.messages, (_) => _onMessages()))
      ..add(ever<BuddyRefused<Object?>?>(_c.refusal, _onRefusal))
      ..add(ever<String?>(_c.bounced, _onBounced))
      ..add(ever<bool>(_c.repliedFree, (v) {
        if (v && mounted) BuddySnack.show(context, SocialStringsC.movedToPeople);
      }));
    final id = widget.roomId;
    if (id != null) _track(null, id: id);
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients || !_c.hasOlder.value || _c.loadingOlder.value) return;
    final p = _scroll.position;
    if (p.pixels <= p.minScrollExtent + DS.s(200)) unawaited(_loadOlder());
  }

  Future<void> _loadOlder() async {
    final fromEnd = _scroll.hasClients ? _scroll.position.maxScrollExtent - _scroll.position.pixels : 0.0;
    await _c.loadOlder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final p = _scroll.position;
      _scroll.jumpTo((p.maxScrollExtent - fromEnd).clamp(p.minScrollExtent, p.maxScrollExtent));
    });
  }

  void _onMessages() {
    if (_c.loadingOlder.value) return;
    _toBottom();
  }

  void _track(ChatRoomModel? r, {String? id}) {
    final roomId = id ?? r?.roomId;
    if (roomId == null || roomId == _trackedRoom) return;
    final old = _trackedRoom;
    if (old != null) OpenRoomTracker.close(old);
    _trackedRoom = roomId;
    OpenRoomTracker.open(roomId);
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    final tracked = _trackedRoom;
    if (tracked != null) OpenRoomTracker.close(tracked);
    _input.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    Get.delete<RoomController>(tag: _tag, force: true);
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 240), curve: Curves.fastOutSlowIn);
    });
  }

  void _onRefusal(BuddyRefused<Object?>? r) {
    if (r == null || !mounted) return;
    _c.refusal.value = null;
    final type = r.type;
    if (type == SocialErrorTypes.awaitingReply) return;
    if (PlusSheets.handles(type)) {
      PlusSheets.limitReached(context, errorType: type!, data: r.data, from: 'chat');
      return;
    }
    if (type == SocialErrorTypes.textTooLong) return;
    AppToast.error(r.message ?? SocialStringsC.sendFailed);
  }

  void _onBounced(String? text) {
    if (text == null) return;
    _c.bounced.value = null;
    if (_input.text.trim().isEmpty) _input.text = text;
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    final ok = await _c.send(text);
    if (!ok && _input.text.isEmpty) _input.text = text;
  }

  String get _peerName => _c.room.value?.peer?.name ?? _c.preflight.value?.peer.name ?? widget.name ?? '';

  String get _peerFirst {
    final n = _peerName.trim();
    final i = n.indexOf(' ');
    return i <= 0 ? n : n.substring(0, i);
  }

  SocialPerson? get _peer => _c.room.value?.peer ?? _c.preflight.value?.peer;

  @override
  Widget build(BuildContext context) => KitStatusBar(
        lightIcons: false,
        child: Scaffold(
          backgroundColor: ListingPalette.indigo.page,
          body: Obx(() {
            final view = _c.view.value;
            return Column(
              children: [
                SafeArea(bottom: false, child: _header()),
                Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: _body(view))),
                if (view == RoomView.ready) _pinnedSafety(),
                if (view == RoomView.ready) _bottom(),
              ],
            );
          }),
        ),
      );

  Widget _header() {
    final r = _c.room.value;
    if (r != null && r.isTrip || r == null && widget.tripId != null) {
      final trip = r?.trip;
      final title = trip?.title ?? '';
      final (art, tone) = SocialTripRoomRow.lookOf(trip?.tripId ?? widget.tripId ?? '', cityKey: trip?.cityKey ?? 0);
      return ChatRoomHeader(
        key: const ValueKey('dm_room_header'),
        tone: _tone,
        initial: ChatLook3D.initialOf(title),
        name: title,
        subtitle: SocialStringsC.members(trip?.memberCount ?? 0),
        subtitleLead: (trip != null && (trip.photoUrls.isNotEmpty || trip.initials.isNotEmpty)) ? SocialAvatarStack(key: const ValueKey('dm_trip_members'), photoUrls: trip.photoUrls, initials: trip.initials, size: 22) : null,
        leading: ChatRoomHeader.tripArt(key: const ValueKey('dm_trip_art'), art: art, gradient: tone.gradient),
        onBack: () => Get.back(),
        onMore: r == null ? null : _tripMenu,
        moreKey: const ValueKey('dm_room_more'),
      );
    }
    final subtitle = r != null ? SocialPersonRoomRow.subtitleOf(r) : (_peer?.homeCity ?? SocialStringsC.newToYou);
    return ChatRoomHeader(
      key: const ValueKey('dm_room_header'),
      tone: _tone,
      initial: _peer?.initial.isNotEmpty == true ? _peer!.initial : ChatLook3D.initialOf(_peerName),
      name: SocialFormats.shortName(_peerName),
      nameTrailing: GenderGlyph(gender: _peer?.gender ?? ''),
      avatarGradient: BuddyLook.avatarGradient(_peer?.userId ?? widget.userId ?? _peerName),
      subtitle: subtitle,
      onBack: () => Get.back(),
      onMore: _peer == null ? null : _directMenu,
      moreKey: const ValueKey('dm_room_more'),
      photoUrl: _peer?.photoUrl ?? widget.photoUrl,
    );
  }

  Widget _body(RoomView view) {
    switch (view) {
      case RoomView.loading:
        const widths = [180.0, 140.0, 220.0, 120.0];
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: DS.insets(l: 18, t: 8, r: 18, b: 10),
          children: [for (var i = 0; i < widths.length; i++) ChatSkeletonBubble3D(width: widths[i], mine: i.isOdd)],
        );
      case RoomView.offline:
      case RoomView.failed:
        return ListView(children: [
          StateCard.error(title: view == RoomView.offline ? SocialStrings.offline : SocialStrings.failed, actionLabel: SocialStrings.retry, onAction: _c.open),
        ]);
      case RoomView.gone:
        return ListView(children: [
          ChatStateCard3D(tone: _tone, art: ListingArt.speechBalloon, title: widget.tripId != null ? SocialStringsC.noTripChat : SocialStrings.gone),
        ]);
      case RoomView.ready:
        return _messages();
    }
  }

  Widget _messages() {
    final r = _c.room.value;
    final items = _c.messages.toList();
    final peerRead = _c.peerLastReadSeq.value;
    final trip = _c.isTrip;
    final children = <Widget>[
      if (_c.loadingOlder.value) const LoadMoreFooter(loading: true),
      const ChatSystemNote(SocialStringsC.disappear),
      if (r != null && r.isIncomingRequest) _info(SocialStringsC.receiverInfo(_peerFirst)),
    ];
    String? lastDay;
    for (final m in items) {
      final day = _dayLabel(m.createdAt);
      if (day != lastDay) {
        children.add(ChatSystemNote(day));
        lastDay = day;
      }
      children.add(KeyedSubtree(key: ValueKey(m.isLocal ? 'local_${m.clientMessageId}' : 'seq_${m.seq}'), child: _bubble(m, trip: trip, peerRead: peerRead)));
    }
    return ChatThreadFade(
      child: ListView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: DS.insets(l: 18, t: 8, r: 18, b: 16) + EdgeInsets.only(bottom: _noticeShown ? DS.s(ChatNoticePanel3D.overhang) + DS.s(8) : 0),
        children: children,
      ),
    );
  }

  Widget _pinnedSafety() {
    final r = _c.room.value;
    final safety = !_c.isTrip && (r == null || r.isRequest);
    final actions = r != null && r.isIncomingRequest;
    if (!safety && !actions) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('dm_pinned_safety'),
      padding: DS.gapInsets(l: 18, r: 18, b: 10) + EdgeInsets.only(bottom: _noticeShown ? DS.s(ChatNoticePanel3D.overhang) : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (safety) ChatSafetyNote3D(text: SocialStringsC.safety, margin: EdgeInsets.zero),
          if (actions) _receiverActions(),
        ],
      ),
    );
  }

  static Color _senderInk(String seed) {
    final i = BuddyLook.avatarIndex(seed);
    if (i == 3) return BuddyLook.note[NoteToneColor.amber]!.$2;
    return BuddyLook.avatarGradients[i].last;
  }

  static String _dayLabel(DateTime? at) {
    if (at == null) return SocialStringsC.today;
    final l = at.toLocal();
    final now = DateTime.now();
    final d = DateTime(l.year, l.month, l.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff <= 0) return SocialStringsC.today;
    if (diff == 1) return SocialStringsC.yesterday;
    return BuddyFormat.dayMonth(l);
  }

  static String? _timeOf(DateTime? at) {
    if (at == null) return null;
    final l = at.toLocal();
    return BuddyFormat.time12('${l.hour}:${l.minute}');
  }

  Widget _info(String text) => Container(
        margin: DS.gapInsets(t: 4, b: 4),
        padding: DS.insets(l: 16, t: 12, r: 16, b: 12),
        decoration: BoxDecoration(color: BuddyLook.note[NoteToneColor.indigo]!.$1, borderRadius: DS.circular(16)),
        child: Row(children: [
          Image.asset(ListingArt.speechBalloon, width: DS.s(34), height: DS.s(34)),
          Gap.h(12),
          Expanded(child: Text(text, style: Ink3D.text(13.5, FontWeight.w400, Ink3D.body, letterSpacing: 0, height: 1.45))),
        ]),
      );

  Widget _bubble(ChatMessageModel m, {required bool trip, required int peerRead}) {
    if (m.isSystem) return ChatSystemNote(m.text, colors: BuddyLook.note[NoteToneColor.teal]);
    final mine = _c.isMine(m) || m.isLocal;
    final ticks = !mine || m.isLocal ? ChatTicks.none : (!trip && peerRead >= m.seq ? ChatTicks.read : ChatTicks.sent);
    final sender = trip && !mine && (m.senderName ?? '').isNotEmpty ? SocialFormats.shortName(m.senderName!) : null;
    Widget bubble = ChatBubble3D(
      tone: _tone,
      text: m.text,
      mine: mine,
      ticks: ticks,
      dimmed: m.sending,
      time: m.isLocal ? null : _timeOf(m.createdAt),
      sender: sender,
      senderColor: sender == null ? null : _senderInk(m.senderId ?? sender),
      maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      maskToken: m.masked ? SocialStringsC.maskToken : null,
    );
    if (!mine) {
      bubble = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (d) => _messageMenu(m, d.globalPosition),
        child: bubble,
      );
    }
    return Padding(
      padding: DS.gapInsets(t: 4, b: 4),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          bubble,
          if (mine && m.masked)
            Padding(padding: DS.insets(t: 4, r: 4), child: Text(SocialStringsC.masked, style: Ink3D.text(12, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0))),
          if (m.failed)
            Tap3D(
              key: ValueKey('dm_retry_${m.clientMessageId}'),
              onTap: () => _c.retry(m.clientMessageId ?? ''),
              label: SocialStringsC.notSent,
              exclude: true,
              child: Padding(padding: DS.insets(t: 4, r: 4), child: Text(SocialStringsC.notSent, style: Ink3D.text(12, FontWeight.w600, BuddyLook.dangerText, letterSpacing: 0))),
            ),
        ],
      ),
    );
  }

  void _messageMenu(ChatMessageModel m, Offset at) {
    final roomId = _c.currentRoomId;
    if (roomId == null || m.isLocal) return;
    showMenu3D(context, anchor: Rect.fromLTWH(at.dx, at.dy, 1, 1), items: [
      MenuItem3D(label: SocialStringsC.reportMessage, art: ListingArt.warning, danger: true, onTap: () => _reportMessage(roomId, m.seq)),
    ]);
  }

  Future<void> _reportMessage(String roomId, int seq) async {
    final ok = await ReportMessageDialog.show(context, roomId: roomId, seq: seq);
    if (ok) AppToast.success(SocialStringsC.reported);
  }

  Widget _receiverActions() {
    final peer = _peer;
    return Padding(
      padding: DS.gapInsets(t: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _link(SocialStringsC.delete, BuddyLook.subText, BuddyLook.closeBg, _deleteRequest, const ValueKey('dm_receiver_delete')),
          if (peer != null) ...[
            Gap.h(10),
            _link(SocialStrings.report, BuddyLook.dangerText, BuddyLook.note[NoteToneColor.danger]!.$1, () => _report(), const ValueKey('dm_receiver_report')),
            Gap.h(10),
            _link(SocialStrings.block, BuddyLook.dangerText, BuddyLook.note[NoteToneColor.danger]!.$1, () => _block(), const ValueKey('dm_receiver_block')),
          ],
        ],
      ),
    );
  }

  Widget _link(String label, Color color, Color bg, VoidCallback onTap, Key key) => Tap3D(
        key: key,
        onTap: onTap,
        label: label,
        exclude: true,
        child: Container(
          padding: DS.sym(h: 16, v: 8),
          decoration: BoxDecoration(color: bg, borderRadius: DS.circular(18)),
          child: Text(label, style: Ink3D.text(13.5, FontWeight.w600, color, letterSpacing: 0)),
        ),
      );

  Future<void> _deleteRequest() async {
    final ok = await BuddyConfirmBox.ask(context,
        art: ListingArt.memo, title: SocialStringsC.deleteRequestTitle, body: SocialStringsC.deleteRequestBody, confirmLabel: SocialStringsC.delete, confirmKind: ConfirmKind.danger);
    if (!ok || !mounted) return;
    final r = await _c.deleteRoom();
    if (!mounted) return;
    if (r.isOk) {
      Get.back();
      AppToast.success(SocialStringsC.deleted);
    } else {
      BuddyFeedback.writeFailed(r);
    }
  }

  Future<void> _report() async {
    final peer = _peer;
    if (peer == null) return;
    final out = await ReportDialog.show(context, person: peer.asBuddyPerson, contextName: BuddyContext.chat);
    if (out == ReportOutcome.reportedAndBlocked) _afterBlock();
  }

  Future<void> _block() async {
    final peer = _peer;
    if (peer == null) return;
    if (await BlockDialog.show(context, person: peer.asBuddyPerson, contextName: BuddyContext.chat)) _afterBlock();
  }

  void _afterBlock() {
    final id = _c.currentRoomId;
    if (id != null) RoomsController.maybe?.removeRoom(id);
    if (mounted) Get.back();
  }

  void _directMenu(Rect anchor) {
    final peer = _peer;
    if (peer == null) return;
    showMenu3D(context, anchor: anchor, width: 220, items: [
      MenuItem3D(label: SocialStringsC.viewProfile, art: ListingArt.panda, onTap: () => SocialNav.openTraveller(peer.userId)),
      MenuItem3D(label: SocialStringsC.reportName(peer.shortName), art: ListingArt.warning, danger: true, onTap: _report),
      MenuItem3D(label: SocialStringsC.blockName(peer.shortName), art: ListingArt.locked, danger: true, onTap: _block),
    ]);
  }

  void _tripMenu(Rect anchor) {
    final trip = _c.room.value?.trip;
    final roomId = _c.currentRoomId;
    if (trip == null || roomId == null) return;
    final seq = _c.latestOtherSeq();
    final left = _c.lock == RoomLock.left;
    showMenu3D(context, anchor: anchor, width: 220, items: [
      MenuItem3D(label: SocialStringsC.membersItem, art: ListingArt.panda, onTap: () => BuddyNavigation.openTravellers(trip.tripId)),
      if (seq != null) MenuItem3D(label: SocialStringsC.reportChat, art: ListingArt.warning, danger: true, onTap: () => _reportMessage(roomId, seq)),
      if (!left) MenuItem3D(label: SocialStringsC.leaveTrip, art: ListingArt.memo, danger: true, onTap: () => _leave(trip.tripId)),
    ]);
  }

  Future<void> _leave(String tripId) async {
    if (!await LeaveTripDialog.ask(context)) return;
    final r = await ViewerDeps.viewer.leave(tripId);
    switch (r) {
      case BuddyOk():
        ViewerTripCache.remove(tripId);
        BuddyLive.sharedTrips.value++;
        ViewerDeps.snack(ViewerStrings.youLeft);
        final id = _c.currentRoomId;
        if (id != null) RoomsController.maybe?.removeRoom(id);
        if (mounted) Get.back();
      default:
        ViewerDeps.toastError(r);
    }
  }

  String? get _noticeText {
    final p = _c.preflight.value;
    if (_c.room.value == null && p != null && !p.canMessage) return SocialStringsC.cannotMessage;
    if (_c.lock == RoomLock.left) return _c.isTrip ? SocialStringsC.leftTrip : SocialStringsC.cannotMessage;
    return null;
  }

  bool get _noticeShown => _noticeText != null;

  Widget _bottom() {
    final r = _c.room.value;
    final p = _c.preflight.value;
    final notice = _noticeText;
    if (notice != null) return ChatNoticePanel3D(key: const ValueKey('dm_notice'), tone: _tone, text: notice);
    final lock = _c.lock;
    final newChats = _newChats();
    if (lock == RoomLock.awaitingReply) {
      return _lockBar(SocialStringsC.firstMessageTitle, SocialStringsC.freeCountLine(newChats, _peerFirst), 'dm_lock_awaiting');
    }
    if (lock == RoomLock.limit) {
      return _lockBar(SocialStringsC.limitTitle, SocialStringsC.limitLine(newChats), 'dm_lock_limit');
    }
    final incoming = r != null && r.isIncomingRequest;
    final showFree = r == null && p != null && !p.isFree && !(SocialMeController.maybe?.me.value?.limits.isPlus ?? false);
    return _composer(hint: incoming ? SocialStringsC.replyFree : SocialStringsC.writeMessage, freeLine: showFree ? SocialStringsC.firstFreeLine(newChats) : null);
  }

  LimitLine _newChats() {
    final pre = _c.newChats;
    final lim = SocialMeController.maybe?.me.value?.limits.newChats;
    final use = pre.limit > 0 ? pre : (lim ?? pre);
    return LimitLine(limit: use.limit, left: use.left);
  }

  Widget _panel({required Widget child}) => Container(
        width: double.infinity,
        padding: DS.insets(l: 22, t: 18, r: 22, b: 18) + EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(const BorderRadius.vertical(top: Radius.circular(24))), boxShadow: ChatLook3D.panel),
        child: child,
      );

  Widget _lockBar(String title, String line, String key) {
    final canUpgrade = SocialMeController.maybe?.me.value?.limits.canUpgrade ?? true;
    return _panel(
      child: Column(
        key: ValueKey(key),
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: DS.s(18), color: _tone.g2),
              Gap.h(8),
              Flexible(child: Text(title, textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
            ],
          ),
          Gap.v(4),
          Text(line, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0, height: 1.4)),
          if (canUpgrade) ...[
            Gap.v(12),
            GradientPillButton(
              key: const ValueKey('dm_chat_more_plus'),
              tone: ListingTone.cF,
              label: SocialStringsC.chatMorePlus,
              onTap: _openPlus,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPlus() async {
    await SocialNav.openPlus(from: 'chat');
    if (mounted) await _c.refreshLock();
  }

  Widget _composer({required String hint, String? freeLine}) {
    final canSend = _c.canSend;
    return Container(
      padding: DS.insets(l: 16, t: 10, r: 16, b: 12) + EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(const BorderRadius.vertical(top: Radius.circular(24))), boxShadow: ChatLook3D.panel),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (freeLine != null)
            Padding(
              padding: DS.insets(b: 8),
              child: Text(freeLine, key: const ValueKey('dm_free_line'), textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, BuddyLook.subText, letterSpacing: 0)),
            ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _input,
            builder: (_, v, _) {
              final n = v.text.length;
              final live = canSend && v.text.trim().isNotEmpty;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (n >= RoomController.maxLength - RoomController.counterFrom)
                    Padding(
                      padding: DS.insets(r: 70, b: 4),
                      child: Text('$n/${RoomController.maxLength}',
                          key: const ValueKey('dm_counter'), style: Ink3D.text(12, FontWeight.w600, n >= RoomController.maxLength - RoomController.counterWarn ? BuddyLook.amberText : BuddyLook.greyText, letterSpacing: 0)),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          constraints: BoxConstraints(minHeight: DS.s(50)),
                          padding: DS.sym(h: 18, v: 12),
                          decoration: BoxDecoration(color: BuddyLook.closeBg, borderRadius: DS.circular(25)),
                          child: TextField(
                            key: const ValueKey('dm_composer'),
                            controller: _input,
                            enabled: canSend,
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(RoomController.maxLength)],
                            style: Ink3D.text(14.5, FontWeight.w400, Ink3D.title, letterSpacing: 0),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              hintText: hint,
                              hintStyle: Ink3D.text(14.5, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0),
                            ),
                          ),
                        ),
                      ),
                      Gap.h(10),
                      Tap3D(
                        key: const ValueKey('dm_send'),
                        onTap: live ? _send : null,
                        label: SocialStringsC.send,
                        exclude: true,
                        child: Opacity(
                          opacity: live ? Alpha.full : Alpha.v45,
                          child: Container(
                            width: DS.s(50),
                            height: DS.s(50),
                            decoration: BoxDecoration(shape: BoxShape.circle, gradient: _tone.gradient, boxShadow: live ? _tone.glow() : null),
                            child: Icon(Icons.send_rounded, size: DS.s(22), color: DesignColors.onPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
