import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import '../models/question_template_model.dart';

class ChatPlusMenuSheet extends StatelessWidget {
  final List<QuestionTemplateModel> questions;
  final void Function(QuestionTemplateModel) onAskQuestion;
  final VoidCallback onRequestContact;
  final VoidCallback onScheduleVisit;
  final Color accent;

  const ChatPlusMenuSheet({
    super.key,
    required this.questions,
    required this.onAskQuestion,
    required this.onRequestContact,
    required this.onScheduleVisit,
    this.accent = FitnessAppTheme.nearlyDarkBlue,
  });

  static Future<void> show(
    BuildContext context, {
    required List<QuestionTemplateModel> questions,
    required void Function(QuestionTemplateModel) onAskQuestion,
    required VoidCallback onRequestContact,
    required VoidCallback onScheduleVisit,
    Color accent = FitnessAppTheme.nearlyDarkBlue,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatPlusMenuSheet(
        questions: questions,
        onAskQuestion: onAskQuestion,
        onRequestContact: onRequestContact,
        onScheduleVisit: onScheduleVisit,
        accent: accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return ChatSheetFrame(
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TemplateStagger(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChatSheetFrame.grabber(),
                if (questions.isNotEmpty)
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const ChatSheetLabel('About this listing'),
                    ...questions.map((q) => ChatSheetRow(
                          asset: TravelIcon.note,
                          label: q.questionText,
                          color: accent,
                          onTap: () {
                            Navigator.pop(context);
                            onAskQuestion(q);
                          },
                        )),
                    const Divider(color: FitnessAppTheme.spacer, height: 1),
                  ]),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const ChatSheetLabel('Contact'),
                  ChatSheetRow(
                    asset: TravelIcon.chat,
                    label: 'Request contact number',
                    color: accent,
                    onTap: () {
                      Navigator.pop(context);
                      onRequestContact();
                    },
                  ),
                  const Divider(color: FitnessAppTheme.spacer, height: 1),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const ChatSheetLabel('Visit'),
                  ChatSheetRow(
                    asset: TravelIcon.calendar,
                    label: 'Schedule a visit',
                    color: accent,
                    onTap: () {
                      Navigator.pop(context);
                      onScheduleVisit();
                    },
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
