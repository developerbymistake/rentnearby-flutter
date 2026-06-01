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

    await _disconnect();

    final token = StorageService.getToken();
    if (token == null) return;

    _currentDistrictId = districtId;

    _connection = HubConnectionBuilder()
        .withUrl(
          '${AppConstants.serverUrl}/hubs/banner?districtId=$districtId',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ),
        )
        .withAutomaticReconnect()
        .build();

    // Push payload used directly — no REST call.
    // Local dismissed set filters out previously dismissed banners,
    // so dismissed users never see the banner even on re-activation.
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
      // May have missed a push while disconnected — sync via REST once
      bannerCtrl.checkBanner(districtId);
    });

    try {
      await _connection!.start();
    } catch (_) {
      // Hub unreachable — fall back to REST for initial state
      await bannerCtrl.checkBanner(districtId);
    }
  }

  Future<void> _disconnect() async {
    try {
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
    _currentDistrictId = null;
  }
}
