import 'package:flutter/widgets.dart';

class SingleFlight<T> {
  Future<T>? _inFlight;

  bool get busy => _inFlight != null;

  Future<T> run(Future<T> Function() action) {
    final current = _inFlight;
    if (current != null) return current;
    final f = action();
    _inFlight = f;
    f.whenComplete(() {
      if (identical(_inFlight, f)) _inFlight = null;
    }).ignore();
    return f;
  }
}

class LatestOnly {
  int _seq = 0;

  int next() => ++_seq;

  bool isLatest(int id) => id == _seq;

  void cancel() => _seq++;
}

class SingleFlightButton extends StatefulWidget {
  const SingleFlightButton({super.key, required this.onPressed, required this.builder});

  final Future<void> Function()? onPressed;
  final Widget Function(BuildContext context, VoidCallback? onPressed, bool busy) builder;

  @override
  State<SingleFlightButton> createState() => _SingleFlightButtonState();
}

class _SingleFlightButtonState extends State<SingleFlightButton> {
  bool _busy = false;

  Future<void> _tap() async {
    final action = widget.onPressed;
    if (_busy || action == null) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.onPressed == null || _busy ? null : _tap, _busy);
}
