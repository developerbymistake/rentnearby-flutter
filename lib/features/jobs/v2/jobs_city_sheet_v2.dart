import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_jobs.dart';
import '../../../utils/input_formatters.dart';
import '../../trip/data/trip_city_catalog.dart';
import '../../trip/models/trip_city_model.dart';
import '../../trip/trip_strings_city.dart';
import '../widgets/jobs_ui.dart';

abstract final class JobsCityStrings {
  static const String title = 'Choose a city';
  static const String hint = 'Search city';
  static const String allStates = 'All';
  static const String none = 'No city found';
  static const String noneBody = 'Check the spelling or try another city.';
}

class JobsCitySheetV2 extends StatefulWidget {
  const JobsCitySheetV2({super.key});

  static Future<TripCityModel?> show(BuildContext context) {
    return Sheet3D.show<TripCityModel>(context, builder: (_) => const JobsCitySheetV2());
  }

  @override
  State<JobsCitySheetV2> createState() => _JobsCitySheetV2State();
}

class _JobsCitySheetV2State extends State<JobsCitySheetV2> {
  final _search = TextEditingController();
  late final TripCityCatalog _catalog = TripCityCatalog.to;
  String _query = '';
  String? _state;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _catalog.warmFromDisk();
    if (!_catalog.hasData) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await _catalog.load();
    } catch (_) {
      _failed = true;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cities = _catalog.hasData ? _catalog.ready(_query, stateName: _state) : const <TripCityModel>[];
    final states = _catalog.hasData ? _catalog.liveStates() : const <String>[];
    final tone = JobsUi.look;
    return Sheet3D(
      tone: tone,
      art: ListingArt.worldMap,
      title: JobsCityStrings.title,
      size: SheetSize.list,
      scrollable: false,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetSearchField(
            tone: tone,
            controller: _search,
            hint: JobsCityStrings.hint,
            leadingArt: ListingArt.compass,
            inputFormatters: noEmojiInputFormatters,
            margin: const EdgeInsets.fromLTRB(18, 2, 18, 0),
            flat: true,
            onChanged: (v) => setState(() => _query = v),
          ),
          if (states.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i <= states.length; i++)
                    JobsChoiceChip(
                      label: i == 0 ? JobsCityStrings.allStates : states[i - 1],
                      selected: i == 0 ? _state == null : _state == states[i - 1],
                      onTap: () => setState(() => _state = i == 0 ? null : states[i - 1]),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(child: _body(cities)),
        ],
      ),
    );
  }

  Widget _body(List<TripCityModel> cities) {
    final tone = JobsUi.look;
    if (_loading && !_catalog.hasData) {
      return JobsSheetMessage(tone: tone, art: ListingArt.worldMap, loading: true);
    }
    if (!_catalog.hasData) {
      return JobsSheetMessage(
        tone: tone,
        art: ListingArt.calendar,
        title: TripStringsCity.citiesLoadingTitle,
        body: TripStringsCity.citiesLoadingBody,
        actionLabel: TripStringsCity.tryAgain,
        onAction: _failed ? _load : null,
      );
    }
    if (cities.isEmpty) {
      return JobsSheetMessage(tone: tone, art: ListingArt.compass, title: JobsCityStrings.none, body: JobsCityStrings.noneBody);
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 16 + MediaQuery.paddingOf(context).bottom),
      itemCount: cities.length,
      itemBuilder: (_, i) => _row(cities[i], i),
    );
  }

  Widget _row(TripCityModel c, int i) {
    final line = c.placeLine;
    final tone = JobsUi.look;
    return Tap3D(
      onTap: () => Navigator.of(context).pop(c),
      label: c.name,
      exclude: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: i > 0 ? const Border(top: BorderSide(color: Ink3D.line)) : null),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: tone.tint, borderRadius: BorderRadius.circular(16)))),
                    const Positioned(left: -4, top: -10, child: Art3D(asset: ListingArt.roundPushpin, size: 60, shadowBlur: 4, shadowOffset: Offset(3, 5), shadowAlpha: 0.28)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w600, Ink3D.title)),
                    if (line.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
