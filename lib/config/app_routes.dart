import 'package:get/get.dart';
import '../design/design.dart';
import '../controllers/tab_config_controller.dart' show AppTabKeys;
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/app_intro_screen.dart';
import '../screens/phone_verify_screen.dart';
import '../screens/main_screen.dart';
import '../screens/chat_conversation_screen.dart';
import '../screens/chats_list_screen.dart';
import '../screens/listing_reports_screen.dart';
import '../screens/report_detail_screen.dart';
import '../screens/my_filed_reports_screen.dart';
import '../screens/plans_billing_screen.dart';
import '../screens/plan_history_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/role_select_screen.dart';
import '../screens/role_change_screen.dart';
import '../features/stay/stay_routes.dart';
import '../features/jobs/jobs_routes.dart';
import '../features/taxi/taxi_routes.dart';
import '../features/taxi/ways/taxi_ways_routes.dart';
import '../features/trip/trip_routes.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String intro = '/intro';
  static const String onboarding = '/onboarding';
  static const String phoneVerify = '/phone-verify';
  // keep /otp as alias for phone-verify (backward compat for any deep links)
  static const String otp = '/otp';
  static const String main = '/main';
  static const String chatConversation = '/chat-conversation';
  static const String chatsList = '/chats-list';
  static const String listingReports = '/listing-reports';
  static const String reportDetail = '/report-detail';
  static const String myFiledReports = '/my-filed-reports';
  static const String plansBilling = '/plans';
  static const String planHistory = '/plans/history';

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

  static const String jobs = '/jobs';
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
  static const String taxiWays = '/taxi-ways';
  static const String journeyPlan = '/journey-plan';
  static const String journeyRoad = '/journey-road';
  static const String myJourneys = '/my-journeys';
  static const String savedJourney = '/saved-journey';

  static const String tripSpots = '/trip-spots';
  static const String tripPlan = '/trip-plan';
  static const String tripTaxi = '/trip-taxi';
  static const String tripStay = '/trip-stay';
  static const String tripMap = '/trip-map';
  static const String myTrips = '/my-trips';
  static const String tripReplies = '/trip-replies';
  static const String stayEnquiries = '/stay-enquiries';
  static const String tripLeads = '/trip-leads';
  static const String tripTaxiReplies = '/trip-taxi-replies';
  static const String tripSummary = '/trip-summary';
  static const String stayAdvanceDetails = '/stay-advance-details';

  static const Set<String> ownerOnly = {plansBilling, planHistory};
  static const Set<String> stayOwnerOnly = {staySetup, stayBasicDetails, stayRooms, stayRules, staySubmit, myStays, myJobs, postJob, stayEnquiries, stayAdvanceDetails};
  static const Set<String> taxiDriverOnly = {taxiSetup, taxiVehicle, taxiRoutes, taxiSubmit, myTaxi, tripLeads};

  static const Map<String, String> _routeTabKeys = {
    staySetup: AppTabKeys.stays,
    stayBasicDetails: AppTabKeys.stays,
    stayRooms: AppTabKeys.stays,
    stayRules: AppTabKeys.stays,
    staySubmit: AppTabKeys.stays,
    stayAdvanceDetails: AppTabKeys.stays,
    myStays: AppTabKeys.stays,
    stayDetail: AppTabKeys.stays,
    jobs: AppTabKeys.jobs,
    myJobs: AppTabKeys.jobs,
    postJob: AppTabKeys.jobs,
    jobDetail: AppTabKeys.jobs,
    taxiSetup: AppTabKeys.taxi,
    taxiVehicle: AppTabKeys.taxi,
    taxiRoutes: AppTabKeys.taxi,
    taxiSubmit: AppTabKeys.taxi,
    myTaxi: AppTabKeys.taxi,
    taxiDetail: AppTabKeys.taxi,
    taxiList: AppTabKeys.taxi,
    taxiWays: AppTabKeys.taxi,
    journeyPlan: AppTabKeys.taxi,
    journeyRoad: AppTabKeys.taxi,
    myJourneys: AppTabKeys.taxi,
    savedJourney: AppTabKeys.taxi,
  };

  static String? tabKeyForRoute(String route) => _routeTabKeys[route];

  static final Set<String> _registeredNames = {for (final p in routes) p.name};

  static bool isRegistered(String name) => _registeredNames.contains(name);

  static final routes = [
    GetPage(name: splash, page: () => const SplashScreen()),
    GetPage(
      name: login,
      page: () => const LoginScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: intro,
      page: () => const AppIntroScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: onboarding,
      page: () => const OnboardingScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: phoneVerify,
      page: () => const PhoneVerifyScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: otp,
      page: () => const PhoneVerifyScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: main,
      page: () => const MainScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: plansBilling,
      page: () => const PlansBillingScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: planHistory,
      page: () => const PlanHistoryScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: chatConversation,
      page: () => const ChatConversationScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: chatsList,
      page: () => const ChatsListScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: listingReports,
      page: () => const ListingReportsScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: reportDetail,
      page: () => const ReportDetailScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: myFiledReports,
      page: () => const MyFiledReportsScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: notifications,
      page: () => const NotificationsScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: roleSelect,
      page: () => const RoleSelectScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    GetPage(
      name: roleChange,
      page: () => const RoleChangeScreen(),
      customTransition: TemplateTransition(),
      transitionDuration: templateTransitionDuration,
    ),
    ...stayPages,
    ...jobPages,
    ...taxiPages,
    ...taxiWaysPages,
    ...tripPages,
  ];
}
