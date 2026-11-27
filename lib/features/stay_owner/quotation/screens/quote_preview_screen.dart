import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../controllers/plan_controller.dart';
import '../../../../design/design.dart';
import '../../../../utils/app_toast.dart';
import '../../../owner_core/look/owner_look.dart';
import '../../calendar/widgets/stay_calendar_widgets.dart';
import '../../strings/stay_quote_strings.dart';
import '../../widgets/stay_widgets.dart';
import '../controllers/quote_download_controller.dart';
import '../controllers/quote_form_controller.dart';
import '../model/quote_money.dart';
import '../model/quote_source.dart';
import '../pdf/quote_engine.dart';
import '../pdf/quote_page_image.dart';
import '../pdf/quote_templates.dart';
import '../widgets/quote_calm_limit_sheet.dart';
import '../widgets/quote_line_card.dart';
import '../widgets/quote_usage_line.dart';

// Q6 / Q7: the A4 page as an image (offline, no PDF, no count), then Download PDF.
class QuotePreviewScreen extends StatefulWidget {
  const QuotePreviewScreen({super.key, required this.args, this.source, this.engine, this.offline});

  final Map<String, dynamic> args;
  final QuoteSource? source;
  final QuoteEngineApi? engine;
  final QuoteOfflineCheck? offline;

  static const int maxWidthPx = 1080;

  @override
  State<QuotePreviewScreen> createState() => _QuotePreviewScreenState();
}

