// What the trip day needs from a local taxi (GET /taxis/browse people, dayKm, lat, lng); the server ranks by it.
class TripTaxiNeed {
  static const int maxPeople = 12;
  static const int maxDayKm = 1000;

  final int people;
  final int dayKm;
  final double? lat;
  final double? lng;

  const TripTaxiNeed({this.people = 0, this.dayKm = 0, this.lat, this.lng});

  factory TripTaxiNeed.of({required int people, required double km, double? lat, double? lng}) => TripTaxiNeed(
        people: people.clamp(0, maxPeople).toInt(),
        dayKm: km.isFinite && km > 0 ? km.ceil().clamp(0, maxDayKm).toInt() : 0,
        lat: lat,
        lng: lng,
      );

  bool get hasPoint =>
      lat != null && lng != null && lat! >= -90 && lat! <= 90 && lng! >= -180 && lng! <= 180 && !(lat == 0 && lng == 0);

  bool get isEmpty => people <= 0 && dayKm <= 0 && !hasPoint;

  Map<String, dynamic> get params => {
        if (people > 0) 'people': people,
        if (dayKm > 0) 'dayKm': dayKm,
        if (hasPoint) 'lat': lat,
        if (hasPoint) 'lng': lng,
      };

  String get key => isEmpty ? '' : '$people|$dayKm|${hasPoint ? '${lat!.toStringAsFixed(4)},${lng!.toStringAsFixed(4)}' : ''}';
}

// The server's fit of one driver to the day (TaxiBrowseDto trip* fields); null fields = not sent.
class TripTaxiFit {
  final bool? seatsFit;
  final int? cars;
  final int? dayCost;
  final int? extraKm;
  final double? pickupKm;

  const TripTaxiFit({this.seatsFit, this.cars, this.dayCost, this.extraKm, this.pickupKm});

  factory TripTaxiFit.fromJson(Map<String, dynamic> json) => TripTaxiFit(
        seatsFit: json['tripSeatsFit'] is bool ? json['tripSeatsFit'] as bool : null,
        cars: (json['tripCars'] as num?)?.toInt(),
        dayCost: (json['tripDayCost'] as num?)?.toInt(),
        extraKm: (json['tripExtraKm'] as num?)?.toInt(),
        pickupKm: (json['tripPickupKm'] as num?)?.toDouble(),
      );

  bool get isEmpty => seatsFit == null && cars == null && dayCost == null && extraKm == null && pickupKm == null;

  int get carCount => cars == null || cars! < 1 ? 1 : cars!;

  // The day's cost for the whole group: the server's cars x day rate, else the listed day rate.
  int? costFor(int? dayRate) => dayCost ?? (dayRate == null ? null : dayRate * carCount);
}
