import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../config/app_routes.dart';
import '../../../../design/design.dart';
import '../../../../utils/app_toast.dart';
import '../../../social/shared/social_nav.dart';
import '../../buddies/models/buddy_models.dart';
import '../../buddy_error_types.dart';
import '../../buddy_limits.dart';
import '../../shared/buddy_look.dart';
import '../../shared/buddy_result.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../../shared/widgets/buddy_bottom_bar.dart';
import '../../shared/widgets/buddy_page.dart';
import '../../shared/widgets/check_line.dart';
import '../../shared/widgets/person_row.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/small_pill.dart';
import '../data/trip_members_api.dart';
import '../models/sharing_models.dart';
import '../sharing_deps.dart';
import '../sharing_strings.dart';

class InvitePeopleScreen extends StatefulWidget {
  const InvitePeopleScreen({super.key, required this.tripId, this.api});

  final String tripId;
  final TripMembersApi? api;

  static const Key myBuddiesKey = ValueKey('invite_my_buddies');
  static const Key sendKey = ValueKey('invite_send');
  static const Key backKey = ValueKey('invite_back_to_plan');

  static Future<void> open(String tripId, {VoidCallback? onChanged}) async {
    await Get.toNamed(AppRoutes.tripInvitePeople, arguments: {'tripId': tripId});
    onChanged?.call();
  }

  @override
  State<InvitePeopleScreen> createState() => _InvitePeopleScreenState();
}

class _InvitePeopleScreenState extends State<InvitePeopleScreen> {
  late final TripMembersApi _api = widget.api ?? SharingDeps.members;
  String _requestId = const Uuid().v4();
  final List<InviteCandidate> _items = [];
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

  static bool _taken(InviteCandidate c) => c.person.tripState == BuddyTripState.invited || c.person.tripState == BuddyTripState.joined;

  int get _seats => _seatsLeft ?? BuddyLimits.maxTravellers;

  int get _invitable => _items.where((c) => !_taken(c)).length + (_cursor == null ? 0 : 1);

  bool get _lowSeats => _seats < _invitable;

  bool get _hasBuddies => _items.any((c) => c.isBuddy);

  List<InviteCandidate> get _freeBuddies => [for (final c in _items) if (c.isBuddy && !_taken(c)) c];

  bool get _allBuddiesTicked {
    final free = _freeBuddies;
    return free.isNotEmpty && free.every((c) => _ticked.contains(c.userId));
  }

  bool get _showList => !(_loading && _items.isEmpty) && !(_failed && _items.isEmpty) && !(_count == 0 && _items.isEmpty);

  String _fullLine() => _seats <= 0 ? SharingStrings.tripIsFull : SharingStrings.onlySeatsLeft(_seats);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final results = await Future.wait([_api.members(widget.tripId), _api.inviteCandidates(widget.tripId)]);
    if (!mounted) return;
    final m = results[0];
    final c = results[1];
    setState(() {
      _loading = false;
      if (m is BuddyOk<TripMembers>) _seatsLeft = m.value.seatsLeft;
      if (c is BuddyOk<InviteCandidateList>) {
        _items
          ..clear()
          ..addAll(c.value.items);
        _count = c.value.count;
        _cursor = c.value.nextCursor;
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
    final r = await _api.inviteCandidates(widget.tripId, cursor: c);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (r is BuddyOk<InviteCandidateList>) {
        _items.addAll(r.value.items);
        _cursor = r.value.nextCursor;
      }
    });
  }

  void _tap(InviteCandidate c) {
    setState(() {
      if (_ticked.remove(c.userId)) {
        _error = null;
      } else if (_ticked.length >= _seats) {
        _error = _fullLine();
      } else {
        _ticked.add(c.userId);
        _error = null;
      }
    });
  }

  void _toggleBuddies() {
    setState(() {
      final free = _freeBuddies;
      _error = null;
      if (_allBuddiesTicked) {
        _ticked.removeWhere((id) => free.any((c) => c.userId == id));
        return;
      }
      for (final c in free) {
        if (_ticked.contains(c.userId)) continue;
        if (_ticked.length >= _seats) {
          _error = _fullLine();
          break;
        }
        _ticked.add(c.userId);
      }
    });
  }

  String _nameOf(String id) => _items.firstWhereOrNull((i) => i.userId == id)?.person.name ?? BuddySharedStrings.someone;

  void _backToPlan() => Navigator.of(context).popUntil(
      (r) => r.settings.name == AppRoutes.tripOverview || r.settings.name == AppRoutes.main || r.isFirst);

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
        const quiet = {InviteOutcomes.invited, InviteOutcomes.alreadyInvited, InviteOutcomes.alreadyOnTrip};
        for (final o in value.results.where((o) => !quiet.contains(o.outcome))) {
          AppToast.error(SharingStrings.couldNotInvite(_nameOf(o.userId)));
        }
        final sent = value.results.where((o) => o.outcome == InviteOutcomes.invited).map((o) => o.userId).toList();
        if (sent.isNotEmpty) {
          AppToast.success(sent.length == 1 ? SharingStrings.inviteSentTo(_nameOf(sent.first)) : SharingStrings.invitesSent(sent.length));
          _backToPlan();
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
            _error = _fullLine();
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

  Widget _title(InviteCandidate c) {
    final text = Text(c.person.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0));
    if (!c.isBuddy) return text;
    return Row(
      children: [
        ExcludeSemantics(child: Icon(Icons.star_rounded, key: ValueKey('invite_star_${c.userId}'), size: DS.s(16), color: BuddyLook.amberText)),
        Gap.h(4),
        Flexible(child: text),
      ],
    );
  }

