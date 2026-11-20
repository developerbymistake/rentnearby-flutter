import '../../buddy_navigation.dart';
import '../viewer_deps.dart';
import '../viewer_strings.dart';

abstract final class JoinedSnack {
  static void show(String tripId) =>
      ViewerDeps.snack(ViewerStrings.joinedAsViewer, actionLabel: ViewerStrings.open, onAction: () => BuddyNavigation.openTripView(tripId));
}
