import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/dio_error_mapper.dart';
import '../../../utils/input_formatters.dart';
import '../data/trip_city_catalog.dart';
import '../data/trip_repository.dart';
import '../models/trip_city_model.dart';
import '../trip_colors.dart';
import '../trip_strings.dart';
import '../trip_strings_a4.dart';

class TripCitySupplyCache {
  static const _ttl = Duration(minutes: 10);
  static final _cache = <int, (TripCitySupply, DateTime)>{};
  static final _inFlight = <int, Future<TripCitySupply>>{};

  static TripCitySupply? cached(int cityKey) {
    final hit = _cache[cityKey];
    if (hit == null || DateTime.now().difference(hit.$2) > _ttl) return null;
    return hit.$1;
  }

  static Future<TripCitySupply> load(int cityKey) {
    final hit = cached(cityKey);
    if (hit != null) return Future.value(hit);
    return _inFlight[cityKey] ??= _fetch(cityKey).whenComplete(() => _inFlight.remove(cityKey));
  }

  static Future<TripCitySupply> _fetch(int cityKey) async {
    final s = await const TripRepository().citySupply(cityKey);
    _cache[cityKey] = (s, DateTime.now());
    return s;
  }
}

class TripCitySheet extends StatefulWidget {
  const TripCitySheet({super.key});

  static Future<TripCityModel?> pick(BuildContext context) {
    return showModalBottomSheet<TripCityModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const TripCitySheet(),
    );
  }

  @override
  State<TripCitySheet> createState() => _TripCitySheetState();
}

enum _LoadError { none, failed, plannerOff }

class _TripCitySheetState extends State<TripCitySheet> {
  final _searchCtrl = TextEditingController();
  late final TripCityCatalog _catalog;

  List<TripCityModel> _items = const [];
  String _query = '';
  bool _loading = false;
  _LoadError _error = _LoadError.none;
  int? _expanded;
  final _supply = <int, TripCitySupply>{};
  final _supplyFailed = <int>{};

  double? _baseHeight;
  double? _baseTopPadding;

