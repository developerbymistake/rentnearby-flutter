/// Outcome of the plan-selection dialog shown by both my_listings_screen.dart
/// and my_plots_screen.dart before a paid Go-Live (`_showPlanSelectionDialog`
/// in each). A dedicated sealed type — not an overloaded Map key on the plan
/// payload itself — so "user wants to top up first" can never be confused
/// with (or collide with a field name inside) an actual selected-plan Map.
sealed class PlanSelectionResult {}

/// User picked an affordable plan and explicitly confirmed the spend (see the
/// "Confirm Spend" step in `_showPlanSelectionDialog`). [plan] is the raw
/// plan Map as returned by `GET /listings/plans` or `/plots/plans`.
class PlanSelected extends PlanSelectionResult {
  final Map<String, dynamic> plan;
  PlanSelected(this.plan);
}

/// User tapped "Add Coins" on an unaffordable plan row instead of selecting
/// one. Caller should route to CoinPacksScreen (with `returnToGoLive: true`)
/// and, if the purchase completes, reopen the plan-selection dialog — it will
/// re-evaluate affordability against the refreshed wallet balance.
class PlanSelectionAddCoins extends PlanSelectionResult {}
