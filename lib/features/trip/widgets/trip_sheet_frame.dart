import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:flutter/material.dart';

class TripSheetFrame extends StatelessWidget {
  const TripSheetFrame({
    super.key,
    required this.title,
    this.description,
    required this.children,
    this.footer,
    this.art,
    this.tone,
    this.size = SheetSize.hug,
    this.footnote,
    this.endNote,
  });

  final String title;
  final String? description;
  final List<Widget> children;
  final Widget? footer;
  final String? art;
  final ListingTone? tone;
  final SheetSize size;
  final String? footnote;
  final String? endNote;

  static Future<T?> show<T>(BuildContext context, Widget child) =>
      SheetFrame.show<T>(context, builder: (_) => child);

  @override
  Widget build(BuildContext context) {
    final count = children.length > 10 ? 10 : children.length;
    return Sheet3D(
      tone: tone ?? ListingTone.indigo,
      art: art,
      title: title,
      subtitle: description,
      centerTitle: art != null,
      size: size,
      footer: footer,
      footnote: footnote,
      padding: EdgeInsets.fromLTRB(22, 0, 22, footer == null ? 20 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++)
            TemplateEntranceOnce(index: i, count: count, child: children[i]),
          if (endNote case final note?)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(note, textAlign: TextAlign.center, style: RepliesLook.foot),
            ),
        ],
      ),
    );
  }
}
