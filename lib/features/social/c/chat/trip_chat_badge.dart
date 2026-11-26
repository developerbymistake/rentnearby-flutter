import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/buddy_look.dart';
import 'models/chat_models.dart';
import 'rooms_controller.dart';

class TripChatBadge extends StatefulWidget {
  const TripChatBadge({super.key, required this.tripId, required this.child});

  final String tripId;
  final Widget child;

  static int unreadOf(RoomsController rooms, String tripId) {
    for (final r in rooms.trips.items) {
      if (r.trip?.tripId == tripId) return r.unread;
    }
    return 0;
  }

  @override
  State<TripChatBadge> createState() => _TripChatBadgeState();
}

class _TripChatBadgeState extends State<TripChatBadge> {
  @override
  void initState() {
    super.initState();
    final rooms = RoomsController.maybe;
    if (rooms != null && rooms.trips.state.value == RoomsLoad.idle) rooms.load(RoomBucket.trips);
  }

  @override
  Widget build(BuildContext context) {
    final rooms = RoomsController.maybe;
    if (rooms == null) return widget.child;
    return Obx(() {
      final n = TripChatBadge.unreadOf(rooms, widget.tripId);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (n > 0)
            Positioned(
              right: -DS.s(2),
              top: -DS.s(2),
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey('trip_chat_unread'),
                  constraints: BoxConstraints(minWidth: DS.s(20)),
                  padding: DS.sym(h: 5, v: 1),
                  decoration: BoxDecoration(color: BuddyLook.countBadge, borderRadius: DS.circular(10)),
                  child: Text(n > 99 ? '99+' : '$n', textAlign: TextAlign.center, style: Ink3D.text(11, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
                ),
              ),
            ),
        ],
      );
    });
  }
}
