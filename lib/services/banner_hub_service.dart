import 'package:get/get.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/app_constants.dart';
import '../controllers/banner_controller.dart';
import '../models/banner_model.dart';
import 'storage_service.dart';

class BannerHubService extends GetxService {
  static BannerHubService get to => Get.find();

  HubConnection? _connection;
  String? _currentDistrictId;

  Future<void> connectForDistrict(String districtId) async {
    final bannerCtrl = Get.find<BannerController>();

    // Idempotent — skip if already connected to same district
    if (_currentDistrictId == districtId &&
        _connection?.state == HubConnectionState.Connected) {
      return;
    }

    await _disconnect();

    final token = StorageService.getToken();
    if (token == null) return;

    _currentDistrictId = districtId;

    final hubUrl =
        '${AppConstants.serverUrl}/hubs/banner?districtId=$districtId&access_token=$token';

    _connection = HubConnectionBuilder()
        .withUrl(hubUrl)
        .withAutomaticReconnect()
        .build();

    _connection!.on('BannerActivated', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = args[0] as Map<String, dynamic>;
        bannerCtrl.activeBanner.value = BannerModel.fromJson(data);
      } catch (_) {}
    });

    _connection!.on('BannerDeactivated', (_) {
      bannerCtrl.activeBanner.value = null;
    });

    _connection!.onreconnected(({String? connectionId}) {
      // Sync state after reconnect — may have missed a push while disconnected
      bannerCtrl.checkBanner(districtId);
    });

    try {
      await _connection!.start();
    } catch (_) {
      // Hub unreachable (offline / server down) — fall back to REST
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
