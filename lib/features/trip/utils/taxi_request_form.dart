import '../models/taxi_request_models.dart';
import '../trip_strings_taxi_request.dart';

enum TaxiFormBlock { none, noSection, pickupUnavailable, pickupMissing, dropUnavailable, dropMissing }

class TaxiRequestForm {
  final TaxiPickupPlaces places;
  final List<int> planDays;
  final bool pickupOn;
  final bool sightseeingOn;
  final bool dropOn;
  final int? pickupCityKey;
  final bool dropSame;
  final int? dropCityKey;
  final Set<int> days;
  final int seats;

  const TaxiRequestForm({
    required this.places,
    required this.planDays,
    required this.pickupOn,
    required this.sightseeingOn,
    required this.dropOn,
    required this.pickupCityKey,
    required this.dropSame,
    required this.dropCityKey,
    required this.days,
    required this.seats,
  });

  factory TaxiRequestForm.initial({required TaxiPickupPlaces places, required List<int> planDays}) => TaxiRequestForm(
        places: places,
        planDays: planDays,
        pickupOn: true,
        sightseeingOn: true,
        dropOn: true,
        pickupCityKey: null,
        dropSame: true,
        dropCityKey: null,
        days: planDays.toSet(),
        seats: TaxiSeats.snap(places.suggestedSeats),
      );

  TaxiRequestForm _with({
    bool? pickupOn,
    bool? sightseeingOn,
    bool? dropOn,
    Object? pickupCityKey = _keep,
    bool? dropSame,
    Object? dropCityKey = _keep,
    Set<int>? days,
    int? seats,
  }) =>
      TaxiRequestForm(
        places: places,
        planDays: planDays,
        pickupOn: pickupOn ?? this.pickupOn,
        sightseeingOn: sightseeingOn ?? this.sightseeingOn,
        dropOn: dropOn ?? this.dropOn,
        pickupCityKey: identical(pickupCityKey, _keep) ? this.pickupCityKey : pickupCityKey as int?,
        dropSame: dropSame ?? this.dropSame,
        dropCityKey: identical(dropCityKey, _keep) ? this.dropCityKey : dropCityKey as int?,
        days: days ?? this.days,
        seats: seats ?? this.seats,
      );

  static const Object _keep = Object();

  TaxiRequestForm setPickupOn(bool on) => _with(pickupOn: on);

  TaxiRequestForm setSightseeingOn(bool on) => _with(sightseeingOn: on);

  TaxiRequestForm setDropOn(bool on) => _with(dropOn: on);

  TaxiRequestForm choosePickup(int cityKey) => _with(pickupCityKey: cityKey);

  TaxiRequestForm dropSameAsPickup() => _with(dropSame: true, dropCityKey: null);

  TaxiRequestForm chooseDrop(int cityKey) => _with(dropSame: false, dropCityKey: cityKey);

  TaxiRequestForm toggleDay(int day) {
    if (!planDays.contains(day)) return this;
    final next = {...days};
    if (!next.remove(day)) next.add(day);
    return _with(days: next);
  }

  TaxiRequestForm setSeats(int value) => TaxiSeats.options.contains(value) ? _with(seats: value) : this;

  bool get sightseeingActive => sightseeingOn && sightseeingDays.isNotEmpty;

  bool get dropIsSameAsPickup => dropOn && pickupOn && dropSame;

  List<int> get sightseeingDays => [for (final d in planDays) if (days.contains(d)) d];

  TaxiPickupPlace? get pickupPlace => places.pickupByKey(pickupCityKey);

  TaxiPickupPlace? get dropPlace => places.dropByKey(dropSame ? null : dropCityKey);

  TaxiFormBlock get block {
    if (!pickupOn && !sightseeingActive && !dropOn) return TaxiFormBlock.noSection;
    if (pickupOn) {
      if (places.pickup.isEmpty) return TaxiFormBlock.pickupUnavailable;
      if (pickupPlace == null) return TaxiFormBlock.pickupMissing;
    }
    if (dropOn && !dropIsSameAsPickup) {
      if (places.drop.isEmpty) return TaxiFormBlock.dropUnavailable;
      if (dropPlace == null) return TaxiFormBlock.dropMissing;
    }
    return TaxiFormBlock.none;
  }

  bool get canSend => block == TaxiFormBlock.none;

  String get summary {
    switch (block) {
      case TaxiFormBlock.noSection:
        return TripStringsTaxiRequest.summaryNoSection;
      case TaxiFormBlock.pickupUnavailable:
        return TripStringsTaxiRequest.summaryNoPickup;
      case TaxiFormBlock.dropUnavailable:
        return TripStringsTaxiRequest.summaryNoDrop;
      default:
    }
    final parts = <String>[
      if (pickupOn)
        pickupPlace == null
            ? TripStringsTaxiRequest.summaryChoosePickup
            : TripStringsTaxiRequest.summaryPickupAt(pickupPlace!.name),
      if (sightseeingActive) TripStringsTaxiRequest.summaryDays(sightseeingDays.length),
      if (dropOn)
        dropIsSameAsPickup
            ? TripStringsTaxiRequest.summaryDropSame
            : (dropPlace == null
                ? TripStringsTaxiRequest.summaryChooseDrop
                : TripStringsTaxiRequest.summaryDropAt(dropPlace!.name)),
    ];
    final text = parts.join(', ');
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  }

  Map<String, dynamic> toBody(String clientRequestId, List<TaxiDayStat> dayStats) => {
        'clientRequestId': clientRequestId,
        'pickup': {'on': pickupOn, 'cityKey': pickupOn ? pickupCityKey : null},
        'sightseeing': {'on': sightseeingActive, 'days': sightseeingActive ? sightseeingDays : <int>[]},
        'drop': {
          'on': dropOn,
          'sameAsPickup': dropIsSameAsPickup,
          'cityKey': dropOn && !dropIsSameAsPickup ? dropCityKey : null,
        },
        'seats': seats,
        'dayStats': [for (final s in dayStats) s.toJson()],
      };
}
