import 'dart:async';
import 'package:get/get.dart';
import '../models/inclusion_model.dart';
import '../models/service_category_model.dart';
import '../models/service_detail_model.dart';
import '../models/service_list_item_model.dart';
import '../models/service_package_model.dart';
import '../repositories/service_catalog_repository.dart';

class ServiceCatalogController extends GetxController {
  final categories = <ServiceCategoryModel>[].obs;
  final categoriesLoading = false.obs;
  bool _categoriesLoadedOnce = false;

  final services = <ServiceListItemModel>[].obs;
  final servicesLoading = false.obs;
  bool _servicesLoadedOnce = false;
  Future<void>? _servicesLoadFuture;

  ServiceCatalogRepository get _repo => Get.find<ServiceCatalogRepository>();

  @override
  void onInit() {
    super.onInit();
    loadCategories();
  }

  Future<void> loadCategories({bool forceRefresh = false}) async {
    if (_categoriesLoadedOnce && !forceRefresh) return;
    categoriesLoading.value = true;
    try {
      categories.value = await _repo.getCategories(forceRefresh: forceRefresh);
      _categoriesLoadedOnce = true;
    } catch (_) {
    } finally {
      categoriesLoading.value = false;
    }
  }

  // Caches the in-flight Future rather than a bare boolean re-check — the Services tab's own
  // background prefetch and the rail-overview screen's load can both fire around the same time,
  // and a bare boolean would let both issue a duplicate GET before either completes.
  Future<void> ensureServicesLoaded({bool forceRefresh = false}) {
    if (_servicesLoadedOnce && !forceRefresh) return Future.value();
    return _servicesLoadFuture ??= _loadServices(forceRefresh).whenComplete(() => _servicesLoadFuture = null);
  }

  Future<void> _loadServices(bool forceRefresh) async {
    servicesLoading.value = true;
    try {
      services.value = await _repo.getServices(forceRefresh: forceRefresh);
      _servicesLoadedOnce = true;
    } catch (_) {
    } finally {
      servicesLoading.value = false;
    }
    if (_servicesLoadedOnce) {
      if (!_categoriesLoadedOnce) await loadCategories();
    }
  }

  Future<void> refreshAll() => Future.wait([
        loadCategories(forceRefresh: true),
        ensureServicesLoaded(forceRefresh: true),
      ]);

  List<ServiceCategoryModel> get activeCategories {
    final list = categories.where((c) => c.isActive).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  List<ServiceListItemModel> servicesForCategory(String categoryId) =>
      _sortedActive(services.where((s) => s.serviceCategoryId == categoryId));

  List<ServiceListItemModel> _sortedActive(Iterable<ServiceListItemModel> list) =>
      list.where((s) => s.isActive).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Future<List<ServiceListItemModel>> loadServicesForCategory(String categoryId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _repo.isServicesCacheFresh) {
      return servicesForCategory(categoryId);
    }
    final raw = await _repo.getServicesByCategory(categoryId, forceRefresh: forceRefresh);
    return _sortedActive(raw);
  }

  ServiceCategoryModel? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<ServiceDetailModel?> loadServiceDetail(String serviceId) => _repo.getServiceById(serviceId);

  Future<List<ServicePackageModel>> loadPackages(String serviceId) => _repo.getPackages(serviceId);

  Future<List<InclusionModel>> loadInclusions({bool forceRefresh = false}) =>
      _repo.getInclusions(forceRefresh: forceRefresh);
}
