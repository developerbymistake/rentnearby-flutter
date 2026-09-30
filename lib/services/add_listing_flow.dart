import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/listing_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/plot_controller.dart';
import '../utils/app_toast.dart';
import '../widgets/listing_limit_reached_sheet.dart';
import 'listing_permission_service.dart';
import 'plot_permission_service.dart';

class AddListingFlow {
  AddListingFlow._();

  /// isRooms while a limit check is in flight, null otherwise.
  static final Rxn<bool> checking = Rxn<bool>();

  static Future<void> start(bool isRooms) async {
    if (checking.value != null) return;
    checking.value = isRooms;
    try {
      if (isRooms) {
        await _startRoom();
      } else {
        await _startPlot();
      }
    } catch (_) {
      AppToast.error('Could not verify your listing limit. Please try again.');
    } finally {
      checking.value = null;
    }
  }

  static Future<void> _startRoom() async {
    final listingCtrl = Get.find<ListingController>();
    if (!listingCtrl.hasLoadedMyListings) {
      final loaded = await listingCtrl.loadMyListings();
      if (!loaded) {
        AppToast.error('Could not verify your listing limit. Please try again.');
        return;
      }
    }
    final result = await ListingPermissionService(
      listingCtrl,
      Get.find<LocationController>(),
    ).check();
    switch (result) {
      case ListingAllowed():
        Get.toNamed(AppRoutes.addListing);
      case ListingNeedsDistrict():
        AppToast.error('Your area is not supported yet. Contact admin to expand coverage.');
      case ListingLimitReached():
        final context = Get.context;
        if (context == null) return;
        ListingLimitReachedSheet.show(
          context,
          cap: result.cap,
          unitSingular: 'room',
          unitPlural: 'rooms',
          accent: AppColors.primary,
          onManage: () => Get.toNamed(AppRoutes.myListings),
        );
    }
  }

  static Future<void> _startPlot() async {
    final plotCtrl = Get.find<PlotController>();
    if (!plotCtrl.hasLoadedMyPlots) {
      final loaded = await plotCtrl.loadMyPlots(reset: true);
      if (!loaded) {
        AppToast.error('Could not verify your listing limit. Please try again.');
        return;
      }
    }
    final result = await PlotPermissionService(
      plotCtrl,
      Get.find<LocationController>(),
    ).check();
    switch (result) {
      case PlotAllowed():
        Get.toNamed(AppRoutes.addPlot);
      case PlotNeedsDistrict():
        AppToast.error('Your area is not supported yet. Contact admin to expand coverage.');
      case PlotLimitReached():
        final context = Get.context;
        if (context == null) return;
        ListingLimitReachedSheet.show(
          context,
          cap: result.cap,
          unitSingular: 'plot',
          unitPlural: 'plots',
          accent: AppColors.plot,
          onManage: () => Get.toNamed(AppRoutes.myPlots),
        );
    }
  }
}
