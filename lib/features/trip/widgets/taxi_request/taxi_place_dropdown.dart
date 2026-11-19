import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../trip_strings_taxi_request.dart';
import 'taxi_request_look.dart';

class TaxiPlaceDropdown extends StatefulWidget {
  const TaxiPlaceDropdown({
    super.key,
    required this.hint,
    required this.places,
    required this.selectedKey,
    required this.onPick,
    this.sameOption = false,
    this.onSame,
    this.empty,
    this.keyPrefix = 'taxi_place',
    this.field,
    this.open,
  });

  final String hint;
  final List<TaxiPickupPlace> places;
  final int? selectedKey;
  final ValueChanged<TaxiPickupPlace> onPick;
  final bool sameOption;
  final VoidCallback? onSame;
  final Widget? empty;
  final String keyPrefix;
  final Widget? field;
  final bool? open;

  static BoxDecoration fieldDecoration() => BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.circular(25),
        boxShadow: DS.shadows(TaxiRequestLook.field),
      );

  static BoxConstraints fieldConstraints() => BoxConstraints(minHeight: DS.s(50));

  static TextStyle valueStyle() => Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0);

  @override
  State<TaxiPlaceDropdown> createState() => _TaxiPlaceDropdownState();
}

class _TaxiPlaceDropdownState extends State<TaxiPlaceDropdown> {
  late bool _open = widget.selectedKey == null;

  bool get _isOpen => widget.open ?? _open;

  TaxiPickupPlace? get _selected {
    for (final p in widget.places) {
      if (p.cityKey == widget.selectedKey) return p;
    }
    return null;
  }

  @override
  void didUpdateWidget(TaxiPlaceDropdown old) {
    super.didUpdateWidget(old);
    if (widget.selectedKey != null && widget.selectedKey != old.selectedKey) _open = false;
  }

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    final selected = _selected;
    final open = _isOpen;
    final list = <Widget>[
      if (widget.sameOption)
        _row(
          key: ValueKey('${widget.keyPrefix}_same_row'),
          name: TripStringsTaxiRequest.sameAsPickup,
          chip: null,
          onTap: () {
            setState(() => _open = false);
            widget.onSame?.call();
          },
        ),
      if (widget.places.isEmpty)
        Padding(padding: DS.sym(h: 16, v: 20), child: widget.empty ?? const SizedBox.shrink())
      else
        for (final p in widget.places)
          _row(
            key: ValueKey('${widget.keyPrefix}_${p.cityKey}'),
            name: p.name,
            chip: TripStringsTaxiRequest.drivers(p.drivers),
            onTap: () {
              setState(() => _open = false);
              widget.onPick(p);
            },
          ),
    ];
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.field ??
              Tap3D(
                onTap: () => setState(() => _open = !_open),
                label: selected?.name ?? widget.hint,
                child: Container(
                  key: ValueKey('${widget.keyPrefix}_field'),
                  constraints: TaxiPlaceDropdown.fieldConstraints(),
                  alignment: Alignment.centerLeft,
                  padding: DS.sym(h: 18),
                  decoration: TaxiPlaceDropdown.fieldDecoration(),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selected?.name ?? widget.hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: selected == null
                              ? Ink3D.text(14, FontWeight.w400, TripLook.mutedText, letterSpacing: 0)
                              : TaxiPlaceDropdown.valueStyle(),
                        ),
                      ),
                      Icon(open ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: tone.g2, size: DS.s(18)),
                    ],
                  ),
                ),
              ),
          if (open) ...[
            Gap.v(8),
            Container(
              key: ValueKey('${widget.keyPrefix}_panel'),
              decoration: BoxDecoration(
                color: DesignColors.surface,
                borderRadius: DS.br(TripCustomizeLook.errorRadius),
                border: Border.all(color: ListingPalette.indigo.line, width: DS.s(2)),
                boxShadow: DS.shadows(TaxiRequestLook.list),
              ),
              child: ClipRRect(
                borderRadius: DS.br(TripCustomizeLook.errorRadius),
                child: Padding(
                  padding: DS.sym(v: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) Container(height: DS.s(1), color: Ink3D.line),
                        list[i],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row({required Key key, required String name, required String? chip, required VoidCallback onTap}) {
    final tone = ListingTone.indigo;
    return Tap3D(
      onTap: onTap,
      label: name,
      child: Container(
        key: key,
        constraints: BoxConstraints(minHeight: DS.s(56)),
        padding: DS.sym(h: 16, v: 12),
        child: Row(
          children: [
            Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TaxiPlaceDropdown.valueStyle())),
            if (chip != null) ...[
              Gap.h(8),
              Container(
                padding: DS.sym(h: 12, v: 4),
                decoration: BoxDecoration(color: ListingPalette.indigo.tint, borderRadius: DS.circular(10)),
                child: Text(chip, style: Ink3D.text(12.5, FontWeight.w700, tone.text, letterSpacing: 0)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
