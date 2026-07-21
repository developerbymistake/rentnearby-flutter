import '../models/inclusion_model.dart';
import '../models/service_category_model.dart';
import '../models/service_detail_model.dart';
import '../models/service_list_item_model.dart';
import '../models/service_package_model.dart';
import '../services/api_service.dart';
import '../utils/ttl_cache.dart';

/// Thin TTL-caching wrapper around the read-only Service Catalog endpoints
/// (mounted at `/services/...` — the same handlers the admin CRUD group
/// hits, no active-only filtering server-side, mirrors GetDistricts/
/// GetCities being dual-mounted). Mirrors ListingRepository's/
/// WalletRepository's style: simple in-memory caches keyed only by time.
///
/// The whole catalog is small (3 categories, 15 services, ~26 packages for
/// the seeded data) and admin-managed, so categories/services/inclusions are
/// fetched unfiltered and cached for 5 minutes — callers
/// (ServiceCatalogController) do the parent-scoping client-side rather than
/// issuing a fresh request per category. Package detail reads (by service, or
/// by id — needed once a specific package's Inclusions are shown) are never
/// cached: they're only read once per screen visit and admin package edits
/// (price/discount) should be visible immediately.
class ServiceCatalogRepository {
  List<ServiceCategoryModel>? _categoriesCache;
  DateTime? _categoriesCacheTime;

  List<ServiceListItemModel>? _servicesCache;
  DateTime? _servicesCacheTime;

  List<InclusionModel>? _inclusionsCache;
  DateTime? _inclusionsCacheTime;

  static const _ttl = Duration(minutes: 5);

  bool _isValid(DateTime? time) => isCacheValid(time, _ttl);

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

  /// Rail preview for one Category — pre-sorted (featured first, then
  /// SortOrder) and capped server-side (see GetServicesPreview/
  /// GetPreviewByServiceCategoryIdAsync on the backend). Deliberately
  /// uncached and parameterized (mirrors getPackages' style, not the
  /// whole-catalog-then-filter style above) since it's inherently a
  /// server-computed slice, not something worth replicating client-side.
  Future<List<ServiceListItemModel>> getServicesPreview(String categoryId, {int limit = 6}) async {
    final res = await ApiService.get('/services/preview', params: {
      'serviceCategoryId': categoryId,
      'limit': '$limit',
    });
    return (res['data'] as List? ?? [])
        .map((e) => ServiceListItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
    _inclusionsCache = null;
    _inclusionsCacheTime = null;
  }
}
