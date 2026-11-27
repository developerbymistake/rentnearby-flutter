import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../owner_core/data/owner_result.dart';
import '../../../owner_core/data/single_flight.dart';
import '../../strings/stay_quote_strings.dart';
import '../data/quote_models.dart';
import '../model/quote_doc.dart';
import '../model/quote_draft.dart';
import '../model/quote_file_name.dart';
import '../model/quote_source.dart';
import '../pdf/quote_engine.dart';
import '../pdf/quote_templates.dart';
import 'quote_form_controller.dart';

sealed class QuoteDownloadResult {
  const QuoteDownloadResult();
}

class QuoteDownloadSaved extends QuoteDownloadResult {
  const QuoteDownloadSaved({required this.file, required this.reservation, required this.usage});
  final QuoteFile file;
  final QuoteReservation reservation;
  final QuoteUsage usage;
}

class QuoteDownloadInvalid extends QuoteDownloadResult {
  const QuoteDownloadInvalid();
}

class QuoteDownloadMessage extends QuoteDownloadResult {
  const QuoteDownloadMessage(this.message);
  final String message;
}

// Local pre-check or server refusal: the screen opens the limit sheet.
class QuoteDownloadLimit extends QuoteDownloadResult {
  const QuoteDownloadLimit({required this.used, required this.limit, required this.canUpgrade, this.resetsAt});
  final int used;
  final int limit;
  final bool canUpgrade;
  final DateTime? resetsAt;
}

typedef QuoteOfflineCheck = Future<bool> Function();

// Download order of ARCHITECTURE 8.7: validate, online, layout, local pre-check, reserve, save the reservation, images, render.
class QuoteDownloadController extends GetxController {
  QuoteDownloadController({
    required this.form,
    required this.source,
    QuoteEngineApi? engine,
    QuoteOfflineCheck? offline,
    Future<bool> Function()? askStorage,
    DateTime Function()? now,
  })  : engine = engine ?? QuoteEngine.instance,
        _offline = offline ?? connectivityOffline,
        _askStorage = askStorage ?? storagePermission,
        _now = now ?? DateTime.now;

  final QuoteFormController form;
  final QuoteSource source;
  final QuoteEngineApi engine;
  final QuoteOfflineCheck _offline;
  final Future<bool> Function() _askStorage;
  final DateTime Function() _now;
  final _flight = SingleFlight<QuoteDownloadResult>();
  final busy = false.obs;

