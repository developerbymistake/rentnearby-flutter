import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../design/design.dart';
import '../../../../utils/app_toast.dart';
import '../../buddy_error_types.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/buddy_result.dart';
import '../../shared/models/person_models.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../../shared/widgets/buddy_sheet.dart';
import '../../sharing/data/trip_members_api.dart';
import '../../sharing/models/sharing_models.dart';
import '../buddies_strings.dart';
import '../buddy_feedback.dart';
import 'my_buddies_tab.dart';

enum TripPickResult { invited, planATrip, buddyGone }

abstract final class TripPickArt {
  static String of(String title) {
    final t = title.toLowerCase();
    if (t.contains('beach') || t.contains('goa')) return ListingArt.beach;
    if (t.contains('fort') || t.contains('castle') || t.contains('palace')) return ListingArt.castle;
    if (t.contains('temple') || t.contains('kashi')) return ListingArt.hinduTemple;
    if (t.contains('backwater') || t.contains('lake') || t.contains('river')) return ListingArt.canoe;
    if (t.contains('hill') || t.contains('mountain') || t.contains('trek')) return ListingArt.mountain;
    return BuddyArt.luggage;
  }
}

class TripPickSheet extends StatefulWidget {
  const TripPickSheet({super.key, required this.person, this.api = const TripMembersApi(), this.initialSelected});

  final BuddyPerson person;
  final TripMembersApi api;
  final String? initialSelected;

  static Future<TripPickResult?> show(BuildContext context, BuddyPerson person, {TripMembersApi api = const TripMembersApi()}) =>
      SheetFrame.show<TripPickResult>(context, builder: (_) => TripPickSheet(person: person, api: api));

  static String line(InviteOption o) {
    final dates = BuddyFormat.dateRange(o.startDate, o.endDate);
    final part = dates.isNotEmpty ? dates : BuddiesStrings.draftDays(o.dayCount);
    final withCount = o.option != InviteOptionKind.onTrip && o.option != InviteOptionKind.inviteSent;
    return withCount ? '$part · ${BuddiesStrings.travellers(o.travellerCount)}' : part;
  }

  static (String, BuddyBadgeTone)? badge(InviteOption o) => switch (o.option) {
        InviteOptionKind.onTrip => (BuddiesStrings.onThisTrip, BuddyBadgeTone.view),
        InviteOptionKind.inviteSent => (BuddiesStrings.inviteSentBadge, BuddyBadgeTone.pending),
        InviteOptionKind.full => (BuddiesStrings.tripFull, BuddyBadgeTone.grey),
        InviteOptionKind.noPlaces => (BuddiesStrings.noPlaces, BuddyBadgeTone.grey),
        _ => null,
      };

  @override
  State<TripPickSheet> createState() => _TripPickSheetState();
}

enum _Load { loading, ready, failed }

