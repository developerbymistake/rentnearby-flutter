import 'package:get/get.dart';

import '../data/quote_doc_store.dart';
import '../pdf/quote_engine.dart';

enum QuoteOpenOutcome { opened, missing, noApp }

class QuoteListController extends GetxController {
  QuoteListController({required this.store, QuoteEngineApi? engine}) : engine = engine ?? QuoteEngine.instance;

  final QuoteDocStore store;
  final QuoteEngineApi engine;
  final rows = <QuoteIndexRow>[].obs;
  final loaded = false.obs;

  List<QuoteIndexRow> get downloaded => rows.where((r) => r.downloaded).toList();
  List<QuoteIndexRow> get drafts => rows.where((r) => !r.downloaded).toList();

  Future<void> load() async {
    try {
      await store.prune();
    } catch (_) {}
    rows.assignAll(store.rows());
    loaded.value = true;
  }

  Future<QuoteOpenOutcome> openFile(QuoteIndexRow row) async {
    final uri = row.fileUri;
    if (uri == null) return QuoteOpenOutcome.missing;
    try {
      return switch (await engine.open(uri)) {
        QuoteOpenResult.opened => QuoteOpenOutcome.opened,
        QuoteOpenResult.missing => QuoteOpenOutcome.missing,
        QuoteOpenResult.noApp => QuoteOpenOutcome.noApp,
      };
    } on QuoteEngineException {
      return QuoteOpenOutcome.missing;
    }
  }
}
