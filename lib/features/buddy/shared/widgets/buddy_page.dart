import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/trip_plan_header.dart';

class BuddyPage extends StatelessWidget {
  const BuddyPage({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleLeading,
    this.onBack,
    this.trailing = const [],
    this.header,
    this.top,
    required this.body,
    this.scroll = true,
    this.bottomBar,
    this.snack,
    this.overlay,
  });

  final String title;
  final String? subtitle;
  final Widget? subtitleLeading;
  final VoidCallback? onBack;
  final List<Widget> trailing;
  final Widget? header;
  final Widget? top;
  final Widget body;
  final bool scroll;
  final Widget? bottomBar;
  final Widget? snack;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final content = scroll
        ? SingleChildScrollView(
            padding: EdgeInsets.only(bottom: DS.s(20)),
            child: body,
          )
        : body;
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header ?? TripFlowHeader(title: title, subtitle: subtitle, subtitleLeading: subtitleLeading, onBack: onBack ?? () => Navigator.of(context).maybePop(), trailing: trailing),
              ?top,
              Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: content)),
              ?bottomBar,
            ],
          ),
          if (snack != null) Positioned(left: DS.s(18), right: DS.s(18), bottom: DS.s(bottomBar == null ? 24 : 104), child: snack!),
          ?overlay,
        ],
      ),
    );
  }
}
