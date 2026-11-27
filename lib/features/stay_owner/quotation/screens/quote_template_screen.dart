import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../design/design.dart';
import '../../../owner_core/look/owner_look.dart';
import '../../calendar/widgets/stay_calendar_widgets.dart';
import '../../strings/stay_quote_strings.dart';
import '../../widgets/stay_widgets.dart';
import '../controllers/quote_form_controller.dart';
import '../model/quote_source.dart';
import '../pdf/quote_engine.dart';
import '../pdf/quote_page_image.dart';
import '../pdf/quote_templates.dart';
import '../widgets/quote_line_card.dart';

// Q5: Classic, Colour band, Modern. Bundled thumbnails first, then page 1 of this document in each template.
class QuoteTemplateScreen extends StatefulWidget {
  const QuoteTemplateScreen({super.key, required this.args, this.source, this.engine});

  final Map<String, dynamic> args;
  final QuoteSource? source;
  final QuoteEngineApi? engine;

  static const int thumbWidth = 360;

  @override
  State<QuoteTemplateScreen> createState() => _QuoteTemplateScreenState();
}

class _QuoteTemplateScreenState extends State<QuoteTemplateScreen> {
  late final QuoteSource _source = widget.source ?? AppQuoteSource();
  late final QuoteEngineApi _engine = widget.engine ?? QuoteEngine.instance;
  QuoteFormController? _c;
  bool _owns = false;
  final Map<String, ui.Image> _live = {};
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final had = QuoteFormController.maybe;
    final c = await QuoteFormController.open(widget.args, _source);
    if (!mounted) return;
    if (c == null) {
      Get.back<void>();
      return;
    }
    setState(() {
      _c = c;
      _owns = !identical(had, c);
    });
    _thumbs(c);
  }

  Future<void> _thumbs(QuoteFormController c) async {
    final doc = c.doc();
    for (final t in QuoteTemplates.all) {
      if (_disposed) return;
      try {
        final p = await _engine.preview(t.id, doc, widthPx: QuoteTemplateScreen.thumbWidth, watermark: false);
        if (p.pages.isEmpty || _disposed) continue;
        final img = await QuotePageImage.decode(p.pages.first);
        if (_disposed) {
          img.dispose();
          return;
        }
        setState(() {
          _live[t.id]?.dispose();
          _live[t.id] = img;
        });
      } on QuoteEngineException {
        return;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    QuotePageImage.disposeAll(_live.values);
    if (_owns && identical(QuoteFormController.maybe, _c)) Get.delete<QuoteFormController>(tag: QuoteFormController.tag, force: true);
    super.dispose();
  }

  Widget _thumb(QuoteTemplateInfo t) {
    final live = _live[t.id];
    final w = DS.s(92);
    return Container(
      width: w,
      height: w * 1123 / 794,
      decoration: BoxDecoration(color: DesignColors.surface, border: Border.all(color: StayLook.rowLine, width: DS.s(1)), borderRadius: DS.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: live != null ? RawImage(image: live, fit: BoxFit.cover) : Image.asset(t.thumb, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
    );
  }

  Widget _option(QuoteFormController c, QuoteTemplateInfo t, bool on) => Semantics(
        selected: on,
        button: true,
        label: t.name,
        child: GestureDetector(
          onTap: () => c.setTemplate(t.id),
          child: Container(
            margin: DS.insets(l: 18, t: 12, r: 18),
            padding: DS.sym(h: 14, v: 10),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              borderRadius: DS.br(CardRadius.tile),
              border: Border.all(color: on ? ListingTone.forest.g2 : Colors.transparent, width: DS.s(2)),
              boxShadow: DS.shadows(Ink3D.softShadow),
            ),
            child: Row(children: [
              _thumb(t),
              Gap.h(14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.name, style: QuoteText.head),
                  Gap.v(2),
                  Text(t.sub, style: QuoteText.small),
                ]),
              ),
              Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: on ? ListingTone.forest.g2 : Ink3D.hint, size: DS.s(24)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: OwnerLook.stay.page,
      body: Column(children: [
        if (c == null) const StayCalHeader(title: StayQuoteStrings.chooseTemplate),
        if (c != null)
          Obx(() {
            final d = c.draft.value;
            return StayCalHeader(title: StayQuoteStrings.chooseTemplate, subtitle: d.guestName.isEmpty ? c.numberHint : '${c.numberHint} · ${d.guestName}');
          }),
        Expanded(
          child: c == null
              ? const SizedBox.shrink()
              : Obx(() {
                  final sel = QuoteTemplates.safe(c.draft.value.template);
                  return ListView(padding: DS.insets(b: 24), children: [for (final t in QuoteTemplates.all) _option(c, t, t.id == sel)]);
                }),
        ),
        StayCalBar(
          primary: StayQuoteStrings.preview,
          onPrimary: c == null
              ? null
              : () async {
                  await c.saveNow();
                  await Get.toNamed<dynamic>(AppRoutes.stayQuotationPreview, arguments: {'documentId': c.draft.value.documentId});
                },
        ),
      ]),
    );
  }
}
