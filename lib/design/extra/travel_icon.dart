import 'package:flutter/material.dart';

class TravelIcon extends StatelessWidget {
  const TravelIcon(this.asset, {super.key, this.size = 24});

  final String asset;
  final double size;

  static const String _dir = 'assets/images/design/travel3d/';
  static const String taxi = '${_dir}taxi.png';
  static const String stay = '${_dir}camping.png';
  static const String search = '${_dir}magnifying_glass_tilted_left.png';
  static const String profile = '${_dir}fox.png';
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
  static const String fox = '${_dir}fox.png';
  static const String seedling = '${_dir}seedling.png';
  static const String cardIndex = '${_dir}card_index_dividers.png';
  static const String alarmClock = '${_dir}alarm_clock.png';
  static const String memo = '${_dir}memo.png';
  static const String shield = '${_dir}shield.png';
  static const String locked = '${_dir}locked.png';
  static const String mobilePhone = '${_dir}mobile_phone.png';
  static const String hinduTemple = '${_dir}hindu_temple.png';
  static const String sunriseMountains = '${_dir}sunrise_over_mountains.png';
  static const String canoe = '${_dir}canoe.png';
  static const String ferrisWheel = '${_dir}ferris_wheel.png';
  static const String classicalBuilding = '${_dir}classical_building.png';
  static const String tiger = '${_dir}tiger.png';
  static const String droplet = '${_dir}droplet.png';
  static const String rock = '${_dir}rock.png';
  static const String framedPicture = '${_dir}framed_picture.png';
  static const String lion = '${_dir}lion.png';
  static const String bridge = '${_dir}bridge_at_night.png';
  static const String castle = '${_dir}castle.png';
  static const String crown = '${_dir}crown.png';
  static const String diyaLamp = '${_dir}diya_lamp.png';
  static const String tree = '${_dir}deciduous_tree.png';
  static const String tulip = '${_dir}tulip.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
  }
}
