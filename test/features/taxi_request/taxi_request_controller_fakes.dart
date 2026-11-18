import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/trip/data/taxi_request_repository.dart';
import 'package:bakhli/features/trip/data/trip_enquiry_repository.dart';
import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';

Map<String, dynamic> sampleJson(String name) =>
    jsonDecode(File('test/features/taxi_request/samples/$name').readAsStringSync()) as Map<String, dynamic>;

TaxiRequest sampleRequest(String name, {Map<String, dynamic> change = const {}}) =>
    TaxiRequest.fromJson({...sampleJson(name), ...change});

TaxiPickupPlaces samplePlaces() => TaxiPickupPlaces.fromJson(sampleJson('pickup_places.json'));

const List<int> planDays = [1, 2, 3, 4];

class FakeTaxiRepo implements TaxiRequestRepository {
  TaxiResult<TaxiPickupPlaces> placesAnswer = TaxiOk(samplePlaces());
  final List<TaxiResult<TaxiRequest>> createAnswers = [];
  TaxiResult<TaxiRequest> Function(String id) getAnswer =
      (id) => TaxiOk(sampleRequest('taxi_request_collecting.json'));
  TaxiResult<TaxiRequest>? actionAnswer;

  final List<Map<String, dynamic>> createBodies = [];
  final List<String> getIds = [];
  final List<String> actions = [];

  @override
  Future<TaxiResult<TaxiPickupPlaces>> pickupPlaces(String tripId) async => placesAnswer;

  @override
  Future<TaxiResult<TaxiRequest>> create(String tripId, Map<String, dynamic> body) async {
    createBodies.add(body);
    return createAnswers.removeAt(0);
  }

  @override
  Future<TaxiResult<TaxiRequest?>> forTrip(String tripId) async {
    final r = getAnswer('trip:$tripId');
    return r is TaxiOk<TaxiRequest> ? TaxiOk<TaxiRequest?>(r.value) : const TaxiNotFound<TaxiRequest?>();
  }

  @override
  Future<TaxiResult<TaxiRequest>> get(String requestId) async {
    getIds.add(requestId);
    return getAnswer(requestId);
  }

  Future<TaxiResult<TaxiRequest>> _action(String name) async {
    actions.add(name);
    return actionAnswer ?? const TaxiFailed(message: 'no answer');
  }

  @override
  Future<TaxiResult<TaxiRequest>> cancel(String requestId, {String reason = 'TravellerCancelled', ReasonChip? chip}) =>
      _action('cancel:$reason:${chip?.wire}');

  @override
  Future<TaxiResult<TaxiRequest>> askMore(String requestId) => _action('askMore');

  @override
  Future<TaxiResult<TaxiRequest>> select(String requestId, String offerId) => _action('select:$offerId');

  @override
  Future<TaxiResult<TaxiRequest>> notAgreed(String requestId, String offerId) => _action('notAgreed:$offerId');

  @override
  Future<TaxiResult<TaxiRequest>> end(String requestId) => _action('end');

  @override
  Future<TaxiResult<TaxiRequest>> rate(String requestId, int stars) => _action('rate:$stars');
}

class FakeEnquiries extends TripEnquiryRepository {
  FakeEnquiries({this.fail});

  final Object? fail;
  final List<String> withdrawn = [];
  final List<String> cancelled = [];

  @override
  Future<TripEnquiryModel> withdraw(String enquiryId) async {
    if (fail != null) throw fail!;
    withdrawn.add(enquiryId);
    return TripEnquiryModel.fromJson({'id': enquiryId, 'status': 'Withdrawn'});
  }

  @override
  Future<TripEnquiryModel> cancel(String enquiryId, {String? reason}) async {
    if (fail != null) throw fail!;
    cancelled.add(enquiryId);
    return TripEnquiryModel.fromJson({'id': enquiryId, 'status': 'Cancelled'});
  }
}
