import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_taxi_owner.dart';
import '../../../utils/app_toast.dart';
import '../../taxi/setup/taxi_photo_pick.dart';
import '../../taxi/setup/taxi_setup_controller.dart';
import '../strings/taxi_photo_strings.dart';
import '../taxi_driver_deps.dart';
import '../widgets/taxi_widgets.dart';
import 'taxi_hub_controller.dart';

abstract final class TaxiDisplayPhotoAction {
  static final ImagePicker _picker = ImagePicker();

  static Future<void> change(BuildContext context) async {
    final setup = TaxiSetupController.ensure();
    if (setup.displayUploading.value) return;
    final file = await TaxiPhotoPick.pick(context, picker: _picker, onDenied: (type) => _denied(context, type));
    if (file == null || !context.mounted) return;
    final bad = await TaxiPhotoPick.reject(file);
    if (bad != null) {
      AppToast.error(bad);
      return;
    }
    while (context.mounted) {
      if (setup.displayUploading.value) return;
      final res = await setup.uploadDisplayPhoto(file.path);
      if (res != null) {
        AppToast.success(TaxiPhotoStrings.displayUpdated);
        TaxiHubController.maybe?.reload(force: true);
        TaxiDriverDeps.refreshHome().ignore();
        return;
      }
      if (!context.mounted) return;
      final retry = await TaxiConfirm.ask(
        context,
        title: TaxiPhotoStrings.uploadFailedTitle,
        body: TaxiPhotoStrings.displayUploadFailedBody,
        confirm: TaxiPhotoStrings.retry,
        cancel: TaxiPhotoStrings.skip,
      );
      if (!retry) return;
    }
  }

  static Future<void> _denied(BuildContext context, String type) async {
    if (!context.mounted) return;
    final ok = await showTaxiOwnerDialog(
      context,
      art: ListingArt.camera,
      title: '$type Permission Required',
      body: 'Please enable $type access in your device Settings to add photos.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Open Settings',
    );
    if (ok == true) openAppSettings();
  }
}
