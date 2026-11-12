import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../design/tokens/design_colors.dart';

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
  static const String skip = 'Skip', next = 'Next', getStarted = 'Start planning';

  static const List<IntroSlideCopy> slides = [
    IntroSlideCopy(
      eyebrow: 'WELCOME TO BAKHLI',
      headline: 'Trips worth remembering',
      sub: 'Discover places, plan every day and travel in comfort.',
      top: AppColors.accent,
      bottom: AppColors.primary,
      accent: AppColors.primary,
    ),
    IntroSlideCopy(
      eyebrow: 'PLAN',
      headline: 'Every day, beautifully planned',
      sub: 'Your places arranged into a smooth route, day by day.',
      top: AppColors.tripDark,
      bottom: AppColors.primary,
      accent: AppColors.tripDark,
    ),
    IntroSlideCopy(
      eyebrow: 'STAY',
      headline: 'Stay somewhere special',
      sub: 'Homestays to luxury retreats, matched to your style.',
      top: AppColors.stayDark,
      bottom: DesignColors.introPlum,
      accent: AppColors.stayDark,
    ),
    IntroSlideCopy(
      eyebrow: 'TAXI',
      headline: 'Ride in comfort',
      sub: 'Comfortable cars for every leg of your trip.',
      top: AppColors.taxi,
      bottom: AppColors.taxiDark,
      accent: AppColors.taxiDark,
    ),
    IntroSlideCopy(
      eyebrow: 'ON THE DAY',
      headline: 'Your day, always at hand',
      sub: "Today's plan, timings and bookings in one place.",
      top: DesignColors.introSky,
      bottom: AppColors.taxiDark,
      accent: AppColors.taxiDark,
    ),
    IntroSlideCopy(
      eyebrow: 'BAKHLI',
      headline: tagline,
      sub: 'Great stays, comfortable rides, one effortless plan.',
      top: AppColors.textDark,
      bottom: AppColors.primary,
      accent: AppColors.textDark,
    ),
  ];

  static String stylesPicked(int n) => n == 1 ? '1 style picked' : '$n styles picked';

  static const List<String> travelStyles = [
    'Mountains',
    'Beaches',
    'Heritage',
    'Nature',
    'Food',
    'Spiritual',
    'Adventure',
    'Family',
  ];
  static const String nodeA = 'Arrive', nodeB = 'Explore', nodeC = 'Unwind';
  static const String day1 = 'Day 1 · 3 stops', day2 = 'Day 2 · 2 stops', yourRide = 'Your ride';
  static const String stayTitle = 'Luxury stay', stayTimes = 'Check in 11 AM · Check out 10 AM';
  static const List<String> stayStyles = ['Homestay', 'Hostel', 'Hotel'];
  static const String reserve = 'Enquire', reserved = 'Request sent', stayConfirmed = 'Host replies soon';
  static const String ridesTitle = 'Your rides';
  static const List<String> rideRows = ['Getting there', 'Sightseeing, day by day', 'Coming back'];
  static const List<String> carTypes = ['Sedan', 'SUV', 'Traveller'];
  static const String todayTitle = 'Today · Day 2', todayProgress = '2 of 3 done', todayDone = 'All done today';
  static const List<String> todayRows = ['8:30 AM Pickup', 'Sightseeing stops', 'Check in'];
  static const String shareTrip = 'Share trip';
  static const String nextTrip = 'Your next trip', ringValue = '0%';
}
