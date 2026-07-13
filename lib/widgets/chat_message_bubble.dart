import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/message_model.dart';
import '../models/question_template_model.dart';

class ChatMessageBubble extends StatelessWidget {
  final MessageModel message;
  final List<QuestionTemplateModel> templates;
  final void Function(String answerKey, String answerText)? onAnswerQuestion;
  final VoidCallback? onApproveContact;
  final VoidCallback? onDeclineContact;
  // Called with whichever specific offered time the recipient tapped — a
  // proposal can offer more than one slot, so there's no single implicit
  // "accept" action anymore.
  final void Function(DateTime)? onAcceptSlot;
  final VoidCallback? onDeclineSchedule;
  final VoidCallback? onCounterSchedule;
  final VoidCallback? onCall;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.templates,
    this.onAnswerQuestion,
    this.onApproveContact,
    this.onDeclineContact,
    this.onAcceptSlot,
    this.onDeclineSchedule,
    this.onCounterSchedule,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case 'quick_reply':
        return _quickReply(context);
      case 'contact_request':
        return _contactRequest(context);
      case 'contact_response':
        return _contactResponse(context);
      case 'schedule_proposal':
        return _scheduleProposal(context);
      case 'schedule_response':
        return _scheduleResponse(context);
      default:
        // Defensive fallback only — the backend never emits Type == "system" (or any other
        // unrecognized type) today. Kept so an unrecognized future type renders as a plain
        // status pill instead of crashing the switch (message.type is a raw wire string, not
        // an enum, so exhaustiveness can't be checked at compile time).
        return _system(message.payload['text'] as String? ?? '');
    }
  }

  // ── quick_reply ──────────────────────────────────────────────────────────

  Widget _quickReply(BuildContext context) {
    final text = message.payload['text'] as String? ?? '…';
    final key = message.payload['key'] as String?;
    QuestionTemplateModel? template;
    if (key != null) {
      try {
        template = templates.firstWhere((t) => t.key == key);
      } catch (_) {
        template = null;
      }
    }

    final bubble = _bubbleRow(text, mine: message.isMine);

    // Show reply options under the other party's question, if we know its catalog entry.
    // Rendered as a vertical, right-aligned stack of "ghost" bubbles — each one previews
    // what the eventual sent message would look like, so it reads as picking a reply to
    // send rather than filling in a form field.
    if (!message.isMine && template != null && template.answerOptions.isNotEmpty && onAnswerQuestion != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        bubble,
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: template.answerOptions.asMap().entries.map((entry) {
              final i = entry.key;
              final opt = entry.value;
              final negative = opt.sentiment == 'negative';
              final color = negative ? AppColors.error : AppColors.primary;
              return FadeInUp(
                duration: const Duration(milliseconds: 260),
                delay: Duration(milliseconds: 40 * i),
                from: 12,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onAnswerQuestion!(opt.key, opt.text),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 260),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14), topRight: const Radius.circular(14),
                            bottomLeft: const Radius.circular(14), bottomRight: const Radius.circular(3),
                          ),
                          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.4, style: BorderStyle.solid),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(
                            child: Text(opt.text,
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded, size: 16, color: color.withValues(alpha: 0.6)),
                        ]),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]);
    }

    return bubble;
  }

  // ── contact_request / contact_response ──────────────────────────────────

  Widget _contactRequest(BuildContext context) {
    // The owner side answers via the card's own buttons; the requester just sees a pending card.
    return _card(
      icon: Icons.call_outlined,
      title: message.isMine ? 'Contact number requested' : 'Wants your contact number',
      readAt: message.readAt,
      actions: (!message.isMine && onApproveContact != null)
          ? [
              _actionBtn('Approve', primary: true, onTap: onApproveContact),
              _actionBtn('Decline', primary: false, onTap: onDeclineContact),
            ]
          : null,
      mine: message.isMine,
    );
  }

  Widget _contactResponse(BuildContext context) {
    final approved = message.payload['approved'] == true;
    if (!approved) return _system('Contact request declined');

    final phone = message.payload['phone'] as String?;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _system('Contact shared'),
      if (phone != null)
        FadeInUp(
          duration: const Duration(milliseconds: 280),
          from: 12,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCall,
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Call', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  // ── schedule_proposal / schedule_response ───────────────────────────────

  Widget _scheduleProposal(BuildContext context) {
    final status = message.payload['status'] as String? ?? 'pending';
    final rawList = message.payload['proposedAts'] as List<dynamic>? ?? const [];
    final proposedAts = rawList
        .map((e) => DateTime.tryParse(e is String ? e : ''))
        .whereType<DateTime>()
        .toList();
    final superseded = status == 'superseded';
    final canRespond = !message.isMine && status == 'pending' && onAcceptSlot != null;

    return _ScheduleProposalCard(
      mine: message.isMine,
      readAt: message.readAt,
      title: message.isMine ? 'Visit proposed' : 'Visit requested',
      proposedAts: proposedAts,
      canRespond: canRespond,
      superseded: superseded,
      onConfirm: onAcceptSlot,
      onCounterSchedule: onCounterSchedule,
      onDeclineSchedule: onDeclineSchedule,
    );
  }

  Widget _scheduleResponse(BuildContext context) {
    final status = message.payload['status'] as String? ?? 'declined';
    if (status == 'declined') return _system('Visit request declined');
    final confirmedAtRaw = message.payload['confirmedAt'] as String?;
    final confirmedAt = confirmedAtRaw != null ? DateTime.tryParse(confirmedAtRaw) : null;
    return _card(
      icon: Icons.check_circle_outline_rounded,
      title: 'Visit confirmed',
      subtitle: confirmedAt != null ? _formatDateTime(confirmedAt) : null,
      readAt: message.readAt,
      mine: message.isMine,
    );
  }

  // ── shared building blocks ───────────────────────────────────────────────

  Widget _bubbleRow(String text, {required bool mine}) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : Colors.white,
            border: mine ? null : Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14), topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 3),
              bottomRight: Radius.circular(mine ? 3 : 14),
            ),
            boxShadow: mine ? null : [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 13.5,
                      color: mine ? Colors.white : AppColors.textDark)),
              if (mine) ...[
                const SizedBox(height: 2),
                _readTick(message.readAt != null),
              ],
            ],
          ),
        ),
      );

  Widget _system(String text) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: AppColors.textDark.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
          child: Text(text, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
        ),
      );
}

