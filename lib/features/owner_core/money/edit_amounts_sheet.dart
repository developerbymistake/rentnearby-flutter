import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../data/owner_result.dart';
import '../data/single_flight.dart';
import '../look/owner_look.dart';
import '../sheets/owner_sheet.dart';
import '../strings/owner_shared_strings.dart';
import '../../../utils/app_toast.dart';
import 'money_note_math.dart';
import 'money_notes_fields.dart';

class EditAmountsWords {
  const EditAmountsWords({required this.title, required this.finalHint, required this.save});

  final String title;
  final String finalHint;
  final String save;
}

abstract final class EditAmountsSheet {
  static Future<bool> show(
    BuildContext context, {
    required OwnerLook look,
    required EditAmountsWords words,
    required MoneyNote initial,
    required Future<OwnerResult<dynamic>> Function(MoneyNote note) save,
  }) async {
    final controller = MoneyNotesController(
      finalAmount: initial.finalAmount,
      receivedSoFar: initial.receivedSoFar,
      paidInFull: initial.paidInFull,
    );
    bool dirty() {
      final n = controller.note;
      return n.finalAmount != initial.finalAmount || n.receivedSoFar != initial.receivedSoFar || n.paidInFull != initial.paidInFull;
    }

    try {
      final saved = await OwnerSheet.show<bool>(
        context,
        look: look,
        title: words.title,
        dirty: dirty,
        child: (_) => MoneyNotesFields(controller: controller, look: look, finalHint: words.finalHint),
        footer: (c) => ListenableBuilder(
          listenable: controller,
          builder: (c, _) => SingleFlightButton(
            onPressed: controller.error != null
                ? null
                : () async {
                    final r = await save(controller.note);
                    if (!c.mounted) return;
                    switch (r) {
                      case OwnerOk():
                        Navigator.of(c).pop(true);
                      case OwnerOffline():
                        AppToast.error(OwnerSharedStrings.noConnection);
                      case OwnerRefused(:final message):
                        AppToast.error(message ?? OwnerSharedStrings.noConnection);
                      case OwnerFailed():
                        AppToast.error(OwnerSharedStrings.noConnection);
                    }
                  },
            builder: (c, onPressed, busy) => PrimaryButton(label: words.save, tone: look.kit, loading: busy, onPressed: onPressed),
          ),
        ),
      );
      return saved == true;
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    }
  }
}
