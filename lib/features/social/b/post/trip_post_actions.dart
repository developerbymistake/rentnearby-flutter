import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/buddies/buddies_strings.dart';
import '../../../buddy/buddies/buddy_feedback.dart';
import '../../../buddy/buddies/data/buddies_api.dart';
import '../../../buddy/buddies/models/buddy_models.dart';
import '../../../buddy/buddies/widgets/block_dialog.dart';
import '../../../buddy/buddies/widgets/report_sheet.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../../buddy/shared/strings_shared.dart';
import '../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../../buddy/shared/widgets/buddy_confirm_box.dart';
import '../../../buddy/shared/widgets/buddy_sheet.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../../buddy/shared/widgets/menu_row.dart';
import '../../shared/data/social_report_api.dart';
import '../../shared/social_models.dart';
import '../social_strings_b.dart';

class TripPostMenuItem {
  const TripPostMenuItem({required this.art, required this.title, this.subtitle, this.danger = false, required this.onSelected});

  final String art;
  final String title;
  final String? subtitle;
  final bool danger;
  final Future<void> Function() onSelected;
}

abstract final class TripPostActions {
  static Future<void> showMenu(BuildContext context, {required PublicTrip trip, VoidCallback? onBlocked}) async {
    final owner = trip.owner;
    final items = trip.isMine
        ? const <TripPostMenuItem>[]
        : <TripPostMenuItem>[
            TripPostMenuItem(
              art: BuddyArt.warning,
              title: SocialStringsB.reportTrip,
              subtitle: SocialStringsB.reportTripLine,
              danger: true,
              onSelected: () async {
                final outcome = await ReportTripPostDialog.show(context, tripId: trip.tripId);
                if (!context.mounted) return;
                if (outcome == ReportOutcome.reportedAndBlocked) {
                  onBlocked?.call();
                } else if (outcome == ReportOutcome.reported) {
                  BuddySnack.show(context, SocialStringsB.reported);
                }
              },
            ),
            TripPostMenuItem(
              art: BuddyArt.shield,
              title: SocialStringsB.blockPerson(owner.shortName),
              subtitle: SocialStringsB.blockLine,
              danger: true,
              onSelected: () async {
                final ok = await BlockDialog.show(context, person: owner.asBuddyPerson, contextName: BuddyContext.tripPost);
                if (ok) onBlocked?.call();
              },
            ),
          ];
    if (items.isEmpty) return;
    final picked = await BuddySheet.show<int>(
      context,
      avatar: BuddyAvatar(initial: owner.initial, seed: owner.userId, size: BuddyAvatarSize.lg, ring: true, photoUrl: owner.photoUrl),
      title: owner.name,
      subtitle: owner.username,
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: DS.s(1), thickness: DS.s(1), color: BuddyLook.hairline),
            MenuRow(
              key: ValueKey('trip_post_menu_$i'),
              art: items[i].art,
              title: items[i].title,
              subtitle: items[i].subtitle,
              danger: items[i].danger,
              onTap: () => Navigator.of(c).pop(i),
            ),
          ],
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    await items[picked].onSelected();
  }
}

class ReportTripPostDialog extends StatefulWidget {
  const ReportTripPostDialog({super.key, required this.tripId, required this.reasons, this.api = const SocialReportApi()});

  final String tripId;
  final List<ReportReason> reasons;
  final SocialReportApi api;

  static Future<ReportOutcome?> show(BuildContext context, {required String tripId, SocialReportApi api = const SocialReportApi()}) async {
    final rs = await const BuddiesApi().reportReasons();
    if (!context.mounted) return null;
    final reasons = rs.valueOrNull;
    if (reasons == null || reasons.isEmpty) {
      BuddyFeedback.writeFailed(rs);
      return null;
    }
    return Dialog3D.show<ReportOutcome>(context, builder: (_) => ReportTripPostDialog(tripId: tripId, reasons: reasons, api: api));
  }

  @override
  State<ReportTripPostDialog> createState() => _ReportTripPostDialogState();
}

class _ReportTripPostDialogState extends State<ReportTripPostDialog> {
  late String? _reasonId = widget.reasons.first.id;
  bool _alsoBlock = false;
  bool _busy = false;
  String? _error;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reasonId;
    if (reason == null) {
      setState(() => _error = BuddiesStrings.pickReason);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final note = _note.text.trim();
    final r = await widget.api.reportTripPost(widget.tripId, reasonId: reason, note: note.isEmpty ? null : note, alsoBlock: _alsoBlock);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r is BuddyOk<void>) {
      Navigator.of(context).pop(_alsoBlock ? ReportOutcome.reportedAndBlocked : ReportOutcome.reported);
    } else {
      BuddyFeedback.writeFailed(r);
    }
  }

  @override
  Widget build(BuildContext context) => BuddyConfirmBox.box(
        art: BuddyArt.warning,
        title: SocialStringsB.reportTrip,
        cancelLabel: BuddySharedStrings.cancel,
        confirmLabel: BuddiesStrings.report,
        confirmKind: ConfirmKind.danger,
        busy: _busy,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _send,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(SocialStringsB.reportTripBody, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w400, BuddyLook.subText, height: 1.5, letterSpacing: 0)),
            Gap.v(14),
            ReasonChips(reasons: widget.reasons, selectedId: _reasonId, onPick: _busy ? null : (id) => setState(() => _reasonId = id)),
            if (widget.reasons.any((r) => r.id == _reasonId && r.isOther)) ...[Gap.v(10), ReportNoteField(controller: _note)],
            Gap.v(12),
            TickRow(label: BuddiesStrings.alsoBlock, checked: _alsoBlock, onTap: _busy ? null : () => setState(() => _alsoBlock = !_alsoBlock)),
            if (_error != null) ...[Gap.v(10), ErrorLine(text: _error!)],
          ],
        ),
      );
}
