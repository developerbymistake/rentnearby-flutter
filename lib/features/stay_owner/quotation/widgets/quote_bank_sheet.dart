import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../../owner_core/look/owner_look.dart';
import '../../../owner_core/sheets/owner_sheet.dart';
import '../../../owner_core/sheets/sheet_disposables.dart';
import '../../strings/stay_quote_setup_strings.dart';
import '../controllers/quote_profile_controller.dart';
import '../data/quote_models.dart';

sealed class QuoteBankEdit {
  const QuoteBankEdit();
}

class QuoteBankSet extends QuoteBankEdit {
  const QuoteBankSet(this.bank);
  final QuoteBank bank;
}

class QuoteBankRemove extends QuoteBankEdit {
  const QuoteBankRemove();
}

// The bank account editor of Business details (ARCHITECTURE 10.5 G15); the page Save sends it.
abstract final class QuoteBankSheet {
  static Future<QuoteBankEdit?> show(BuildContext context, QuoteBank current) {
    final holder = TextEditingController(text: current.holder);
    final account = TextEditingController(text: current.accountNo);
    final ifsc = TextEditingController(text: current.ifsc);
    final bank = TextEditingController(text: current.bank);
    final branch = TextEditingController(text: current.branch);
    final error = ValueNotifier<String?>(null);
    final tone = OwnerLook.stay.tone;
    final text = [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(QuoteProfileRules.bankTextMax)];

    QuoteBank read() => QuoteBank(
          holder: QuoteProfileRules.clean(holder.text),
          accountNo: account.text.trim(),
          ifsc: ifsc.text.trim().toUpperCase(),
          bank: QuoteProfileRules.clean(bank.text),
          branch: QuoteProfileRules.clean(branch.text),
        );

    return OwnerSheet.show<QuoteBankEdit>(
      context,
      look: OwnerLook.stay,
      title: QuoteSetupStrings.bankSheetTitle,
      child: (c) => SheetDisposables(
        notifiers: [holder, account, ifsc, bank, branch, error],
        child: ValueListenableBuilder<String?>(
          valueListenable: error,
          builder: (_, e, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillField(tone: tone, label: QuoteSetupStrings.holder, controller: holder, inputFormatters: text, textCapitalization: TextCapitalization.words),
              PillField(
                tone: tone,
                label: QuoteSetupStrings.accountNo,
                controller: account,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)],
                firstLabel: false,
              ),
              PillField(
                tone: tone,
                label: QuoteSetupStrings.ifsc,
                controller: ifsc,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')), LengthLimitingTextInputFormatter(11)],
                firstLabel: false,
              ),
              PillField(tone: tone, label: QuoteSetupStrings.bankName, controller: bank, inputFormatters: text, textCapitalization: TextCapitalization.words, firstLabel: false),
              PillField(
                tone: tone,
                label: QuoteSetupStrings.branch,
                hint: QuoteSetupStrings.optional,
                controller: branch,
                inputFormatters: text,
                textCapitalization: TextCapitalization.words,
                firstLabel: false,
              ),
              FieldMessage(error: e),
              Gap.v(6),
            ],
          ),
        ),
      ),
      footer: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientPillButton(
            tone: tone,
            label: QuoteSetupStrings.done,
            onTap: () {
              final b = read();
              final e = QuoteProfileRules.bankError(b) ?? (b.hasAccount ? null : QuoteSetupStrings.bankFieldsNeeded);
              if (e != null) {
                error.value = e;
                return;
              }
              Navigator.of(c).pop(QuoteBankSet(b));
            },
          ),
          if (current.hasAccount) ...[
            Gap.v(8),
            SecondaryButton(label: QuoteSetupStrings.remove, neutral: true, onPressed: () => Navigator.of(c).pop(const QuoteBankRemove())),
          ],
        ],
      ),
    );
  }
}
