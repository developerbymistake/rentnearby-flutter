import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../design/extra/ext_auth.dart';
import '../../../../utils/input_formatters.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_sheet.dart';
import '../../../trip/data/trip_city_catalog.dart';
import '../social_strings_a.dart';

class PickedHome {
  const PickedHome({required this.city, required this.state});

  final String city;
  final String state;

  String get label => state.isEmpty ? city : '$city, $state';
}

class _PlaceOption {
  const _PlaceOption({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class PlacePickerSheet extends StatefulWidget {
  const PlacePickerSheet({super.key});

  static const int maxResults = 30;

  static Future<String?> pick(BuildContext context) async {
    TripCityCatalog.to.load().ignore();
    final r = await BuddySheet.show<_PlaceOption>(
      context,
      title: SocialStringsA.pickPlaceTitle,
      art: ListingArt.roundPushpin,
      builder: (_) => const PlacePickerSheet(),
    );
    return r?.title;
  }

  @override
  State<PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<PlacePickerSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<_PlaceOption> _results = const [];

  @override
  void initState() {
    super.initState();
    _results = _find('');
    TripCityCatalog.to.load().then((_) {
      if (mounted) _search(_ctrl.text);
    }).ignore();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search(String q) => setState(() => _results = _find(q));

  List<_PlaceOption> _find(String q) {
    final cities = TripCityCatalog.to.search(q);
    final out = <_PlaceOption>[];
    final query = q.trim().toLowerCase();
    if (query.length >= 2) {
      final seen = <String>{};
      for (final c in cities) {
        final s = c.stateName.trim();
        if (s.isNotEmpty && s.toLowerCase().contains(query) && seen.add(s.toLowerCase())) {
          out.add(_PlaceOption(title: s, subtitle: SocialStringsA.stateLine));
        }
      }
    }
    for (final c in cities) {
      if (out.length >= PlacePickerSheet.maxResults) break;
      out.add(_PlaceOption(title: c.name, subtitle: c.placeLine));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthPillInput(
          tone: ListingTone.indigo,
          focusNode: _focus,
          leadingArt: ListingArt.search,
          child: TextField(
            key: const ValueKey('place_search'),
            controller: _ctrl,
            focusNode: _focus,
            autofocus: true,
            inputFormatters: noEmojiInputFormatters,
            style: AuthPillInput.nameStyle,
            decoration: AuthPillInput.decoration(SocialStringsA.searchPlace),
            onChanged: _search,
          ),
        ),
        Gap.v(8),
        if (_results.isEmpty)
          Padding(
            padding: DS.sym(v: 20),
            child: Text(SocialStringsA.noPlaceFound, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
          ),
        for (final r in _results)
          Tap3D(
            onTap: () => Navigator.of(context).pop(r),
            label: r.title,
            exclude: true,
            child: Container(
              padding: DS.sym(h: 6, v: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: BuddyLook.hairline))),
              child: Row(
                children: [
                  ExcludeSemantics(child: Art3D(asset: ListingArt.roundPushpin, size: 26, shadowBlur: 2, shadowOffset: const Offset(1, 2))),
                  Gap.h(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                        if (r.subtitle.isNotEmpty)
                          Text(r.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
