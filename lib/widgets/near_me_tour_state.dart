/// Plain-Dart bookkeeping for the "Find Near Me" tour — deliberately NOT a
/// GetX controller/singleton. `mapShouldPause` (app_map_state.dart) is a
/// single global flag shared by both Explore screens, which is exactly why
/// tour state must stay a private field on each screen's own State object:
/// a Room tour and a Plot tour must never be able to see or clobber each
/// other. This class only holds the index/bounds/hand-off bookkeeping that's
/// identical between the two screens — presentation (colors, icons, sheets)
/// stays fully separate per screen.
class NearMeTour<T> {
  bool isActive = false;
  List<T> results = [];
  int currentIndex = 0;
  int totalMatching = 0;

  void start(List<T> items, {required int totalMatching}) {
    isActive = true;
    results = items;
    currentIndex = 0;
    this.totalMatching = totalMatching;
  }

  T get current => results[currentIndex];

  bool get isFirstResult => currentIndex == 0;
  bool get isLastResult => currentIndex == results.length - 1;

  /// Only true once the tour has actually reached its last card AND there's
  /// something beyond the capped list to hand off to — not simply "5 shown."
  bool get showHandoff => isLastResult && remainingCount > 0;
  int get remainingCount => (totalMatching - results.length).clamp(0, totalMatching);

  void next() {
    if (currentIndex < results.length - 1) currentIndex++;
  }

  void prev() {
    if (currentIndex > 0) currentIndex--;
  }

  void reset() {
    isActive = false;
    results = [];
    currentIndex = 0;
    totalMatching = 0;
  }
}