class _QuotePreviewScreenState extends State<QuotePreviewScreen> {
  late final QuoteSource _source = widget.source ?? AppQuoteSource();
  late final QuoteEngineApi _engine = widget.engine ?? QuoteEngine.instance;
  QuoteFormController? _c;
  QuoteDownloadController? _dl;
  bool _owns = false;
  List<ui.Image> _pages = const [];
  List<TransformationController> _zoom = const [];
  final _zoomed = ValueNotifier<bool>(false);
  String? _error;
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
      _dl = QuoteDownloadController(form: c, source: _source, engine: _engine, offline: widget.offline);
    });
    if (!_source.offline) {
      try {
        await _source.ensureImages(c.business.value.assetsVersion);
      } catch (_) {}
      if (!mounted) return;
    }
    await _render(c);
  }

  int _widthPx() {
    final mq = MediaQuery.of(context);
    return math.min((mq.size.width * mq.devicePixelRatio).round(), QuotePreviewScreen.maxWidthPx);
  }

  Future<void> _render(QuoteFormController c) async {
    try {
      final p = await _engine.preview(QuoteTemplates.safe(c.draft.value.template), c.doc(), widthPx: _widthPx(), watermark: c.business.value.previewWatermark);
      final images = await QuotePageImage.decodeAll(p);
      if (_disposed) {
        QuotePageImage.disposeAll(images);
        return;
      }
      final old = _pages;
      setState(() {
        _pages = images;
        _error = null;
        if (_zoom.length != images.length) _resetZoom(images.length);
      });
      QuotePageImage.disposeAll(old);
    } on QuoteEngineException catch (e) {
      if (!_disposed) setState(() => _error = QuoteDownloadController.messageOf(e.failure));
    }
  }

  // One zoom per page; while a page is zoomed the list stops scrolling, so a drag pans the page instead of fighting the list.
  void _resetZoom(int n) {
    for (final z in _zoom) {
      z.dispose();
    }
    _zoomed.value = false;
    _zoom = [
      for (var i = 0; i < n; i++) TransformationController()..addListener(_onZoom),
    ];
  }

  void _onZoom() => _zoomed.value = _zoom.any((z) => z.value.getMaxScaleOnAxis() > 1.01);

  @override
  void dispose() {
    _disposed = true;
    for (final z in _zoom) {
      z.dispose();
    }
    _zoomed.dispose();
    QuotePageImage.disposeAll(_pages);
    if (_owns && identical(QuoteFormController.maybe, _c)) Get.delete<QuoteFormController>(tag: QuoteFormController.tag, force: true);
    super.dispose();
  }

  Future<void> _download() async {
    final dl = _dl;
    if (dl == null) return;
    final r = await dl.download();
    if (!mounted) return;
    switch (r) {
      case QuoteDownloadSaved saved:
        if (Get.isRegistered<PlanController>()) Get.find<PlanController>().invalidate().ignore();
        setState(() {});
        await QuoteSavedSheet.show(context, result: saved, template: QuoteTemplates.of(_c!.draft.value.template).name, total: _c!.totals.total, engine: _engine);
      case QuoteDownloadLimit limit:
        await QuoteLimitSheets.show(context, used: limit.used, limit: limit.limit, canUpgrade: limit.canUpgrade, resetsAt: limit.resetsAt);
        // The owner may have bought Plus from the sheet: the next tap must see the new limit.
        await _source.refreshUsage();
        if (mounted) setState(() {});
      case QuoteDownloadMessage(:final message):
        AppToast.info(message);
      case QuoteDownloadInvalid():
        AppToast.info(StayQuoteStrings.fixForm);
    }
  }

  String _footLine(QuoteFormController c) {
    final res = c.draft.value.reservation;
    if (res != null && res.freeAt(DateTime.now())) return StayQuoteStrings.freeUntil(res.freeUntil.toLocal());
    return StayQuoteStrings.downloadsLine(QuoteUsageSource.view(hub: _source.usage).line1);
  }

  Widget _page() {
    if (_error != null) return StayErrorCard(art: ListingArt.warning, title: _error!);
    if (_pages.isEmpty) return Padding(padding: DS.all(18), child: const SkeletonFormCard());
    return ValueListenableBuilder<bool>(
      valueListenable: _zoomed,
      builder: (context, zoomed, child) => ListView(
        physics: zoomed ? const NeverScrollableScrollPhysics() : null,
        padding: DS.insets(l: 10, t: 12, r: 10, b: 12),
        children: [
          for (var i = 0; i < _pages.length; i++)
            Container(
              margin: DS.insets(b: 10),
              decoration: BoxDecoration(boxShadow: DS.shadows(Ink3D.softShadow)),
              child: AspectRatio(
                aspectRatio: _pages[i].width / _pages[i].height,
                child: InteractiveViewer(
                  transformationController: i < _zoom.length ? _zoom[i] : null,
                  maxScale: 2,
                  minScale: 1,
                  panEnabled: zoomed,
                  child: RawImage(image: _pages[i], fit: BoxFit.fill),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(QuoteFormController c) {
    final canDownload = QuoteTemplates.canDownload(c.business.value.minTemplateVersion);
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(22))),
        boxShadow: DS.shadows(Ink3D.topEdge),
      ),
      padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(10), DS.s(14), MediaQuery.viewPaddingOf(context).bottom + DS.s(12)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(StayQuoteStrings.previewOnly, textAlign: TextAlign.center, style: QuoteText.small.copyWith(color: Ink3D.sub)),
        Gap.v(8),
        Row(children: [
          Expanded(child: StayPill(label: StayQuoteStrings.edit, kind: StayPillKind.outline, expand: true, onTap: () => Get.until((r) => r.settings.name == AppRoutes.stayQuotationEdit || r.isFirst))),
          Gap.h(10),
          Expanded(
            flex: 2,
            child: Obx(() => PrimaryButton(
                  label: StayQuoteStrings.downloadPdf,
                  tone: StayCalKit.green,
                  compact: true,
                  loading: _dl?.busy.value ?? false,
                  onPressed: canDownload && !(_dl?.busy.value ?? false) && _pages.isNotEmpty ? _download : null,
                )),
          ),
        ]),
        Gap.v(4),
        Text(canDownload ? _footLine(c) : StayQuoteStrings.updateToDownload, textAlign: TextAlign.end, style: QuoteText.small),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: OwnerLook.stay.page,
      body: Column(children: [
        StayCalHeader(
          title: StayQuoteStrings.preview,
          subtitle: c == null ? null : '${c.numberHint} · ${QuoteTemplates.of(c.draft.value.template).name}',
          trailing: StayWhitePill(label: StayQuoteStrings.change, color: StayLook.indigoText, onTap: () => Get.back<void>()),
        ),
        Expanded(child: _page()),
        if (c != null) _bar(c),
      ]),
    );
  }
}

class QuoteSavedSheet extends StatelessWidget {
  const QuoteSavedSheet({super.key, required this.result, required this.template, required this.total, required this.engine});

  final QuoteDownloadSaved result;
  final String template;
  final int total;
  final QuoteEngineApi engine;

  static Future<void> show(BuildContext context, {required QuoteDownloadSaved result, required String template, required int total, required QuoteEngineApi engine}) =>
      SheetFrame.show<void>(context, builder: (_) => QuoteSavedSheet(result: result, template: template, total: total, engine: engine));

  Widget _kv(String k, String v) => StayKv(label: k, value: v);

  @override
  Widget build(BuildContext context) {
    final f = result.file;
    final r = result.reservation;
    final u = result.usage;
    return SheetFrame(
      tone: ListingTone.forest,
      art: ListingArt.memo,
      title: StayQuoteStrings.savedTitle,
      subtitle: StayQuoteStrings.savedSub(f.displayName, f.pages),
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        PrimaryButton(
          label: StayQuoteStrings.openFile,
          tone: StayCalKit.green,
          onPressed: () async {
            final o = await engine.open(f.uri).catchError((_) => QuoteOpenResult.missing);
            if (o == QuoteOpenResult.noApp) AppToast.info(StayQuoteStrings.noPdfApp);
            if (o == QuoteOpenResult.missing) AppToast.info(StayQuoteStrings.fileGone);
          },
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(StayQuoteStrings.done, style: QuoteText.head.copyWith(color: Ink3D.grey))),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Gap.v(8),
        _kv(StayQuoteStrings.total, QuoteMoney.inr(total)),
        _kv(StayQuoteStrings.template, template),
        _kv(StayQuoteStrings.downloadsThisMonth, QuoteUsageSource.view(hub: u).line1),
        if (r.freeAt(DateTime.now()))
          Padding(
            padding: DS.insets(t: 10),
            child: Text(StayQuoteStrings.freeReDownload(r.freeUntil.toLocal()), textAlign: TextAlign.center, style: QuoteText.label.copyWith(color: StayLook.greenText)),
          ),
        Gap.v(8),
      ]),
    );
  }
}
