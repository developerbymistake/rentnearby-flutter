import '../models/coin_pack_model.dart';
import '../models/coin_transaction_model.dart';
import '../services/api_service.dart';
import '../utils/ttl_cache.dart';

/// Thin TTL-caching wrapper around the wallet/coin-pack read endpoints —
/// mirrors ListingRepository's style. Balance gets a short TTL since it
/// changes on every spend/credit; the coin-pack catalog is admin-managed and
/// barely changes, so it gets a long TTL; transactions are a paginated list
/// and are never cached — always fetched fresh.
class WalletRepository {
  int? _balanceCache;
  DateTime? _balanceCacheTime;

  List<CoinPackModel>? _packsCache;
  DateTime? _packsCacheTime;

  static const _shortTtl = Duration(seconds: 30);
  static const _longTtl = Duration(minutes: 5);

  /// [forceRefresh] skips the cache check entirely — for explicit user-initiated refresh actions
  /// (pull-to-refresh, hub reconnect resync) where serving a stale cached value would be wrong even
  /// if it's still within TTL.
  Future<int> getBalance({bool forceRefresh = false}) async {
    if (!forceRefresh && _balanceCache != null && isCacheValid(_balanceCacheTime, _shortTtl)) {
      return _balanceCache!;
    }
    final res = await ApiService.get('/wallet/balance');
    final balance = (res['data']?['balance'] as num?)?.toInt() ?? 0;
    _balanceCache = balance;
    _balanceCacheTime = DateTime.now();
    return balance;
  }

  /// Call after every spend/credit (purchase verified, code redeemed, a
  /// Go-Live spend elsewhere) so the next getBalance() hits the network
  /// instead of serving a stale cached value.
  void invalidateBalance() {
    _balanceCache = null;
    _balanceCacheTime = null;
  }

  /// Deterministically sets the cache to an already-known-correct value — from a mutation response
  /// or a WalletHub push — instead of invalidating and forcing a redundant network round-trip.
  /// Race-free: the caller already has the authoritative post-mutation balance in hand.
  void primeBalance(int value) {
    _balanceCache = value;
    _balanceCacheTime = DateTime.now();
  }

  Future<List<CoinPackModel>> getCoinPacks() async {
    if (_packsCache != null && isCacheValid(_packsCacheTime, _longTtl)) {
      return _packsCache!;
    }
    final res = await ApiService.get('/coin-packs/');
    final list = (res['data'] as List? ?? [])
        .map((e) => CoinPackModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _packsCache = list;
    _packsCacheTime = DateTime.now();
    return list;
  }

  Future<({List<CoinTransactionModel> items, bool hasMore})> getTransactions({
    int page = 1,
    int pageSize = 20,
    String? reason,
  }) async {
    final params = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (reason != null && reason.isNotEmpty) params['reason'] = reason;
    final res = await ApiService.get('/wallet/transactions', params: params);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    final items = (data['items'] as List? ?? [])
        .map((e) => CoinTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, hasMore: data['hasMore'] == true);
  }
}
