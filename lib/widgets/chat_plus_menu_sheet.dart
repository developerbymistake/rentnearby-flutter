import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/question_template_model.dart';

/// The "+" menu — confirmed pattern (Option A): tap opens a flat, tap-to-select
/// list, composer itself stays a single clean row. No free text anywhere here.
class ChatPlusMenuSheet extends StatelessWidget {
  final List<QuestionTemplateModel> questions;
  final void Function(QuestionTemplateModel) onAskQuestion;
  final VoidCallback onRequestContact;
  final VoidCallback onScheduleVisit;

  const ChatPlusMenuSheet({
    super.key,
    required this.questions,
    required this.onAskQuestion,
    required this.onRequestContact,
    required this.onScheduleVisit,
  });

  static Future<void> show(
    BuildContext context, {
    required List<QuestionTemplateModel> questions,
    required void Function(QuestionTemplateModel) onAskQuestion,
    required VoidCallback onRequestContact,
    required VoidCallback onScheduleVisit,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ChatPlusMenuSheet(
        questions: questions,
        onAskQuestion: onAskQuestion,
        onRequestContact: onRequestContact,
        onScheduleVisit: onScheduleVisit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          if (questions.isNotEmpty) ...[
            _sectionLabel('About this listing'),
            ...questions.map((q) => _item(
                  context,
                  icon: Icons.help_outline_rounded,
                  label: q.questionText,
                  onTap: () {
                    Navigator.pop(context);
                    onAskQuestion(q);
                  },
                )),
          ],
          _sectionLabel('Contact'),
          _item(context, icon: Icons.call_outlined, label: 'Request contact number', onTap: () {
            Navigator.pop(context);
            onRequestContact();
          }),
          _sectionLabel('Visit'),
          _item(context, icon: Icons.calendar_month_rounded, label: 'Schedule a visit', onTap: () {
            Navigator.pop(context);
            onScheduleVisit();
          }),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text.toUpperCase(),
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600,
                  color: AppColors.textHint, letterSpacing: 0.4)),
        ),
      );

  Widget _item(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
            ),
          ]),
        ),
      );
}
