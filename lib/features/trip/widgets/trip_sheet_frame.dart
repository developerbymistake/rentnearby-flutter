import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

class TripSheetFrame extends StatelessWidget {
  const TripSheetFrame({super.key, required this.title, this.description, required this.children, this.footer});

  final String title;
  final String? description;
  final List<Widget> children;
  final Widget? footer;

  static Future<T?> show<T>(BuildContext context, Widget child) =>
      SheetFrame.show<T>(context, builder: (_) => child);

  @override
  Widget build(BuildContext context) {
    final count = children.length > 10 ? 10 : children.length;
    return SheetFrame(
      title: title,
      subtitle: description,
      footer: footer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++)
            TemplateEntranceOnce(index: i, count: count, child: children[i]),
        ],
      ),
    );
  }
}
