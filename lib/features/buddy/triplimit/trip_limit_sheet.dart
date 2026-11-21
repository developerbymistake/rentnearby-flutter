import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../trip/utils/trip_clock.dart';
import '../shared/buddy_look.dart';
import '../shared/widgets/buddy_badge.dart';
import '../shared/widgets/buddy_sheet.dart';
import '../shared/widgets/small_pill.dart';
import 'trip_limit_actions.dart';
import 'trip_limit_models.dart';
import 'trip_limit_strings.dart';

abstract final class TripLimitSheet {
  static Future<bool> show(
    BuildContext context,
    TripSlots slots, {
    required TripLimitReason reason,
    TripLimitActions actions = const DefaultTripLimitActions(),
  }) async {
    final freed = await BuddySheet.show<bool>(
      context,
      art: BuddyArt.luggage,
      title: TripLimitStrings.title,
      subtitle: TripLimitStrings.body(reason, slots.limit),
      builder: (c) => _Body(slots: slots, reason: reason, actions: actions),
    );
    return freed == true;
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.slots, required this.reason, required this.actions});

  final TripSlots slots;
  final TripLimitReason reason;
  final TripLimitActions actions;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late TripSlots _slots = widget.slots;
  String? _busyId;

  Future<void> _act(TripSlotTrip trip) async {
    if (_busyId != null) return;
    setState(() => _busyId = trip.id);
    var done = false;
    try {
      done = trip.isOwner ? await widget.actions.deleteOwned(context, trip) : await widget.actions.leave(context, trip);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
    if (!done || !mounted) return;
    final next = _slots.without(trip.id);
    if (!next.isFull) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _slots = next);
  }

  Widget _row(TripSlotTrip t, {required bool first}) {
    final today = TripClock.today();
    final line = t.isOwner ? TripLimitStrings.ownLine(t.startDate, t.endDate) : TripLimitStrings.viewerLine(t.ownerName, t.startDate, t.endDate);
    return Column(
      key: ValueKey('trip_limit_row_${t.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!first) Divider(height: DS.s(1), thickness: DS.s(1), color: BuddyLook.hairline),
        Padding(
          padding: DS.sym(v: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                    Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w500, BuddyLook.subText, letterSpacing: 0)),
                  ],
                ),
              ),
              if (t.endedBy(today)) ...[Gap.h(8), const BuddyBadge(TripLimitStrings.ended)],
              Gap.h(8),
              Tap3D(
                key: ValueKey('trip_limit_action_${t.id}'),
                onTap: _busyId == null ? () => _act(t) : null,
                label: t.isOwner ? TripLimitStrings.delete : TripLimitStrings.leave,
                exclude: true,
                child: BuddyBadge(
                  t.isOwner ? TripLimitStrings.delete : TripLimitStrings.leave,
                  tone: t.isOwner ? BuddyBadgeTone.danger : BuddyBadgeTone.view,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _slots.trips.length; i++) _row(_slots.trips[i], first: i == 0),
          if (widget.reason == TripLimitReason.invite)
            Padding(
              padding: DS.insets(t: 10),
              child: Text(
                TripLimitStrings.inviteWaits,
                textAlign: TextAlign.center,
                style: Ink3D.text(12, FontWeight.w500, BuddyLook.subText, letterSpacing: 0),
              ),
            ),
          Gap.v(16),
          SmallPill(
            key: const ValueKey('trip_limit_not_now'),
            label: TripLimitStrings.notNow,
            kind: SmallPillKind.teal,
            expand: true,
            tall: true,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      );
}
