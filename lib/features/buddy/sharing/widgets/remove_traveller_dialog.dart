import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../buddy_error_types.dart';
import '../../shared/buddy_look.dart';
import '../../shared/buddy_result.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_confirm_box.dart';
import '../data/trip_members_api.dart';
import '../models/sharing_models.dart';
import '../sharing_deps.dart';
import '../sharing_strings.dart';

enum RemoveOutcome { removed, notOnTrip }

class RemoveTravellerDialog extends StatefulWidget {
  const RemoveTravellerDialog({super.key, required this.tripId, required this.member, this.api});

  final String tripId;
  final JoinedMember member;
  final TripMembersApi? api;

  static Future<RemoveOutcome?> show(BuildContext context, String tripId, JoinedMember member) =>
      Dialog3D.show<RemoveOutcome>(context, builder: (_) => RemoveTravellerDialog(tripId: tripId, member: member));

  @override
  State<RemoveTravellerDialog> createState() => _RemoveTravellerDialogState();
}

class _RemoveTravellerDialogState extends State<RemoveTravellerDialog> {
  late final TripMembersApi _api = widget.api ?? SharingDeps.members;
  int? _count;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final r = await _api.expenseCount(widget.tripId, widget.member.userId);
    if (mounted) setState(() => _count = r is BuddyOk<int> ? r.value : 0);
  }

  Future<void> _remove() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await _api.remove(widget.tripId, widget.member.userId);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case BuddyOk<RemoveResult>():
        Navigator.of(context).pop(RemoveOutcome.removed);
      case BuddyRefused<RemoveResult>(:final type) when type == BuddyErrorTypes.notOnTrip:
        Navigator.of(context).pop(RemoveOutcome.notOnTrip);
      default:
        SharingDeps.toastError(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.member.name;
    final n = _count;
    return BuddyConfirmBox.box(
      art: BuddyArt.panda,
      title: SharingStrings.removeTitle(name),
      cancelLabel: BuddySharedStrings.cancel,
      confirmLabel: SharingStrings.remove,
      confirmKind: ConfirmKind.danger,
      busy: _busy,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: _remove,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (n != null && n > 0)
            Container(
              key: const ValueKey('remove_shares_line'),
              margin: DS.insets(b: 12),
              padding: DS.sym(h: 16, v: 12),
              decoration: BoxDecoration(color: BuddyLook.reasonBg, borderRadius: DS.circular(16)),
              child: Text(SharingStrings.removeShares(name, n), style: Ink3D.text(13, FontWeight.w500, BuddyLook.dangerText, height: 1.5, letterSpacing: 0)),
            ),
          Text(
            SharingStrings.removeLoses(name, hasShare: n != null && n > 0),
            key: const ValueKey('remove_loses_line'),
            textAlign: TextAlign.center,
            style: Ink3D.text(13.5, FontWeight.w400, BuddyLook.subText, height: 1.5, letterSpacing: 0),
          ),
        ],
      ),
    );
  }
}
