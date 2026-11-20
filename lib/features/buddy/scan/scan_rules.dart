enum ScanVerdict { notBakhli, own, other }

abstract final class ScanRules {
  static final RegExp pattern = RegExp(r'^Bakhli#[0-9]{8}$');
  static const Duration debounce = Duration(seconds: 2);

  static bool isBakhliUsername(String? text) => text != null && pattern.hasMatch(text);

  static ScanVerdict classify(String? text, String? ownUsername) {
    if (!isBakhliUsername(text)) return ScanVerdict.notBakhli;
    if (ownUsername != null && text == ownUsername) return ScanVerdict.own;
    return ScanVerdict.other;
  }
}

class ScanDebounce {
  ScanDebounce({this.window = ScanRules.debounce, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Duration window;
  final DateTime Function() _clock;
  DateTime? _until;

  bool get open => _until == null || !_clock().isBefore(_until!);

  void mark() => _until = _clock().add(window);

  void reset() => _until = null;
}
