import 'package:get/get.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/app_intro_screen.dart';
import '../screens/phone_verify_screen.dart';
import '../screens/main_screen.dart';
import '../screens/listing_detail_screen.dart';
import '../screens/add_listing_screen.dart';
import '../screens/add_plot_screen.dart';
import '../screens/my_listings_screen.dart';
import '../screens/my_plots_screen.dart';
import '../screens/plot_detail_screen.dart';
import '../screens/chat_conversation_screen.dart';
import '../screens/chats_list_screen.dart';
import '../screens/listing_reports_screen.dart';
import '../screens/report_detail_screen.dart';
import '../screens/my_filed_reports_screen.dart';
import '../screens/credit_packs_screen.dart';
import '../screens/redeem_code_screen.dart';
import '../screens/wallet_ledger_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/role_select_screen.dart';
import '../screens/role_change_screen.dart';
import '../features/stay/stay_routes.dart';
import '../features/jobs/jobs_routes.dart';
import '../features/taxi/taxi_routes.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String intro = '/intro';
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
  static const String chatConversation = '/chat-conversation';
  static const String chatsList = '/chats-list';
  static const String listingReports = '/listing-reports';
  static const String reportDetail = '/report-detail';
  static const String myFiledReports = '/my-filed-reports';
  static const String creditPacks = '/credit-packs';
  static const String redeemCode = '/redeem-code';
  static const String walletLedger = '/wallet-ledger';

  // Notification inbox — backs the Home-screen bell icon.
  static const String notifications = '/notifications';

  static const String roleSelect = '/role-select';
  static const String roleChange = '/role-change';

  static const String staySetup = '/stay-setup';
  static const String stayBasicDetails = '/stay-basic-details';
  static const String stayRooms = '/stay-rooms';
  static const String stayRules = '/stay-rules';
  static const String staySubmit = '/stay-submit';
  static const String myStays = '/my-stays';
  static const String stayDetail = '/stay-detail';

  static const String myJobs = '/my-jobs';
  static const String postJob = '/post-job';
  static const String jobDetail = '/job-detail';

  static const String taxiSetup = '/taxi-setup';
  static const String taxiVehicle = '/taxi-vehicle';
  static const String taxiRoutes = '/taxi-routes';
  static const String taxiSubmit = '/taxi-submit';
  static const String myTaxi = '/my-taxi';
  static const String taxiDetail = '/taxi-detail';
  static const String taxiList = '/taxi-list';

  static const Set<String> roomOwnerOnly = {myListings, addListing};
  static const Set<String> plotOwnerOnly = {myPlots, addPlot};
  static const Set<String> stayOwnerOnly = {staySetup, stayBasicDetails, stayRooms, stayRules, staySubmit, myStays, myJobs, postJob};
  static const Set<String> taxiDriverOnly = {taxiSetup, taxiVehicle, taxiRoutes, taxiSubmit, myTaxi};

  static final routes = [
    GetPage(name: splash, page: () => const SplashScreen()),
    GetPage(
      name: login,
      page: () => const LoginScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: intro,
      page: () => const AppIntroScreen(),
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
      name: creditPacks,
      page: () => const CreditPacksScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: redeemCode,
      page: () => const RedeemCodeScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: walletLedger,
      page: () => const WalletLedgerScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: chatConversation,
      page: () => const ChatConversationScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: chatsList,
      page: () => const ChatsListScreen(),
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
    GetPage(
      name: notifications,
      page: () => const NotificationsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: roleSelect,
      page: () => const RoleSelectScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: roleChange,
      page: () => const RoleChangeScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    ...stayPages,
    ...jobPages,
    ...taxiPages,
  ];
}