  @override
  void initState() {
    super.initState();
    _catalog = TripCityCatalog.to;
    _catalog.warmFromDisk();
    _items = _catalog.search('');
    _loading = _items.isEmpty;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _baseHeight ??= media.size.height;
    _baseTopPadding ??= media.padding.top;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _loading = _items.isEmpty;
      _error = _LoadError.none;
    });
    _load();
  }

  Future<void> _load() async {
    try {
      await _catalog.load();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = _catalog.search(_query);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = _catalog.search(_query);
        if (_items.isEmpty) {
          _error = DioErrorMapper.errorType(e) == TripErrorTypes.plannerDisabled
              ? _LoadError.plannerOff
              : _LoadError.failed;
        }
      });
    }
  }

  void _onSearch(String v) {
    setState(() {
      _query = v;
      _items = _catalog.search(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final baseHeight = _baseHeight ?? media.size.height;
    final baseTopPadding = _baseTopPadding ?? media.padding.top;
    final maxHeight = (baseHeight - baseTopPadding) * 0.94;
    final sheetHeight = (baseHeight * 0.75).clamp(0.0, maxHeight);
    return SizedBox(
      height: sheetHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          _buildSearchBox(),
          Expanded(child: _buildBody()),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        gradient: TripColors.gradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      TripStrings.planATrip,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      TripStrings.pickCity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: TextField(
        controller: _searchCtrl,
        cursorColor: TripColors.accent,
        inputFormatters: noEmojiInputFormatters,
        onChanged: _onSearch,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
        decoration: InputDecoration(
          hintText: TripStrings.searchCity,
          hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textHint),
          filled: true,
          fillColor: TripColors.palette.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TripColors.accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty) {
      if (_loading) return _loadingIndicator();
      switch (_error) {
        case _LoadError.plannerOff:
          return _messageState(TripStrings.plannerOff, TripStrings.plannerOffSubtitle);
        case _LoadError.failed:
          return _messageState(TripStrings.citiesFailed, TripStrings.checkConnection, onRetry: _retry);
        case _LoadError.none:
          break;
      }
      if (_query.trim().isEmpty) return _messageState(TripStrings.noCitiesYet, TripStrings.noCitiesYetSubtitle);
      return _emptyState(TripStrings.noCityMatch(_query));
    }
    final sectioned = _query.trim().isEmpty && _items.any((c) => c.isPopularDestination);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: sectioned ? _sectionedRows() : _items.map(_cityRow).toList(),
    );
  }

  List<Widget> _sectionedRows() {
    final popular = _items.where((c) => c.isPopularDestination).toList();
    final rest = _items.where((c) => !c.isPopularDestination).toList();
    return [
      _sectionHeader(TripStrings.popular),
      ...popular.map(_cityRow),
      if (rest.isNotEmpty) ...[
        _sectionHeader(TripStrings.allCities),
        ...rest.map(_cityRow),
      ],
    ];
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
        child: Text(
          text,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight),
        ),
      );

  void _toggle(TripCityModel city) {
    final key = city.cityKey;
    if (_expanded == key) {
      setState(() => _expanded = null);
      return;
    }
    setState(() => _expanded = key);
    _loadSupply(key);
  }

  void _loadSupply(int key) {
    final hit = TripCitySupplyCache.cached(key);
    if (hit != null) {
      _supply[key] = hit;
      _supplyFailed.remove(key);
      return;
    }
    _supplyFailed.remove(key);
    TripCitySupplyCache.load(key).then((s) {
      if (mounted) setState(() => _supply[key] = s);
    }).catchError((Object _) {
      if (mounted) setState(() => _supplyFailed.add(key));
    });
  }

  Widget _cityRow(TripCityModel city) {
    final ready = city.isReady;
    final color = ready ? AppColors.textDark : AppColors.textHint;
    final place = city.placeLine;
    final open = ready && _expanded == city.cityKey;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: open ? TripColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: ready ? () => _toggle(city) : null,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                child: Row(
                  children: [
                    Icon(Iconsax.location, size: 17, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            city.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: color),
                          ),
                          if (place.isNotEmpty)
                            Text(
                              place,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (ready) ...[
                      const Text(
                        TripStringsA4.ready,
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.successText),
                      ),
                      Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: AppColors.textHint),
                    ] else
                      const Text(
                        TripStrings.comingSoon,
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textHint),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (open) _supplyPanel(city),
        ],
      ),
    );
  }

  Widget _supplyPanel(TripCityModel city) {
    final key = city.cityKey;
    final s = _supply[key];
    final failed = _supplyFailed.contains(key);
    final String line;
    final IconData icon;
    if (s != null) {
      line = s.isEmpty ? TripStringsA4.noSupplyLine : TripStringsA4.supplyLine(s.stays, s.drivers);
      icon = s.isEmpty ? Iconsax.info_circle : Iconsax.building_4;
    } else if (failed) {
      line = TripStringsA4.supplyFailed;
      icon = Iconsax.cloud_cross;
    } else {
      line = TripStringsA4.supplyChecking;
      icon = Iconsax.clock;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(37, 0, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textMedium),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium),
                ),
              ),
              if (failed)
                TextButton(
                  onPressed: () => setState(() => _loadSupply(key)),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: const Text(
                    TripStrings.retry,
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: TripColors.accentDark),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, city),
              style: ElevatedButton.styleFrom(
                backgroundColor: TripColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                TripStringsA4.planHere,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingIndicator() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: TripColors.accent),
          ),
        ),
      );

  Widget _emptyState(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight),
          ),
        ),
      );

  Widget _messageState(String title, String subtitle, {VoidCallback? onRetry}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  TripStrings.retry,
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: TripColors.accent),
                ),
              ),
            ],
          ],
        ),
      );
}
