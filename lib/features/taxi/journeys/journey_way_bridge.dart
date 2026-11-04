import '../ways/models/taxi_ways_models.dart';
import 'journey_models.dart';

extension SavedJourneyWays on SavedJourney {
  WayPlan toWayPlan() => WayPlan(
        planKey: planKey,
        cars: legs.length,
        total: listedTotal ?? legs.fold<int>(0, (sum, l) => sum + (l.listedFare ?? 0)),
        legs: legs.map(wayLeg).toList(),
      );

  Map<int, WayDriver> chosenDrivers() => {for (final l in legs) l.legIndex: wayDriver(l, l.driver)};

  WayLeg wayLeg(SavedJourneyLeg leg) {
    final keys = leg.legKey.split('~');
    final drivers = [wayDriver(leg, leg.driver), ...leg.backups.where((b) => b.available).map((b) => wayDriver(leg, b))];
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
    );
  }

  WayDriver wayDriver(SavedJourneyLeg leg, JourneyContact c) => WayDriver(
        taxiId: c.taxiId,
        driverName: c.driverName,
        vehicleTypeName: c.vehicleTypeName,
        seats: c.seats,
        plateDisplay: c.plateDisplay,
        cityName: c.cityName,
        tripReplyLabel: c.tripReplyLabel,
        fromName: leg.fromName,
        toName: leg.toName,
        listedFare: leg.listedFare ?? 0,
        partial: leg.partial,
        phone: c.phone,
        whatsApp: c.whatsApp,
      );
}