// ── shared building blocks — top-level so both ChatMessageBubble and
// _ScheduleProposalCard (below) can use them ──────────────────────────────

// onDark: true for _bubbleRow's navy "mine" background, false for _card's always-white
// background — the "sent" (not-yet-read) tick color needs to stay visible on either.
Widget _readTick(bool read, {bool onDark = true}) => Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Icon(
        read ? Icons.done_all_rounded : Icons.done_rounded,
        size: 14,
        color: read ? const Color(0xFF34B7F1) : (onDark ? Colors.white70 : AppColors.textHint),
      ),
    );

Widget _card({
  required IconData icon,
  required String title,
  String? subtitle,
  Widget? extra,
  List<Widget>? actions,
  required DateTime? readAt,
  required bool mine,
}) =>
    Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 15, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ),
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(subtitle, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium)),
            ),
          ],
          if (extra != null) ...[
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.only(left: 34), child: extra),
          ],
          if (actions != null) ...[
            const SizedBox(height: 10),
            Column(
              children: actions.asMap().entries.map((entry) {
                return FadeInUp(
                  duration: const Duration(milliseconds: 260),
                  delay: Duration(milliseconds: 40 * entry.key),
                  from: 12,
                  child: Padding(padding: const EdgeInsets.only(bottom: 6), child: entry.value),
                );
              }).toList(),
            ),
          ],
          if (mine) ...[
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: _readTick(readAt != null, onDark: false)),
          ],
        ]),
      ),
    );

