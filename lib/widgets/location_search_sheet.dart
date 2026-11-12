import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../config/module_palette.dart';
import '../design/design.dart';
import '../models/place_result_model.dart';
import '../services/photon_service.dart';
import '../utils/input_formatters.dart';

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
    return showModalBottomSheet<PlaceResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FitnessAppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
    final sheetHeight = (baseHeight * 0.75).clamp(0.0, maxHeight);
    return SizedBox(
      height: sheetHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TemplateEntrance(
            animation: templateInterval(_enter, 0, 3),
            animationController: _enter,
            child: const GateSheetHeader(title: 'Search location'),
          ),
          TemplateEntrance(
            animation: templateInterval(_enter, 1, 3),
            animationController: _enter,
            child: _buildSearchBox(),
          ),
          Expanded(
            child: TemplateEntrance(
              animation: templateInterval(_enter, 2, 3),
              animationController: _enter,
              child: _buildBody(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: GateSearchBar(
        controller: _searchCtrl,
        autofocus: true,
        hint: 'Search area, locality, landmark...',
        inputFormatters: noEmojiInputFormatters,
        onChanged: _onChanged,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _loadingRows();
    if (_error != null) {
      return _errorState(_error!, () => _runSearch(_searchCtrl.text));
    }
    if (!_searched) return _emptyState('Search area, locality or landmark');
    if (_results.isEmpty) {
      return _emptyState('No results for "${_searchCtrl.text}"');
    }
    final count = math.min(_results.length, 10);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _results.length,
      itemBuilder: (context, i) => TemplateEntrance(
        animation: templateInterval(_rows, math.min(i, count - 1), count),
        animationController: _rows,
        child: _resultRow(_results[i]),
      ),
    );
  }

  Widget _resultRow(PlaceResult result) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pop(context, result),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              child: Row(
                children: [
                  const TravelIcon(TravelIcon.place, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TripKit.text(14, weight: FontWeight.w600),
                        ),
                        if (result.subtitle.isNotEmpty)
                          Text(
                            result.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FitnessAppTheme.caption,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: FitnessAppTheme.spacer),
      ],
    );
  }

  Widget _loadingRows() => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  TemplatePlaceholder(height: 40, width: 40, radius: 20),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TemplatePlaceholder(height: 12, width: 160),
                      SizedBox(height: 8),
                      TemplatePlaceholder(height: 10, width: 100),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _emptyState(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            const TravelIcon(TravelIcon.map, size: 44),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FitnessAppTheme.caption,
            ),
          ],
        ),
      );

  Widget _errorState(String message, VoidCallback onRetry) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          children: [
            const TravelIcon(TravelIcon.map, size: 44),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FitnessAppTheme.caption,
            ),
            const SizedBox(height: 10),
            GateTextButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      );
}
