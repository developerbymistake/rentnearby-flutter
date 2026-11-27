import 'package:flutter/material.dart';
import '../../../../design/design.dart';
import '../../../nearby/widgets/place_search_bar.dart';
import 'taxi_search_strings.dart';

class TaxiSearchCard extends StatelessWidget {
  const TaxiSearchCard({
    super.key,
    required this.fromLabel,
    required this.toLabel,
    required this.date,
    required this.isToday,
    required this.canSwap,
    required this.onFrom,
    required this.onTo,
    required this.onDate,
    required this.onSwap,
    this.onClearFrom,
    this.onClearTo,
    this.toError,
  });

  final String fromLabel;
  final String? toLabel;
  final DateTime date;
  final bool isToday;
  final bool canSwap;
  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback onDate;
  final VoidCallback onSwap;
  final VoidCallback? onClearFrom;
  final VoidCallback? onClearTo;
  final String? toError;

  static const double swapInset = 8;
  // Rows end before the Swap touch box; dividers start under the text, not the icon.
  static double get swapRoom => DS.s(KitMetrics.touch) + DS.s(swapInset) + DS.s(4);
  static double get textStart => DS.s(8) + DS.s(36) + DS.gh(10);

  bool get _hasError => toError != null && toError!.trim().isNotEmpty;

  Widget _divider({required double right, bool error = false}) => Container(
        height: DS.s(error ? 1.5 : 1),
        margin: EdgeInsets.only(left: textStart, right: right),
        color: error ? Form3D.errorText : ListingPalette.coral.line,
      );

  @override
  Widget build(BuildContext context) {
    final to = toLabel;
    return WhiteCard3D(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: swapRoom),
                    child: PlaceSearchBarView(
                      flat: true,
                      caption: TaxiSearchStrings.from,
                      label: fromLabel,
                      art: ListingArt.roundPushpin,
                      onTap: onFrom,
                      onClear: onClearFrom,
                      clearLabel: TaxiSearchStrings.useMyCentre,
                    ),
                  ),
                  _divider(right: swapRoom),
                  Padding(
                    padding: EdgeInsets.only(right: swapRoom),
                    child: PlaceSearchBarView(
                      flat: true,
                      caption: TaxiSearchStrings.to,
                      label: to,
                      hint: TaxiSearchStrings.toHint,
                      art: ListingArt.search,
                      onTap: onTo,
                      onClear: to == null || to.isEmpty ? null : onClearTo,
                      clearLabel: TaxiSearchStrings.clearTo,
                      error: toError,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                bottom: 0,
                right: DS.s(swapInset),
                child: Center(child: _SwapButton(enabled: canSwap, onTap: onSwap)),
              ),
            ],
          ),
          _divider(right: DS.s(14), error: _hasError),
          Semantics(
            container: true,
            button: true,
            label: TaxiSearchStrings.dateRowSemantics(date, isToday: isToday),
            onTap: onDate,
            excludeSemantics: true,
            child: Row(
              children: [
                Expanded(
                  child: PlaceSearchBarView(
                    flat: true,
                    caption: TaxiSearchStrings.dateCaption,
                    label: TaxiSearchStrings.dayText(date),
                    art: ListingArt.calendar,
                    onTap: onDate,
                  ),
                ),
                if (isToday)
                  Padding(
                    padding: EdgeInsets.only(right: DS.s(12)),
                    child: ListingFilterChip(tone: ListingTone.coral, label: TaxiSearchStrings.today, selected: true, onTap: onDate),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap3D(
      onTap: enabled ? onTap : null,
      label: TaxiSearchStrings.swapLabel,
      exclude: true,
      child: SizedBox(
        width: DS.s(KitMetrics.touch),
        height: DS.s(KitMetrics.touch),
        child: Center(
          child: Container(
            width: DS.s(36),
            height: DS.s(36),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              shape: BoxShape.circle,
              boxShadow: enabled ? DS.shadows(Ink3D.softShadow) : null,
              border: enabled ? null : Border.all(color: Ink3D.line),
            ),
            child: Icon(Icons.swap_vert_rounded, size: DS.s(22), color: enabled ? ListingPalette.coral.g2 : DesignColors.textDisabled),
          ),
        ),
      ),
    );
  }
}

class SearchTaxisButton extends StatelessWidget {
  const SearchTaxisButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(16), DS.s(18), 0),
      child: PrimaryButton(label: TaxiSearchStrings.searchTaxis, tone: KitTone.taxi, heroCorner: true, onPressed: onPressed),
    );
  }
}
