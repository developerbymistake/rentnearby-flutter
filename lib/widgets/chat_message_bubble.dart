import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
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
  final ListingTone? tone;

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
    this.tone,
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
        return ChatSystemNote(message.payload.safeString('text') ?? '');
    }
  }

  ListingTone get _tone => tone ?? ListingTone.forest;

  ChatTicks _ticks(DateTime? readAt) => readAt != null ? ChatTicks.read : ChatTicks.sent;

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

    final bubble = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: ChatBubble3D(
        tone: _tone,
        text: text,
        mine: message.isMine,
        ticks: message.isMine ? _ticks(message.readAt) : ChatTicks.none,
      ),
    );

    if (!message.isMine && answerOptions.isNotEmpty && onAnswerQuestion != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        bubble,
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < answerOptions.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                ChatAnswerPill(
                  tone: _tone,
                  label: answerOptions[i].text,
                  negative: answerOptions[i].sentiment == 'negative',
                  onTap: () => onAnswerQuestion!(answerOptions[i].key, answerOptions[i].text),
                ),
              ],
            ],
          ),
        ),
      ]);
    }

    return bubble;
  }

  Widget _contactRequest(BuildContext context) {
    final canAct = !message.isMine && onApproveContact != null;
    return _cardSlot(ChatCard3D(
      tone: _tone,
      art: ListingArt.speechBalloon,
      title: message.isMine ? 'Contact number requested' : 'Wants your contact number',
      mine: message.isMine,
      ticks: message.isMine ? _ticks(message.readAt) : ChatTicks.none,
      buttons: canAct
          ? [
              ChatCardButton(label: 'Approve', onTap: onApproveContact),
              ChatCardButton(label: 'Decline', onTap: onDeclineContact, kind: ChatButtonKind.secondary),
            ]
          : const [],
    ));
  }

  Widget _contactResponse(BuildContext context) {
    final approved = message.payload['approved'] == true;
    if (!approved) return const ChatSystemNote('Contact request declined');

    final phone = message.payload.safeString('phone');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const ChatSystemNote('Contact shared'),
      if (phone != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: GradientPillButton(
            tone: _tone,
            label: 'Call',
            icon: Icons.call_rounded,
            height: 44,
            fontSize: 14,
            onTap: onCall,
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
      tone: _tone,
    );
  }

  Widget _scheduleResponse(BuildContext context) {
    final status = message.payload.safeString('status') ?? 'declined';
    if (status == 'declined') return const ChatSystemNote('Visit request declined');
    final confirmedAtRaw = message.payload.safeString('confirmedAt');
    final confirmedAt = confirmedAtRaw != null ? DateTime.tryParse(confirmedAtRaw) : null;
    return _cardSlot(ChatCard3D(
      tone: _tone,
      art: ListingArt.calendar,
      title: 'Visit confirmed',
      mine: message.isMine,
      ticks: message.isMine ? _ticks(message.readAt) : ChatTicks.none,
      chips: confirmedAt != null ? [ChatChip(_formatDateTime(confirmedAt))] : const [],
    ));
  }
}

Widget _cardSlot(Widget card) => Padding(padding: const EdgeInsets.only(top: 4, bottom: 6), child: card);

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
  final ListingTone tone;

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
    required this.tone,
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
    return _cardSlot(ChatCard3D(
      tone: widget.tone,
      art: ListingArt.calendar,
      title: widget.title,
      mine: widget.mine,
      dimmed: widget.superseded,
      ticks: widget.mine ? (widget.readAt != null ? ChatTicks.read : ChatTicks.sent) : ChatTicks.none,
      subtitle: widget.canRespond && multiSlot
          ? 'Select a time, then confirm'
          : (widget.proposedAts.isEmpty ? 'a visit' : null),
      chips: [
        for (final dt in widget.proposedAts)
          widget.canRespond
              ? ChatChip(
                  _formatDateTime(dt),
                  selectable: true,
                  selected: _selected == dt,
                  onTap: () => setState(() => _selected = dt),
                )
              : ChatChip(_formatDateTime(dt)),
      ],
      buttons: widget.canRespond
          ? [
              ChatCardButton(label: 'Confirm visit', onTap: _selected != null ? () => widget.onConfirm!(_selected!) : null),
              ChatCardButton(label: 'Propose different time', onTap: widget.onCounterSchedule, kind: ChatButtonKind.secondary),
              ChatCardButton(label: 'Decline', onTap: widget.onDeclineSchedule, kind: ChatButtonKind.danger),
            ]
          : const [],
    ));
  }
}
