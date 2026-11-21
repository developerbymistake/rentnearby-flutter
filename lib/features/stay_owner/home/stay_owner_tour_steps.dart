import '../../../config/tour_registry.dart';
import '../../../navigation/tour_keys.dart';

final _kept = [TourKeys.homeInstagramCard, TourKeys.homeActionMenu, TourKeys.homeProfileNavIcon];

List<TourStep> stayOwnerHomeTourSteps() => [
      for (final s in todayHomeTourSteps())
        if (_kept.contains(s.key)) s,
    ];
