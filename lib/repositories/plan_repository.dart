import '../models/my_plan_model.dart';
import '../models/plan_model.dart';
import '../models/plan_purchase_result.dart';
import '../services/api_service.dart';
import '../utils/ttl_cache.dart';

class PlanRepository {
  PlanCatalogModel? _catalog;
  DateTime? _catalogTime;
  static const _catalogTtl = Duration(minutes: 5);

  MyPlanModel? _me;
  DateTime? _meTime;
  Future<MyPlanModel>? _meInFlight;
  int _meGen = 0;
  static const _meTtl = Duration(seconds: 30);

  Future<PlanCatalogModel> getCatalog({bool forceRefresh = false}) async {
    if (!forceRefresh && _catalog != null && isCacheValid(_catalogTime, _catalogTtl)) return _catalog!;
    final res = await ApiService.get('/plans/catalog');
    _catalog = PlanCatalogModel.fromJson(res['data'] as Map<String, dynamic>? ?? {});
    _catalogTime = DateTime.now();
    return _catalog!;
  }

  Future<MyPlanModel> getMe({bool forceRefresh = false}) {
    if (!forceRefresh && _me != null && isCacheValid(_meTime, _meTtl)) return Future.value(_me!);
    if (forceRefresh) {
      _meGen++;
      final fresh = _fetchMe();
      _meInFlight = fresh;
      return fresh.whenComplete(() {
        if (identical(_meInFlight, fresh)) _meInFlight = null;
      });
    }
    if (_meInFlight != null) return _meInFlight!;
    final flight = _fetchMe();
    _meInFlight = flight;
    return flight.whenComplete(() {
      if (identical(_meInFlight, flight)) _meInFlight = null;
    });
  }

  Future<MyPlanModel> _fetchMe() async {
    final gen = _meGen;
    final res = await ApiService.get('/plans/me');
    final me = MyPlanModel.fromJson(res['data'] as Map<String, dynamic>? ?? {});
    return gen == _meGen ? _storeMe(me) : me;
  }

  MyPlanModel _storeMe(MyPlanModel me) {
    _me = me;
    _meTime = DateTime.now();
    return me;
  }

  void invalidateMe() {
    _meGen++;
    _me = null;
    _meTime = null;
  }

  void clear() {
    invalidateMe();
    _catalog = null;
    _catalogTime = null;
  }

  Future<PlanQuote> quote(String planId, int cycleMonths, String? couponCode) async {
    final res = await ApiService.post('/plans/quote', {
      'planId': planId,
      'cycleMonths': cycleMonths,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
    });
    return PlanQuote.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<PlanOrder> createOrder(String planId, int cycleMonths, String? couponCode) async {
    final res = await ApiService.post('/plans/purchases', {
      'planId': planId,
      'cycleMonths': cycleMonths,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
    });
    return PlanOrder.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<PurchaseStatus> verify(
    String purchaseId, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final res = await ApiService.post('/plans/purchases/$purchaseId/verify', {
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    });
    return PurchaseStatus.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<PurchaseStatus> getStatus(String purchaseId) async {
    final res = await ApiService.get('/plans/purchases/$purchaseId');
    return PurchaseStatus.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<PurchaseStatus?> getOpen() async {
    final res = await ApiService.get('/plans/purchases/open');
    final data = res['data'];
    return data is Map<String, dynamic> ? PurchaseStatus.fromJson(data) : null;
  }

  Future<List<PurchaseHistoryItem>> getHistory({int limit = 20}) async {
    final res = await ApiService.get('/plans/purchases', params: {'limit': limit});
    return (res['data'] as List? ?? [])
        .map((e) => PurchaseHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MyPlanModel> startTrial(String planId) async {
    final res = await ApiService.post('/plans/trial', {'planId': planId});
    _meGen++;
    return _storeMe(MyPlanModel.fromJson(res['data'] as Map<String, dynamic>));
  }

  Future<void> swapLive({required bool isPlot, required String targetId, required String pauseListingId}) async {
    await ApiService.post('/${isPlot ? 'plots' : 'listings'}/$targetId/swap-live', {'pauseListingId': pauseListingId});
  }
}
