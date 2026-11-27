import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../design/design.dart';
import '../../../../utils/app_toast.dart';
import '../../../owner_core/look/owner_look.dart';
import '../../calendar/widgets/stay_calendar_widgets.dart';
import '../../strings/stay_quote_doc_strings.dart';
import '../../strings/stay_quote_strings.dart';
import '../../widgets/stay_widgets.dart';
import '../controllers/quote_form_controller.dart';
import '../controllers/quote_list_controller.dart';
import '../data/quote_doc_store.dart';
import '../data/quote_models.dart';
import '../model/quote_money.dart';
import '../model/quote_source.dart';
import '../pdf/quote_templates.dart';
import '../widgets/quote_enquiry_pick_sheet.dart';
import '../widgets/quote_line_card.dart';
import '../widgets/quote_usage_line.dart';

// Q3: this month's count, documents on this phone (drafts first), New quotation / From an enquiry.
class QuoteListScreen extends StatefulWidget {
  const QuoteListScreen({super.key, required this.args, this.source});

  final Map<String, dynamic> args;
  final QuoteSource? source;

  @override
  State<QuoteListScreen> createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends State<QuoteListScreen> {
  late final QuoteSource _source = widget.source ?? AppQuoteSource();
  QuoteListController? _c;
  final _ready = false.obs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final ok = await _source.ensureReady(context, appTemplateVersion: QuoteTemplates.version);
    if (!mounted) return;
    if (!ok) {
      Get.back<void>();
      return;
    }
    final uid = _source.userId;
    if (uid == null) return;
    final store = await QuoteFormController.openStore(uid);
    if (!mounted) return;
    final c = QuoteListController(store: store);
    setState(() => _c = c);
    await c.load();
    _ready.value = true;
  }

  Future<void> _openForm(Map<String, dynamic> args) async {
    await Get.toNamed<dynamic>(AppRoutes.stayQuotationEdit, arguments: args);
    if (mounted) await _c?.load();
  }

  Future<void> _fromEnquiry() async {
    final p = await QuoteEnquiryPickSheet.pick(context);
    if (p != null) await _openForm({'prefill': p.toArgs()});
  }

  Future<void> _open(QuoteIndexRow row) async {
    final c = _c;
    if (c == null) return;
    switch (await c.openFile(row)) {
      case QuoteOpenOutcome.opened:
        return;
      case QuoteOpenOutcome.noApp:
        AppToast.info(StayQuoteStrings.noPdfApp);
      case QuoteOpenOutcome.missing:
        AppToast.info(StayQuoteStrings.fileGone);
        await _openForm({'documentId': row.id});
    }
  }

  String _sub(QuoteIndexRow r) {
    final kind = r.kind == QuoteKind.proforma.name ? StayQuoteStrings.kindProforma : StayQuoteStrings.kindQuotation;
    final a = r.checkIn;
    final b = r.checkOut;
    return StayQuoteStrings.rowSub(kind, a != null && b != null ? StayQuoteStrings.range(a, b) : null, r.total > 0 ? QuoteMoney.inr(r.total) : null);
  }

  String _when(QuoteIndexRow r) {
    final at = (r.savedAt ?? r.updatedAt).toLocal();
    final now = DateTime.now();
    return at.year == now.year && at.month == now.month && at.day == now.day ? StayQuoteStrings.today : StayQuoteStrings.dayMonth(at);
  }

  StayRowData _row(QuoteIndexRow r) {
    final name = r.guest.isEmpty ? StayQuoteDocStrings.guest : r.guest;
    final title = r.downloaded && r.number != null ? '${r.number} · $name' : '${StayQuoteStrings.draft} · $name';
    return StayRowData(
      art: ListingArt.memo,
      tint: StayLook.greenSoft,
      title: title,
      sub: _sub(r),
      semantics: title,
      onTap: () => _openForm({'documentId': r.id}),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_when(r), style: QuoteText.small),
          if (r.downloaded) StayPill(label: StayQuoteStrings.open, kind: StayPillKind.outline, onTap: () => _open(r)),
        ],
      ),
    );
  }

  Widget _body() {
    final c = _c;
    return Obx(() {
      _ready.value;
      final usage = _source.usage;
      final rows = c?.rows.toList() ?? const <QuoteIndexRow>[];
      final downloaded = rows.where((r) => r.downloaded).toList();
      final drafts = rows.where((r) => !r.downloaded).toList();
      return ListView(
        padding: DS.insets(b: 24),
        children: [
          if (_source.offline) StaySmallLine(text: StayQuoteStrings.offline, art: ListingArt.antenna),
          QuoteUsageHero(view: QuoteUsageSource.view(hub: usage)),
          if (c != null && c.loaded.value && rows.isEmpty)
            StayErrorCard(art: ListingArt.memo, title: StayQuoteStrings.emptyTitle, message: StayQuoteStrings.emptyBody),
          if (drafts.isNotEmpty) ...[
            const StaySectionTitle(title: StayQuoteStrings.notDownloaded),
            StayRowsCard(rows: [for (final r in drafts) _row(r)]),
          ],
          if (downloaded.isNotEmpty) ...[
            const StaySectionTitle(title: StayQuoteStrings.downloadedHere),
            StaySmallLine(text: StayQuoteStrings.nothingOnline),
            StayRowsCard(rows: [for (final r in downloaded) _row(r)]),
          ],
        ],
      );
    });
  }

  Widget _bar() => Container(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(22))),
          boxShadow: DS.shadows(Ink3D.topEdge),
        ),
        padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(10), DS.s(14), MediaQuery.viewPaddingOf(context).bottom + DS.s(12)),
        child: Row(children: [
          Expanded(child: StayPill(label: StayQuoteStrings.fromAnEnquiry, kind: StayPillKind.outline, expand: true, onTap: _c == null ? null : _fromEnquiry)),
          Gap.h(10),
          Expanded(
            child: PrimaryButton(
              label: StayQuoteStrings.newQuotation,
              tone: StayCalKit.green,
              compact: true,
              onPressed: _c == null ? null : () => _openForm(const {'new': true}),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OwnerLook.stay.page,
      body: Column(children: [
        Obx(() {
          _ready.value;
          final name = _source.businessName;
          return StayCalHeader(
            title: StayQuoteStrings.title,
            subtitle: name,
            trailing: StayWhitePill(label: StayQuoteStrings.businessDetails, color: StayLook.indigoText, onTap: () => Get.toNamed(AppRoutes.stayQuotationBusiness)),
          );
        }),
        Expanded(child: _body()),
        _bar(),
      ]),
    );
  }
}
