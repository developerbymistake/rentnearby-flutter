import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../trip_strings_taxi_request.dart';

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
  });

  final String hint;
  final List<TaxiPickupPlace> places;
  final int? selectedKey;
  final ValueChanged<TaxiPickupPlace> onPick;
  final bool sameOption;
  final VoidCallback? onSame;
  final Widget? empty;
  final String keyPrefix;

  @override
  State<TaxiPlaceDropdown> createState() => _TaxiPlaceDropdownState();
}

class _TaxiPlaceDropdownState extends State<TaxiPlaceDropdown> {
  late bool _open = widget.selectedKey == null;

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
    final emptyBox = Padding(padding: DS.all(16), child: widget.empty ?? const SizedBox.shrink());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tap3D(
          onTap: () => setState(() => _open = !_open),
          label: selected?.name ?? widget.hint,
          child: Container(
            key: ValueKey('${widget.keyPrefix}_field'),
            padding: DS.sym(h: 18, v: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(28), boxShadow: DS.shadows(Ink3D.softShadow)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected?.name ?? widget.hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(15, selected == null ? FontWeight.w400 : FontWeight.w600, selected == null ? Ink3D.grey : Ink3D.title),
                  ),
                ),
                Icon(_open ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, color: tone.text, size: DS.s(24)),
              ],
            ),
          ),
        ),
        if (_open) ...[
          Gap.v(8),
          Container(
            key: ValueKey('${widget.keyPrefix}_panel'),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: DS.circular(20),
              border: Border.all(color: Form3D.outline),
              boxShadow: DS.shadows(Ink3D.softShadow),
            ),
            child: Column(
              children: [
                if (widget.sameOption)
                  _row(
                    key: ValueKey('${widget.keyPrefix}_same'),
                    name: TripStringsTaxiRequest.sameAsPickup,
                    chip: null,
                    onTap: () {
                      setState(() => _open = false);
                      widget.onSame?.call();
                    },
                  ),
                if (widget.places.isEmpty)
                  emptyBox
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
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _row({required Key key, required String name, required String? chip, required VoidCallback onTap}) {
    final tone = ListingTone.indigo;
    return Tap3D(
      onTap: onTap,
      label: name,
      child: Container(
        key: key,
        padding: DS.sym(h: 16, v: 14),
        child: Row(
          children: [
            Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, Ink3D.title))),
            if (chip != null) ...[
              Gap.h(8),
              Container(
                padding: DS.sym(h: 12, v: 5),
                decoration: BoxDecoration(color: tone.tint, borderRadius: DS.circular(10)),
                child: Text(chip, style: Ink3D.text(12, FontWeight.w700, tone.text)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
