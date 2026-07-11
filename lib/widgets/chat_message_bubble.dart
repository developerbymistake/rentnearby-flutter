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
  final VoidCallback? onAcceptSchedule;
  final VoidCallback? onDeclineSchedule;
  final VoidCallback? onCounterSchedule;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.templates,
    this.onAnswerQuestion,
    this.onApproveContact,
    this.onDeclineContact,
    this.onAcceptSchedule,
    this.onDeclineSchedule,
    this.onCounterSchedule,
    this.onCall,
    this.onWhatsApp,
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
    if (!message.isMine && template != null && template.answerOptions.isNotEmpty && onAnswerQuestion != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        bubble,
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
          child: Wrap(spacing: 6, runSpacing: 6, children: template.answerOptions.map((opt) {
            final negative = opt.sentiment == 'negative';
            return OutlinedButton(
              onPressed: () => onAnswerQuestion!(opt.key, opt.text),
              style: OutlinedButton.styleFrom(
                foregroundColor: negative ? AppColors.error : AppColors.primary,
                side: BorderSide(color: negative ? AppColors.error.withValues(alpha: 0.4) : AppColors.primaryLight),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(opt.text, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600)),
            );
          }).toList()),
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
      title: message.isMine ? 'Contact number requested' : 'Contact number requested',
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
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
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onWhatsApp,
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('WhatsApp', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ),
    ]);
  }

  // ── schedule_proposal / schedule_response ───────────────────────────────

  Widget _scheduleProposal(BuildContext context) {
    final status = message.payload['status'] as String? ?? 'pending';
    final proposedAtRaw = message.payload['proposedAt'] as String?;
    final proposedAt = proposedAtRaw != null ? DateTime.tryParse(proposedAtRaw) : null;
    final label = proposedAt != null ? _formatDateTime(proposedAt) : 'a visit';
    final superseded = status == 'superseded';

    final canRespond = !message.isMine && status == 'pending' && onAcceptSchedule != null;

    return Opacity(
      opacity: superseded ? 0.45 : 1,
      child: _card(
        icon: Icons.calendar_month_rounded,
        title: message.isMine ? 'Visit proposed' : 'Visit requested',
        subtitle: label,
        actions: canRespond
            ? [
                _actionBtn('Accept', primary: true, onTap: onAcceptSchedule),
                _actionBtn('Propose different time', primary: false, onTap: onCounterSchedule),
                _actionBtn('Decline', primary: false, negative: true, onTap: onDeclineSchedule),
              ]
            : null,
        mine: message.isMine,
      ),
    );
  }

  Widget _scheduleResponse(BuildContext context) {
    final status = message.payload['status'] as String? ?? 'declined';
    if (status == 'declined') return _system('Visit request declined');
    return _card(icon: Icons.check_circle_outline_rounded, title: 'Visit confirmed', mine: message.isMine);
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
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14), topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 3),
              bottomRight: Radius.circular(mine ? 3 : 14),
            ),
            boxShadow: mine ? null : [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Text(text,
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 13.5,
                  color: mine ? Colors.white : AppColors.textDark)),
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

  Widget _card({
    required IconData icon,
    required String title,
    String? subtitle,
    List<Widget>? actions,
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
            if (actions != null) ...[
              const SizedBox(height: 10),
              Column(children: actions.map((a) => Padding(padding: const EdgeInsets.only(bottom: 6), child: a)).toList()),
            ],
          ]),
        ),
      );

  Widget _actionBtn(String label, {required bool primary, bool negative = false, VoidCallback? onTap}) => SizedBox(
        width: double.infinity,
        child: primary
            ? ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
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

  static String _formatDateTime(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]} ${dt.day}, $hour:$minute $ampm';
  }
}
