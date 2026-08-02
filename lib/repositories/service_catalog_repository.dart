import '../models/inclusion_model.dart';
import '../models/service_category_model.dart';
import '../models/service_detail_model.dart';
import '../models/service_list_item_model.dart';
import '../models/service_package_model.dart';
import '../services/api_service.dart';
import '../utils/ttl_cache.dart';

// No active-only filtering server-side on /services (dual-mounted for admin) — callers must
// filter isActive themselves.
class ServiceCatalogRepository {
  List<ServiceCategoryModel>? _categoriesCache;
  DateTime? _categoriesCacheTime;

  List<ServiceListItemModel>? _servicesCache;
  DateTime? _servicesCacheTime;

  final Map<String, List<ServiceListItemModel>> _servicesByCategoryCache = {};
  final Map<String, DateTime> _servicesByCategoryCacheTime = {};

  List<InclusionModel>? _inclusionsCache;
  DateTime? _inclusionsCacheTime;

  static const _ttl = Duration(minutes: 5);

  bool _isValid(DateTime? time) => isCacheValid(time, _ttl);

  bool get isServicesCacheFresh => _servicesCache != null && _isValid(_servicesCacheTime);

  Future<List<ServiceCategoryModel>> getCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _categoriesCache != null && _isValid(_categoriesCacheTime)) {
      return _categoriesCache!;
    }
    final res = await ApiService.get('/services/categories');
    final list = (res['data'] as List? ?? [])
        .map((e) => ServiceCategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _categoriesCache = list;
    _categoriesCacheTime = DateTime.now();
    return list;
  }

  Future<List<ServiceListItemModel>> getServices({bool forceRefresh = false}) async {
    if (!forceRefresh && _servicesCache != null && _isValid(_servicesCacheTime)) {
      return _servicesCache!;
    }
    final res = await ApiService.get('/services');
    final list = (res['data'] as List? ?? [])
        .map((e) => ServiceListItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _servicesCache = list;
    _servicesCacheTime = DateTime.now();
    return list;
  }

  Future<List<ServiceListItemModel>> getServicesByCategory(String categoryId, {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _servicesByCategoryCache.containsKey(categoryId) &&
        _isValid(_servicesByCategoryCacheTime[categoryId])) {
      return _servicesByCategoryCache[categoryId]!;
    }
    final res = await ApiService.get('/services', params: {'serviceCategoryId': categoryId});
    final list = (res['data'] as List? ?? [])
        .map((e) => ServiceListItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _servicesByCategoryCache[categoryId] = list;
    _servicesByCategoryCacheTime[categoryId] = DateTime.now();
    return list;
  }

  Future<List<InclusionModel>> getInclusions({bool forceRefresh = false}) async {
    if (!forceRefresh && _inclusionsCache != null && _isValid(_inclusionsCacheTime)) {
      return _inclusionsCache!;
    }
    final res = await ApiService.get('/services/inclusions');
    final list = (res['data'] as List? ?? [])
        .map((e) => InclusionModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _inclusionsCache = list;
    _inclusionsCacheTime = DateTime.now();
    return list;
  }

  Future<ServiceDetailModel?> getServiceById(String id) async {
    final res = await ApiService.get('/services/$id');
    final data = res['data'];
    if (data is! Map<String, dynamic>) return null;
    return ServiceDetailModel.fromJson(data);
  }

  Future<List<ServicePackageModel>> getPackages(String serviceId) async {
    final res = await ApiService.get('/services/packages', params: {'serviceId': serviceId});
    return (res['data'] as List? ?? [])
        .map((e) => ServicePackageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ServicePackageModel?> getPackageById(String id) async {
    final res = await ApiService.get('/services/packages/$id');
    final data = res['data'];
    if (data is! Map<String, dynamic>) return null;
    return ServicePackageModel.fromJson(data);
  }

  /// Call after any admin-driven catalog change becomes relevant to this
  /// session (currently no consumer-side mutation triggers this — reserved
  /// for parity with ListingRepository/WalletRepository's invalidation
  /// convention and for pull-to-refresh call sites).
  void invalidateAll() {
    _categoriesCache = null;
    _categoriesCacheTime = null;
    _servicesCache = null;
    _servicesCacheTime = null;
    _servicesByCategoryCache.clear();
    _servicesByCategoryCacheTime.clear();
    _inclusionsCache = null;
    _inclusionsCacheTime = null;
  }
}
