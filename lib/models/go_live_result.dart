/// Outcome of a POST /listings/{id}/go-live or /plots/{id}/go-live call.
/// Both ListingController.goLive and PlotController.goLivePlot return this,
/// so callers (my_listings_screen.dart, my_plots_screen.dart) can branch on
/// "insufficient balance" specifically — to open the shared
/// InsufficientBalanceSheet — instead of just toasting a generic error.
sealed class GoLiveResult {}

class GoLiveSuccess extends GoLiveResult {
  final DateTime? validUntil;
  final String? planType;
  final int balance;
  GoLiveSuccess({required this.validUntil, required this.planType, required this.balance});
}

/// [requiredCoins] is the price of the plan the caller attempted to activate
/// — known client-side from the selected plan (0 is never passed here, since
/// this outcome only occurs on the paid branch), not parsed out of the
/// server's message string. Paired with the caller's live wallet balance to
/// drive InsufficientBalanceSheet.
class GoLiveInsufficientBalance extends GoLiveResult {
  final String message;
  final int requiredCoins;
  GoLiveInsufficientBalance({required this.message, required this.requiredCoins});
}

class GoLiveConcurrentUpdate extends GoLiveResult {
  final String message;
  GoLiveConcurrentUpdate(this.message);
}

class GoLiveFailure extends GoLiveResult {
  final String message;
  GoLiveFailure(this.message);
}
