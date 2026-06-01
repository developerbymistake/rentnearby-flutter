import 'package:get/get.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/app_constants.dart';
import '../controllers/banner_controller.dart';
import 'storage_service.dart';

class BannerHubService extends GetxService {
  static BannerHubService get to => Get.find();

  HubConnection? _connection;
  String? _currentDistrictId;

  Future<void> connectForDistrict(String districtId) async {
    final bannerCtrl = Get.find<BannerController>();

    if (_currentDistrictId == districtId &&
        _connection?.state == HubConnectionState.Connected) {
      return;
    }

    await disconnect();

    if (StorageService.getToken() == null) return;

    _connection = HubConnectionBuilder()
        .withUrl(
          '${AppConstants.serverUrl}/hubs/banner?districtId=$districtId',
          options: HttpConnectionOptions(
            // Always reads fresh token — handles JWT refresh correctly
            accessTokenFactory: () async => StorageService.getToken() ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on('BannerActivated', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = args[0] as Map<String, dynamic>;
        bannerCtrl.applyFromPush(data);
      } catch (_) {}
    });

    _connection!.on('BannerDeactivated', (_) {
      bannerCtrl.activeBanner.value = null;
    });

    _connection!.onreconnected(({String? connectionId}) {
      bannerCtrl.checkBanner(districtId);
    });

    try {
      await _connection!.start();
      // Only mark connected district after successful start
      _currentDistrictId = districtId;
    } catch (_) {
      // Connection failed — fall back to REST, don't mark as connected
      _connection = null;
      await bannerCtrl.checkBanner(districtId);
    }
  }

  Future<void> disconnect() async {
    try {
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
    _currentDistrictId = null;
  }
}
