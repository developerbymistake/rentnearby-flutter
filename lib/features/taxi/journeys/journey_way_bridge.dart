import '../ways/models/taxi_ways_models.dart';
import 'journey_models.dart';

extension SavedJourneyWays on SavedJourney {
  WayPlan toWayPlan() => WayPlan(
        planKey: planKey,
        cars: legs.length,
        total: listedTotal ?? legs.fold<int>(0, (sum, l) => sum + (l.listedFare ?? 0)),
        legs: legs.map(wayLeg).toList(),
      );

  // Saved legs are the server's priced choice: no manual pick, so asks follow the saved seat cover.
  Map<int, WayDriver> chosenDrivers() => const {};

  WayLeg wayLeg(SavedJourneyLeg leg) {
    final keys = leg.legKey.split('~');
    final cover = leg.coverOthers;
    final coverDrivers = [
      for (final id in cover)
        for (final c in leg.coverDrivers)
          if (c.taxiId == id) c,
    ];
    final drivers = [
      wayDriver(leg, leg.driver),
      ...coverDrivers.map((c) => wayDriver(leg, c)),
      ...leg.backups.where((b) => b.available && !cover.contains(b.taxiId)).map((b) => wayDriver(leg, b)),
    ];
    return WayLeg(
      legKey: leg.legKey,
      index: leg.legIndex,
      from: WayPlace(key: keys.length == 3 ? keys[1] : '', name: leg.fromName, lat: leg.fromLat, lng: leg.fromLng),
      to: WayPlace(key: keys.length == 3 ? keys[2] : '', name: leg.toName, lat: leg.toLat, lng: leg.toLng),
      meetingPlace: leg.meetingPlace,
      listedFare: leg.listedFare ?? 0,
      partial: leg.partial,
      topDrivers: drivers,
      driverCount: drivers.length,
      carsNeeded: leg.carsOf(people),
      seatsNote: leg.seatsNote,
      coverTaxiIds: [leg.driver.taxiId, ...cover],
    );
  }

  // Per car of this driver: exact only for the saved driver alone (the stretch fare over his own cars); else unknown (0).
  WayDriver wayDriver(SavedJourneyLeg leg, JourneyContact c) {
    final stretch = leg.listedFare ?? 0;
    final cars = leg.carsOf(people);
    final alone = c.taxiId == leg.driver.taxiId && leg.coverOthers.isEmpty;
    final perCar = alone && cars >= 1 && stretch % cars == 0 ? stretch ~/ cars : 0;
    return WayDriver(
      taxiId: c.taxiId,
      driverName: c.driverName,
      vehicleTypeName: c.vehicleTypeName,
      seats: c.seats,
      plateDisplay: c.plateDisplay,
      cityName: c.cityName,
      tripReplyLabel: c.tripReplyLabel,
      fromName: leg.fromName,
      toName: leg.toName,
      listedFare: perCar,
      partial: leg.partial,
      phone: c.phone,
      whatsApp: c.whatsApp,
    );
  }
}
