import 'package:flutter/material.dart';

class AppBottomDock extends StatelessWidget {
  const AppBottomDock({super.key, required this.banner, required this.nav});

  final Widget banner;
  final Widget nav;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [banner, nav]);
  }
}
