import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
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
    return showModalBottomSheet<TripCityModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: DesignColors.surface,
      barrierColor: DesignColors.scrim,
      elevation: 0,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(borderRadius: CardRadius.sheet),
      builder: (_) => const JobsCitySheetV2(),
    );
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
    final media = MediaQuery.of(context);
    final cities = _catalog.hasData ? _catalog.ready(_query, stateName: _state) : const <TripCityModel>[];
    final states = _catalog.hasData ? _catalog.liveStates() : const <String>[];
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: DesignColors.borderSoft, borderRadius: CardRadius.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 16, KitMetrics.gutter, 12),
              child: Text(JobsCityStrings.title, style: TypeTokens.style(18, FontWeight.w700, color: DesignColors.textStrong)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
              child: TextField(
                controller: _search,
                inputFormatters: noEmojiInputFormatters,
                textInputAction: TextInputAction.search,
                style: TypeTokens.body,
                decoration: JobsUi.input(JobsCityStrings.hint).copyWith(
                  prefixIcon: const Icon(Icons.search_rounded, color: DesignColors.textGrey),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (states.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 12, KitMetrics.gutter, 0),
                child: JobsChoiceWrap(
                  labels: [JobsCityStrings.allStates, ...states],
                  isActive: (i) => i == 0 ? _state == null : _state == states[i - 1],
                  onTap: (i) => setState(() => _state = i == 0 ? null : states[i - 1]),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(child: _body(cities)),
          ],
        ),
      ),
    );
  }

  Widget _body(List<TripCityModel> cities) {
    if (_loading && !_catalog.hasData) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (!_catalog.hasData) {
      return _message(
        TripStringsCity.citiesLoadingTitle,
        TripStringsCity.citiesLoadingBody,
        retry: _failed ? _load : null,
      );
    }
    if (cities.isEmpty) return _message(JobsCityStrings.none, JobsCityStrings.noneBody);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 16 + MediaQuery.paddingOf(context).bottom),
      itemCount: cities.length,
      itemBuilder: (_, i) => _row(cities[i]),
    );
  }

  Widget _row(TripCityModel c) {
    final line = c.placeLine;
    return InkWell(
      onTap: () => Navigator.of(context).pop(c),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KitMetrics.touch),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.place_outlined, size: 22, color: DesignColors.textGrey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeTokens.style(15, FontWeight.w600, color: DesignColors.textStrong),
                    ),
                    if (line.isNotEmpty)
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypeTokens.style(12, FontWeight.w400, color: DesignColors.textGrey),
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

  Widget _message(String title, String body, {VoidCallback? retry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: TypeTokens.style(15, FontWeight.w600, color: DesignColors.textStrong)),
            const SizedBox(height: 4),
            Text(body, textAlign: TextAlign.center, style: TypeTokens.style(13, FontWeight.w400, color: DesignColors.textGrey)),
            if (retry != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: retry, child: const Text(TripStringsCity.tryAgain)),
            ],
          ],
        ),
      ),
    );
  }
}