class _TripPickSheetState extends State<TripPickSheet> {
  _Load _load = _Load.loading;
  List<InviteOption> _options = const [];
  late String? _selected = widget.initialSelected;
  bool _busy = false;
  String? _opId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _load = _Load.loading);
    final r = await widget.api.inviteOptions(widget.person.userId);
    if (!mounted) return;
    switch (r) {
      case BuddyOk(:final value):
        setState(() {
          _options = value;
          _load = _Load.ready;
          if (!value.any((o) => o.tripId == _selected && o.available)) _selected = null;
        });
      case BuddyRefused(:final type) when type == BuddyErrorTypes.personNotFound:
        Navigator.of(context).pop(TripPickResult.buddyGone);
      default:
        setState(() => _load = _Load.failed);
    }
  }

  Future<void> _send() async {
    final tripId = _selected;
    if (tripId == null || _busy) return;
    _opId ??= const Uuid().v4();
    setState(() => _busy = true);
    final r = await widget.api.invite(tripId, [widget.person.userId], clientRequestId: _opId!);
    if (!mounted) return;
    setState(() => _busy = false);
    final name = widget.person.name;
    switch (r) {
      case BuddyOk(:final value):
        _opId = null;
        final outcome = value.results.where((o) => o.userId == widget.person.userId).map((o) => o.outcome).firstOrNull ??
            (value.results.isEmpty ? null : value.results.first.outcome);
        switch (outcome) {
          case InviteOutcomes.invited || InviteOutcomes.alreadyInvited:
            Navigator.of(context).pop(TripPickResult.invited);
          case InviteOutcomes.alreadyOnTrip:
            AppToast.info(BuddiesStrings.alreadyOnTrip(name));
            _fetch();
          default:
            AppToast.error(BuddiesStrings.couldNotInvite(name));
        }
      case BuddyRefused(:final type, :final statusCode):
        _opId = null;
        if (statusCode == 429) {
          AppToast.error(BuddySharedStrings.tooManyTries);
        } else if (type == BuddyErrorTypes.tripFull || type == BuddyErrorTypes.tripCompleted) {
          _fetch();
        } else if (type == BuddyErrorTypes.noPlaces) {
          AppToast.error(BuddiesStrings.addPlacesFirst);
        } else {
          AppToast.error(BuddiesStrings.couldNotInvite(name));
        }
      case BuddyOffline() || BuddyFailed():
        BuddyFeedback.writeFailed(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = BuddiesStrings.inviteTitle(widget.person.name);
    switch (_load) {
      case _Load.loading:
        return BuddySheet.frame(art: BuddyArt.luggage, title: title, subtitle: BuddiesStrings.inviteSubtitle, child: const BuddyListSkeleton());
      case _Load.failed:
        return BuddySheet.frame(
          art: BuddyArt.luggage,
          title: title,
          child: _Empty(art: BuddyArt.antenna, title: BuddySharedStrings.couldNotLoad, line: BuddySharedStrings.couldNotLoadLine),
          footer: GradientPillButton(tone: BuddyLook.teal, label: BuddySharedStrings.retry, onTap: _fetch),
        );
      case _Load.ready:
        break;
    }
    if (_options.isEmpty) {
      return BuddySheet.frame(
        art: BuddyArt.luggage,
        title: title,
        child: const _Empty(art: ListingArt.worldMap, title: BuddiesStrings.noTripsTitle, line: BuddiesStrings.noTripsLine),
        footer: GradientPillButton(tone: BuddyLook.teal, label: BuddiesStrings.planATrip, onTap: () => Navigator.of(context).pop(TripPickResult.planATrip)),
      );
    }
    return BuddySheet.frame(
      art: BuddyArt.luggage,
      title: title,
      subtitle: BuddiesStrings.inviteSubtitle,
      footer: GradientPillButton(
        tone: BuddyLook.teal,
        label: BuddiesStrings.sendInvite,
        enabled: _selected != null,
        loading: _busy,
        onTap: _selected == null || _busy ? null : _send,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _options.length; i++) ...[
            if (i > 0) Divider(height: DS.s(1), thickness: DS.s(1), color: BuddyLook.hairline),
            _TripRow(
              option: _options[i],
              selected: _options[i].tripId == _selected,
              onTap: _options[i].available && !_busy ? () => setState(() => _selected = _options[i].tripId) : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.option, required this.selected, required this.onTap});

  final InviteOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = TripPickSheet.badge(option);
    final dim = !option.available;
    final info = Row(
      children: [
        Container(
          width: DS.s(44),
          height: DS.s(44),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: ListingPalette.indigo.g2.withValues(alpha: Alpha.v14), borderRadius: DS.circular(12)),
          child: Art3D(asset: TripPickArt.of(option.title), size: 34, shadowBlur: 2, shadowOffset: const Offset(1, 2)),
        ),
        Gap.h(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(option.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              Text(TripPickSheet.line(option), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
            ],
          ),
        ),
      ],
    );
    return Tap3D(
      onTap: onTap,
      selected: selected,
      label: option.title,
      exclude: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DS.s(50)),
        child: Padding(
          padding: DS.sym(v: 6),
          child: Row(
            children: [
              Expanded(child: dim ? Opacity(opacity: Alpha.v55, child: info) : info),
              Gap.h(12),
              if (badge != null)
                BuddyBadge(badge.$1, tone: badge.$2)
              else
                Container(
                  width: DS.s(26),
                  height: DS.s(26),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected ? BuddyLook.teal.gradient : null,
                    border: selected ? null : Border.all(color: BuddyLook.checkOff, width: DS.s(2)),
                  ),
                  child: selected ? Icon(Icons.check_rounded, size: DS.s(18), color: DesignColors.onPrimary) : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.art, required this.title, required this.line});

  final String art;
  final String title;
  final String line;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(t: 18, b: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Art3D(asset: art, size: 84, shadowBlur: 6, shadowOffset: const Offset(5, 8))),
            Gap.v(12),
            Text(title, textAlign: TextAlign.center, style: Ink3D.text(19, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
            Padding(
              padding: EdgeInsets.only(top: DS.s(4)),
              child: Text(line, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w400, BuddyLook.subText, letterSpacing: 0)),
            ),
          ],
        ),
      );
}
