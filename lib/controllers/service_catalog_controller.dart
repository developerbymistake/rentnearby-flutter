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
  final categoryPreviews = <String, List<ServiceListItemModel>>{}.obs;
  final servicesLoading = false.obs;
  bool _servicesLoadedOnce = false;
  Future<void>? _servicesLoadFuture;
  int _servicesGeneration = 0;

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

  // Caches the in-flight Future rather than a bare boolean re-check — Services tab and the
  // category grid screen can both call this around the same time, and a bare boolean would let
  // both fire a duplicate GET before either completes.
  Future<void> ensureServicesLoaded({bool forceRefresh = false}) {
    if (_servicesLoadedOnce && !forceRefresh) return Future.value();
    return _servicesLoadFuture ??= _loadServices(forceRefresh).whenComplete(() => _servicesLoadFuture = null);
  }

  Future<void> _loadServices(bool forceRefresh) async {
    final generation = ++_servicesGeneration;
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
      unawaited(Future.wait(activeCategories.map((c) => _loadCategoryPreview(c, generation))));
    }
  }

  Future<void> refreshAll() => Future.wait([
        loadCategories(forceRefresh: true),
        ensureServicesLoaded(forceRefresh: true),
      ]);

  Future<void> _loadCategoryPreview(ServiceCategoryModel category, int generation) async {
    try {
      final result = await _repo.getServicesPreview(category.id);
      if (generation != _servicesGeneration) return;
      categoryPreviews[category.id] = result;
    } catch (_) {
      if (generation != _servicesGeneration) return;
      categoryPreviews[category.id] = const [];
    }
  }

  List<ServiceCategoryModel> get activeCategories {
    final list = categories.where((c) => c.isActive).toList();
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

  Future<ServiceDetailModel?> loadServiceDetail(String serviceId) => _repo.getServiceById(serviceId);

  Future<List<ServicePackageModel>> loadPackages(String serviceId) => _repo.getPackages(serviceId);

  Future<List<InclusionModel>> loadInclusions({bool forceRefresh = false}) =>
      _repo.getInclusions(forceRefresh: forceRefresh);
}
