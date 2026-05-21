import 'package:get/get.dart';

/// True while a map-bearing full-screen route (/add-listing, /add-plot) is active.
/// Both explore screens observe this and swap their map for a shimmer while true.
final RxBool mapShouldPause = false.obs;
