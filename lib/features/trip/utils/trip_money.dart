// Mirror of the server MoneySplit: every split sums exactly to its total.
class TripMoney {
  static const int maxUnits = 50;
  static const int maxPrice = 9900000;

  // Largest remainder (Hamilton): floors, then the leftover units go to the largest fractions, ties to the lower index.
  static List<int> apportion(int total, List<int> weights) {
    final n = weights.length;
    final shares = List<int>.filled(n, 0);
    if (n == 0 || total <= 0) return shares;
    final w = [for (final x in weights) x < 0 ? 0 : x];
    var sum = w.fold<int>(0, (s, x) => s + x);
    if (sum == 0) {
      for (var i = 0; i < n; i++) {
        w[i] = 1;
      }
      sum = n;
    }
    final rest = <(int, int)>[];
    var given = 0;
    for (var i = 0; i < n; i++) {
      final exact = BigInt.from(total) * BigInt.from(w[i]);
      final s = BigInt.from(sum);
      shares[i] = (exact ~/ s).toInt();
      rest.add(((exact % s).toInt(), i));
      given += shares[i];
    }
    rest.sort((a, b) {
      final c = b.$1.compareTo(a.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    var left = total - given;
    for (final r in rest) {
      if (left <= 0) break;
      shares[r.$2]++;
      left--;
    }
    return shares;
  }

  static List<int> even(int total, int parts) => parts <= 0 ? const [] : apportion(total, List<int>.filled(parts, 1));

  static int shareOf(int total, int parts, int index) {
    if (parts <= 0 || index < 0 || index >= parts) return 0;
    return even(total, parts)[index];
  }

  // The kept part of an evenly split total: the sum of the kept positions' shares.
  static int keptOf(int total, int parts, Iterable<int> keptIndexes) {
    final shares = even(total, parts);
    var sum = 0;
    for (final i in keptIndexes.toSet()) {
      if (i >= 0 && i < shares.length) sum += shares[i];
    }
    return sum;
  }

  // amount x part / whole, rounded half up.
  static int proRata(int amount, int part, int whole) {
    if (whole <= 0 || amount <= 0 || part <= 0) return 0;
    return ((BigInt.from(amount) * BigInt.from(part) * BigInt.two + BigInt.from(whole)) ~/ (BigInt.from(whole) * BigInt.two))
        .toInt();
  }

  // Whole-rupee unit prices q_i >= 1 with sum(units_i x q_i) == target, closest to the ratio of `prices`
  // (min sum units_i x |q_i - exact_i|, ties: fewer moves). Same DP as the server. Null when none exists.
  static List<int>? unitPrices(int target, List<int> units, List<int> prices) {
    final k = units.length;
    if (k == 0 || k != prices.length || target <= 0) return null;
    if (units.any((u) => u <= 0) || prices.any((p) => p <= 0 || p > maxPrice)) return null;
    final unitSum = units.fold<int>(0, (s, u) => s + u);
    if (unitSum > maxUnits || target > maxPrice * unitSum) return null;
    var offered = 0;
    for (var i = 0; i < k; i++) {
      offered += units[i] * prices[i];
    }
    final floors = List<int>.filled(k, 0);
    var placed = 0;
    for (var i = 0; i < k; i++) {
      floors[i] = (BigInt.from(prices[i]) * BigInt.from(target) ~/ BigInt.from(offered)).toInt();
      placed += units[i] * floors[i];
    }
    final deficit = target - placed;
    final bound = unitSum;
    final span = bound * unitSum;
    if (deficit < -span || deficit > span) return null;
    final width = 2 * span + 1;
    const inf = -1;
    final cost = List.generate(k + 1, (_) => List<int>.filled(width, inf));
    final moves = List.generate(k + 1, (_) => List<int>.filled(width, 0));
    final pick = List.generate(k + 1, (_) => List<int>.filled(width, 0));
    cost[0][span] = 0;
    for (var j = 0; j < k; j++) {
      final u = units[j];
      final exactNum = prices[j] * target;
      for (var s = 0; s < width; s++) {
        final base = cost[j][s];
        if (base == inf) continue;
        for (var c = -bound; c <= bound; c++) {
          final q = floors[j] + c;
          if (q < 1) continue;
          final ns = s + c * u;
          if (ns < 0 || ns >= width) continue;
          final nc = base + (q * offered - exactNum).abs() * u;
          final nm = moves[j][s] + c.abs();
          final cur = cost[j + 1][ns];
          if (cur == inf || nc < cur || (nc == cur && nm < moves[j + 1][ns])) {
            cost[j + 1][ns] = nc;
            moves[j + 1][ns] = nm;
            pick[j + 1][ns] = c;
          }
        }
      }
    }
    final end = span + deficit;
    if (cost[k][end] == inf) return null;
    final result = List<int>.filled(k, 0);
    var at = end;
    for (var j = k; j >= 1; j--) {
      final c = pick[j][at];
      result[j - 1] = floors[j - 1] + c;
      at -= c * units[j - 1];
    }
    return result;
  }

  // The counter's per-night amount for the guest's price X over the host's lines: exactly X x total units.
  static int counterPerNight(int price, List<int> units, List<int> linePrices) {
    final total = units.fold<int>(0, (s, u) => s + u);
    final q = unitPrices(price * total, units, linePrices);
    if (q == null) return price * total;
    var sum = 0;
    for (var i = 0; i < q.length; i++) {
      sum += units[i] * q[i];
    }
    return sum;
  }
}
