import 'package:flutter/material.dart';

class TravelIcon extends StatelessWidget {
  const TravelIcon(this.asset, {super.key, this.size = 24});

  final String asset;
  final double size;

  static const String _dir = 'assets/images/design/travel3d/';
  static const String taxi = '${_dir}taxi.png';
  static const String stay = '${_dir}house_with_garden.png';
  static const String search = '${_dir}magnifying_glass_tilted_left.png';
  static const String profile = '${_dir}bust_in_silhouette.png';
  static const String flag = '${_dir}chequered_flag.png';
  static const String warning = '${_dir}warning.png';
  static const String route = '${_dir}compass.png';
  static const String chat = '${_dir}speech_balloon.png';
  static const String place = '${_dir}round_pushpin.png';
  static const String calendar = '${_dir}calendar.png';
  static const String money = '${_dir}money_bag.png';
  static const String map = '${_dir}world_map.png';
  static const String bell = '${_dir}bell.png';
  static const String star = '${_dir}star.png';
  static const String pin = '${_dir}pushpin.png';
  static const String photo = '${_dir}camera.png';
  static const String checkout = '${_dir}key.png';
  static const String luggage = '${_dir}luggage.png';
  static const String airplane = '${_dir}airplane.png';
  static const String note ='${_dir}clipboard.png';
  static const String plane = '${_dir}airplane.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
  }
}
