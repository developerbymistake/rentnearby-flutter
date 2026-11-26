import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../utils/app_toast.dart';
import '../widgets/traveller_only_screen.dart';

abstract final class TravellerGateStrings {
  static const String title = 'These features are for travellers.';
  static const String message = 'Use a seeker account.';
  static const String line = '$title $message';
  static const String goBack = 'Go back';
}

abstract final class TravellerGate {
  static bool get allowed => !Get.isRegistered<AuthController>() || Get.find<AuthController>().canUseTravellerFeatures;

  static void tell() => AppToast.info(TravellerGateStrings.line);
}

class TravellerOnlyMiddleware extends GetMiddleware {
  @override
  GetPageBuilder? onPageBuildStart(GetPageBuilder? page) => TravellerGate.allowed ? page : () => const TravellerOnlyScreen();
}
