import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../buddy_error_types.dart';
import '../../buddy_limits.dart';
import '../../shared/buddy_look.dart';
import '../../shared/buddy_result.dart';
import '../../shared/models/person_models.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_confirm_box.dart';
import '../buddies_strings.dart';
import '../buddy_feedback.dart';
import '../data/buddies_api.dart';
import '../models/buddy_models.dart';

class BlockDialog extends StatefulWidget {
  const BlockDialog({super.key, required this.person, required this.contextName, required this.api, this.blockContext, this.reasons = const [], this.startTicked = false});

  final BuddyPerson person;
  final String contextName;
  final BuddiesApi api;
  final BlockContext? blockContext;
  final List<ReportReason> reasons;
  final bool startTicked;

  static Future<bool> show(BuildContext context, {required BuddyPerson person, required String contextName, BuddiesApi api = const BuddiesApi()}) async {
    final (bc, rs) = await (api.blockContext(person.userId), api.reportReasons()).wait;
    if (!context.mounted) return false;
    final ok = await Dialog3D.show<bool>(
      context,
      builder: (_) => BlockDialog(
        person: person,
        contextName: contextName,
        api: api,
        blockContext: bc.valueOrNull,
        reasons: rs.valueOrNull ?? const [],
      ),
    );
    return ok == true;
  }

  static List<String> tripLines(BuddyPerson person, BlockContext? bc) {
    final trips = bc?.tripsInCommon ?? const <TripInCommon>[];
    final mine = trips.where((t) => t.iOwn).toList();
    final theirs = trips.where((t) => !t.iOwn).toList();
    return [
      if (mine.length == 1) BuddiesStrings.stillOnYourTrip(person.name, mine.first.title),
      if (mine.length > 1) BuddiesStrings.stillOnYourTrips(person.name, mine.length),
      if (theirs.isNotEmpty) BuddiesStrings.youAreOnTheirTrip(person.name),
    ];
  }

  @override
  State<BlockDialog> createState() => _BlockDialogState();
}

class _BlockDialogState extends State<BlockDialog> {
  late bool _tick = widget.startTicked;
  late String? _reasonId = widget.reasons.isEmpty ? null : widget.reasons.first.id;
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _block() async {
    final reason = _reasonId;
    if (_tick && reason == null) {
      setState(() => _error = BuddiesStrings.pickReason);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final note = _note.text.trim();
    final r = await widget.api.block(
      widget.person.userId,
      alsoReport: _tick && reason != null ? ReportInput(reasonId: reason, note: note.isEmpty ? null : note) : null,
      context: widget.contextName,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case BuddyOk():
        Navigator.of(context).pop(true);
      case BuddyRefused(:final type) when type == BuddyErrorTypes.tooManyBlocks:
        setState(() => _error = BuddiesStrings.tooManyBlocks);
      case BuddyRefused(:final type) when type == BuddyErrorTypes.invalidReason:
        setState(() => _error = BuddiesStrings.pickReason);
      default:
        BuddyFeedback.writeFailed(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = BlockDialog.tripLines(widget.person, widget.blockContext);
    final reasons = widget.reasons;
    return BuddyConfirmBox.box(
      art: BuddyArt.shield,
      title: BuddiesStrings.blockTitle(widget.person.name),
      cancelLabel: BuddySharedStrings.cancel,
      confirmLabel: BuddiesStrings.block,
      confirmKind: ConfirmKind.danger,
      busy: _busy,
      onCancel: () => Navigator.of(context).pop(false),
      onConfirm: _block,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final l in lines) ...[TripLineBox(text: l), Gap.v(10)],
          Text(BuddiesStrings.blockBody, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w400, BuddyLook.subText, height: 1.5, letterSpacing: 0)),
          if (reasons.isNotEmpty) ...[
            Gap.v(14),
            TickRow(label: BuddiesStrings.alsoReport, checked: _tick, onTap: _busy ? null : () => setState(() => _tick = !_tick)),
            if (_tick) ...[
              Gap.v(12),
              ReasonChips(reasons: reasons, selectedId: _reasonId, onPick: _busy ? null : (id) => setState(() => _reasonId = id)),
              if (reasons.any((r) => r.id == _reasonId && r.isOther)) ...[Gap.v(10), ReportNoteField(controller: _note)],
            ],
          ],
          if (_error != null) ...[Gap.v(10), ErrorLine(text: _error!)],
        ],
      ),
    );
  }
}

