import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import '../models/message_model.dart';
import '../models/question_template_model.dart';
import 'trip_chat_cards.dart';
import 'trip_offer_cards.dart';

class ChatMessageBubble extends StatelessWidget {
  final MessageModel message;
  final List<QuestionTemplateModel> templates;
  final void Function(String answerKey, String answerText)? onAnswerQuestion;
  final VoidCallback? onApproveContact;
  final VoidCallback? onDeclineContact;
  final void Function(DateTime)? onAcceptSlot;
  final VoidCallback? onDeclineSchedule;
  final VoidCallback? onCounterSchedule;
  final VoidCallback? onCall;
  final Color accent;
  final Gradient? gradient;
  final bool isOwner;
  final TripChatCallbacks? trip;

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
    this.accent = DesignColors.primary,
    this.gradient,
    this.isOwner = false,
    this.trip,
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
      case 'trip_enquiry':
      case 'trip_offer':
      case 'trip_offer_response':
      case 'trip_advance_request':
      case 'trip_advance_proof_sent':
      case TripOfferCards.counterType:
      case TripOfferCards.revisedType:
      case TripOfferCards.changeType:
        return TripChatCards.build(context, message, isOwner: isOwner, accent: accent, callbacks: trip);
      default:
        return _system(message.payload.safeString('text') ?? '');
    }
  }

  Widget _quickReply(BuildContext context) {
    final text = message.payload.safeString('text') ?? '…';
    final key = message.payload.safeString('key');

    var answerOptions = _parseAnswerOptions(message.payload['answerOptions']);
    if (answerOptions.isEmpty && key != null) {
      QuestionTemplateModel? template;
      try {
        template = templates.firstWhere((t) => t.key == key);
      } catch (_) {
        template = null;
      }
      answerOptions = template?.answerOptions ?? const [];
    }

    final bubble = _bubbleRow(text, mine: message.isMine);

    if (!message.isMine && answerOptions.isNotEmpty && onAnswerQuestion != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        bubble,
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: answerOptions.asMap().entries.map((entry) {
              final i = entry.key;
              final opt = entry.value;
              final negative = opt.sentiment == 'negative';
              final color = negative ? RepliesTone.bad : accent;
              return ChatReveal(
                index: i,
                count: answerOptions.length,
                offset: 12,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PressScale(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      decoration: BoxDecoration(
                        color: DesignColors.surface,
                        borderRadius: CardRadius.pill,
                        border: Border.all(color: color, width: 1.5),
                        boxShadow: ShadowTokens.elev1,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: CardRadius.pill,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          splashColor: DesignColors.tint(color, Alpha.soft),
                          highlightColor: Colors.transparent,
                          onTap: () => onAnswerQuestion!(opt.key, opt.text),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Flexible(
                                child: Text(opt.text, style: TypeTokens.style(14, FontWeight.w600, color: color)),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.chevron_right_rounded, size: 18, color: color),
                            ]),
                          ),
                        ),
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

  Widget _contactRequest(BuildContext context) {
    return _card(
      asset: TravelIcon.chat,
      title: message.isMine ? 'Contact number requested' : 'Wants your contact number',
      readAt: message.readAt,
      actions: (!message.isMine && onApproveContact != null)
          ? [
              _actionBtn('Approve', primary: true, accent: accent, onTap: onApproveContact),
              _actionBtn('Decline', primary: false, accent: accent, onTap: onDeclineContact),
            ]
          : null,
      mine: message.isMine,
      accent: accent,
    );
  }

  Widget _contactResponse(BuildContext context) {
    final approved = message.payload['approved'] == true;
    if (!approved) return _system('Contact request declined');

    final phone = message.payload.safeString('phone');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _system('Contact shared'),
      if (phone != null)
        ChatReveal(
          offset: 12,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: PrimaryButton(
              label: 'Call',
              icon: const Icon(Icons.call_rounded, size: 18, color: DesignColors.onPrimary),
              tone: _toneOf(DesignColors.primaryLight),
              onPressed: onCall,
            ),
          ),
        ),
    ]);
  }

  Widget _scheduleProposal(BuildContext context) {
    final status = message.payload.safeString('status') ?? 'pending';
    final rawList = message.payload.safeList('proposedAts');
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
      accent: accent,
    );
  }

  Widget _scheduleResponse(BuildContext context) {
    final status = message.payload.safeString('status') ?? 'declined';
    if (status == 'declined') return _system('Visit request declined');
    final confirmedAtRaw = message.payload.safeString('confirmedAt');
    final confirmedAt = confirmedAtRaw != null ? DateTime.tryParse(confirmedAtRaw) : null;
    return _card(
      asset: TravelIcon.calendar,
      badgeColor: DesignColors.goodDeep,
      title: 'Visit confirmed',
      subtitle: confirmedAt != null ? _formatDateTime(confirmedAt) : null,
      readAt: message.readAt,
      mine: message.isMine,
      accent: accent,
    );
  }

  Widget _bubbleRow(String text, {required bool mine}) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine && gradient == null ? accent : (mine ? null : DesignColors.surface),
            gradient: mine ? gradient : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 8),
              bottomRight: Radius.circular(mine ? 8 : 16),
            ),
            boxShadow: ShadowTokens.elev1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text,
                  style: TypeTokens.style(14, FontWeight.w400,
                      color: mine ? DesignColors.surface : DesignColors.textPrimary, letterSpacing: 0.2)),
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
          decoration: BoxDecoration(color: DesignColors.tint(DesignColors.textGrey, Alpha.hairline), borderRadius: CardRadius.pill),
          child: Text(text, style: TypeTokens.style(12, FontWeight.w500, color: TypeTokens.secondary)),
        ),
      );
}

