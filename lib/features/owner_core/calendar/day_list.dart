import 'package:flutter/material.dart';

import '../../../design/design.dart';
import 'models/calendar_models.dart';

class DayList extends StatelessWidget {
  const DayList({super.key, required this.entries, required this.row, this.empty, this.shrinkWrap = false, this.controller});

  final List<CalendarEntry> entries;
  final Widget Function(BuildContext context, CalendarEntry entry) row;
  final String? empty;
  final bool shrinkWrap;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      final text = empty;
      if (text == null || text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: DS.sym(h: 18, v: 16),
        child: Text(text, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w500, Ink3D.grey, height: 1.4, letterSpacing: 0)),
      );
    }
    return ListView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: DS.sym(h: 18, v: 8),
      itemCount: entries.length,
      itemBuilder: (context, i) => Padding(
        padding: EdgeInsets.only(bottom: DS.gv(10)),
        child: row(context, entries[i]),
      ),
    );
  }
}