  Widget _row(InviteCandidate c, int index) {
    if (index == _items.length - 1 && _cursor != null) WidgetsBinding.instance.addPostFrameCallback((_) => _more());
    final b = c.person;
    final taken = _taken(c);
    final ticked = _ticked.contains(c.userId);
    final dim = !taken && !ticked && _ticked.length >= _seats;
    final line = Padding(
      padding: DS.sym(h: 16),
      child: CheckLine(
        key: ValueKey('invite_row_${c.userId}'),
        leading: BuddyAvatar(initial: b.initial, seed: b.userId, photoUrl: b.photoUrl),
        title: b.name,
        titleWidget: _title(c),
        subtitle: b.username,
        checked: ticked,
        enabled: !taken,
        tone: BuddyLook.teal,
        trailingBadge: !taken
            ? null
            : b.tripState == BuddyTripState.joined
                ? const BuddyBadge(SharingStrings.onThisTripBadge, tone: BuddyBadgeTone.view)
                : const BuddyBadge(SharingStrings.inviteSentBadge, tone: BuddyBadgeTone.pending),
        onTap: () => _tap(c),
      ),
    );
    return dim ? Opacity(opacity: Alpha.v55, child: line) : line;
  }

  Widget _myBuddies() => PersonListCard(
        margin: DS.insets(l: 18, t: 16, r: 18),
        children: [
          Padding(
            padding: DS.sym(h: 16),
            child: CheckLine(
              key: InvitePeopleScreen.myBuddiesKey,
              leading: const ExcludeSemantics(child: Art3D(asset: ListingArt.star, size: 36, shadowBlur: 2, shadowOffset: Offset(1, 2))),
              title: SharingStrings.myBuddies,
              subtitle: SharingStrings.myBuddiesLine,
              checked: _allBuddiesTicked,
              enabled: _freeBuddies.isNotEmpty,
              tone: BuddyLook.teal,
              onTap: _toggleBuddies,
            ),
          ),
        ],
      );

  Widget _empty() => Padding(
        key: const ValueKey('invite_empty'),
        padding: EdgeInsets.only(top: DS.s(40), left: DS.s(18), right: DS.s(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Art3D(asset: BuddyArt.panda, size: 72, shadowBlur: 4, shadowOffset: Offset(2, 4)),
            Gap.v(10),
            Text(SharingStrings.noFollowsYet, textAlign: TextAlign.center, style: Ink3D.text(16, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
            Gap.v(4),
            Text(SharingStrings.noFollowsLine, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, BuddyLook.subText, height: 1.5, letterSpacing: 0)),
            Gap.v(14),
            SizedBox(
              width: DS.s(200),
              child: GradientPillButton(
                key: const ValueKey('invite_find_people'),
                tone: BuddyLook.teal,
                label: SharingStrings.findPeople,
                onTap: () => SocialNav.openPeople(tab: 'following'),
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
        padding: DS.sym(h: 18, v: 20),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_lowSeats)
          Padding(
            padding: DS.insets(l: 22, t: 16, r: 22),
            child: Text(SharingStrings.seatsLeft(_seats),
                key: const ValueKey('invite_seats_line'), style: Ink3D.text(13, FontWeight.w700, BuddyLook.tealEnd, letterSpacing: 0)),
          ),
        if (_hasBuddies) _myBuddies(),
        const SectionLabel(SharingStrings.peopleYouFollow),
        PersonListCard(children: [for (var i = 0; i < _items.length; i++) _row(_items[i], i)]),
        Padding(
          padding: DS.insets(l: 22, t: 12, r: 22),
          child: err != null
              ? Text(err, key: const ValueKey('invite_error_line'), style: Ink3D.text(12.5, FontWeight.w700, BuddyLook.dangerText, letterSpacing: 0))
              : Text(SharingStrings.followFootnote, style: Ink3D.text(12.5, FontWeight.w400, BuddyLook.subText, height: 1.5, letterSpacing: 0)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _showList;
    return BuddyPage(
      title: SharingStrings.inviteTitle,
      subtitle: SharingStrings.inviteSubtitle,
      body: _body(),
      bottomBar: BuddyBottomBar(
        children: [
          WhitePillButton(key: InvitePeopleScreen.backKey, tone: BuddyLook.teal, label: SharingStrings.backToPlan, onTap: _backToPlan),
          if (list)
            GradientPillButton(
              key: InvitePeopleScreen.sendKey,
              tone: BuddyLook.teal,
              label: SharingStrings.sendInvitesN(_ticked.length),
              enabled: _ticked.isNotEmpty,
              loading: _sending,
              onTap: _ticked.isEmpty || _sending ? null : _send,
              offColor: BuddyLook.checkOff,
            ),
        ],
      ),
    );
  }
}
