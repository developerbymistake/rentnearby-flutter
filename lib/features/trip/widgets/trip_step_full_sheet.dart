import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_strings.dart';
import '../trip_strings_enquiry_simple.dart';
import 'trip_sheet_frame.dart';
import 'trip_withdraw_sheet.dart';

class TripStepFullSheet {
  static Future<bool> show(BuildContext context, TripStepFull full, {int? leg}) async {
    final ok = await TripSheetFrame.show<bool>(context, _StepFullBody(full: full));
    return ok == true;
  }

  static String ago(DateTime? t, [DateTime? now]) {
    if (t == null) return '';
    final d = (now ?? DateTime.now()).difference(t.toLocal());
    if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

class _StepFullBody extends StatefulWidget {
  const _StepFullBody({required this.full});

  final TripStepFull full;

  @override
  State<_StepFullBody> createState() => _StepFullBodyState();
}

class _StepFullBodyState extends State<_StepFullBody> {
  late final List<TripStepFullAsk> _asks = widget.full.totalLimit ? widget.full.quietAsks : widget.full.waitingAsks;
  late final Set<String> _ticked = {if (widget.full.totalLimit) for (final a in _asks) a.enquiryId};
  bool _busy = false;

  Future<void> _withdraw() async {
    if (_busy || _ticked.isEmpty) return;
    setState(() => _busy = true);
    var all = true;
    for (final id in List.of(_ticked)) {
      if (await TripEnquiryController.to.withdraw(id)) {
        _ticked.remove(id);
      } else {
        all = false;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (all) Navigator.pop(context, true);
  }

  String _label(TripStepFullAsk a) {
    final name = (a.listingName ?? '').trim().isEmpty ? TripStrings.stay : a.listingName!.trim();
    final when = TripStepFullSheet.ago(a.askedAt);
    final state = widget.full.totalLimit ? TripStringsEnq.quietPill : '';
    return [name, state, if (when.isNotEmpty) TripStringsEnq.askedAgo(when)].where((s) => s.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.full;
    final w = full.waitingAsks.length;
    final q = full.quietAsks.length;
    final tone = ListingTone.forest;
    return TripSheetFrame(
      tone: tone,
      art: ListingArt.clipboard,
      size: SheetSize.confirm,
      title: full.totalLimit ? TripStringsEnq.fullTotalTitle : TripStringsEnq.fullWaitingTitle,
      description: full.totalLimit ? TripStringsEnq.fullTotalSub(w + q, w, q) : TripStringsEnq.fullWaitingSub,
      endNote: full.totalLimit && w > 0 ? TripStringsEnq.fullTotalNote(w) : null,
      footer: TripTwoButtons(
        tone: tone,
        secondaryLabel: TripStringsEnq.keep,
        primaryLabel: TripStringsEnq.withdraw,
        busy: _busy,
        onSecondary: () => Navigator.pop(context, false),
        onPrimary: _ticked.isEmpty ? null : _withdraw,
      ),
      children: [
        for (final a in _asks)
          CheckRow(
            tone: tone,
            value: _ticked.contains(a.enquiryId),
            label: _label(a),
            onChanged: _busy
                ? null
                : (v) => setState(() => v ? _ticked.add(a.enquiryId) : _ticked.remove(a.enquiryId)),
          ),
        Gap.v(8),
      ],
    );
  }
}
