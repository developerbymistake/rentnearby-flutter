import '../json/owner_json.dart';

enum PlanCardState { free, trial, plus, cancelled, grace, onHold, ended, adminGrant, paymentOff, unknown }

abstract final class PlanCardStates {
  static const Map<String, PlanCardState> wire = {
    'Free': PlanCardState.free,
    'Trial': PlanCardState.trial,
    'Plus': PlanCardState.plus,
    'Cancelled': PlanCardState.cancelled,
    'Grace': PlanCardState.grace,
    'OnHold': PlanCardState.onHold,
    'Ended': PlanCardState.ended,
    'AdminGrant': PlanCardState.adminGrant,
    'PaymentOff': PlanCardState.paymentOff,
  };

  static PlanCardState parse(Object? raw) => OwnerJson.pick(raw, wire, PlanCardState.unknown);
}
