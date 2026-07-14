import 'package:get/get.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/phone_verify_screen.dart';
import '../screens/main_screen.dart';
import '../screens/listing_detail_screen.dart';
import '../screens/add_listing_screen.dart';
import '../screens/add_plot_screen.dart';
import '../screens/my_listings_screen.dart';
import '../screens/my_plots_screen.dart';
import '../screens/payment_screen.dart';
import '../screens/plot_detail_screen.dart';
import '../screens/chat_conversation_screen.dart';
import '../screens/listing_reports_screen.dart';
import '../screens/report_detail_screen.dart';
import '../screens/my_filed_reports_screen.dart';
import '../screens/view_all_screen.dart';
import '../controllers/view_all_controller.dart' show ViewAllListingType;

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String phoneVerify = '/phone-verify';
  // keep /otp as alias for phone-verify (backward compat for any deep links)
  static const String otp = '/otp';
  static const String main = '/main';
  static const String listingDetail = '/listing-detail';
  static const String plotDetail = '/plot-detail';
  static const String addListing = '/add-listing';
  static const String addPlot = '/add-plot';
  static const String myListings = '/my-listings';
  static const String myPlots = '/my-plots';
  static const String paymentScreen = '/payment-screen';
  static const String chatConversation = '/chat-conversation';
  static const String listingReports = '/listing-reports';
  static const String reportDetail = '/report-detail';
  static const String myFiledReports = '/my-filed-reports';
  static const String viewAllRooms = '/view-all-rooms';
  static const String viewAllPlots = '/view-all-plots';
  static final routes = [
    GetPage(name: splash, page: () => const SplashScreen()),
    GetPage(
      name: login,
      page: () => const LoginScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: onboarding,
      page: () => const OnboardingScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: phoneVerify,
      page: () => const PhoneVerifyScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: otp,
      page: () => const PhoneVerifyScreen(),
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
      name: plotDetail,
      page: () => const PlotDetailScreen(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 350),
    ),
    GetPage(
      name: addListing,
      page: () => const AddListingScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: addPlot,
      page: () => const AddPlotScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: myListings,
      page: () => const MyListingsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: myPlots,
      page: () => const MyPlotsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: viewAllRooms,
      page: () => ViewAllScreen(
        listingType: ViewAllListingType.rooms,
        initialTypeId: (Get.arguments as Map?)?['typeId'] as String?,
      ),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: viewAllPlots,
      page: () => ViewAllScreen(
        listingType: ViewAllListingType.plots,
        initialTypeId: (Get.arguments as Map?)?['typeId'] as String?,
      ),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: paymentScreen,
      page: () => const PaymentScreen(),
      transition: Transition.upToDown,
      transitionDuration: const Duration(milliseconds: 350),
    ),
    GetPage(
      name: chatConversation,
      page: () => const ChatConversationScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: listingReports,
      page: () => const ListingReportsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: reportDetail,
      page: () => const ReportDetailScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: myFiledReports,
      page: () => const MyFiledReportsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  ];
}