class TripLineBox extends StatelessWidget {
  const TripLineBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(h: 16, v: 12),
        decoration: BoxDecoration(color: BuddyLook.note[NoteToneColor.danger]!.$1, borderRadius: DS.circular(16)),
        child: Text(text, style: Ink3D.text(13, FontWeight.w500, BuddyLook.dangerText, height: 1.5, letterSpacing: 0)),
      );
}

class ErrorLine extends StatelessWidget {
  const ErrorLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w600, BuddyLook.dangerText, height: 1.4, letterSpacing: 0));
}

class TickRow extends StatelessWidget {
  const TickRow({super.key, required this.label, required this.checked, required this.onTap});

  final String label;
  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tap3D(
        onTap: onTap,
        toggled: checked,
        label: label,
        exclude: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: DS.s(40)),
          child: Row(
            children: [
              Container(
                width: DS.s(26),
                height: DS.s(26),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: DS.circular(8),
                  gradient: checked ? BuddyLook.danger.gradient : null,
                  border: checked ? null : Border.all(color: BuddyLook.checkOff, width: DS.s(2)),
                ),
                child: checked ? Icon(Icons.check_rounded, size: DS.s(18), color: DesignColors.onPrimary) : null,
              ),
              Gap.h(12),
              Expanded(child: Text(label, style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
            ],
          ),
        ),
      );
}

class ReasonChips extends StatelessWidget {
  const ReasonChips({super.key, required this.reasons, required this.selectedId, required this.onPick});

  final List<ReportReason> reasons;
  final String? selectedId;
  final ValueChanged<String>? onPick;

  static BorderRadius get radius =>
      DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(20), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: DS.s(8),
        runSpacing: DS.s(8),
        children: [
          for (final r in reasons)
            Tap3D(
              onTap: onPick == null ? null : () => onPick!(r.id),
              selected: r.id == selectedId,
              label: r.name,
              exclude: true,
              child: Container(
                constraints: BoxConstraints(minHeight: DS.s(40)),
                padding: DS.sym(h: 14),
                decoration: BoxDecoration(
                  color: r.id == selectedId ? null : DesignColors.surface,
                  gradient: r.id == selectedId ? BuddyLook.danger.gradient : null,
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: (r.id == selectedId ? BuddyLook.dangerEnd : DesignColors.textStrong).withValues(alpha: r.id == selectedId ? Alpha.v40 : Alpha.v16),
                      offset: DS.shadowOffset(const Offset(1, 3)),
                      blurRadius: DS.shadowBlur(8),
                    ),
                  ],
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(r.name,
                      maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, r.id == selectedId ? DesignColors.onPrimary : BuddyLook.subText, letterSpacing: 0)),
                ),
              ),
            ),
        ],
      );
}

class ReportNoteField extends StatelessWidget {
  const ReportNoteField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(h: 14, v: 10),
        decoration: BoxDecoration(color: DesignColors.scaffold, borderRadius: DS.circular(16)),
        child: TextField(
          controller: controller,
          maxLines: 3,
          minLines: 2,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(BuddyLimits.reportNoteMax)],
          style: Ink3D.text(13.5, FontWeight.w400, Ink3D.title, letterSpacing: 0),
          decoration: InputDecoration(
            isCollapsed: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: BuddiesStrings.noteHint,
            hintStyle: Ink3D.text(13.5, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0),
          ),
        ),
      );
}