extension _SafePayload on Map<String, dynamic> {
  String? safeString(String key) {
    final v = this[key];
    return v is String ? v : null;
  }

  List<dynamic> safeList(String key) {
    final v = this[key];
    return v is List ? v : const [];
  }
}

Widget _readTick(bool read, {bool onDark = true}) => Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Icon(
        read ? Icons.done_all_rounded : Icons.done_rounded,
        size: 14,
        color: onDark
            ? (read ? DesignColors.surface : DesignColors.tint(DesignColors.surface, Alpha.strong))
            : (read ? DesignColors.primaryLight : DesignColors.textMuted),
      ),
    );

Widget _card({
  Key? key,
  required String asset,
  required String title,
  String? subtitle,
  Widget? extra,
  List<Widget>? actions,
  required DateTime? readAt,
  required bool mine,
  required Color accent,
  Color? badgeColor,
  bool dimmed = false,
}) =>
    Align(
      key: key,
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dimmed ? DesignColors.surfaceMuted : DesignColors.surface,
          borderRadius: CardRadius.tile,
          boxShadow: dimmed ? const [] : ShadowTokens.elev1,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: DesignColors.tint(badgeColor ?? accent, Alpha.tint), shape: BoxShape.circle),
              child: TravelIcon(asset, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: TypeTokens.style(14, FontWeight.w700,
                        color: dimmed ? DesignColors.textMuted : DesignColors.textStrong))),
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Text(subtitle, style: TypeTokens.style(14, FontWeight.w400, color: TypeTokens.secondary)),
            ),
          ],
          if (extra != null) ...[
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.only(left: 38), child: extra),
          ],
          if (actions != null) ...[
            const SizedBox(height: 10),
            Column(
              children: actions.asMap().entries.map((entry) {
                return ChatReveal(
                  index: entry.key,
                  count: actions.length,
                  offset: 12,
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

KitTone _toneOf(Color color) => KitTone.solid(color);

Widget _actionBtn(String label, {required bool primary, required Color accent, bool negative = false, VoidCallback? onTap}) {
  if (primary) {
    return PrimaryButton(label: label, tone: _toneOf(accent), onPressed: onTap);
  }
  return SecondaryButton(
    label: label,
    tone: _toneOf(negative ? RepliesTone.bad : accent),
    neutral: !negative,
    onPressed: onTap,
  );
}

List<AnswerOption> _parseAnswerOptions(dynamic raw) {
  if (raw is! List) return const [];
  try {
    return raw.whereType<Map<String, dynamic>>().map(AnswerOption.fromJson).toList();
  } catch (_) {
    return const [];
  }
}

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final ampm = local.hour >= 12 ? 'PM' : 'AM';
  final minute = local.minute.toString().padLeft(2, '0');
  return '${days[local.weekday - 1]} ${local.day}, $hour:$minute $ampm';
}

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
  final Color accent;

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
    required this.accent,
  });

  @override
  State<_ScheduleProposalCard> createState() => _ScheduleProposalCardState();
}

class _ScheduleProposalCardState extends State<_ScheduleProposalCard> {
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.canRespond && widget.proposedAts.length == 1) {
      _selected = widget.proposedAts.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final multiSlot = widget.proposedAts.length > 1;
    return KitSwitcher(
      child: _card(
        key: ValueKey(widget.superseded),
        dimmed: widget.superseded,
        asset: TravelIcon.calendar,
        title: widget.title,
        readAt: widget.readAt,
        mine: widget.mine,
        accent: widget.accent,
        subtitle: widget.canRespond && multiSlot
            ? 'Select a time, then confirm'
            : (widget.proposedAts.isEmpty ? 'a visit' : null),
        extra: widget.proposedAts.isEmpty
            ? null
            : Wrap(spacing: 6, runSpacing: 6, children: widget.proposedAts.asMap().entries.map((entry) {
                final dt = entry.value;
                final isSelected = _selected == dt;
                final chip = widget.canRespond
                    ? PickChip(
                        label: _formatDateTime(dt),
                        selected: isSelected,
                        activeColor: widget.accent,
                        icon: isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        onTap: () => setState(() => _selected = dt),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: DesignColors.scaffold, borderRadius: CardRadius.pill),
                        child: Text(_formatDateTime(dt),
                            style: TypeTokens.style(12, FontWeight.w600, color: TypeTokens.secondary)),
                      );
                return ChatReveal(
                  key: ValueKey(entry.key),
                  index: entry.key,
                  count: widget.proposedAts.length,
                  offset: 12,
                  child: chip,
                );
              }).toList()),
        actions: widget.canRespond
            ? [
                _actionBtn('Confirm visit', primary: true, accent: widget.accent,
                    onTap: _selected != null ? () => widget.onConfirm!(_selected!) : null),
                _actionBtn('Propose different time', primary: false, accent: widget.accent, onTap: widget.onCounterSchedule),
                _actionBtn('Decline', primary: false, accent: widget.accent, negative: true, onTap: widget.onDeclineSchedule),
              ]
            : null,
      ),
    );
  }
}
