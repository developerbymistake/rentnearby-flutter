import 'package:get/get.dart';
import '../models/inclusion_model.dart';
import '../models/service_category_model.dart';
import '../models/service_detail_model.dart';
import '../models/service_list_item_model.dart';
import '../models/service_package_model.dart';
import '../models/service_section_model.dart';
import '../repositories/service_catalog_repository.dart';

/// Holds the whole (small, admin-managed) catalog in memory — Sections,
/// Categories, Services — loaded once via [loadCatalog] and sliced
/// client-side by the derived getters below, rather than re-fetching per
/// screen. This is what makes the Home rails loop over "whatever Sections
/// the API returns" with zero per-section network round-trips, and is what
/// lets a brand-new admin-added Section/Category/Service show up with zero
/// app code — the traversal below is generic over ids, never a hardcoded
/// Section/Category name or index.
class ServiceCatalogController extends GetxController {
  final sections = <ServiceSectionModel>[].obs;
  final categories = <ServiceCategoryModel>[].obs;
  final services = <ServiceListItemModel>[].obs;
  // Home-rail preview per Section — backend-computed (sorted + capped via
  // GET /services/preview), keyed by ServiceSectionModel.id. Kept separate
  // from `services` (the full catalog, still used by servicesForCategory
  // for the category drill-down screen) since this is server logic, not a
  // client-side slice of the full list.
  final sectionPreviews = <String, List<ServiceListItemModel>>{}.obs;
  final catalogLoading = false.obs;
  bool _loadedOnce = false;

  ServiceCatalogRepository get _repo => Get.find<ServiceCatalogRepository>();

  @override
  void onInit() {
    super.onInit();
    loadCatalog();
  }

  Future<void> loadCatalog({bool forceRefresh = false}) async {
    if (_loadedOnce && !forceRefresh) return;
    catalogLoading.value = true;
    try {
      final results = await Future.wait([
        _repo.getSections(forceRefresh: forceRefresh),
        _repo.getCategories(forceRefresh: forceRefresh),
        _repo.getServices(forceRefresh: forceRefresh),
      ]);
      sections.value = results[0] as List<ServiceSectionModel>;
      categories.value = results[1] as List<ServiceCategoryModel>;
      services.value = results[2] as List<ServiceListItemModel>;
      _loadedOnce = true;
      await Future.wait(activeSections.map(_loadSectionPreview));
    } catch (_) {
      // Swallow — Home/list screens fall back to empty-state rendering
      // (an empty rail/list) rather than surfacing a toast on first load,
      // matching HomeController's rooms/plots summary loaders.
    } finally {
      catalogLoading.value = false;
    }
  }

  Future<void> _loadSectionPreview(ServiceSectionModel section) async {
    try {
      sectionPreviews[section.id] = await _repo.getServicesPreview(section.id);
    } catch (_) {
      sectionPreviews[section.id] = const [];
    }
  }

  // ── Derived getters ─────────────────────────────────────────────────────

  List<ServiceSectionModel> get activeSections {
    final list = sections.where((s) => s.isActive).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  List<ServiceCategoryModel> categoriesForSection(String sectionId) {
    final list = categories.where((c) => c.isActive && c.serviceSectionId == sectionId).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  List<ServiceListItemModel> servicesForCategory(String categoryId) {
    final list = services.where((s) => s.isActive && s.serviceCategoryId == categoryId).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  ServiceCategoryModel? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  ServiceSectionModel? sectionById(String id) {
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ── Single-item / detail loaders (never cached — proxy straight through) ─

  Future<ServiceDetailModel?> loadServiceDetail(String serviceId) => _repo.getServiceById(serviceId);

  Future<List<ServicePackageModel>> loadPackages(String serviceId) => _repo.getPackages(serviceId);

  Future<List<InclusionModel>> loadInclusions({bool forceRefresh = false}) =>
      _repo.getInclusions(forceRefresh: forceRefresh);
}
