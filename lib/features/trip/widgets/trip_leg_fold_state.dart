import 'package:flutter/foundation.dart';

class TripLegFoldState extends ChangeNotifier {
  final Set<int> _folded = {};

  bool isFolded(int leg) => _folded.contains(leg);

  Set<int> get folded => Set.unmodifiable(_folded);

  void toggle(int leg) {
    if (!_folded.remove(leg)) _folded.add(leg);
    notifyListeners();
  }

  void set(int leg, bool folded) {
    if (folded ? _folded.add(leg) : _folded.remove(leg)) notifyListeners();
  }

  void openAll() {
    if (_folded.isEmpty) return;
    _folded.clear();
    notifyListeners();
  }
}
