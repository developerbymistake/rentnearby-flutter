import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../utils/app_toast.dart';
import '../../../../utils/input_formatters.dart';
import '../../../owner_core/look/owner_look.dart';
import '../../../owner_core/sheets/owner_sheet.dart';
import '../../../owner_core/sheets/sheet_disposables.dart';
import '../../strings/stay_quote_setup_strings.dart';
import '../controllers/quote_profile_controller.dart';

// Mock Q2 "Request a name change": goes to the admin through the existing pending-edit review.
abstract final class QuoteNameChangeSheet {
  static Future<bool> show(BuildContext context, QuoteProfileController ctrl, String currentName) async {
    final current = TextEditingController(text: currentName);
    final name = TextEditingController();
    final note = TextEditingController();
    final error = ValueNotifier<String?>(null);
    final tone = OwnerLook.stay.tone;
    final ok = await OwnerSheet.show<bool>(
      context,
      look: OwnerLook.stay,
      title: QuoteSetupStrings.nameSheetTitle,
      subtitle: QuoteSetupStrings.nameSheetSub,
      child: (c) => SheetDisposables(
        notifiers: [current, name, note, error],
        child: ValueListenableBuilder<String?>(
          valueListenable: error,
          builder: (_, e, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillField(tone: tone, label: QuoteSetupStrings.currentName, controller: current, readOnly: true, enabled: false),
              PillField(
                tone: tone,
                label: QuoteSetupStrings.newName,
                controller: name,
                autofocus: true,
                errorText: e,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(QuoteProfileRules.nameMax)],
                firstLabel: false,
              ),
              PillField(
                tone: tone,
                label: QuoteSetupStrings.reason,
                hint: QuoteSetupStrings.optional,
                controller: note,
                maxLines: 3,
                minLines: 2,
                inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(QuoteProfileRules.noteMax)],
                firstLabel: false,
              ),
              Gap.v(6),
            ],
          ),
        ),
      ),
      footer: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() => GradientPillButton(
                tone: tone,
                label: QuoteSetupStrings.sendRequest,
                loading: ctrl.sendingName.value,
                enabled: !ctrl.sendingName.value,
                onTap: () async {
                  final e = QuoteProfileController.nameError(currentName, name.text);
                  if (e != null) {
                    error.value = e;
                    return;
                  }
                  error.value = null;
                  final sent = await ctrl.requestName(name.text, note.text, tell: AppToast.info);
                  if (sent && c.mounted) Navigator.of(c).pop(true);
                },
              )),
          Gap.v(8),
          SecondaryButton(label: QuoteSetupStrings.notNow, neutral: true, onPressed: () => Navigator.of(c).pop(false)),
        ],
      ),
    );
    return ok == true;
  }
}
