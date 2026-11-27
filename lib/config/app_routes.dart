import 'package:get/get.dart';
import '../design/design.dart';
import '../controllers/tab_config_controller.dart' show AppTabKeys;
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/basic_details_screen.dart';
import '../screens/profile_photo_screen.dart';
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
import '../features/buddy/buddy_routes.dart';
import '../features/social/a/social_pages_a.dart';
import '../features/social/b/social_pages_b.dart';
import '../features/social/c/social_pages_c.dart';
import '../features/stay_owner/stay_owner_routes.dart';
import '../features/taxi_driver/taxi_driver_routes.dart';
import '../navigation/traveller_gate.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String intro = '/intro';
  static const String onboarding = '/onboarding';
  static const String basicDetails = '/basic-details';
  static const String profilePhoto = '/profile-photo';
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
  static const String myStays = '/my-stays';
  static const String stayDetail = '/stay-detail';

  static const String jobs = '/jobs';
  static const String myJobs = '/my-jobs';
  static const String postJob = '/post-job';
  static const String jobDetail = '/job-detail';

  static const String taxiSetup = '/taxi-setup';
  static const String taxiVehicle = '/taxi-vehicle';
  static const String taxiRoutes = '/taxi-routes';
  static const String myTaxi = '/my-taxi';
  static const String taxiDetail = '/taxi-detail';
  static const String taxiList = '/taxi-list';
  static const String taxiWays = '/taxi-ways';
  static const String journeyPlan = '/journey-plan';
  static const String journeyRoad = '/journey-road';
  static const String myJourneys = '/my-journeys';
  static const String savedJourney = '/saved-journey';

  static const String tripWhere = '/trip-where';
  static const String tripSpots = '/trip-spots';
  static const String tripPlan = '/trip-plan';
  static const String tripStay = '/trip-stay';
  static const String tripMap = '/trip-map';
  static const String myTrips = '/my-trips';
  static const String tripReplies = '/trip-replies';
  static const String myEnquiries = '/my-enquiries';
  static const String stayEnquiries = '/stay-enquiries';
  static const String tripLeads = '/trip-leads';
  static const String stayShareDetails = '/stay-share-details';

  static const String tripCustomize = '/trip-customize';
  static const String tripOverview = '/trip-overview';
  static const String tripArchived = '/trip-archived';
  static const String tripTaxiRequest = '/trip-taxi-request';
  static const String tripTaxiStatus = '/trip-taxi-status';
  static const String taxiRequestRing = '/taxi-request-ring';
  static const String taxiRequests = '/taxi-requests';
  static const String taxiRequestDetail = '/taxi-request-detail';
  static const String taxiBookings = '/taxi-bookings';
  static const String taxiRating = '/taxi-rating';
  static const String taxiReady = '/taxi-ready';

  static const String buddies = '/buddies';
  static const String buddiesBlocked = '/buddies-blocked';
  static const String buddyScan = '/buddy-scan';
  static const String tripInvite = '/trip-invite';
  static const String tripInvitePeople = '/trip-invite-people';
  static const String tripTravellers = '/trip-travellers';
  static const String tripView = '/trip-view';
  static const String tripDayPlan = '/trip-day-plan';
  static const String tripDayMap = '/trip-day-map';
  static const String tripMyShare = '/trip-my-share';
  static const String tripExpenses = '/trip-expenses';
  static const String tripExpense = '/trip-expense';
  static const String tripSettle = '/trip-settle';
  static const String tripMoneySummary = '/trip-money-summary';

  static const String settings = '/settings';
  static const String editProfile = '/edit-profile';
  static const String traveller = '/traveller';
  static const String people = '/people';
  static const String addBuddies = '/add-buddies';
  static const String travelBuddies = '/travel-buddies';
  static const String tripPost = '/trip-post';
  static const String postTrip = '/post-trip';
  static const String joinRequests = '/join-requests';
  static const String dmRoom = '/dm-room';
  static const String seekerPlus = '/seeker-plus';
  static const String travelLevels = '/travel-levels';

  static const String stayCalendar = '/stay-calendar';
  static const String stayCalendarEntry = '/stay-calendar-entry';
  static const String stayUpcoming = '/stay-upcoming';
  static const String stayPast = '/stay-past';
  static const String stayMoneySummary = '/stay-money-summary';
  static const String stayBalanceDue = '/stay-balance-due';
  static const String staySpecialPrices = '/stay-special-prices';
  static const String stayPlanVisible = '/stay-plan-visible';
  static const String stayQuotations = '/stay-quotations';
  static const String stayQuotationBusiness = '/stay-quotation-business';
  static const String stayQuotationEdit = '/stay-quotation-edit';
  static const String stayQuotationTemplate = '/stay-quotation-template';
  static const String stayQuotationPreview = '/stay-quotation-preview';
  static const String stayAttention = '/stay-attention';
  static const String stayLiveEdit = '/stay-live-edit';
  static const String stayEnquiryRing = '/stay-enquiry-ring';
  static const String stayRingReady = '/stay-ring-ready';
  static const String taxiCalendarEntry = '/taxi-calendar-entry';
  static const String taxiUpcoming = '/taxi-upcoming';
  static const String taxiPast = '/taxi-past';
  static const String taxiMoneySummary = '/taxi-money-summary';
  static const String taxiBalanceDue = '/taxi-balance-due';
  static const String taxiPlanVisible = '/taxi-plan-visible';
  static const String taxiAttention = '/taxi-attention';
  static const String taxiAvailability = '/taxi-availability';
  static const String taxiRouteResults = '/taxi-route-results';

  static const Set<String> stayOwnerNewRoutes = {
    stayCalendar,
    stayCalendarEntry,
    stayUpcoming,
    stayPast,
    stayMoneySummary,
    stayBalanceDue,
    staySpecialPrices,
    stayPlanVisible,
    stayAttention,
    stayLiveEdit,
    stayEnquiryRing,
    stayRingReady,
    stayQuotations,
    stayQuotationBusiness,
    stayQuotationEdit,
    stayQuotationTemplate,
    stayQuotationPreview,
  };
  static const Set<String> taxiDriverNewRoutes = {
    taxiCalendarEntry,
    taxiUpcoming,
    taxiPast,
    taxiMoneySummary,
    taxiBalanceDue,
    taxiPlanVisible,
    taxiAttention,
    taxiAvailability,
  };

  static const Set<String> travellerOnly = {
    tripCustomize,
    tripOverview,
    tripArchived,
    tripTaxiRequest,
    tripTaxiStatus,
    tripWhere,
    tripSpots,
    tripPlan,
    tripStay,
    tripMap,
    myTrips,
    tripReplies,
    myEnquiries,
    buddies,
    buddiesBlocked,
    buddyScan,
    tripInvite,
    tripInvitePeople,
    tripTravellers,
    tripView,
    tripDayPlan,
    tripDayMap,
    tripMyShare,
    tripExpenses,
    tripExpense,
    tripSettle,
    tripMoneySummary,
    myJourneys,
    savedJourney,
    settings,
    editProfile,
    traveller,
    people,
    addBuddies,
    travelBuddies,
    tripPost,
    postTrip,
    joinRequests,
    dmRoom,
    seekerPlus,
    travelLevels,
  };

  static const Set<String> ownerOnly = {plansBilling, planHistory};
  static const Set<String> stayOwnerOnly = {staySetup, stayBasicDetails, stayRooms, stayRules, myStays, myJobs, postJob, stayEnquiries, stayShareDetails, ...stayOwnerNewRoutes};
  static const Set<String> taxiDriverOnly = {
    taxiSetup,
    taxiVehicle,
    taxiRoutes,
    myTaxi,
    tripLeads,
    taxiRequestRing,
    taxiRequests,
    taxiRequestDetail,
    taxiBookings,
    taxiRating,
    taxiReady,
    ...taxiDriverNewRoutes,
  };

  static const Map<String, String> _routeTabKeys = {
    staySetup: AppTabKeys.stays,
    stayBasicDetails: AppTabKeys.stays,
    stayRooms: AppTabKeys.stays,
    stayRules: AppTabKeys.stays,
    stayShareDetails: AppTabKeys.stays,
    myStays: AppTabKeys.stays,
    stayDetail: AppTabKeys.stays,
    jobs: AppTabKeys.jobs,
    myJobs: AppTabKeys.jobs,
    postJob: AppTabKeys.jobs,
    jobDetail: AppTabKeys.jobs,
    taxiSetup: AppTabKeys.taxi,
    taxiVehicle: AppTabKeys.taxi,
    taxiRoutes: AppTabKeys.taxi,
    myTaxi: AppTabKeys.taxi,
    taxiDetail: AppTabKeys.taxi,
    taxiList: AppTabKeys.taxi,
    taxiWays: AppTabKeys.taxi,
    taxiRouteResults: AppTabKeys.taxi,
    journeyPlan: AppTabKeys.taxi,
    journeyRoad: AppTabKeys.taxi,
    myJourneys: AppTabKeys.taxi,
    savedJourney: AppTabKeys.taxi,
    tripLeads: AppTabKeys.taxi,
    taxiRequestRing: AppTabKeys.taxi,
    taxiRequests: AppTabKeys.taxi,
    taxiRequestDetail: AppTabKeys.taxi,
    taxiBookings: AppTabKeys.taxi,
    taxiRating: AppTabKeys.taxi,
    taxiReady: AppTabKeys.taxi,
  };

  static String? tabKeyForRoute(String route) => _routeTabKeys[route];

  static final Set<String> _registeredNames = {for (final p in routes) p.name};

  static bool isRegistered(String name) => _registeredNames.contains(name);

  static const Set<String> retiredTripTaxiRoutes = {'/trip-taxi', '/trip-taxi-replies'};

  static bool _on(Object? v) => v == true || v == 'true';

  // Old pushes name the retired trip taxi pages, or carry a question step into the plan: both land elsewhere.
  static ({String route, Map<String, dynamic>? args})? liveTarget(String? route, [Map<String, dynamic>? args]) {
    if (route == null) return null;
    if ((route == tripPlan || route == myTrips) && args?['open'] == 'myEnquiries') {
      return (
        route: myEnquiries,
        args: {
          'enquiryId': ?args!['enquiryId'],
          'bucket': ?args['bucket'],
          'stepKey': ?args['stepKey'],
          'similar': ?args['similar'],
        },
      );
    }
    final deletedTripId = args?['deletedTripId'];
    if (route == myTrips && deletedTripId is String && deletedTripId.isNotEmpty) {
      return (route: tripView, args: {'tripId': deletedTripId, 'deleted': true});
    }
    final tripId = args?['tripId'];
    if (route == tripPlan && (args?['step'] != null || args?['row'] != null || _on(args?['nudge']) || _on(args?['reopen']))) {
      return (route: tripOverview, args: {'tripId': ?tripId});
    }
    if (!retiredTripTaxiRoutes.contains(route)) return (route: route, args: args);
    return (route: tripPlan, args: {'tripId': ?tripId});
  }

  static GetPage<dynamic> _gate(GetPage<dynamic> p) =>
      travellerOnly.contains(p.name) ? p.copy(middlewares: [TravellerOnlyMiddleware()]) : p;

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
      name: basicDetails,
      page: () => const BasicDetailsScreen(),
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
      name: profilePhoto,
      page: () => const ProfilePhotoScreen(),
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
    ...taxiWaysPages.map(_gate),
    ...tripPages.map(_gate),
    ...buddyPages.map(_gate),
    ...socialPagesA.map(_gate),
    ...socialPagesB.map(_gate),
    ...socialPagesC.map(_gate),
    ...stayOwnerPages,
    ...taxiDriverPages,
  ];
}
