import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../services/storage_service.dart';
import '../models/trip_plan_model.dart';
import '../utils/trip_wizard_rules.dart';
import 'trip_plan_controller.dart';

class TripWizardController extends GetxController {
  TripWizardController(this.tripId, String initialKey) : currentKey = initialKey.obs;

  final String tripId;
  final RxString currentKey;
  ModalRoute<dynamic>? route;
  int _lastIndex = 0;
  Worker? _remember;

  static final List<TripWizardController> _live = [];
  static int _serial = 0;

  static String nextTag(String tripId) => '$tripId#${++_serial}';

  static TripWizardController? onTop(String tripId) {
    for (final w in _live.reversed) {
      if (w.tripId == tripId && w.route?.isCurrent == true) return w;
    }
    return null;
  }

  List<TripStepInfo> get steps => TripPlanController.to.wizardSteps;

  int get index {
    final list = steps;
    final i = list.indexWhere((s) => s.key.id == currentKey.value);
    if (i >= 0) {
      _lastIndex = i;
      return i;
    }
    if (list.isEmpty) return 0;
    return _lastIndex.clamp(0, list.length - 1);
  }

  TripStepInfo? get current {
    final list = steps;
    if (list.isEmpty) return null;
    return list[index];
  }

  TripStepInfo? get previous {
    final i = index;
    return i > 0 && i - 1 < steps.length ? steps[i - 1] : null;
  }

  TripStepInfo? get following {
    final list = steps;
    final i = index;
    return i + 1 < list.length ? list[i + 1] : null;
  }

  bool get isFirst => index == 0;

  bool get isLast => index >= steps.length - 1;

  @override
  void onInit() {
    super.onInit();
    _live.add(this);
    _remember = ever<String>(currentKey, (_) => rememberLast());
    rememberLast();
  }

  @override
  void onClose() {
    _remember?.dispose();
    _live.remove(this);
    super.onClose();
  }

  void prev() {
    final p = previous;
    if (p != null) currentKey.value = p.key.id;
  }

  void next() {
    final n = following;
    if (n != null) currentKey.value = n.key.id;
  }

  void openKey(String id) {
    if (steps.any((s) => s.key.id == id)) currentKey.value = id;
  }

  TripStepInfo? firstOpen() => TripWizardRules.nextStep(steps);

  List<TripStepInfo> get _skippable => [
        for (final x in steps)
          if (x.state == TripStepState.todo &&
              (x.key.kind == TripWizardStepKind.stay && x.day != null ||
                  x.key.kind == TripWizardStepKind.taxi && x.day != null ||
                  x.key.kind == TripWizardStepKind.gettingThere ||
                  x.key.kind == TripWizardStepKind.comingBack ||
                  x.key.kind == TripWizardStepKind.travel && (x.legIndex ?? x.key.legIndex) != null))
            x,
      ];

  int get openCount => _skippable.length;

  int skipRest() {
    final c = TripPlanController.to;
    final list = _skippable;
    for (final x in list) {
      switch (x.key.kind) {
        case TripWizardStepKind.stay:
          c.setSkippedNight(x.day!);
        case TripWizardStepKind.taxi:
          c.setSkippedTaxiDay(x.day!);
        case TripWizardStepKind.gettingThere:
          c.markStepOwn(TripStepRole.gettingThere);
        case TripWizardStepKind.comingBack:
          c.markStepOwn(TripStepRole.comingBack);
        case TripWizardStepKind.travel:
          c.setOwnTravel((x.legIndex ?? x.key.legIndex)!);
        default:
      }
    }
    return list.length;
  }

  void rememberLast() {
    final cur = current;
    if (cur != null) StorageService.saveTripWizardLast(tripId, cur.key.id);
  }
}