Widget _actionBtn(String label, {required bool primary, bool negative = false, VoidCallback? onTap}) {
  final disabled = onTap == null;
  return SizedBox(
    width: double.infinity,
    child: primary
        ? ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: disabled ? AppColors.divider : AppColors.primary,
              foregroundColor: disabled ? AppColors.textHint : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 9),
            ),
            child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600)),
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: negative ? AppColors.error : AppColors.textMedium,
              side: BorderSide(color: negative ? AppColors.error.withValues(alpha: 0.4) : AppColors.divider),
              padding: const EdgeInsets.symmetric(vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
  );
}

String _formatDateTime(DateTime dt) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${days[dt.weekday - 1]} ${dt.day}, $hour:$minute $ampm';
}

// ── schedule_proposal's slot picker — stateful because the recipient now picks a
// slot first (highlighted, not fired immediately) and only "Confirm visit" commits
// it. Replaces the old "tap any time to instantly accept it" interaction, which had
// no visible affordance telling the recipient a tap would do anything at all.
class _ScheduleProposalCard extends StatefulWidget {
  final bool mine;
  final DateTime? readAt;
  final String title;
  final List<DateTime> proposedAts;
  final bool canRespond;
  final bool superseded;
  final void Function(DateTime)? onConfirm;
  final VoidCallback? onCounterSchedule;
  final VoidCallback? onDeclineSchedule;

  const _ScheduleProposalCard({
    required this.mine,
    required this.readAt,
    required this.title,
    required this.proposedAts,
    required this.canRespond,
    required this.superseded,
    this.onConfirm,
    this.onCounterSchedule,
    this.onDeclineSchedule,
  });

  @override
  State<_ScheduleProposalCard> createState() => _ScheduleProposalCardState();
}

class _ScheduleProposalCardState extends State<_ScheduleProposalCard> {
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    // A single-slot proposal has only one possible answer — pre-select it so
    // "Confirm visit" is already a one-tap action instead of forcing an extra
    // "select the only option" step first.
    if (widget.canRespond && widget.proposedAts.length == 1) {
      _selected = widget.proposedAts.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final multiSlot = widget.proposedAts.length > 1;
    return Opacity(
      opacity: widget.superseded ? 0.45 : 1,
      child: _card(
        icon: Icons.calendar_month_rounded,
        title: widget.title,
        readAt: widget.readAt,
        mine: widget.mine,
        subtitle: widget.canRespond && multiSlot
            ? 'Select a time, then confirm'
            : (widget.proposedAts.isEmpty ? 'a visit' : null),
        extra: widget.proposedAts.isEmpty
            ? null
            : Wrap(spacing: 6, runSpacing: 6, children: widget.proposedAts.asMap().entries.map((entry) {
                final dt = entry.value;
                final isSelected = _selected == dt;
                final chip = widget.canRespond
                    ? OutlinedButton.icon(
                        onPressed: () => setState(() => _selected = dt),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isSelected ? AppColors.primary : Colors.white,
                          foregroundColor: isSelected ? Colors.white : AppColors.primary,
                          side: BorderSide(color: isSelected ? AppColors.primary : AppColors.primaryLight),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: Icon(isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 15),
                        label: Text(_formatDateTime(dt),
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600)),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                        child: Text(_formatDateTime(dt),
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                      );
                return FadeInUp(
                  duration: const Duration(milliseconds: 260),
                  delay: Duration(milliseconds: 40 * entry.key),
                  from: 10,
                  child: chip,
                );
              }).toList()),
        actions: widget.canRespond
            ? [
                _actionBtn('Confirm visit', primary: true,
                    onTap: _selected != null ? () => widget.onConfirm!(_selected!) : null),
                _actionBtn('Propose different time', primary: false, onTap: widget.onCounterSchedule),
                _actionBtn('Decline', primary: false, negative: true, onTap: widget.onDeclineSchedule),
              ]
            : null,
      ),
    );
  }
}
