import 'package:get/get.dart';
import '../screens/splash_screen.dart';
import '../screens/otp_screen.dart';
import '../screens/main_screen.dart';
import '../screens/listing_detail_screen.dart';
import '../screens/add_listing_screen.dart';
import '../screens/payment_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String otp = '/otp';
  static const String main = '/main';
  static const String listingDetail = '/listing-detail';
  static const String addListing = '/add-listing';
  static const String paymentScreen = '/payment-screen';

  static final routes = [
    GetPage(name: splash, page: () => const SplashScreen()),
    GetPage(
      name: otp,
      page: () => const OtpScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: main,
      page: () => const MainScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: listingDetail,
      page: () => const ListingDetailScreen(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 350),
    ),
    GetPage(
      name: addListing,
      page: () => const AddListingScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 350),
    ),
    GetPage(
      name: paymentScreen,
      page: () => const PaymentScreen(),
      transition: Transition.upToDown,
      transitionDuration: const Duration(milliseconds: 350),
    ),
  ];
}
