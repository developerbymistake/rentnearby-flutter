import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
import '../models/question_template_model.dart';

class ChatPlusMenuSheet extends StatelessWidget {
  final List<QuestionTemplateModel> questions;
  final void Function(QuestionTemplateModel) onAskQuestion;
  final VoidCallback onRequestContact;
  final VoidCallback onScheduleVisit;
  final Color accent;
  final ListingTone? tone;

  const ChatPlusMenuSheet({
    super.key,
    required this.questions,
    required this.onAskQuestion,
    required this.onRequestContact,
    required this.onScheduleVisit,
    this.accent = FitnessAppTheme.nearlyDarkBlue,
    this.tone,
  });

  static Future<void> show(
    BuildContext context, {
    required List<QuestionTemplateModel> questions,
    required void Function(QuestionTemplateModel) onAskQuestion,
    required VoidCallback onRequestContact,
    required VoidCallback onScheduleVisit,
    Color accent = FitnessAppTheme.nearlyDarkBlue,
    ListingTone? tone,
  }) {
    return Sheet3D.show(
      context,
      builder: (_) => ChatPlusMenuSheet(
        questions: questions,
        onAskQuestion: onAskQuestion,
        onRequestContact: onRequestContact,
        onScheduleVisit: onScheduleVisit,
        accent: accent,
        tone: tone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ListingTone.forest;
    final rows = <Widget>[
      if (questions.isNotEmpty) ...[
        const ChatSheetLabel3D('About this listing'),
        for (final q in questions)
          ChatSheetRow3D(
            tone: t,
            art: ListingArt.clipboard,
            label: q.questionText,
            onTap: () {
              Navigator.pop(context);
              onAskQuestion(q);
            },
          ),
        const ChatSheetDivider3D(),
      ],
      const ChatSheetLabel3D('Contact'),
      ChatSheetRow3D(
        tone: t,
        art: ListingArt.speechBalloon,
        label: 'Request contact number',
        onTap: () {
          Navigator.pop(context);
          onRequestContact();
        },
      ),
      const ChatSheetDivider3D(),
      const ChatSheetLabel3D('Visit'),
      ChatSheetRow3D(
        tone: t,
        art: ListingArt.calendar,
        label: 'Schedule a visit',
        onTap: () {
          Navigator.pop(context);
          onScheduleVisit();
        },
      ),
    ];
    return Sheet3D(
      tone: t,
      art: ListingArt.speechBalloon,
      size: SheetSize.hug,
      scrollable: questions.isEmpty,
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: questions.isEmpty
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: rows)
          : _WholeRowList(children: rows),
    );
  }
}

class _WholeRowList extends StatefulWidget {
  const _WholeRowList({required this.children});

  static const double maxListHeight = 512;
  static const double topRoom = 334;

  final List<Widget> children;

  @override
  State<_WholeRowList> createState() => _WholeRowListState();
}

class _WholeRowListState extends State<_WholeRowList> {
  final _content = GlobalKey();
  late List<GlobalKey> _keys;
  double? _height;
  double _limit = 0;

  @override
  void initState() {
    super.initState();
    _keys = [for (final _ in widget.children) GlobalKey()];
  }

  void _measure() {
    if (!mounted) return;
    final box = _content.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    var best = 0.0;
    for (var i = 0; i < _keys.length; i++) {
      if (widget.children[i] is! ChatSheetRow3D) continue;
      final row = _keys[i].currentContext?.findRenderObject() as RenderBox?;
      if (row == null || !row.hasSize) continue;
      final bottom = row.localToGlobal(Offset(0, row.size.height), ancestor: box).dy;
      if (bottom <= _limit + 0.5 && bottom > best) best = bottom;
    }
    final h = best > 0 ? best : _limit;
    if (_height != h) setState(() => _height = h);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final fit = (MediaQuery.sizeOf(context).height - _WholeRowList.topRoom).clamp(0.0, _WholeRowList.maxListHeight);
        final limit = c.maxHeight.isFinite ? c.maxHeight.clamp(0.0, fit) : fit;
        if (limit != _limit) {
          _limit = limit;
          _height = null;
        }
        if (_height == null) WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
        return SizedBox(
          height: _height ?? limit,
          child: SingleChildScrollView(
            child: Column(
              key: _content,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (var i = 0; i < widget.children.length; i++) KeyedSubtree(key: _keys[i], child: widget.children[i])],
            ),
          ),
        );
      },
    );
  }
}
