import 'package:flutter/material.dart';

import '../../design/design.dart';
import 'buddy_error_types.dart';
import 'shared/buddy_look.dart';
import 'shared/buddy_result.dart';
import 'shared/strings_shared.dart';
import 'shared/widgets/buddy_page.dart';
import 'sharing/data/trip_members_api.dart';
import 'sharing/models/sharing_models.dart';
import 'sharing/screens/travellers_owner_screen.dart';
import 'sharing/sharing_strings.dart';
import 'viewer/screens/travellers_viewer_screen.dart';

class TravellersRoute extends StatefulWidget {
  const TravellersRoute({super.key, required this.tripId, this.api = const TripMembersApi()});

  final String tripId;
  final TripMembersApi api;

  @override
  State<TravellersRoute> createState() => _TravellersRouteState();
}

class _TravellersRouteState extends State<TravellersRoute> {
  BuddyResult<TripMembers>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_result != null) setState(() => _result = null);
    final r = await widget.api.members(widget.tripId);
    if (mounted) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r is BuddyOk<TripMembers>) {
      return r.value.isOwner
          ? TravellersOwnerScreen(tripId: widget.tripId, members: r.value)
          : TravellersViewerScreen(tripId: widget.tripId, members: r.value);
    }
    final gone = r is BuddyRefused<TripMembers> && r.type == BuddyErrorTypes.tripNotFound;
    return BuddyPage(
      title: SharingStrings.travellersTitle,
      body: r == null
          ? Padding(padding: DS.all(40), child: const Center(child: CircularProgressIndicator()))
          : StateCard3D(
              tone: BuddyLook.teal,
              art: gone ? BuddyArt.luggage : BuddyArt.antenna,
              title: BuddySharedStrings.couldNotLoad,
              message: gone ? null : BuddySharedStrings.couldNotLoadLine,
              actionLabel: gone ? null : BuddySharedStrings.retry,
              onAction: gone ? null : _load,
              layout: StateLayout.tall,
            ),
    );
  }
}
