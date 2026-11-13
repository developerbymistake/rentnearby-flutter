import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../config/module_palette.dart';
import '../design/design.dart';
import '../models/place_result_model.dart';
import '../services/photon_service.dart';
import '../utils/input_formatters.dart';
import 'location_switch_sheet.dart';

class LocationSearchSheet extends StatefulWidget {
  final LatLng? bias;
  final ModulePalette palette;
  final String? preferState;
  const LocationSearchSheet(
      {super.key,
      this.bias,
      this.palette = templateModulePalette,
      this.preferState});

  static Future<PlaceResult?> show(BuildContext context,
      {LatLng? bias,
      ModulePalette palette = templateModulePalette,
      String? preferState}) {
    return Sheet3D.show<PlaceResult>(
      context,
      builder: (_) => LocationSearchSheet(
          bias: bias, palette: palette, preferState: preferState),
    );
  }

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet>
    with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late final ListingTone _tone = moduleToneFor(widget.palette);
  Timer? _debounce;
  late final AnimationController _enter = AnimationController(
      duration: const Duration(milliseconds: 600), vsync: this)
    ..forward();
  late final AnimationController _rows = AnimationController(
      duration: const Duration(milliseconds: 600), vsync: this)
    ..forward();

  List<PlaceResult> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  double? _baseHeight;
  double? _baseTopPadding;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _baseHeight ??= media.size.height;
    _baseTopPadding ??= media.padding.top;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _enter.dispose();
    _rows.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
        _searched = false;
      });
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 600), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await PhotonService.search(query,
          bias: widget.bias, preferState: widget.preferState);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _searched = true;
      });
      _rows.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _searched = true;
        _error = 'Could not search. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final baseHeight = _baseHeight ?? media.size.height;
    final baseTopPadding = _baseTopPadding ?? media.padding.top;
    final maxHeight = (baseHeight - baseTopPadding) * 0.94;
    final sheetHeight = math.max(baseHeight * 0.75, 615.0).clamp(0.0, maxHeight);
    return SizedBox(
      height: sheetHeight + Sheet3D.artRoom,
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Sheet3D(
          tone: _tone,
          art: ListingArt.worldMap,
          centerTitle: false,
          scrollable: false,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetListHeader(tone: _tone, title: 'Search location'),
              TemplateEntrance(
                animation: templateInterval(_enter, 0, 2),
                animationController: _enter,
                child: _buildSearchBox(),
              ),
              Expanded(
                child: TemplateEntrance(
                  animation: templateInterval(_enter, 1, 2),
                  animationController: _enter,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return SheetSearchField(
      tone: _tone,
      controller: _searchCtrl,
      autofocus: true,
      hint: 'Search area, locality, landmark...',
      leadingArt: ListingArt.roundPushpin,
      inputFormatters: noEmojiInputFormatters,
      onChanged: _onChanged,
    );
  }

  Widget _buildBody() {
    if (_loading) return sheetSkeleton(twoLines: true);
    if (_error != null) {
      return sheetStateView(_tone, _error!, onRetry: () => _runSearch(_searchCtrl.text));
    }
    if (!_searched) return sheetStateView(_tone, 'Search area, locality or landmark');
    if (_results.isEmpty) {
      return sheetStateView(_tone, 'No results for "${_searchCtrl.text}"');
    }
    final count = math.min(_results.length, 10);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final result = _results[i];
        return TemplateEntrance(
          animation: templateInterval(_rows, math.min(i, count - 1), count),
          animationController: _rows,
          child: SheetListRow(
            tone: _tone,
            title: result.name,
            subtitle: result.subtitle.isEmpty ? null : result.subtitle,
            art: ListingArt.roundPushpin,
            divider: i > 0,
            onTap: () => Navigator.pop(context, result),
          ),
        );
      },
    );
  }
}