  static Future<bool> connectivityOffline() async {
    try {
      final results = await Connectivity().checkConnectivity().timeout(const Duration(seconds: 2), onTimeout: () => const [ConnectivityResult.wifi]);
      return results.isNotEmpty && results.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  // Android 7-9 only: the channel answers StorageDenied until WRITE_EXTERNAL_STORAGE is granted once.
  static Future<bool> storagePermission() async {
    try {
      final s = await Permission.storage.request();
      if (s.isPermanentlyDenied) await openAppSettings();
      return s.isGranted;
    } catch (_) {
      return false;
    }
  }

  static String messageOf(QuoteEngineFailure f) => switch (f) {
        QuoteEngineFailure.tooLong => StayQuoteStrings.tooLong,
        QuoteEngineFailure.unsupported => StayQuoteStrings.unsupported,
        QuoteEngineFailure.storageDenied => StayQuoteStrings.storageDenied,
        QuoteEngineFailure.noSpace => StayQuoteStrings.noSpace,
        QuoteEngineFailure.busy => StayQuoteStrings.busy,
        QuoteEngineFailure.renderFailed => StayQuoteStrings.renderFailed,
      };

  Future<QuoteDownloadResult> download() => _flight.run(() async {
        busy.value = true;
        try {
          return await _download();
        } finally {
          busy.value = false;
        }
      });

  Future<QuoteDownloadResult> _download() async {
    if (!form.validate()) return const QuoteDownloadInvalid();
    final b = form.business.value;
    if (!QuoteTemplates.canDownload(b.minTemplateVersion)) return const QuoteDownloadMessage(StayQuoteStrings.updateToDownload);
    if (await _offline()) return const QuoteDownloadMessage(StayQuoteStrings.offlineDownload);
    final template = QuoteTemplates.safe(form.draft.value.template);
    final kind = form.draft.value.kind;
    try {
      final check = await engine.layout(template, form.doc());
      if (!check.ok) return QuoteDownloadMessage(check.tooLong ? StayQuoteStrings.tooLong : StayQuoteStrings.renderFailed);
    } on QuoteEngineException catch (e) {
      return QuoteDownloadMessage(messageOf(e.failure));
    }

    final saved = form.draft.value.reservationFor(kind);
    final inWindow = saved != null && saved.freeAt(_now());
    final usage = source.usage;
    // The cached hub may predate a plan change (Plus bought, Plus lapsed): only a hub that agrees with /plans/me may refuse locally.
    if (!inWindow && usage != null && usage.full && usage.limit == source.planLimit) {
      return QuoteDownloadLimit(used: usage.used, limit: usage.limit, canUpgrade: usage.canUpgrade, resetsAt: usage.resetsAt);
    }

    final outcome = await source.reserve(form.draft.value.documentId, kind);
    final QuoteReserveResult r;
    switch (outcome) {
      case QuoteReserved(:final result):
        r = result;
      case QuoteReserveRefused(:final refusal):
        return _refused(refusal);
      case QuoteReserveOffline():
        return const QuoteDownloadMessage(StayQuoteStrings.offlineDownload);
      case QuoteReserveFailed():
        return const QuoteDownloadMessage(StayQuoteStrings.reserveFailed);
    }

    final now = _now();
    final previous = form.draft.value.reservationFor(kind);
    var reservation = QuoteReservation(
      number: r.number,
      display: r.display,
      issuedAt: r.issuedAt ?? now,
      freeUntil: r.freeUntil ?? now,
      freeLeft: r.freeLeft,
      businessName: r.businessName,
      fileUri: previous?.fileUri,
      fileName: previous?.fileName,
      pages: previous?.pages,
      savedAt: previous?.savedAt,
    );
    form.applyReservation(kind, reservation);
    await form.saveNow();

    // Always: the files are wiped at logout and missing on a reinstall or a second phone; files already there are skipped.
    try {
      await source.ensureImages(r.assetsVersion);
    } catch (_) {}
    await form.refreshBusiness(source);
    final logo = r.assetsVersion > 0 && await source.hasImage(QuoteImageKind.logo, r.assetsVersion);
    final signature = r.assetsVersion > 0 && await source.hasImage(QuoteImageKind.signature, r.assetsVersion);

    final fileName = QuoteFileName.of(r.display, form.draft.value.guestName);
    final doc = form.doc(number: r.display, businessName: r.businessName, logo: logo, signature: signature, assetsVersion: r.assetsVersion);
    QuoteFile file;
    try {
      file = await _render(template, doc, fileName);
    } on QuoteEngineException catch (e) {
      return QuoteDownloadMessage(messageOf(e.failure));
    }
    final old = previous?.fileUri;
    if (old != null && old != file.uri) await engine.delete(old);
    reservation = reservation.withFile(uri: file.uri, name: file.displayName, pages: file.pages, at: _now());
    form.applyReservation(kind, reservation);
    await form.saveNow();
    return QuoteDownloadSaved(file: file, reservation: reservation, usage: r.usage);
  }

  // A killed renderer fails once with RenderFailed; one automatic retry builds a new WebView.
  Future<QuoteFile> _render(String template, QuoteDoc doc, String fileName) async {
    try {
      return await engine.render(template, doc, fileName: fileName);
    } on QuoteEngineException catch (e) {
      if (e.failure == QuoteEngineFailure.storageDenied) {
        if (!await _askStorage()) rethrow;
        return engine.render(template, doc, fileName: fileName);
      }
      if (e.failure != QuoteEngineFailure.renderFailed) rethrow;
      return engine.render(template, doc, fileName: fileName);
    }
  }

  QuoteDownloadResult _refused(OwnerRefused<dynamic> r) {
    final info = QuoteLimitInfo.of(r);
    if (info != null) return QuoteDownloadLimit(used: info.used, limit: info.limit, canUpgrade: info.canUpgrade, resetsAt: info.resetsAt);
    if (r.type == QuoteErrorTypes.stayNotApproved) return const QuoteDownloadMessage(StayQuoteStrings.notApproved);
    if (r.type == QuoteErrorTypes.termsNotAccepted) return const QuoteDownloadMessage(StayQuoteStrings.termsNeeded);
    final m = r.message;
    return QuoteDownloadMessage(m != null && m.isNotEmpty ? m : StayQuoteStrings.reserveFailed);
  }
}
