import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:uuid/uuid.dart';
import '../../../config/module_palette.dart';
import '../../../models/browse_item.dart';
import '../../../widgets/nearby_item_row.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../data/trip_enquiry_repository.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_strings.dart';
import '../trip_strings_enquiry_simple.dart';
import '../trip_strings_rc.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_send_result_sheet.dart';
import '../widgets/trip_sheet_frame.dart';
import '../widgets/trip_step_full_sheet.dart';

class SimilarStay {
  final String id;
  final String name;
  final String? stayTypeName;
  final String? cityName;
  final double? distanceKm;
  final int? pricePerNight;
  final String? thumbnailUrl;
  final bool repliesFast;

  const SimilarStay({
    required this.id,
    required this.name,
    this.stayTypeName,
    this.cityName,
    this.distanceKm,
    this.pricePerNight,
    this.thumbnailUrl,
    this.repliesFast = false,
  });

  static int? _price(Object? v) => v is num && v > 0 ? v.toInt() : null;

  factory SimilarStay.fromJson(Map<String, dynamic> j) => SimilarStay(
        id: j['id'] as String? ?? '',
        name: (j['name'] as String?)?.trim().isNotEmpty ?? false ? (j['name'] as String).trim() : TripStrings.stay,
        stayTypeName: j['stayTypeName'] as String?,
        cityName: j['cityName'] as String?,
        distanceKm: (j['distanceKm'] as num?)?.toDouble(),
        pricePerNight: _price(j['datesPerNight']) ?? _price(j['quotePerNight']) ?? _price(j['minPricePerNight']),
        thumbnailUrl: j['thumbnailUrl'] as String?,
        repliesFast: j['repliesFast'] == true,
      );
}

class SimilarStays {
  final int free;
  final List<SimilarStay> items;

  const SimilarStays({this.free = 0, this.items = const []});

  factory SimilarStays.fromJson(Map<String, dynamic> j) => SimilarStays(
        free: (j['free'] as num?)?.toInt() ?? 0,
        items: [
          for (final m in ((j['items'] as List?) ?? const []).whereType<Map<String, dynamic>>())
            if ((m['id'] as String?)?.isNotEmpty ?? false) SimilarStay.fromJson(m),
        ],
      );

  Set<String> preTicked() => {for (final s in items.take(free < 0 ? 0 : free)) s.id};
}

class SimilarStaysCard extends StatelessWidget {
  const SimilarStaysCard({super.key, required this.reference, this.onFindAnother});

  final TripEnquiryModel reference;
  final VoidCallback? onFindAnother;

  @override
  Widget build(BuildContext context) {
    if (reference.tripId == null || reference.day == null) return const SizedBox.shrink();
    return GreyPillBox(
      margin: EdgeInsets.fromLTRB(DS.s(20), DS.gv(10), DS.s(20), 0),
      padding: DS.insets(l: 14, t: 14, r: 14, b: 14),
      child: SimilarStaysBody(key: ValueKey('similar-${reference.id}'), reference: reference, onFindAnother: onFindAnother),
    );
  }
}

class SimilarStaysSheet {
  static Future<void> show(BuildContext context, {required TripEnquiryModel reference, String? title}) async {
    if (reference.tripId == null || reference.day == null) return;
    await TripSheetFrame.show<void>(context, _SheetBody(reference: reference, title: title));
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.reference, this.title});

  final TripEnquiryModel reference;
  final String? title;

  @override
  Widget build(BuildContext context) => TripSheetFrame(
        tone: ListingTone.forest,
        art: ListingArt.roundPushpin,
        size: SheetSize.list,
        title: title ?? TripStringsEnq.similarTitle,
        description: TripStringsEnq.similarSub,
        children: [SimilarStaysBody(reference: reference, sheet: true)],
      );
}

class SimilarStaysBody extends StatefulWidget {
  const SimilarStaysBody({super.key, required this.reference, this.onFindAnother, this.sheet = false, this.repo});

  final TripEnquiryModel reference;
  final VoidCallback? onFindAnother;
  final bool sheet;
  final TripEnquiryRepository? repo;

  @override
  State<SimilarStaysBody> createState() => _SimilarStaysBodyState();
}

class _SimilarStaysBodyState extends State<SimilarStaysBody> {
  SimilarStays? _data;
  bool _failed = false;
  bool _loading = true;
  bool _sending = false;
  final _ticked = <String>{};

