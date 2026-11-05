import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

class IntroSlideCopy {
  const IntroSlideCopy({
    required this.eyebrow,
    required this.headline,
    required this.sub,
    required this.top,
    required this.bottom,
    required this.accent,
  });

  final String eyebrow, headline, sub;
  final Color top, bottom, accent;
}

class IntroStrings {
  IntroStrings._();

  static const String tagline = "Let's Plan Your Perfect Trip.";
  static const String skip = 'Skip', next = 'Next', getStarted = 'Get started';

  static const List<IntroSlideCopy> slides = [
    IntroSlideCopy(
      eyebrow: 'WELCOME TO BAKHLI',
      headline: 'Your hills trip, planned',
      sub: 'Pick a city and the spots you love.',
      top: AppColors.accent,
      bottom: AppColors.primary,
      accent: AppColors.primary,
    ),
    IntroSlideCopy(
      eyebrow: 'PLAN IT',
      headline: 'Day by day, on one route',
      sub: 'Shortest route, split into days on a map.',
      top: AppColors.tripDark,
      bottom: AppColors.primary,
      accent: AppColors.tripDark,
    ),
    IntroSlideCopy(
      eyebrow: 'DIRECT, NO MIDDLEMAN',
      headline: 'Talk to hosts and drivers',
      sub: 'Get offers in chat. No commission.',
      top: AppColors.stayDark,
      bottom: AppColors.taxiDark,
      accent: AppColors.stayDark,
    ),
    IntroSlideCopy(
      eyebrow: 'ON THE DAY',
      headline: 'Your day, in one card',
      sub: "See today's plan. Share the trip summary.",
      top: AppColors.taxi,
      bottom: AppColors.taxiDark,
      accent: AppColors.taxiDark,
    ),
    IntroSlideCopy(
      eyebrow: 'BAKHLI',
      headline: tagline,
      sub: 'Stays and taxis, straight from locals.',
      top: AppColors.textDark,
      bottom: AppColors.primary,
      accent: AppColors.textDark,
    ),
  ];

  static String spotsPicked(int n) => n == 1 ? '1 spot picked' : '$n spots picked';

  static const String city = 'Nainital';
  static const List<String> pickSpots = ['Naini Lake', 'Snow View', 'Tiffin Top', 'Mall Road'];
  static const String nodeA = 'Nainital', nodeB = 'Bhimtal', nodeC = 'Kainchi Dham';
  static const String day1 = 'Day 1 · 3 stops', day2 = 'Day 2 · 2 stops', changeCar = 'Change car';
  static const String commission = 'Commission', noCommission = 'No commission';
  static const String ask = 'Room for 2, 14 Dec?',
      sent = 'Sent',
      offerReceived = 'Offer received',
      accept = 'Accept',
      accepted = 'Accepted',
      fareSent = 'Fare sent';
  static const String todayTitle = 'Today · Day 2', todayProgress = '2 of 3 done', todayDone = 'All done today';
  static const List<String> todayRows = ['8:30 Pickup · Bhimtal', 'Kainchi Dham', 'Check in · Lakeside stay'];
  static const String shareSummary = 'Share summary';
  static const String ownerLine = 'Own a stay or taxi? List it free.';
}
