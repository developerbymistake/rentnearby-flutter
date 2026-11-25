import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design/design.dart';
import '../../trip/trip_strings_a3.dart';
import '../guest/v2/taxi_rate_strings.dart';
import '../models/taxi_owner_model.dart';
import 'taxi_rate_rules.dart';

enum TaxiRateRing { rate, km }

class TaxiRateFormController extends ChangeNotifier {
  final cardKey = GlobalKey();
  final rateCtrl = TextEditingController();
  final kmCtrl = TextEditingController();
  TaxiRateRing? ring;
  String _storedRate = '';
  String _storedKm = '';
  bool editable = true;
  bool _disposed = false;

  String get storedRate => _storedRate;
  String get storedKm => _storedKm;
  bool get stored => _storedRate.isNotEmpty && _storedKm.isNotEmpty;
  bool get dirty => rateCtrl.text.trim() != _storedRate || kmCtrl.text.trim() != _storedKm;
  int get dayRate => int.parse(rateCtrl.text.trim());
  int get kmPerDay => int.parse(kmCtrl.text.trim());

  void seed(TaxiOwnerModel? t) {
    _storedRate = '${t?.localDayRate ?? ''}';
    _storedKm = '${t?.localDayKm ?? ''}';
    editable = t?.canEditSetup ?? true;
    rateCtrl.text = _storedRate;
    kmCtrl.text = _storedKm;
    _notify();
  }

  String? check() {
    final error = TaxiRateRules.validate(rateCtrl.text, kmCtrl.text);
    if (error != null) mark();
    return error;
  }

  void mark() {
    ring = TaxiRateRules.rateError(rateCtrl.text) != null ? TaxiRateRing.rate : TaxiRateRing.km;
    _notify();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = cardKey.currentContext;
      if (ctx != null && ctx.mounted) Scrollable.ensureVisible(ctx, alignment: 0.1, duration: const Duration(milliseconds: 250));
    });
  }

  void clearRing(TaxiRateRing r) {
    if (ring == r) ring = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    rateCtrl.dispose();
    kmCtrl.dispose();
    super.dispose();
  }
}

class TaxiLocalRateCard extends StatelessWidget {
  const TaxiLocalRateCard({super.key, required this.controller, required this.tone});
  final TaxiRateFormController controller;
  final ListingTone tone;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          final editable = c.editable;
          return FormSectionCard(
            key: c.cardKey,
            tone: tone,
            art: ListingArt.taxi,
            artSide: FormArtSide.right,
            title: 'Local sightseeing',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(TaxiRateStrings.neededToList, style: FieldMessage.helperStyle.copyWith(fontSize: DS.f(12.5))),
              PillField(
                tone: tone,
                label: TripStringsA3.driverRateLabel,
                firstLabel: false,
                controller: c.rateCtrl,
                readOnly: !editable,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                prefixText: '₹',
                hint: 'e.g. 2500',
                errorRing: c.ring == TaxiRateRing.rate,
                onChanged: (_) => c.clearRing(TaxiRateRing.rate),
              ),
              PillField(
                tone: tone,
                label: TaxiRateStrings.kmLabel,
                firstLabel: false,
                controller: c.kmCtrl,
                readOnly: !editable,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                hint: 'e.g. 120',
                suffix: Text('km', style: Ink3D.text(13, FontWeight.w500, Form3D.muted, letterSpacing: 0)),
                errorRing: c.ring == TaxiRateRing.km,
                onChanged: (_) => c.clearRing(TaxiRateRing.km),
              ),
              Padding(
                padding: EdgeInsets.only(top: DS.gv(12)),
                child: Text('Travellers see this rate. You can quote a different fare for a trip after you read the itinerary.',
                    style: FieldMessage.helperStyle.copyWith(fontSize: DS.f(12))),
              ),
            ]),
          );
        },
      );
}
