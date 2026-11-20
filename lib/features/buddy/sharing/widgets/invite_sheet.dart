import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../design/design.dart';
import '../../../../utils/app_toast.dart';
import '../../buddies/data/buddies_api.dart';
import '../../buddies/models/buddy_models.dart';
import '../../buddy_error_types.dart';
import '../../buddy_limits.dart';
import '../../buddy_navigation.dart';
import '../../shared/buddy_look.dart';
import '../../shared/buddy_result.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../../shared/widgets/buddy_snack.dart';
import '../../shared/widgets/check_line.dart';
import '../../shared/widgets/small_pill.dart';
import '../data/trip_members_api.dart';
import '../models/sharing_models.dart';
import '../sharing_deps.dart';
import '../sharing_strings.dart';

class InviteSheet extends StatefulWidget {
  const InviteSheet({super.key, required this.tripId, this.api, this.buddiesApi});

  final String tripId;
  final TripMembersApi? api;
  final BuddiesApi? buddiesApi;

  static Future<void> show(BuildContext context, String tripId, {VoidCallback? onChanged}) async {
    final msg = await SheetFrame.show<String>(context, builder: (_) => InviteSheet(tripId: tripId));
    if (msg != null && context.mounted) BuddySnack.show(context, msg);
    onChanged?.call();
  }

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  late final TripMembersApi _api = widget.api ?? SharingDeps.members;
  late final BuddiesApi _buddies = widget.buddiesApi ?? SharingDeps.buddies;
  String _requestId = const Uuid().v4();
  final List<BuddyItem> _items = [];
  final List<String> _ticked = [];
  int? _seatsLeft;
  int _count = 0;
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _failed = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static bool _taken(BuddyItem b) => b.tripState == BuddyTripState.invited || b.tripState == BuddyTripState.joined;

  int get _seats => _seatsLeft ?? BuddyLimits.maxTravellers;

  int get _invitable => _items.where((b) => !_taken(b)).length + (_cursor == null ? 0 : 1);

