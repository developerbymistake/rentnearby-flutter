import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/hub/hub_section_title.dart';
import '../../../trip/widgets/hub/hub_tokens.dart';
import '../controllers/shared_trips_controller.dart';
import '../viewer_strings.dart';
import 'former_trip_card.dart';
import 'invite_waiting_card.dart';
import 'shared_trip_card.dart';

class SharedWithMeSection extends StatefulWidget {
  const SharedWithMeSection({super.key});

  @override
  State<SharedWithMeSection> createState() => _SharedWithMeSectionState();
}

class _SharedWithMeSectionState extends State<SharedWithMeSection> {
  late final SharedTripsController _c = SharedTripsController.to;
  late final AppLifecycleListener _life;
  ScrollPosition? _position;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _c.load);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = Scrollable.maybeOf(context)?.position;
    if (p != _position) {
      _position?.removeListener(_onScroll);
      _position = p?..addListener(_onScroll);
    }
  }

  void _onScroll() {
    final p = _position;
    if (p == null || !p.hasContentDimensions) return;
    if (p.pixels >= p.maxScrollExtent - DS.s(300)) _c.loadMore();
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final invites = _c.invites.toList();
        final items = _c.items.toList();
        final former = _c.former.toList();
        final pastCount = _c.pastCount.value;
        if (invites.isEmpty && items.isEmpty && former.isEmpty && pastCount == 0) return const SizedBox.shrink();
        return Column(
          key: const ValueKey('shared_with_me'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HubSectionTitle(title: ViewerStrings.sharedWithMeTitle),
            for (final i in invites) InviteWaitingCard(invite: i),
            for (final t in items) SharedTripCard(trip: t),
            for (final f in former) FormerTripCard(trip: f),
            if (pastCount > 0) ...[
              _PastRow(count: pastCount, open: _c.pastOpen.value, onTap: _c.togglePast),
              if (_c.pastOpen.value) for (final t in _c.past) SharedTripCard(trip: t),
            ],
          ],
        );
      });
}

class _PastRow extends StatelessWidget {
  const _PastRow({required this.count, required this.open, required this.onTap});

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(l: 18, t: 16, r: 18),
        child: InkWell(
          key: const ValueKey('shared_past_row'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: DS.s(44)),
            child: Row(
              children: [
                Expanded(child: Text(ViewerStrings.pastShared(count), style: Ink3D.text(14, FontWeight.w700, HubTokens.blue, letterSpacing: 0))),
                AnimatedRotation(
                  turns: open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(ViewerStrings.arrow, style: Ink3D.text(16, FontWeight.w700, HubTokens.blue, letterSpacing: 0)),
                ),
              ],
            ),
          ),
        ),
      );
}
