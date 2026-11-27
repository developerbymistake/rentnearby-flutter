import '../pdf/quote_engine.dart';
import 'quote_asset_store.dart';
import 'quote_models.dart';

// Removes every quotation trace of one user from the phone (ARCHITECTURE 9.5). PDFs in Downloads are the owner's files and stay.
abstract final class QuoteLocalWipe {
  static QuoteEngineApi Function() engine = _default;
  static QuoteBoxes boxes = const QuoteGetStorageBoxes();
  static QuoteKeyValue secure = const QuoteSecureStore();

  static QuoteEngineApi _default() => QuoteEngine.instance;

  static void debugReset() {
    engine = _default;
    boxes = const QuoteGetStorageBoxes();
    secure = const QuoteSecureStore();
  }

  static Future<void> run(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    try {
      await engine().clearUser(userId);
    } catch (_) {}
    for (final box in [QuoteStorageNames.indexBox(userId), QuoteStorageNames.cacheBox(userId)]) {
      try {
        await boxes.erase(box);
      } catch (_) {}
    }
    try {
      await secure.delete(QuoteStorageNames.bankKey(userId));
    } catch (_) {}
  }
}