  bool get _lowSeats => _seats < _invitable;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final results = await Future.wait([_api.members(widget.tripId), _buddies.buddies(forTripId: widget.tripId)]);
    if (!mounted) return;
    final m = results[0];
    final b = results[1];
    setState(() {
      _loading = false;
      if (m is BuddyOk<TripMembers>) _seatsLeft = m.value.seatsLeft;
      if (b is BuddyOk<BuddyList>) {
        _items
          ..clear()
          ..addAll(b.value.items);
        _count = b.value.count;
        _cursor = b.value.nextCursor;
        _ticked.removeWhere((id) => !_items.any((i) => i.userId == id && !_taken(i)));
      } else {
        _failed = true;
      }
    });
  }

  Future<void> _more() async {
    final c = _cursor;
    if (c == null || _loadingMore) return;
    _loadingMore = true;
    final r = await _buddies.buddies(cursor: c, forTripId: widget.tripId);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (r is BuddyOk<BuddyList>) {
        _items.addAll(r.value.items);
        _cursor = r.value.nextCursor;
      }
    });
  }

  void _tap(BuddyItem b) {
    setState(() {
      if (_ticked.remove(b.userId)) {
        _error = null;
      } else if (_ticked.length >= _seats) {
        _error = _seats <= 0 ? SharingStrings.tripIsFull : SharingStrings.onlySeatsLeft(_seats);
      } else {
        _ticked.add(b.userId);
        _error = null;
      }
    });
  }

  String _nameOf(String id) => _items.firstWhere((i) => i.userId == id, orElse: () => BuddyItem(userId: id, name: BuddySharedStrings.someone, username: null, initial: '', isNew: false)).name;

  Future<void> _send() async {
    if (_sending || _ticked.isEmpty) return;
    setState(() => _sending = true);
    final ids = List<String>.of(_ticked);
    final r = await _api.invite(widget.tripId, ids, clientRequestId: _requestId);
    if (!mounted) return;
    setState(() => _sending = false);
    switch (r) {
      case BuddyOk<InviteResult>(:final value):
        _requestId = const Uuid().v4();
        for (final o in value.results.where((o) => o.outcome == InviteOutcomes.notBuddy)) {
          AppToast.error(SharingStrings.couldNotInvite(_nameOf(o.userId)));
        }
        final sent = value.results.where((o) => o.outcome == InviteOutcomes.invited).map((o) => o.userId).toList();
        if (sent.isNotEmpty) {
          Navigator.of(context).pop(sent.length == 1 ? SharingStrings.inviteSentTo(_nameOf(sent.first)) : SharingStrings.invitesSentTo(sent.length));
          return;
        }
        _ticked.clear();
        await _load();
      case BuddyRefused<InviteResult>(:final type, :final data):
        if (type == BuddyErrorTypes.tripFull) {
          final n = data['seatsLeft'];
          final seats = n is num ? n.toInt() : 0;
          setState(() {
            _seatsLeft = seats;
            _error = seats <= 0 ? SharingStrings.tripIsFull : SharingStrings.onlySeatsLeft(seats);
          });
          await _load();
        } else if (type == BuddyErrorTypes.tripCompleted) {
          AppToast.error(SharingStrings.tripCompleted);
        } else if (type == BuddyErrorTypes.noPlaces) {
          AppToast.error(SharingStrings.addPlacesFirst);
        } else {
          SharingDeps.toastError(r);
        }
      default:
        SharingDeps.toastError(r);
    }
  }

  Widget _row(BuddyItem b, int index) {
    if (index == _items.length - 1 && _cursor != null) WidgetsBinding.instance.addPostFrameCallback((_) => _more());
    final taken = _taken(b);
    final ticked = _ticked.contains(b.userId);
    final dim = !taken && !ticked && _ticked.length >= _seats;
    final line = CheckLine(
      key: ValueKey('invite_row_${b.userId}'),
      leading: BuddyAvatar(initial: b.initial, seed: b.userId),
      title: b.name,
      subtitle: b.username,
      checked: ticked,
      enabled: !taken,
      tone: BuddyLook.teal,
      trailingBadge: !taken
          ? null
          : b.tripState == BuddyTripState.joined
              ? const BuddyBadge(SharingStrings.onThisTripBadge, tone: BuddyBadgeTone.view)
              : const BuddyBadge(SharingStrings.inviteSentBadge, tone: BuddyBadgeTone.pending),
      onTap: () => _tap(b),
    );
    return dim ? Opacity(opacity: Alpha.v55, child: line) : line;
  }

  Widget _empty() => Padding(
        key: const ValueKey('invite_empty'),
        padding: EdgeInsets.only(top: DS.s(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Art3D(asset: BuddyArt.bust, size: 72, shadowBlur: 4, shadowOffset: Offset(2, 4)),
            Gap.v(10),
            Text(SharingStrings.noBuddiesYet, textAlign: TextAlign.center, style: Ink3D.text(16, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
            Gap.v(4),
            Text(SharingStrings.noBuddiesLine, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, BuddyLook.subText, height: 1.5, letterSpacing: 0)),
            Gap.v(14),
            SizedBox(
              width: DS.s(200),
              child: GradientPillButton(
                key: const ValueKey('invite_find_buddy'),
                tone: BuddyLook.teal,
                label: SharingStrings.findABuddy,
                onTap: () {
                  Navigator.of(context).pop();
                  BuddyNavigation.openBuddies(tab: 'find');
                },
              ),
            ),
          ],
        ),
      );

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return Padding(padding: DS.sym(v: 32), child: const Center(child: CircularProgressIndicator()));
    }
    if (_failed && _items.isEmpty) {
      return Padding(
        padding: DS.sym(v: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(BuddySharedStrings.couldNotLoad, style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
            Gap.v(4),
            Text(BuddySharedStrings.couldNotLoadLine, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, BuddyLook.subText, letterSpacing: 0)),
            Gap.v(12),
            SmallPill(label: BuddySharedStrings.retry, kind: SmallPillKind.teal, onTap: _load),
          ],
        ),
      );
    }
    if (_count == 0 && _items.isEmpty) return _empty();
    final err = _error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_lowSeats)
          Text(SharingStrings.seatsLeft(_seats),
              key: const ValueKey('invite_seats_line'), style: Ink3D.text(13, FontWeight.w700, BuddyLook.tealEnd, letterSpacing: 0)),
        Gap.v(12),
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) Divider(height: DS.s(1), thickness: DS.s(1), color: BuddyLook.hairline),
          _row(_items[i], i),
        ],
        if (err != null)
          Padding(
            padding: EdgeInsets.only(top: DS.s(8), left: DS.s(4), right: DS.s(4)),
            child: Text(err, key: const ValueKey('invite_error_line'), style: Ink3D.text(12.5, FontWeight.w700, BuddyLook.dangerText, letterSpacing: 0)),
          )
        else if (!_lowSeats)
          Padding(
            padding: EdgeInsets.only(top: DS.s(12), left: DS.s(4), right: DS.s(4)),
            child: Text(SharingStrings.inviteFootnote, style: Ink3D.text(12.5, FontWeight.w400, BuddyLook.subText, height: 1.5, letterSpacing: 0)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showList = !(_loading && _items.isEmpty) && !(_failed && _items.isEmpty) && !(_count == 0 && _items.isEmpty);
    return Sheet3D(
      tone: BuddyLook.teal,
      art: BuddyArt.panda,
      title: SharingStrings.inviteTitle,
      subtitle: showList && _lowSeats ? null : SharingStrings.inviteSubtitle,
      centerTitle: false,
      padding: DS.insets(l: 18, r: 18),
      footer: showList
          ? GradientPillButton(
              key: const ValueKey('invite_send'),
              tone: BuddyLook.teal,
              label: SharingStrings.sendInviteN(_ticked.length),
              enabled: _ticked.isNotEmpty,
              loading: _sending,
              onTap: _ticked.isEmpty || _sending ? null : _send,
              offColor: BuddyLook.checkOff,
            )
          : null,
      child: _body(),
    );
  }
}
