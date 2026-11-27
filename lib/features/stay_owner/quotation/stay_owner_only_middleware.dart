import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../controllers/auth_controller.dart';
import '../../../utils/app_toast.dart';
import '../strings/stay_quote_setup_strings.dart';

abstract final class StayOwnerGate {
  static bool get allowed => !Get.isRegistered<AuthController>() || Get.find<AuthController>().canListStays.value;
}

// Defence in depth only; the server refuses every quotation call to a non stay owner (403 RoleMismatch).
class StayOwnerOnlyMiddleware extends GetMiddleware {
  @override
  GetPageBuilder? onPageBuildStart(GetPageBuilder? page) => StayOwnerGate.allowed ? page : () => const _LeavePage();
}

class _LeavePage extends StatefulWidget {
  const _LeavePage();

  @override
  State<_LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<_LeavePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppToast.info(QuoteSetupStrings.ownerOnly);
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
