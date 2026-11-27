import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../owner_core/look/owner_look.dart';
import '../../../owner_core/strings/owner_shared_strings.dart';
import '../../strings/stay_quote_setup_strings.dart';
import '../../strings/stay_quote_terms_strings.dart';
import '../../widgets/stay_widgets.dart';
import '../controllers/quote_hub_controller.dart';

// Mock Q0: shown once before the first quotation; Continue only after the tick; never dismissed by a tap outside.
class QuoteTermsSheet extends StatefulWidget {
  const QuoteTermsSheet({super.key, this.hub, this.acceptedAt});

  final QuoteHubController? hub;
  final DateTime? acceptedAt;

  bool get readOnly => hub == null;

  static Future<bool> ask(BuildContext context, QuoteHubController hub) async {
    final ok = await SheetFrame.show<bool>(context, isDismissible: false, builder: (_) => QuoteTermsSheet(hub: hub));
    return ok == true;
  }

  static Future<void> reRead(BuildContext context, DateTime? acceptedAt) =>
      SheetFrame.show<void>(context, builder: (_) => QuoteTermsSheet(acceptedAt: acceptedAt));

  static String dateText(DateTime d) {
    final l = d.toLocal();
    return '${OwnerSharedStrings.dayMonth(l)} ${l.year}';
  }

  @override
  State<QuoteTermsSheet> createState() => _QuoteTermsSheetState();
}

class _QuoteTermsSheetState extends State<QuoteTermsSheet> {
  bool _ticked = false;

  ListingTone get _tone => OwnerLook.stay.tone;

  Future<void> _continue() async {
    final hub = widget.hub;
    if (hub == null || !_ticked) return;
    final ok = await hub.acceptTerms();
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Widget _lines() => Container(
        padding: DS.insets(l: 14, t: 4, r: 14, b: 12),
        decoration: BoxDecoration(color: StayLook.lockedRow, borderRadius: DS.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in QuoteTermsStrings.lines)
              Padding(
                padding: DS.insets(t: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: DS.insets(t: 6),
                      child: Container(width: DS.s(6), height: DS.s(6), decoration: BoxDecoration(color: _tone.g2, shape: BoxShape.circle)),
                    ),
                    Gap.h(10),
                    Expanded(child: Text(line, style: FieldMessage.helperStyle.copyWith(color: Ink3D.body, height: 1.45))),
                  ],
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hub = widget.hub;
    if (hub == null) {
      final at = widget.acceptedAt;
      return SheetFrame(
        tone: _tone,
        art: ListingArt.shield,
        title: QuoteTermsStrings.reReadTitle,
        subtitle: at == null ? null : QuoteSetupStrings.agreedOn(QuoteTermsSheet.dateText(at)),
        footer: SecondaryButton(label: QuoteTermsStrings.close, neutral: true, onPressed: () => Navigator.of(context).pop()),
        child: Padding(padding: DS.insets(t: 12, b: 8), child: _lines()),
      );
    }
    return SheetFrame(
        tone: _tone,
        art: ListingArt.shield,
        title: QuoteTermsStrings.title,
        subtitle: QuoteTermsStrings.subtitle,
        showClose: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Gap.v(12),
            _lines(),
            Gap.v(6),
            CheckRow(tone: _tone, value: _ticked, onChanged: (v) => setState(() => _ticked = v), label: QuoteTermsStrings.agree),
            Gap.v(6),
            Obx(() => GradientPillButton(
                  tone: _tone,
                  label: QuoteTermsStrings.continueLabel,
                  loading: hub.accepting.value,
                  enabled: _ticked && !hub.accepting.value,
                  onTap: _ticked ? _continue : null,
                )),
            Gap.v(10),
            Text(QuoteTermsStrings.readAgain, textAlign: TextAlign.center, style: FieldMessage.helperStyle),
            Gap.v(8),
          ],
        ),
    );
  }
}
