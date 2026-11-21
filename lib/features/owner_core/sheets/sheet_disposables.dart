import 'package:flutter/widgets.dart';

/// Disposes [notifiers] when the sheet route is removed, after its exit animation.
class SheetDisposables extends StatefulWidget {
  const SheetDisposables({super.key, required this.notifiers, required this.child});

  final List<ChangeNotifier> notifiers;
  final Widget child;

  @override
  State<SheetDisposables> createState() => _SheetDisposablesState();
}

class _SheetDisposablesState extends State<SheetDisposables> {
  final Set<ChangeNotifier> _owned = {};

  @override
  void initState() {
    super.initState();
    _owned.addAll(widget.notifiers);
  }

  @override
  void didUpdateWidget(SheetDisposables old) {
    super.didUpdateWidget(old);
    _owned.addAll(widget.notifiers);
  }

  @override
  void dispose() {
    for (final n in _owned) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
