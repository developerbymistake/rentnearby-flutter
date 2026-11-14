import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'hub_tokens.dart';

class HubSectionTitle extends StatelessWidget {
  const HubSectionTitle({
    super.key,
    required this.title,
    this.sub,
    this.top = 24,
    this.action,
    this.onAction,
  });

  final String title;
  final String? sub;
  final double top;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Ink3D.text(18, FontWeight.w600, HubTokens.heading, letterSpacing: 0.3)),
        ),
        if (sub != null)
          Text(sub!, style: Ink3D.text(12.5, FontWeight.w400, HubTokens.headingSub, letterSpacing: 0)),
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(18, top, 18, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: text),
          if (action != null)
            InkWell(
              onTap: onAction,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: Text(action!, style: Ink3D.text(14, FontWeight.w700, HubTokens.blue, letterSpacing: 0)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
