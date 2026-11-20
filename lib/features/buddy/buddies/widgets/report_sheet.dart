import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../buddy_error_types.dart';
import '../../shared/buddy_look.dart';
import '../../shared/buddy_result.dart';
import '../../shared/models/person_models.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_confirm_box.dart';
import '../buddies_strings.dart';
import '../buddy_feedback.dart';
import '../data/buddies_api.dart';
import '../models/buddy_models.dart';
import 'block_dialog.dart';

enum ReportOutcome { reported, reportedAndBlocked }

class ReportDialog extends StatefulWidget {
  const ReportDialog({super.key, required this.person, required this.contextName, required this.api, required this.reasons});

  final BuddyPerson person;
  final String contextName;
  final BuddiesApi api;
  final List<ReportReason> reasons;

  static Future<ReportOutcome?> show(BuildContext context, {required BuddyPerson person, required String contextName, BuddiesApi api = const BuddiesApi()}) async {
    final rs = await api.reportReasons();
    if (!context.mounted) return null;
    final reasons = rs.valueOrNull;
    if (reasons == null || reasons.isEmpty) {
      BuddyFeedback.writeFailed(rs);
      return null;
    }
    return Dialog3D.show<ReportOutcome>(
      context,
      builder: (_) => ReportDialog(person: person, contextName: contextName, api: api, reasons: reasons),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  bool _alsoBlock = true;
  late String? _reasonId = widget.reasons.first.id;
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

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
    final r = await widget.api.report(widget.person.userId, reasonId: reason, note: note.isEmpty ? null : note, alsoBlock: _alsoBlock, context: widget.contextName);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case BuddyOk():
        Navigator.of(context).pop(_alsoBlock ? ReportOutcome.reportedAndBlocked : ReportOutcome.reported);
      case BuddyRefused(:final type) when type == BuddyErrorTypes.invalidReason:
        setState(() => _error = BuddiesStrings.pickReason);
      case BuddyRefused(:final type) when type == BuddyErrorTypes.tooManyBlocks:
        setState(() => _error = BuddiesStrings.tooManyBlocks);
      default:
        BuddyFeedback.writeFailed(r);
    }
  }

  @override
  Widget build(BuildContext context) => BuddyConfirmBox.box(
        art: BuddyArt.warning,
        title: BuddiesStrings.reportTitle(widget.person.name),
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
            Text(BuddiesStrings.reportBody, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w400, BuddyLook.subText, height: 1.5, letterSpacing: 0)),
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
