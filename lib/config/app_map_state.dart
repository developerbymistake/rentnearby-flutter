import 'package:get/get.dart';

/// True while a map-bearing full-screen route is active (see MapPauseObserver).
/// Map screens observe this and swap their map for a shimmer while true.
final RxBool mapShouldPause = false.obs;
