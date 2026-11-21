import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/design.dart';
import '../../../design/extra/pill_field.dart';
import '../../../design/extra/toggle_row.dart';
import '../../../utils/money_format.dart';
import '../look/owner_look.dart';
import '../strings/owner_shared_strings.dart';
import 'money_note_math.dart';

class MoneyNotesController extends ChangeNotifier {
  MoneyNotesController({int? finalAmount, int? receivedSoFar, bool paidInFull = false})
      : finalText = TextEditingController(text: finalAmount?.toString() ?? ''),
        receivedText = TextEditingController(text: receivedSoFar?.toString() ?? '') {
    _paidInFull = paidInFull;
    finalText.addListener(_changed);
    receivedText.addListener(_changed);
  }

  final TextEditingController finalText;
  final TextEditingController receivedText;
  bool _paidInFull = false;
  bool _disposed = false;

  bool get paidInFull => _paidInFull;

  set paidInFull(bool v) {
    if (_paidInFull == v) return;
    _paidInFull = v;
    _changed();
  }

  static int? _read(String text) {
    final t = text.trim();
    return t.isEmpty ? null : int.tryParse(t);
  }

  int? get finalAmount => _read(finalText.text);
  int? get receivedSoFar => _read(receivedText.text);

  MoneyNote get note => MoneyNote(finalAmount: finalAmount, receivedSoFar: receivedSoFar, paidInFull: _paidInFull);

  MoneyNoteError? get error => MoneyNoteMath.validate(note);

  bool get dirtyFromEmpty => finalText.text.isNotEmpty || receivedText.text.isNotEmpty || _paidInFull;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  static String messageOf(MoneyNoteError e) => switch (e) {
        MoneyNoteError.amountRange => OwnerSharedStrings.moneyRange,
        MoneyNoteError.finalNeeded => OwnerSharedStrings.finalNeeded,
        MoneyNoteError.receivedAboveFinal => OwnerSharedStrings.receivedAboveFinal,
      };

  @override
  void dispose() {
    _disposed = true;
    finalText.dispose();
    receivedText.dispose();
    super.dispose();
  }
}

abstract final class MoneyInput {
  static final List<TextInputFormatter> formatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(7),
  ];
}

class MoneyNotesFields extends StatelessWidget {
  const MoneyNotesFields({super.key, required this.controller, required this.look, required this.finalHint});

  final MoneyNotesController controller;
  final OwnerLook look;
  final String finalHint;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final note = controller.note;
        final balance = MoneyNoteMath.balance(note);
        final error = controller.error;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(OwnerSharedStrings.moneyNotes, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0))),
                Text(OwnerSharedStrings.onlyYouSee, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
              ],
            ),
            Gap.v(10),
            PillField(
              tone: look.tone,
              controller: controller.finalText,
              label: OwnerSharedStrings.finalAmount,
              helperText: finalHint,
              prefixText: '${Money.symbol} ',
              keyboardType: TextInputType.number,
              inputFormatters: MoneyInput.formatters,
              errorText: error == MoneyNoteError.amountRange && (note.finalAmount ?? 1) < MoneyNoteMath.finalMin
                  ? MoneyNotesController.messageOf(error!)
                  : null,
            ),
            Gap.v(10),
            PillField(
              tone: look.tone,
              controller: controller.receivedText,
              label: OwnerSharedStrings.receivedSoFar,
              prefixText: '${Money.symbol} ',
              keyboardType: TextInputType.number,
              enabled: !controller.paidInFull,
              inputFormatters: MoneyInput.formatters,
              errorText: error == MoneyNoteError.receivedAboveFinal ? MoneyNotesController.messageOf(error!) : null,
            ),
            if (balance != null) ...[
              Gap.v(10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(OwnerSharedStrings.balanceToCollect, style: Ink3D.text(13, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                        Text(OwnerSharedStrings.balanceHint, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                      ],
                    ),
                  ),
                  Text(Money.exact(balance), style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                ],
              ),
            ],
            Gap.v(6),
            ToggleRow(
              tone: look.tone,
              label: OwnerSharedStrings.paidInFull,
              sublabel: OwnerSharedStrings.paidInFullHint,
              value: controller.paidInFull,
              onChanged: (v) => controller.paidInFull = v,
            ),
            if (error == MoneyNoteError.finalNeeded || (error == MoneyNoteError.amountRange && (note.finalAmount ?? 1) >= MoneyNoteMath.finalMin))
              Padding(
                padding: EdgeInsets.only(top: DS.gv(4)),
                child: Text(MoneyNotesController.messageOf(error!), style: Ink3D.text(12, FontWeight.w500, DesignColors.error, letterSpacing: 0)),
              ),
          ],
        );
      },
    );
  }
}

class BalanceChip extends StatelessWidget {
  const BalanceChip({super.key, required this.chip, required this.amount, this.cancelled = false});

  final MoneyChip chip;
  final int amount;
  final bool cancelled;

  static String? textOf(MoneyChip chip, int amount) => switch (chip) {
        MoneyChip.toCollect => OwnerSharedStrings.toCollect(Money.exact(amount)),
        MoneyChip.paidInFull => OwnerSharedStrings.paidInFull,
        MoneyChip.received => OwnerSharedStrings.received(Money.exact(amount)),
        MoneyChip.none => null,
      };

  @override
  Widget build(BuildContext context) {
    final money = textOf(chip, amount);
    final text = cancelled
        ? (chip == MoneyChip.received && money != null ? '${OwnerSharedStrings.cancelled} · $money' : OwnerSharedStrings.cancelled)
        : money;
    if (text == null) return const SizedBox.shrink();
    final (bg, fg) = cancelled
        ? (OwnerLook.greySoft, Ink3D.grey)
        : switch (chip) {
            MoneyChip.toCollect => (OwnerLook.amberSoft, OwnerLook.amber),
            MoneyChip.paidInFull => (ListingTone.forest.tint, ListingTone.forest.text),
            _ => (OwnerLook.greySoft, Ink3D.grey),
          };
    return Container(
      padding: DS.sym(h: 8, v: 3),
      decoration: BoxDecoration(color: bg, borderRadius: DS.circular(10)),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w700, fg, letterSpacing: 0)),
    );
  }
}
