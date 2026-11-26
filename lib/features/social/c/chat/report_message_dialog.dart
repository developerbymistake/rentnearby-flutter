import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/buddies/buddies_strings.dart';
import '../../../buddy/buddies/buddy_feedback.dart';
import '../../../buddy/buddies/data/buddies_api.dart';
import '../../../buddy/buddies/models/buddy_models.dart';
import '../../../buddy/buddies/widgets/block_dialog.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../../buddy/shared/strings_shared.dart';
import '../../../buddy/shared/widgets/buddy_confirm_box.dart';
import '../../shared/data/social_report_api.dart';
import '../social_strings_c.dart';

class ReportMessageDialog extends StatefulWidget {
  const ReportMessageDialog({super.key, required this.roomId, required this.seq, required this.reasons, this.api = const SocialReportApi()});

  final String roomId;
  final int seq;
  final List<ReportReason> reasons;
  final SocialReportApi api;

  static Future<bool> show(BuildContext context, {required String roomId, required int seq, SocialReportApi api = const SocialReportApi()}) async {
    final rs = await const BuddiesApi().reportReasons();
    if (!context.mounted) return false;
    final reasons = rs.valueOrNull;
    if (reasons == null || reasons.isEmpty) {
      BuddyFeedback.writeFailed(rs);
      return false;
    }
    final ok = await Dialog3D.show<bool>(context, builder: (_) => ReportMessageDialog(roomId: roomId, seq: seq, reasons: reasons, api: api));
    return ok == true;
  }

  @override
  State<ReportMessageDialog> createState() => _ReportMessageDialogState();
}

class _ReportMessageDialogState extends State<ReportMessageDialog> {
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
    final r = await widget.api.reportMessage(widget.roomId, widget.seq, reasonId: reason, note: note.isEmpty ? null : note, alsoBlock: _alsoBlock);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r is BuddyOk<void>) {
      Navigator.of(context).pop(true);
    } else {
      BuddyFeedback.writeFailed(r);
    }
  }

  @override
  Widget build(BuildContext context) => BuddyConfirmBox.box(
        art: BuddyArt.warning,
        title: SocialStringsC.reportMessageTitle,
        cancelLabel: BuddySharedStrings.cancel,
        confirmLabel: BuddiesStrings.report,
        confirmKind: ConfirmKind.danger,
        busy: _busy,
        onCancel: () => Navigator.of(context).pop(false),
        onConfirm: _send,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(SocialStringsC.reportMessageBody, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w400, BuddyLook.subText, height: 1.5, letterSpacing: 0)),
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