  TripEnquiryRepository get _repo => widget.repo ?? const TripEnquiryRepository();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _load() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final r = widget.reference;
      final data = await _repo.similar(tripId: r.tripId!, stepKey: r.stepKeyOrLeg, likeListingId: r.listingId.isEmpty ? null : r.listingId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _ticked
          ..clear()
          ..addAll(data.preTicked());
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _toggle(SimilarStay s) {
    final free = _data?.free ?? 0;
    setState(() {
      if (_ticked.contains(s.id)) {
        _ticked.remove(s.id);
      } else if (_ticked.length < free) {
        _ticked.add(s.id);
      }
    });
  }

  Future<void> _ask() async {
    final data = _data;
    final r = widget.reference;
    if (_sending || data == null || _ticked.isEmpty) return;
    final ids = [for (final s in data.items) if (_ticked.contains(s.id)) s.id];
    final names = {for (final s in data.items) s.id: s.name};
    setState(() => _sending = true);
    final ctrl = TripEnquiryController.to;
    final batch = await ctrl.sendEnquiryFor(
      r.tripId!,
      day: r.day!,
      stayIds: ids,
      names: names,
      nights: r.nights,
      stepKey: r.stepKeyOrLeg,
      clientRequestId: const Uuid().v4(),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    final full = ctrl.lastStepFull;
    final nav = Navigator.of(context);
    if (widget.sheet && (batch != null || full != null)) nav.pop();
    final host = widget.sheet ? nav.context : context;
    if (batch != null) {
      if (!widget.sheet) _load();
      if (host.mounted) await TripSendResultSheet.show(host, batch: batch, names: names, shortlist: true);
    } else if (full != null && host.mounted) {
      await TripStepFullSheet.show(host, full);
    }
  }

  String _subtitle(SimilarStay s) => [
        s.cityName,
        if (s.distanceKm != null && s.distanceKm! > 0) TripFormat.km(s.distanceKm!),
        if (s.repliesFast) TripStringsEnq.repliesInDay,
      ].whereType<String>().where((t) => t.trim().isNotEmpty).join(' · ');

  Widget _row(SimilarStay s, ListingTone tone) {
    final on = _ticked.contains(s.id);
    final price = s.pricePerNight;
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(8)),
      child: NearbyItemRow(
        key: ValueKey('similar-row-${s.id}'),
        thumbnailUrl: s.thumbnailUrl,
        tag: s.stayTypeName ?? '',
        title: s.name,
        subtitle: _subtitle(s),
        caption: '',
        value: price == null ? '' : BrowseItem.inr(price),
        unit: price == null ? '' : TripStringsRc.perNight,
        palette: ModulePalette.stays,
        placeholderIcon: Icons.hotel_rounded,
        elevated: true,
        onTap: () => _toggle(s),
        trailing: Icon(on ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: DS.s(22), color: tone.g2),
      ),
    );
  }

  Widget _empty(String text, ListingTone tone) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center, style: RepliesLook.foot),
          Gap.v(10),
          PillButtonRow(children: [
            if (widget.onFindAnother != null) WhitePillButton(tone: tone, label: TripStrings.findAnother, onTap: widget.onFindAnother),
            GradientPillButton(tone: tone, label: TripStringsEnq.tryAgain, onTap: _load),
          ]),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.forest;
    final data = _data;
    final head = widget.sheet
        ? <Widget>[]
        : <Widget>[
            Text(TripStringsEnq.similarTitle, style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
            Text(TripStringsEnq.similarSub, style: RepliesLook.foot),
          ];
    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [...head, Gap.v(12), Center(child: SizedBox(width: DS.s(22), height: DS.s(22), child: CircularProgressIndicator(strokeWidth: DS.s(2.4), color: tone.g2)))],
      );
    }
    if (_failed || data == null) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [...head, Gap.v(8), _empty(TripStrings.couldNotLoad, tone)]);
    }
    if (data.items.isEmpty) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [...head, Gap.v(8), _empty(TripStringsEnq.noMoreStays, tone)]);
    }
    final n = _ticked.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...head,
        if (widget.sheet) Text(TripStringsEnq.placesFree(data.free), textAlign: TextAlign.center, style: RepliesLook.foot),
        for (final s in data.items) _row(s, tone),
        Gap.v(12),
        Text(TripStringsEnq.phoneShared, textAlign: TextAlign.center, style: RepliesLook.foot),
        Gap.v(8),
        PillButtonRow(children: [
          if (widget.sheet)
            WhitePillButton(tone: tone, label: TripStringsEnq.notNow, onTap: () => Navigator.pop(context))
          else if (widget.onFindAnother != null)
            WhitePillButton(tone: tone, label: TripStrings.findAnother, onTap: widget.onFindAnother),
          GradientPillButton(tone: tone, label: TripStringsEnq.askThese(n), loading: _sending, enabled: n > 0, onTap: n > 0 ? _ask : null),
        ]),
      ],
    );
  }
}
